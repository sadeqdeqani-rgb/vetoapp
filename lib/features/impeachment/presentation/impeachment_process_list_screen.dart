import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_tap_tile.dart';
import '../../referendum/presentation/widgets/geographic_scope_filter.dart';
import '../data/impeachment_repository.dart';
import '../domain/impeachment_office.dart';

class ImpeachmentProcessListScreen extends StatefulWidget {
  const ImpeachmentProcessListScreen({
    super.key,
    required this.office,
    required this.kind,
  });
  final ImpeachmentOffice office;
  final String kind;
  @override
  State<ImpeachmentProcessListScreen> createState() =>
      _ImpeachmentProcessListScreenState();
}

class _ImpeachmentProcessListScreenState
    extends State<ImpeachmentProcessListScreen>
    with WidgetsBindingObserver {
  final _repo = getIt<ImpeachmentRepository>();
  final _search = TextEditingController();
  GeographicScopeSelection _scope = const GeographicScopeSelection();
  List<Map<String, dynamic>> _items = [];
  int _total = 0;
  bool _loading = true;
  String? _error;
  Timer? _timer;

  String get _title => switch (widget.kind) {
    'supporting' => 'حمایت از استیضاح',
    'scheduled' => 'استیضاح‌های زمان‌بندی‌شده',
    'eligible' => 'شرکت در رأی اعتماد',
    'live' => 'نتایج زندهٔ رأی اعتماد',
    _ => 'نتایج نهایی رأی اعتماد',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _syncTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.kind == 'live') _load();
    _syncTimer();
  }

  void _syncTimer() {
    _timer?.cancel();
    if (widget.kind == 'live' &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _timer = Timer.periodic(const Duration(minutes: 10), (_) => _load());
    }
  }

  int? get _level {
    final type = _scope.deepest?.type;
    return type == null
        ? null
        : switch (type) {
          'country' => 1,
          'province' => 2,
          'county' => 3,
          _ => 4,
        };
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.list(
        widget.office.code,
        widget.kind,
        search: _search.text,
        level: _level,
        geographicId: _scope.deepest?.id,
      );
      final raw = data['items'];
      if (!mounted) return;
      setState(() {
        _items =
            raw is List
                ? raw
                    .whereType<Map>()
                    .map((row) => Map<String, dynamic>.from(row))
                    .toList()
                : [];
        final pagination = data['pagination'];
        _total =
            pagination is Map ? int.tryParse('${pagination['total']}') ?? 0 : 0;
        _loading = false;
      });
      _syncTimer();
    } catch (e) {
      if (!mounted) return;
      final body = e is DioException ? e.response?.data : null;
      setState(() {
        _error =
            body is Map && body['message'] != null
                ? '${body['message']}'
                : 'دریافت اطلاعات استیضاح ناموفق بود.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.office.title} · $_title',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFFC62828),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (widget.kind == 'live')
            const Text(
              'نتایج زنده با تازه‌سازی دستی یا بازگشت دوباره به صفحه به‌روز می‌شوند.',
            ),
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              labelText: 'جست‌وجوی عنوان',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                onPressed: () {
                  _search.clear();
                  _load();
                },
                icon: const Icon(Icons.clear),
              ),
            ),
          ),
          const SizedBox(height: 8),
          GeographicScopeFilter(
            accent: AppTheme.danger,
            onChanged: (scope) {
              _scope = scope;
              _load();
            },
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    TextButton(
                      onPressed: _load,
                      child: const Text('تلاش دوباره'),
                    ),
                  ],
                ),
              ),
            )
          else if (_items.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'موردی در این بخش پیدا نشد. تعداد: $_total',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ..._items.map(
              (item) => AppTapTile(
                key: ValueKey('impeachment-${item['process_id']}'),
                icon: Icons.gavel_outlined,
                title: item['title']?.toString() ?? 'استیضاح',
                subtitle:
                    '${item['geographic_label'] ?? ''}: ${item['geographic_name'] ?? ''}'
                    '\nوضعیت: ${item['state_label'] ?? item['state_code'] ?? ''} · حمایت: ${item['support_count'] ?? 0} از ${item['required_support_count'] ?? 0}'
                    '\nشروع رأی اعتماد: ${item['expected_voting_opens_at'] ?? item['voting_opens_at'] ?? 'در انتظار زمان‌بندی'}'
                    '\nپایان رأی اعتماد: ${item['expected_voting_closes_at'] ?? item['voting_closes_at'] ?? 'زمان‌بندی نشده'}',
                accent: const Color(0xFFC62828),
                onTap:
                    () => context.push(
                      '/impeachment/${widget.office.code}/detail/${item['process_id']}',
                      extra: {'kind': widget.kind},
                    ),
              ),
            ),
        ],
      ),
    ),
  );
}
