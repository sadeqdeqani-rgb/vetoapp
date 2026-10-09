import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/services/biometric_auth_service.dart';
import '../../data/repositories/referendum_voting_repository.dart';
import '../widgets/geographic_scope_filter.dart';

class ReferendumVotingDetailScreen extends StatefulWidget {
  const ReferendumVotingDetailScreen({super.key, required this.processId});
  final int processId;

  @override
  State<ReferendumVotingDetailScreen> createState() =>
      _ReferendumVotingDetailScreenState();
}

class _ReferendumVotingDetailScreenState
    extends State<ReferendumVotingDetailScreen>
    with WidgetsBindingObserver {
  final _repository = getIt<ReferendumVotingRepository>();
  final _biometricAuth = getIt<BiometricAuthService>();
  Map<String, dynamic>? _detail;
  Map<String, dynamic>? _results;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  String? _pendingVoteKey;
  String? _pendingSubmissionKey;
  String? _pendingChoice;
  Timer? _refreshTimer;
  GeographicScopeSelection _scope = const GeographicScopeSelection();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restorePendingAttempt();
    _load();
  }

  Future<void> _restorePendingAttempt() async {
    final attempt = await _repository.pendingAttempt(widget.processId);
    if (!mounted || attempt == null) return;
    setState(() {
      _pendingChoice = attempt['choice'];
      _pendingVoteKey = attempt['issuance_key'];
      _pendingSubmissionKey = attempt['submission_key'];
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _detail?['state_code'] == 'VoteCasting')
      _load(silent: true);
    _syncTimer();
  }

  void _syncTimer() {
    _refreshTimer?.cancel();
    if (_detail?['state_code'] == 'VoteCasting' &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _refreshTimer = Timer.periodic(
        const Duration(minutes: 10),
        (_) => _load(silent: true),
      );
    }
  }

  int? get _scopeLevel {
    final type = _scope.deepest?.type;
    if (type == null) return null;
    return switch (type) {
      'country' => 1,
      'province' => 2,
      'county' => 3,
      _ => 4,
    };
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent)
      setState(() {
        _loading = true;
        _error = null;
      });
    try {
      final values = await Future.wait([
        _repository.detail(widget.processId),
        _repository.results(
          widget.processId,
          level: _scopeLevel,
          geographicId: _scope.deepest?.id,
        ),
      ]);
      if (mounted) {
        setState(() {
          _detail = values[0] as Map<String, dynamic>;
          _results = values[1] as Map<String, dynamic>;
          _loading = false;
        });
        _syncTimer();
      }
    } catch (error) {
      if (mounted)
        setState(() {
          _error = _message(error);
          _loading = false;
        });
    }
  }

  String _message(Object error) {
    if (error is DioException) {
      final body = error.response?.data;
      if (body is Map && body['message'] != null)
        return body['message'].toString();
      return 'ارتباط با سرور انجام نشد؛ دوباره تلاش کنید.';
    }
    return error is StateError ? error.message.toString() : 'عملیات انجام نشد.';
  }

  Future<void> _vote(String choice) async {
    final detail = _detail;
    if (detail == null || detail['can_vote'] != true || _submitting) return;
    if (_pendingChoice != null && _pendingChoice != choice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ابتدا همان درخواست رأی قبلی را دوباره پیگیری کنید.'),
        ),
      );
      return;
    }
    var biometricAvailable = false;
    try {
      biometricAvailable =
          await _biometricAuth.canAuthenticate &&
          await _biometricAuth.isConfiguredLocally &&
          await _biometricAuth.isEnabledOnServer();
    } catch (_) {}
    if (!mounted) return;
    final method = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('تأیید نهایی رأی'),
            content: Text(
              'گزینهٔ انتخاب‌شده: ${choice == 'YES' ? 'موافق' : 'مخالف'}\n\nپس از ثبت، رأی قابل تغییر نیست. روش تأیید را انتخاب کنید.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('بازگشت'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'password'),
                child: const Text('رمز عبور'),
              ),
              if (biometricAvailable)
                FilledButton(
                  onPressed: () => Navigator.pop(context, 'biometric'),
                  child: const Text('اثر انگشت'),
                ),
            ],
          ),
    );
    if (method == null || !mounted) return;
    String? password;
    if (method == 'password') {
      password = await showDialog<String>(
        context: context,
        builder: (context) => const _PasswordDialog(),
      );
      if (password == null || !mounted) return;
    }
    setState(() => _submitting = true);
    try {
      final issuanceKey = _pendingVoteKey ??= _newUuid();
      final submissionKey = _pendingSubmissionKey ??= _newUuid();
      _pendingChoice ??= choice;
      await _repository.savePendingAttempt(
        widget.processId,
        choice: choice,
        issuanceKey: issuanceKey,
        submissionKey: submissionKey,
      );
      final receipt =
          method == 'biometric'
              ? await _repository.castWithBiometrics(
                processId: widget.processId,
                choice: choice,
                issuanceKey: issuanceKey,
                submissionKey: submissionKey,
              )
              : await _repository.castWithPassword(
                processId: widget.processId,
                choice: choice,
                password: password!,
                issuanceKey: issuanceKey,
                submissionKey: submissionKey,
              );
      final verification = await _repository.verifyReceipt(
        receipt['receipt_number']?.toString() ?? '',
      );
      await _repository.clearPendingAttempt(widget.processId);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _pendingVoteKey = null;
        _pendingSubmissionKey = null;
        _pendingChoice = null;
      });
      await _load();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('رأی ثبت شد'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      verification['valid'] == true
                          ? 'امضای رسید توسط سرور تأیید شد.'
                          : 'رسید صادر شد، اما تأیید امضا ناموفق بود.',
                    ),
                    Text(
                      'رأی ثبت‌شده: ${receipt['choice_label'] ?? (choice == 'YES' ? 'موافق' : 'مخالف')}',
                    ),
                    const Text(
                      'این رسید در فعالیت‌های حساب شما نیز ذخیره شده است.',
                    ),
                    const SizedBox(height: 10),
                    const Text('شمارهٔ رسید'),
                    SelectableText(
                      receipt['receipt_number']?.toString() ?? '—',
                      textDirection: TextDirection.ltr,
                    ),
                    Text('شمارهٔ ترتیب رأی: ${receipt['sequence_no'] ?? '—'}'),
                    const SizedBox(height: 8),
                    const Text('هش رسید'),
                    SelectableText(
                      receipt['receipt_hash']?.toString() ?? '—',
                      textDirection: TextDirection.ltr,
                    ),
                    const Text('امضای رسید'),
                    SelectableText(
                      receipt['signature']?.toString() ?? '—',
                      textDirection: TextDirection.ltr,
                    ),
                  ],
                ),
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null)
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              TextButton(onPressed: _load, child: const Text('تلاش دوباره')),
            ],
          ),
        ),
      );
    final detail = _detail!;
    final result = _results ?? const <String, dynamic>{};
    final totals =
        result['totals'] is Map
            ? Map<String, dynamic>.from(result['totals'] as Map)
            : <String, dynamic>{};
    final yes = _number(totals['YES']);
    final no = _number(totals['NO']);
    final breakdown =
        result['items'] is List
            ? (result['items'] as List)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : <Map<String, dynamic>>[];
    final checkpoint =
        result['checkpoint'] is Map
            ? Map<String, dynamic>.from(result['checkpoint'] as Map)
            : null;
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
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    detail['title']?.toString() ?? 'همه‌پرسی',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
              ],
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'حوزه: ${detail['geographic_label'] ?? ''} ${detail['geographic_name'] ?? ''}',
                    ),
                    if (detail['voting_opens_at'] != null)
                      Text(
                        'شروع رأی‌گیری: ${_date(detail['voting_opens_at'])}',
                      ),
                    if (detail['voting_closes_at'] != null)
                      Text(
                        'پایان رأی‌گیری: ${_date(detail['voting_closes_at'])}',
                      ),
                    Text(
                      'وضعیت: ${detail['state_label'] ?? detail['state_code'] ?? ''}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'آمار آرا در حوزهٔ انتخاب‌شده',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _VoteCount(
                            label: 'موافق',
                            count: yes,
                            color: const Color(0xFF2E7D32),
                            icon: Icons.thumb_up_alt_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _VoteCount(
                            label: 'مخالف',
                            count: no,
                            color: const Color(0xFFC62828),
                            icon: Icons.thumb_down_alt_outlined,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            GeographicScopeFilter(
              accent: AppTheme.success,
              onChanged: (scope) {
                _scope = scope;
                _load();
              },
            ),
            if (breakdown.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'تفکیک جغرافیایی',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              ...breakdown.map(
                (item) => ListTile(
                  title: Text(item['name']?.toString() ?? ''),
                  subtitle: Text('${item['geographic_label'] ?? ''}'),
                  trailing: Text(
                    '${_number(item['YES'])} موافق · ${_number(item['NO'])} مخالف',
                  ),
                ),
              ),
            ],
            if (checkpoint != null) ...[
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'گواهی نهایی صندوق رأی',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'تعداد آرا در ریشهٔ منتشرشده: ${_number(checkpoint['leaf_count'])}',
                      ),
                      Text(
                        'آخرین شمارهٔ ترتیب: ${_number(checkpoint['last_sequence_no'])}',
                      ),
                      Text('نسخهٔ درخت: ${checkpoint['tree_version'] ?? '—'}'),
                      const SizedBox(height: 8),
                      const Text(
                        'روت مرکل',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SelectableText(
                        checkpoint['root_hash']?.toString() ?? '—',
                        textDirection: TextDirection.ltr,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'دادهٔ امضاشدهٔ درخت',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SelectableText(
                        checkpoint['signed_payload']?.toString() ?? '—',
                        textDirection: TextDirection.ltr,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'امضای درخت',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SelectableText(
                        checkpoint['signature']?.toString() ?? '—',
                        textDirection: TextDirection.ltr,
                      ),
                      Text(
                        'کلید: ${checkpoint['key_id'] ?? '—'} · الگوریتم: ${checkpoint['signature_algorithm'] ?? '—'}',
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (detail['can_vote'] == true) ...[
              const SizedBox(height: 10),
              const Text(
                'رأی خود را انتخاب کنید:',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (_pendingChoice != null) ...[
                Text(
                  'درخواست قبلی برای «${_pendingChoice == 'YES' ? 'موافق' : 'مخالف'}» کامل نشده؛ برای بازیابی همان رسید ادامه دهید.',
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _submitting ? null : () => _vote(_pendingChoice!),
                  icon: const Icon(Icons.replay),
                  label: Text(
                    'پیگیری رأی ${_pendingChoice == 'YES' ? 'موافق' : 'مخالف'}',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        _pendingChoice == 'YES'
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFC62828),
                  ),
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _submitting ? null : () => _vote('YES'),
                        icon: const Icon(Icons.thumb_up_alt_outlined),
                        label: const Text('موافق'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _submitting ? null : () => _vote('NO'),
                        icon: const Icon(Icons.thumb_down_alt_outlined),
                        label: const Text('مخالف'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFC62828),
                        ),
                      ),
                    ),
                  ],
                ),
              if (_submitting)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ] else if (detail['already_voted'] == true)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('رأی شما برای این همه‌پرسی پیش‌تر ثبت شده است.'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VoteCount extends StatelessWidget {
  const _VoteCount({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            '$label: $count',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();
  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('تأیید با رمز عبور'),
    content: TextField(
      controller: _controller,
      obscureText: _obscure,
      decoration: InputDecoration(
        labelText: 'رمز عبور',
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('انصراف'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('تأیید'),
      ),
    ],
  );
}

int _number(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;
String _date(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (parsed == null) return value.toString();
  String p(int n) => n.toString().padLeft(2, '0');
  return '${parsed.year}/${p(parsed.month)}/${p(parsed.day)} ${p(parsed.hour)}:${p(parsed.minute)}';
}

String _newUuid() {
  final random = math.Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex =
      bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
