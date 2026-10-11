import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';

String persianCount(Object? value) {
  final text = '${value ?? 0}'.replaceAllMapped(
    RegExp(r'(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return text.replaceAllMapped(
    RegExp(r'\d'),
    (m) => String.fromCharCode(m[0]!.codeUnitAt(0) + 1728),
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      context.select<AuthCubit, bool>((c) => c.state is Guest)
          ? const _PreviewHome()
          : const _LiveHome();
}

class _LiveHome extends StatefulWidget {
  const _LiveHome();
  @override
  State<_LiveHome> createState() => _LiveHomeState();
}

class _LiveHomeState extends State<_LiveHome> {
  late Future<Map<String, dynamic>> _summary = _load();
  Future<Map<String, dynamic>> _load() async {
    final result = await getIt<Dio>().get<Map<String, dynamic>>(
      '/api/v1/dashboard/summary',
    );
    final data = result.data?['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('پاسخ سرور معتبر نیست.');
    }
    return data;
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: RefreshIndicator(
      onRefresh: () async {
        final future = _load();
        setState(() => _summary = future);
        try {
          await future;
        } catch (_) {
          /* Error shown in the page. */
        }
      },
      child: FutureBuilder<Map<String, dynamic>>(
        future: _summary,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return ListView(
              children: [
                _Card(
                  title: 'دریافت اطلاعات خانه انجام نشد',
                  child: FilledButton(
                    onPressed: () => setState(() => _summary = _load()),
                    child: const Text('تلاش دوباره'),
                  ),
                ),
              ],
            );
          }
          final data = snapshot.data!;
          final state = Map<String, dynamic>.from(
            data['system_state'] as Map? ?? {},
          );
          final code = (state['code'] as num?)?.toInt() ?? 1;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              const _IntroductionWidget(),
              const SizedBox(height: 14),
              _SystemStateCard(
                title: code == 1 ? '' : '${state['title'] ?? ''}',
                registeredUsers: data['active_user_count'],
                remainingUsers: code == 1 ? state['remaining_users'] : null,
              ),
              const SizedBox(height: 14),
              _GeoWidget(
                geography: Map<String, dynamic>.from(
                  data['geography'] as Map? ?? {},
                ),
                total: data['active_user_count'],
              ),
              const SizedBox(height: 14),
              const _EventsWidget(),
            ],
          );
        },
      ),
    ),
  );
}

class _PreviewHome extends StatefulWidget {
  const _PreviewHome();
  @override
  State<_PreviewHome> createState() => _PreviewHomeState();
}

class _PreviewHomeState extends State<_PreviewHome> {
  late Future<_PreviewHomeData> _previewData = _loadPreviewData();

  Future<_PreviewHomeData> _loadPreviewData() async {
    final dio = getIt<Dio>();
    final results = await Future.wait([
      dio.get<Map<String, dynamic>>('/api/v1/public/active-users'),
      dio.get<Map<String, dynamic>>(
        '/api/v1/public/geography-user-counts',
        queryParameters: {'level': 'province'},
      ),
    ]);
    final countData = results[0].data?['data'];
    final activeCount =
        countData is Map ? countData['active_user_count'] : null;
    if (activeCount is! num) {
      throw const FormatException('تعداد کاربران از سرور دریافت نشد.');
    }

    final provinces = _decodeAreas(results[1].data);
    return _PreviewHomeData(
      activeUsers: activeCount.toInt(),
      geography: {'provinces': provinces},
    );
  }

  Future<List<Map<String, dynamic>>> _loadGeographyChildren(
    String level,
    int parentId,
  ) async {
    final type = switch (level) {
      'provinces' => 'province',
      'counties' => 'county',
      _ => 'settlement',
    };
    final response = await getIt<Dio>().get<Map<String, dynamic>>(
      '/api/v1/public/geography-user-counts',
      queryParameters: {
        'level': type,
        if (type != 'province') 'parent_id': parentId,
      },
    );
    return _decodeAreas(response.data);
  }

