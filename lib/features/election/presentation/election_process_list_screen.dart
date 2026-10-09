import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection.dart';
import '../../../core/widgets/app_tap_tile.dart';
import '../../referendum/presentation/widgets/geographic_scope_filter.dart';
import '../data/election_voting_repository.dart';
import '../domain/election_category.dart';

enum ElectionListKind { scheduled, eligible, live, finalized }

class ElectionProcessListScreen extends StatefulWidget {
  const ElectionProcessListScreen({
    super.key,
    required this.category,
    required this.kind,
  });
  final ElectionCategory category;
  final ElectionListKind kind;
  @override
  State<ElectionProcessListScreen> createState() =>
      _ElectionProcessListScreenState();
}

class _ElectionProcessListScreenState extends State<ElectionProcessListScreen>
    with WidgetsBindingObserver {
  final _repository = getIt<ElectionVotingRepository>();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _total = 0;
  int _page = 1;
  Timer? _refreshTimer;
  GeographicScopeSelection _scope = const GeographicScopeSelection();

  String get _kind => switch (widget.kind) {
    ElectionListKind.scheduled => 'scheduled',
    ElectionListKind.eligible => 'eligible',
    ElectionListKind.live => 'live',
    ElectionListKind.finalized => 'finalized',
  };
  String get _title => switch (widget.kind) {
    ElectionListKind.scheduled => 'انتخابات زمان‌بندی‌شده',
    ElectionListKind.eligible => 'شرکت در انتخابات فعال',
    ElectionListKind.live => 'نتایج زندهٔ انتخابات',
    ElectionListKind.finalized => 'نتایج انتخابات پایان‌یافته',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _syncTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        widget.kind == ElectionListKind.live)
      _load();
    _syncTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _syncTimer() {
    _refreshTimer?.cancel();
    if (widget.kind == ElectionListKind.live &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _refreshTimer = Timer.periodic(
        const Duration(minutes: 10),
        (_) => _load(),
      );
    }
  }

  Future<void> _load({bool append = false}) async {
    if (_loadingMore || (append && _items.length >= _total)) return;
    final requestedPage = append ? _page + 1 : 1;
    setState(() {
      if (append) {
        _loadingMore = true;
      } else {
        _loading = true;
        _page = 1;
      }
      _error = null;
    });
    try {
      final selected = _scope.deepest;
      final data = await _repository.list(
        widget.category.code,
        _kind,
        search: _search.text,
        level: selected == null ? null : _levelCode(selected.type),
        geographicId: selected?.id,
        page: requestedPage,
      );
      final rawItems = data['items'];
      final pagination = data['pagination'];
      if (!mounted) return;
      final nextItems =
          rawItems is List
              ? rawItems
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
              : <Map<String, dynamic>>[];
      setState(() {
        _items = append ? [..._items, ...nextItems] : nextItems;
        _page = requestedPage;
        _total =
            pagination is Map ? int.tryParse('${pagination['total']}') ?? 0 : 0;
        _loading = false;
        _loadingMore = false;
      });
      _syncTimer();
    } catch (e) {
      if (!mounted) return;
      final body = e is DioException ? e.response?.data : null;
      setState(() {
        _error =
            body is Map && body['message'] != null
                ? body['message'].toString()
                : 'دریافت انتخابات از سرور ناموفق بود.';
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  int _levelCode(String type) => switch (type) {
    'country' => 1,
    'province' => 2,
    'county' => 3,
    _ => 4,
  };

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
                  '${widget.category.title} · $_title',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.election,
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
          if (widget.kind == ElectionListKind.live)
            const Text(
              'نتایج زنده هنگام بازبودن این صفحه هر ۱۰ دقیقه تازه می‌شوند.',
            ),
          const SizedBox(height: 10),
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              labelText: 'جست‌وجوی عنوان انتخابات',
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
            accent: AppTheme.election,
            onChanged: (scope) {
              _scope = scope;
              _load();
            },
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
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
                  'انتخاباتی در این بخش پیدا نشد. تعداد: $_total',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ..._items.map(
              (item) => AppTapTile(
                key: ValueKey('election-${item['process_id']}'),
                icon: Icons.how_to_vote_outlined,
                title: item['title']?.toString() ?? 'انتخابات',
                subtitle:
                    '${item['geographic_label'] ?? ''}: ${item['geographic_name'] ?? ''}'
                    '\nشروع رأی‌گیری: ${item['expected_voting_opens_at'] ?? item['voting_opens_at'] ?? 'زمان‌بندی نشده'}'
                    '\nپایان رأی‌گیری: ${item['expected_voting_closes_at'] ?? item['voting_closes_at'] ?? 'زمان‌بندی نشده'}',
                accent: AppTheme.election,
                onTap:
                    () => context.push(
                      '/elections/voting/${widget.category.code}/detail/${item['process_id']}',
                      extra: {
                        'voting': widget.kind == ElectionListKind.eligible,
                      },
                    ),
              ),
            ),
          if (!_loading && _error == null && _items.length < _total)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: OutlinedButton.icon(
                onPressed: _loadingMore ? null : () => _load(append: true),
                icon:
                    _loadingMore
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.expand_more),
                label: Text(
                  _loadingMore
                      ? 'در حال دریافت…'
                      : 'نمایش موارد بیشتر (${_items.length} از $_total)',
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
