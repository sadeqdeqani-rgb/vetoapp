import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_tap_tile.dart';
import '../../data/repositories/referendum_voting_repository.dart';
import '../widgets/geographic_scope_filter.dart';

enum ReferendumListKind { scheduled, eligible, liveResults, finalResults }

class ReferendumProcessListScreen extends StatefulWidget {
  const ReferendumProcessListScreen({super.key, required this.kind});
  final ReferendumListKind kind;

  @override
  State<ReferendumProcessListScreen> createState() =>
      _ReferendumProcessListScreenState();
}

class _ReferendumProcessListScreenState
    extends State<ReferendumProcessListScreen>
    with WidgetsBindingObserver {
  final _repository = getIt<ReferendumVotingRepository>();
  final _search = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _refreshTimer;
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;
  int? _targetLevel;
  int _page = 1;
  int _total = 0;
  bool _loadingMore = false;
  GeographicScopeSelection _scope = const GeographicScopeSelection();

  String get _kind => switch (widget.kind) {
    ReferendumListKind.scheduled => 'scheduled',
    ReferendumListKind.eligible => 'eligible',
    ReferendumListKind.liveResults => 'live',
    ReferendumListKind.finalResults => 'finalized',
  };

  String get _title => switch (widget.kind) {
    ReferendumListKind.scheduled => 'همه‌پرسی‌های زمان‌بندی‌شده',
    ReferendumListKind.eligible => 'شرکت در همه‌پرسی‌های فعال',
    ReferendumListKind.liveResults => 'نتایج زندهٔ همه‌پرسی‌ها',
    ReferendumListKind.finalResults => 'نتایج همه‌پرسی‌های پایان‌یافته',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_handleScroll);
    _load();
    _syncTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        widget.kind == ReferendumListKind.liveResults)
      _load(silent: true);
    _syncTimer();
  }

  void _syncTimer() {
    _refreshTimer?.cancel();
    if (widget.kind == ReferendumListKind.liveResults &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _refreshTimer = Timer.periodic(
        const Duration(minutes: 10),
        (_) => _load(silent: true),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _search.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _loadingMore ||
        _items.length >= _total)
      return;
    if (_scrollController.position.extentAfter < 400) _loadMore();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted)
      setState(() {
        _loading = true;
        _error = null;
      });
    try {
      final scope = _scope.deepest;
      final result = await _repository.list(
        _kind,
        search: _search.text,
        level: scope == null ? null : _level(scope.type),
        geographicId: scope?.id,
        targetLevel:
            widget.kind == ReferendumListKind.scheduled ? _targetLevel : null,
        page: 1,
      );
      if (mounted)
        setState(() {
          _items = result.items;
          _total = result.total;
          _page = 1;
          _loading = false;
          _error = null;
        });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _message(error);
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _items.length >= _total) return;
    setState(() => _loadingMore = true);
    try {
      final scope = _scope.deepest;
      final result = await _repository.list(
        _kind,
        search: _search.text,
        level: scope == null ? null : _level(scope.type),
        geographicId: scope?.id,
        targetLevel:
            widget.kind == ReferendumListKind.scheduled ? _targetLevel : null,
        page: _page + 1,
      );
      if (mounted)
        setState(() {
          _items = [..._items, ...result.items];
          _page++;
          _total = result.total;
          _loadingMore = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  int _level(String type) => switch (type) {
    'country' => 1,
    'province' => 2,
    'county' => 3,
    _ => 4,
  };
  String _message(Object error) {
    if (error is DioException) {
      final body = error.response?.data;
      if (body is Map && body['message'] != null)
        return body['message'].toString();
      return 'ارتباط با سرور انجام نشد؛ دوباره تلاش کنید.';
    }
    return error is StateError
        ? error.message.toString()
        : 'دریافت همه‌پرسی‌ها ناموفق بود.';
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        Row(
          children: [
            const Icon(
              Icons.ballot_outlined,
              color: Color(0xFF2E7D32),
              size: 27,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                _title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF1B5E20),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'به‌روزرسانی',
            ),
          ],
        ),
        if (widget.kind == ReferendumListKind.liveResults)
          const Text(
            'نتایج هنگام باز بودن این صفحه هر ۱۰ دقیقه به‌روزرسانی می‌شوند.',
          ),
        const SizedBox(height: 10),
        TextField(
          controller: _search,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'جست‌وجوی موضوع',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              onPressed: () {
                _search.clear();
                _load();
              },
              icon: const Icon(Icons.clear),
            ),
          ),
          onSubmitted: (_) => _load(),
        ),
        if (widget.kind == ReferendumListKind.scheduled) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<int?>(
            value: _targetLevel,
            decoration: const InputDecoration(labelText: 'سطح برگزاری'),
            items: const [
              DropdownMenuItem(value: null, child: Text('همهٔ سطوح')),
              DropdownMenuItem(value: 1, child: Text('کشور')),
              DropdownMenuItem(value: 2, child: Text('استان')),
              DropdownMenuItem(value: 3, child: Text('شهرستان')),
              DropdownMenuItem(value: 4, child: Text('شهر یا روستا')),
            ],
            onChanged: (value) {
              _targetLevel = value;
              _load();
            },
          ),
        ],
        const SizedBox(height: 8),
        GeographicScopeFilter(
          accent: AppTheme.success,
          onChanged: (scope) {
            _scope = scope;
            _load();
          },
        ),
        const SizedBox(height: 10),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator()),
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
                'در این بخش همه‌پرسی‌ای پیدا نشد.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ..._items.map((item) => _ProcessCard(item: item, kind: widget.kind)),
        if (_loadingMore)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    ),
  );
}

class _ProcessCard extends StatelessWidget {
  const _ProcessCard({required this.item, required this.kind});
  final Map<String, dynamic> item;
  final ReferendumListKind kind;

  @override
  Widget build(BuildContext context) {
    final processId = item['process_id']?.toString() ?? '';
    final title = item['title']?.toString() ?? 'همه‌پرسی';
    final level = item['geographic_label']?.toString() ?? '';
    final area = item['geographic_name']?.toString() ?? '';
    final start =
        item['voting_opens_at']?.toString() ??
        item['expected_voting_opens_at']?.toString();
    final end =
        item['voting_closes_at']?.toString() ??
        item['expected_voting_closes_at']?.toString();
    return AppTapTile(
      key: ValueKey('referendum-vote-$processId'),
      icon: Icons.how_to_vote_outlined,
      title: title,
      subtitle:
          '$level: $area\n${start == null ? '' : 'شروع رأی‌گیری: ${_displayDate(start)}'}${end == null ? '' : '\nپایان رأی‌گیری: ${_displayDate(end)}'}',
      accent: const Color(0xFF2E7D32),
      onTap:
          processId.isEmpty
              ? () {}
              : () => context.push(
                '/referendum/voting/detail/$processId',
                extra: {'voting': kind == ReferendumListKind.eligible},
              ),
    );
  }
}

String _displayDate(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return value;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year}/${two(date.month)}/${two(date.day)}  ${two(date.hour)}:${two(date.minute)}';
}