  List<Map<String, dynamic>> _decodeAreas(Object? response) {
    final data = response is Map ? response['data'] : null;
    if (data is! List) {
      throw const FormatException('پاسخ حوزه‌های جغرافیایی معتبر نیست.');
    }
    return data
        .whereType<Map>()
        .map((item) {
          final row = Map<String, dynamic>.from(item);
          return {
            ...row,
            'active_user_count':
                (row['active_user_count'] as num?)?.toInt() ?? 0,
          };
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: FutureBuilder<_PreviewHomeData>(
      future: _previewData,
      builder: (context, snapshot) {
        final children = <Widget>[
          const _IntroductionWidget(),
          const SizedBox(height: 14),
        ];
        if (snapshot.hasError) {
          children.add(
            _Card(
              title: 'دریافت تعداد کاربران انجام نشد',
              child: TextButton.icon(
                onPressed:
                    () => setState(() => _previewData = _loadPreviewData()),
                icon: const Icon(Icons.refresh),
                label: const Text('تلاش دوباره'),
              ),
            ),
          );
        } else if (!snapshot.hasData) {
          children.add(
            const _Card(
              title: 'تعداد کاربران ثبت‌نام‌شده',
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        } else {
          final preview = snapshot.data!;
          final total = preview.activeUsers;
          children
            ..add(
              _SystemStateCard(
                title: '',
                registeredUsers: total,
                remainingUsers: (44000000 - total).clamp(0, 44000000),
              ),
            )
            ..add(const SizedBox(height: 14))
            ..add(
              _GeoWidget(
                geography: preview.geography,
                total: total,
                loadChildren: _loadGeographyChildren,
              ),
            )
            ..add(const SizedBox(height: 14))
            ..add(const _EventsWidget());
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: children,
        );
      },
    ),
  );
}

class _IntroductionWidget extends StatelessWidget {
  const _IntroductionWidget();
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      leading: const Icon(Icons.menu_book_outlined, color: AppTheme.primary),
      title: const Text('معرفی وِتواَپ'),
      trailing: const Icon(Icons.chevron_left),
      onTap: () => context.go('/about'),
    ),
  );
}

class _PreviewHomeData {
  const _PreviewHomeData({required this.activeUsers, required this.geography});
  final int activeUsers;
  final Map<String, dynamic> geography;
}

class _SystemStateCard extends StatelessWidget {
  const _SystemStateCard({
    required this.title,
    required this.registeredUsers,
    required this.remainingUsers,
  });
  final String title;
  final Object? registeredUsers;
  final Object? remainingUsers;

  static const int _activationThreshold = 44000000;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppTheme.primaryDark,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title.trim().isNotEmpty) ...[
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 14),
        ],
        _countRow(
          'تعداد کاربران مورد نیاز برای شروع به کار سامانه',
          '${persianCount(_activationThreshold)} نفر',
          Colors.white,
        ),
        const Divider(color: Color(0x55FFFFFF), height: 18),
        _countRow(
          'تعداد کاربران ثبت‌نام‌شده تا این لحظه',
          '${persianCount(registeredUsers)} نفر',
          Colors.black,
          outlined: true,
        ),
        if (remainingUsers != null) ...[
          const Divider(color: Color(0x55FFFFFF), height: 18),
          _countRow(
            'تعداد کاربران باقی‌مانده برای شروع به کار سامانه',
            '${persianCount(remainingUsers)} نفر',
            Colors.white,
          ),
        ],
      ],
    ),
  );

  Widget _countRow(
    String label,
    String value,
    Color color, {
    bool outlined = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          height: 1.45,
          shadows: outlined ? _whiteOutline : null,
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.4,
          shadows: outlined ? _whiteOutline : null,
        ),
        textAlign: TextAlign.center,
      ),
    ],
  );

  static const _whiteOutline = <Shadow>[
    Shadow(color: Colors.white, offset: Offset(-1, 0), blurRadius: 1),
    Shadow(color: Colors.white, offset: Offset(1, 0), blurRadius: 1),
    Shadow(color: Colors.white, offset: Offset(0, -1), blurRadius: 1),
    Shadow(color: Colors.white, offset: Offset(0, 1), blurRadius: 1),
  ];
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppTheme.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _GeoWidget extends StatefulWidget {
  const _GeoWidget({
    required this.geography,
    required this.total,
    this.loadChildren,
  });
  final Map<String, dynamic> geography;
  final Object? total;
  final Future<List<Map<String, dynamic>>> Function(String, int)? loadChildren;
  @override
  State<_GeoWidget> createState() => _GeoWidgetState();
}

