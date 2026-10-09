import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/services/biometric_auth_service.dart';
import '../../data/repositories/referendum_proposal_repository.dart';
import '../../domain/entities/referendum_proposal.dart';

class ReferendumProposalDetailScreen extends StatefulWidget {
  const ReferendumProposalDetailScreen({super.key, required this.processId});

  final int processId;

  @override
  State<ReferendumProposalDetailScreen> createState() =>
      _ReferendumProposalDetailScreenState();
}

class _ReferendumProposalDetailScreenState
    extends State<ReferendumProposalDetailScreen> {
  final _repository = getIt<ReferendumProposalRepository>();
  final _biometricAuth = getIt<BiometricAuthService>();
  final _search = TextEditingController();
  ReferendumProposal? _proposal;
  ProposalSupportPage? _supportPage;
  int? _breakdownLevel;
  bool _loading = true;
  bool _loadingBreakdown = false;
  bool _loadingMoreAreas = false;
  bool _submitting = false;
  bool _biometricAvailable = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final proposal = await _repository.detail(widget.processId);
      var level = _breakdownLevel;
      if (proposal.availableBreakdownLevels.isNotEmpty &&
          (level == null ||
              !proposal.availableBreakdownLevels.contains(level))) {
        level = proposal.availableBreakdownLevels.first;
      }
      final biometricAvailable =
          proposal.canSupport ? await _canUseBiometric() : false;
      final page =
          level == null
              ? null
              : await _repository.supportBreakdown(
                processId: widget.processId,
                geographicLevelCode: level,
              );
      if (!mounted) return;
      setState(() {
        _proposal = proposal;
        _breakdownLevel = level;
        _supportPage = page;
        _biometricAvailable = biometricAvailable;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _message(error);
        _loading = false;
      });
    }
  }

  Future<bool> _canUseBiometric() async {
    try {
      return await _biometricAuth.canAuthenticate &&
          await _biometricAuth.isConfiguredLocally &&
          await _biometricAuth.isEnabledOnServer();
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadBreakdown() async {
    final level = _breakdownLevel;
    if (level == null) return;
    setState(() => _loadingBreakdown = true);
    try {
      final page = await _repository.supportBreakdown(
        processId: widget.processId,
        geographicLevelCode: level,
        search: _search.text,
      );
      if (!mounted) return;
      setState(() {
        _supportPage = page;
        _loadingBreakdown = false;
        _loadingMoreAreas = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingBreakdown = false;
        _loadingMoreAreas = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_message(error))));
    }
  }

  Future<void> _loadMoreBreakdown() async {
    final level = _breakdownLevel;
    final current = _supportPage;
    if (level == null ||
        current == null ||
        _loadingMoreAreas ||
        current.items.length >= current.total)
      return;
    setState(() => _loadingMoreAreas = true);
    try {
      final nextPage = current.items.length ~/ 100 + 1;
      final page = await _repository.supportBreakdown(
        processId: widget.processId,
        geographicLevelCode: level,
        search: _search.text,
        page: nextPage,
      );
      if (!mounted) return;
      setState(() {
        _supportPage = ProposalSupportPage(
          items: [...current.items, ...page.items],
          total: page.total,
        );
        _loadingMoreAreas = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingMoreAreas = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_message(error))));
    }
  }

  Future<void> _support() async {
    final proposal = _proposal;
    if (proposal == null || !proposal.canSupport || _submitting) return;
    final confirmation = await showDialog<_SupportConfirmation>(
      context: context,
      builder:
          (context) => _SupportConfirmationDialog(
            title: proposal.title,
            biometricAvailable: _biometricAvailable,
          ),
    );
    if (confirmation == null || !mounted) return;
    setState(() => _submitting = true);
    try {
      final receipt =
          confirmation.useBiometric
              ? await _repository.supportWithBiometrics(proposal)
              : await _repository.supportWithPassword(
                proposal: proposal,
                password: confirmation.password!,
              );
      if (!mounted) return;
      setState(() => _submitting = false);
      await _load();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('حمایت ثبت شد'),
              content: SelectableText(
                'رسید دیجیتال با موفقیت صادر شد.\n\nشناسهٔ رسید:\n${receipt['receipt_number'] ?? '—'}\n\nکد کلید: ${receipt['key_id'] ?? '—'}',
                textDirection: TextDirection.ltr,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('متوجه شدم'),
                ),
              ],
            ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_message(error))));
    }
  }

  String _message(Object error) {
    if (error is DioException) {
      final body = error.response?.data;
      if (body is Map) {
        final errors = body['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) return first.first.toString();
        }
        if (body['message'] != null) return body['message'].toString();
      }
      return 'ارتباط با سرور انجام نشد؛ دوباره تلاش کنید.';
    }
    return error is StateError ? error.message.toString() : 'عملیات انجام نشد.';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('تلاش دوباره'),
                      ),
                    ],
                  ),
                ),
              )
              : _proposal == null
              ? const Center(child: Text('موضوع پیدا نشد.'))
              : _content(_proposal!),
    );
  }

  Widget _content(ReferendumProposal proposal) {
    final levels = proposal.availableBreakdownLevels;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFF2E7D32),
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'اطلاعات و آمار موضوع',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: AppTheme.primaryDark),
              ),
            ),
            IconButton(
              onPressed: _load,
              tooltip: 'به‌روزرسانی',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  proposal.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'دامنهٔ موضوع: ${proposal.geographicLabel} ${proposal.geographicName}',
                ),
                const SizedBox(height: 7),
                Text('تعداد حمایت‌ها: ${_count(proposal.supportCount)}'),
                Text(
                  'حدنصاب لازم: ${_count(proposal.requiredSupportCount)} نفر',
                ),
                Text(
                  'جمعیت مبنای حدنصاب: ${_count(proposal.frozenPopulationTotal)} نفر',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _supportAction(proposal),
        const SizedBox(height: 18),
        Text(
          'توزیع حمایت‌ها در زیرشاخه‌های جغرافیایی',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (levels.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'این موضوع در پایین‌ترین سطح جغرافیایی ثبت شده و زیرشاخه‌ای برای نمایش ندارد.',
              ),
            ),
          )
        else ...[
          Wrap(
            spacing: 8,
            children:
                levels
                    .map(
                      (level) => ChoiceChip(
                        label: Text(_levelName(level)),
                        selected: _breakdownLevel == level,
                        selectedColor: AppTheme.success.withValues(alpha: 0.18),
                        side: BorderSide(
                          color: AppTheme.success.withValues(
                            alpha: _breakdownLevel == level ? 0.8 : 0.45,
                          ),
                        ),
                        labelStyle: TextStyle(
                          color: AppTheme.success.withValues(
                            alpha: _breakdownLevel == level ? 0.65 : 1,
                          ),
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (_) {
                          setState(() {
                            _breakdownLevel = level;
                            _search.clear();
                          });
                          _loadBreakdown();
                        },
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _loadBreakdown(),
            decoration: InputDecoration(
              hintText:
                  'جست‌وجوی ${_breakdownLevel == null ? 'حوزه' : _levelName(_breakdownLevel!)}',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                onPressed: _loadBreakdown,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          if (_loadingBreakdown)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Center(child: CircularProgressIndicator()),
            )
          else if ((_supportPage?.items ?? const []).isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('برای این جست‌وجو حمایتی ثبت نشده است.'),
              ),
            )
          else ...[
            Text('حوزه‌های دارای حمایت: ${_count(_supportPage?.total ?? 0)}'),
            ..._supportPage!.items.map(
              (area) => Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.location_on_outlined,
                    color: Color(0xFF2E7D32),
                  ),
                  title: Text(area.name),
                  trailing: Text(
                    _count(area.supportCount),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ),
              ),
            ),
            if (_supportPage!.items.length < _supportPage!.total)
              Center(
                child: OutlinedButton.icon(
                  onPressed: _loadingMoreAreas ? null : _loadMoreBreakdown,
                  icon:
                      _loadingMoreAreas
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.expand_more),
                  label: const Text('نمایش حوزه‌های بیشتر'),
                ),
              ),
          ],
        ],
      ],
    );
  }

  Widget _supportAction(ReferendumProposal proposal) {
    if (_submitting)
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(10),
          child: CircularProgressIndicator(),
        ),
      );
    if (proposal.canSupport) {
      return FilledButton.icon(
        onPressed: _support,
        icon: const Icon(Icons.volunteer_activism_outlined),
        label: const Text('حمایت از موضوع پیشنهادی'),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      );
    }
    final message =
        proposal.hasSupported
            ? 'شما پیش‌تر از این موضوع حمایت کرده‌اید.'
            : proposal.userScopeMatches
            ? 'این موضوع دیگر در مرحلهٔ دریافت حمایت نیست.'
            : 'حمایت فقط برای کاربرانی فعال است که دامنهٔ جغرافیایی حسابشان با دامنهٔ موضوع یکسان باشد.';
    return Card(
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }

  String _levelName(int level) => switch (level) {
    2 => 'استان',
    3 => 'شهرستان',
    _ => 'شهر یا روستا',
  };

  String _count(int value) => value
      .toString()
      .replaceAllMapped(RegExp(r'(?=(\d{3})+(?!\d))'), (_) => ',')
      .replaceAllMapped(
        RegExp(r'\d'),
        (match) => String.fromCharCode(match[0]!.codeUnitAt(0) + 1728),
      );
}

