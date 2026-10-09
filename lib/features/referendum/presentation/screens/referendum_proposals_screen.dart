import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_tap_tile.dart';
import '../../data/repositories/referendum_proposal_repository.dart';
import '../../domain/entities/referendum_proposal.dart';
import '../widgets/geographic_scope_filter.dart';

class ReferendumProposalsScreen extends StatefulWidget {
  const ReferendumProposalsScreen({super.key});

  @override
  State<ReferendumProposalsScreen> createState() =>
      _ReferendumProposalsScreenState();
}

class _ReferendumProposalsScreenState extends State<ReferendumProposalsScreen> {
  final _repository = getIt<ReferendumProposalRepository>();
  List<ReferendumProposal> _items = const [];
  int _total = 0;
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  GeographicScopeSelection _scope = const GeographicScopeSelection();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool append = false}) async {
    final pageNumber = append ? _page + 1 : 1;
    setState(() {
      if (append) {
        _loadingMore = true;
      } else {
        _loading = true;
      }
      _error = null;
    });
    try {
      final selected = _scope.deepest;
      final page = await _repository.list(
        geographicLevelCode:
            selected == null ? null : _levelCode(selected.type),
        geographicId: selected?.id,
        page: pageNumber,
      );
      if (!mounted) return;
      setState(() {
        _items = append ? [..._items, ...page.items] : page.items;
        _page = pageNumber;
        _total = page.total;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _errorMessage(error);
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

  String _errorMessage(Object error) {
    if (error is DioException) {
      final body = error.response?.data;
      if (body is Map && body['message'] != null)
        return body['message'].toString();
      return 'فهرست موضوعات از سرور دریافت نشد. اتصال را بررسی و دوباره تلاش کنید.';
    }
    return error is StateError
        ? error.message.toString()
        : 'بارگذاری موضوعات ناموفق بود.';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            Row(
              children: [
                const Icon(
                  Icons.how_to_vote_outlined,
                  color: Color(0xFF2E7D32),
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'موضوعات در حال کسب حمایت',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 22,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _loading ? null : _load,
                  tooltip: 'به‌روزرسانی',
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'موضوعات از پایگاه داده دریافت می‌شوند. برای دیدن آمار و ثبت حمایت، علامت اطلاعات کنار موضوع را بزنید.',
            ),
            const SizedBox(height: 14),
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
                padding: EdgeInsets.all(30),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _MessageCard(message: _error!, onRetry: _load)
            else if (_items.isEmpty)
              const _MessageCard(
                message: 'در این حوزه جغرافیایی موضوعی در حال کسب حمایت نیست.',
              )
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'تعداد موضوع‌ها: ${_persianCount(_total)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              ..._items.map(
                (proposal) => _ProposalCard(
                  proposal: proposal,
                  onOpen:
                      () => context.push(
                        '/referendum/supported/${proposal.processId}',
                      ),
                ),
              ),
              if (_items.length < _total)
                Center(
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
                    label: const Text('نمایش موضوع‌های بیشتر'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({required this.proposal, required this.onOpen});

  final ReferendumProposal proposal;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AppTapTile(
      key: ValueKey('referendum-proposal-${proposal.processId}'),
      icon: Icons.info_outline_rounded,
      title: proposal.title,
      subtitle:
          '${proposal.geographicLabel}: ${proposal.geographicName}\n'
          'حمایت‌ها: ${_persianCount(proposal.supportCount)} از ${_persianCount(proposal.requiredSupportCount)} حدنصاب',
      accent: const Color(0xFF2E7D32),
      onTap: onOpen,
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('تلاش دوباره'),
            ),
          ],
        ],
      ),
    ),
  );
}

String _persianCount(int value) => value
    .toString()
    .replaceAllMapped(RegExp(r'(?=(\d{3})+(?!\d))'), (_) => ',')
    .replaceAllMapped(
      RegExp(r'\d'),
      (match) => String.fromCharCode(match[0]!.codeUnitAt(0) + 1728),
    );