class _GeoWidgetState extends State<_GeoWidget> {
  late final Map<String, dynamic> _geography = Map.of(widget.geography);
  final Set<String> _loading = {};
  int? provinceId, countyId, settlementId;
  List<Map<String, dynamic>> _rows(String key, [int? parent]) =>
      (_geography[key] as List? ?? [])
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .where(
            (r) =>
                parent == null || (r['parent_id'] as num?)?.toInt() == parent,
          )
          .toList();
  Widget _choice(
    String label,
    String key,
    List<Map<String, dynamic>> rows,
    int? selected,
    ValueChanged<int?> changed, {
    int? parentId,
  }) {
    if (rows.isEmpty && (widget.loadChildren == null || parentId == null)) {
      return const SizedBox.shrink();
    }
    Map<String, dynamic>? selectedRow;
    for (final row in rows) {
      if ((row['id'] as num).toInt() == selected) {
        selectedRow = row;
        break;
      }
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          var available = rows;
          final cacheKey = '$key:$parentId';
          if (available.isEmpty &&
              widget.loadChildren != null &&
              parentId != null) {
            setState(() => _loading.add(cacheKey));
            try {
              final loaded = await widget.loadChildren!(key, parentId);
              final existing =
                  (_geography[key] as List? ?? []).whereType<Map>().toList();
              final knownIds = existing.map((row) => row['id']).toSet();
              _geography[key] = [
                ...existing,
                ...loaded.where((row) => !knownIds.contains(row['id'])),
              ];
              available = _rows(key, parentId);
            } catch (_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('دریافت فهرست $label انجام نشد.')),
                );
              }
            } finally {
              if (mounted) setState(() => _loading.remove(cacheKey));
            }
          }
          if (!mounted || available.isEmpty) return;
          final value = await showModalBottomSheet<int>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => _GeoSearchSheet(label: label, rows: available),
          );
          if (value != null) changed(value);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon:
                _loading.contains('$key:$parentId')
                    ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                    : const Icon(Icons.search),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selectedRow == null
                      ? 'انتخاب $label'
                      : '${selectedRow['name']}  (${persianCount(selectedRow['active_user_count'])} نفر)',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _Card(
    title: 'گستره کاربران',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('ایران: ${persianCount(widget.total)} نفر'),
        _choice(
          'استان',
          'provinces',
          _rows('provinces'),
          provinceId,
          (value) => setState(() {
            provinceId = value;
            countyId = null;
            settlementId = null;
          }),
        ),
        if (provinceId != null)
          _choice(
            'شهرستان',
            'counties',
            _rows('counties', provinceId),
            countyId,
            (value) => setState(() {
              countyId = value;
              settlementId = null;
            }),
            parentId: provinceId,
          ),
        if (countyId != null)
          _choice(
            'شهر / روستا',
            'settlements',
            _rows('settlements', countyId),
            settlementId,
            (value) => setState(() => settlementId = value),
            parentId: countyId,
          ),
      ],
    ),
  );
}

class _GeoSearchSheet extends StatefulWidget {
  const _GeoSearchSheet({required this.label, required this.rows});
  final String label;
  final List<Map<String, dynamic>> rows;

  @override
  State<_GeoSearchSheet> createState() => _GeoSearchSheetState();
}

class _GeoSearchSheetState extends State<_GeoSearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    String normalize(String value) => value
        .trim()
        .toLowerCase()
        .replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll('\u200c', ' ');

    final normalizedQuery = normalize(_query);
    final matches =
        normalizedQuery.isEmpty
            ? widget.rows
            : widget.rows
                .where(
                  (row) =>
                      normalize('${row['name']}').contains(normalizedQuery),
                )
                .toList(growable: false);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.82,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: TextField(
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  labelText: 'جست‌وجوی ${widget.label}',
                  hintText: 'نام ${widget.label} را وارد کنید',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child:
                  matches.isEmpty
                      ? const Center(child: Text('موردی پیدا نشد.'))
                      : ListView.builder(
                        itemCount: matches.length,
                        itemBuilder: (context, index) {
                          final row = matches[index];
                          return ListTile(
                            title: Text('${row['name']}'),
                            trailing: Text(
                              '${persianCount(row['active_user_count'])} نفر',
                              textAlign: TextAlign.left,
                            ),
                            onTap:
                                () => Navigator.of(
                                  context,
                                ).pop((row['id'] as num).toInt()),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventsWidget extends StatelessWidget {
  const _EventsWidget();
  @override
  Widget build(BuildContext context) {
    const types = <String, (String, String, IconData, Color)>{
      'referendum': (
        'آخرین همه‌پرسی‌های در حال برگزاری',
        '/referendum/voting/live-results',
        Icons.how_to_vote_outlined,
        AppTheme.success,
      ),
      'election': (
        'آخرین انتخابات‌های در حال برگزاری',
        '/elections/voting',
        Icons.ballot_outlined,
        AppTheme.election,
      ),
      'impeachment': (
        'آخرین استیضاح‌های در حال برگزاری',
        '/impeachment',
        Icons.gavel_outlined,
        AppTheme.danger,
      ),
    };
    return _Card(
      title: 'آخرین رویدادهای وِتواَپ',
      child: Column(
        children:
            types.entries.map((entry) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(entry.value.$3, color: entry.value.$4),
                title: Text(entry.value.$1),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => context.go(entry.value.$2),
              );
            }).toList(),
      ),
    );
  }
}