class _SupportConfirmation {
  const _SupportConfirmation.password(this.password) : useBiometric = false;
  const _SupportConfirmation.biometric() : password = null, useBiometric = true;

  final String? password;
  final bool useBiometric;
}

class _SupportConfirmationDialog extends StatefulWidget {
  const _SupportConfirmationDialog({
    required this.title,
    required this.biometricAvailable,
  });

  final String title;
  final bool biometricAvailable;

  @override
  State<_SupportConfirmationDialog> createState() =>
      _SupportConfirmationDialogState();
}

class _SupportConfirmationDialogState
    extends State<_SupportConfirmationDialog> {
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('تأیید حمایت'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('حمایت از «${widget.title}» را تأیید کنید.'),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: _obscure,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'رمز عبور',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('انصراف'),
      ),
      if (widget.biometricAvailable)
        IconButton(
          tooltip: 'تأیید با اثر انگشت',
          onPressed:
              () => Navigator.pop(
                context,
                const _SupportConfirmation.biometric(),
              ),
          icon: const Icon(Icons.fingerprint_rounded, size: 30),
        ),
      FilledButton(
        onPressed:
            _password.text.isEmpty
                ? null
                : () => Navigator.pop(
                  context,
                  _SupportConfirmation.password(_password.text),
                ),
        child: const Text('تأیید با رمز'),
      ),
    ],
  );
}
