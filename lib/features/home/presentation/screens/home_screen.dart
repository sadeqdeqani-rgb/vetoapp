import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

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
  bool _submittingRequest = false;

  Future<_PreviewHomeData> _loadPreviewData() async {
    final response = await getIt<Dio>().get<Map<String, dynamic>>(
      '/api/v1/public/activation-requests/count',
    );
    final countData = response.data?['data'];
    if (countData is! Map ||
        countData['request_count'] is! num ||
        countData['required_count'] is! num ||
        countData['remaining_count'] is! num) {
      throw const FormatException('آمار درخواست‌های شروع سامانه معتبر نیست.');
    }
    return _PreviewHomeData(
      requestCount: (countData['request_count'] as num).toInt(),
      requiredCount: (countData['required_count'] as num).toInt(),
      remainingCount: (countData['remaining_count'] as num).toInt(),
    );
  }

  Future<void> _submitActivationRequest() async {
    if (_submittingRequest) return;
    final approved = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('تأیید درخواست'),
            content: const Text(
              'درخواست شما برای شروع به کار سامانه ثبت شود؟ برای جلوگیری از ثبت تکراری، شناسه‌ای با حفظ حریم خصوصی از دستگاه به سرور ارسال می‌شود.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                height: 1.6,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('بازگشت'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('تأیید و ثبت'),
              ),
            ],
          ),
    );
    if (approved != true || !mounted) return;
    setState(() => _submittingRequest = true);
    try {
      final identity = await const MethodChannel(
        'vetoapp/activation-device',
      ).invokeMapMethod<String, dynamic>('getActivationDeviceIdentity');
      if (identity == null) throw StateError('شناسه دستگاه در دسترس نیست.');
      final response = await getIt<Dio>().post<Map<String, dynamic>>(
        '/api/v1/public/activation-requests',
        data: identity,
      );
      final data = response.data?['data'];
      final message =
          data is Map && data['message'] is String
              ? data['message'] as String
              : response.data?['message'] as String? ?? 'پاسخ سرور دریافت نشد.';
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      );
      setState(() => _previewData = _loadPreviewData());
    } catch (error) {
      if (!mounted) return;
      final message =
          error is DioException
              ? (error.response?.data is Map
                  ? ((error.response!.data as Map)['message'] as String? ??
                      'ثبت درخواست انجام نشد؛ اتصال اینترنت را بررسی کنید.')
                  : 'ثبت درخواست انجام نشد؛ اتصال اینترنت را بررسی کنید.')
              : error is PlatformException
              ? (error.message ?? 'بررسی شناسه دستگاه انجام نشد.')
              : error is StateError
              ? error.message
              : 'ثبت درخواست انجام نشد؛ دوباره تلاش کنید.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submittingRequest = false);
    }
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
          _ActivationIntentWidget(
            onTap: _submittingRequest ? null : _submitActivationRequest,
            submitting: _submittingRequest,
          ),
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
              title: 'در حال دریافت آمار درخواست‌ها',
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        } else {
          final preview = snapshot.data!;
          children
            ..add(
              _ActivationCountCard(
                requiredCount: preview.requiredCount,
                requestCount: preview.requestCount,
                remainingCount: preview.remainingCount,
              ),
            )
            ..add(const SizedBox(height: 14));
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
  const _PreviewHomeData({
    required this.requestCount,
    required this.requiredCount,
    required this.remainingCount,
  });
  final int requestCount;
  final int requiredCount;
  final int remainingCount;
}

class _ActivationIntentWidget extends StatelessWidget {
  const _ActivationIntentWidget({
    required this.onTap,
    required this.submitting,
  });
  final VoidCallback? onTap;
  final bool submitting;
  @override
  Widget build(BuildContext context) => Card(
    color: AppTheme.primary.withValues(alpha: 0.1),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'من درخواست شروع به کار سامانه و آغاز انقلاب سوم در ایران را دارم',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                height: 1.65,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              submitting
                  ? 'در حال ثبت درخواست...'
                  : 'برای ثبت درخواست لمس کنید',
              style: TextStyle(
                color: AppTheme.primaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (submitting) ...[
              const SizedBox(height: 8),
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _ActivationCountCard extends StatelessWidget {
  const _ActivationCountCard({
    required this.requiredCount,
    required this.requestCount,
    required this.remainingCount,
  });
  final int requiredCount;
  final int requestCount;
  final int remainingCount;
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
        _countRow(
          'تعداد متقاضیان مورد نیاز برای شروع به کار سامانه',
          '${persianCount(requiredCount)} نفر',
          Colors.white,
        ),
        const Divider(color: Color(0x55FFFFFF), height: 20),
        _countRow(
          'تعداد متقاضیانی که درخواست خود را ثبت کرده‌اند',
          '${persianCount(requestCount)} نفر',
          Colors.white,
        ),
        const Divider(color: Color(0x55FFFFFF), height: 20),
        _countRow(
          'تعداد متقاضیان باقی‌مانده',
          '${persianCount(remainingCount)} نفر',
          Colors.white,
        ),
      ],
    ),
  );

  Widget _countRow(String label, String value, Color color) => Column(
    children: [
      Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.45,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
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
  const _GeoWidget({required this.geography, required this.total});
  final Map<String, dynamic> geography;
  final Object? total;
  @override
  State<_GeoWidget> createState() => _GeoWidgetState();
}

class _GeoWidgetState extends State<_GeoWidget> {
  late final Map<String, dynamic> _geography = Map.of(widget.geography);
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
    List<Map<String, dynamic>> rows,
    int? selected,
    ValueChanged<int?> changed,
  ) {
    if (rows.isEmpty) return const SizedBox.shrink();
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
          final available = rows;
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
            suffixIcon: const Icon(Icons.search),
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
            _rows('counties', provinceId),
            countyId,
            (value) => setState(() {
              countyId = value;
              settlementId = null;
            }),
          ),
        if (countyId != null)
          _choice(
            'شهر / روستا',
            _rows('settlements', countyId),
            settlementId,
            (value) => setState(() => settlementId = value),
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
