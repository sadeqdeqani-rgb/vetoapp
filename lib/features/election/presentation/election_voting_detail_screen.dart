import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

import '../../../core/di/injection.dart';
import '../../auth/data/services/biometric_auth_service.dart';
import '../../referendum/presentation/widgets/geographic_scope_filter.dart';
import '../data/election_voting_repository.dart';
import '../domain/election_category.dart';

class ElectionVotingDetailScreen extends StatefulWidget {
  const ElectionVotingDetailScreen({
    super.key,
    required this.category,
    required this.processId,
    this.voting = false,
  });
  final ElectionCategory category;
  final int processId;
  final bool voting;
  @override
  State<ElectionVotingDetailScreen> createState() =>
      _ElectionVotingDetailScreenState();
}

class _ElectionVotingDetailScreenState extends State<ElectionVotingDetailScreen>
    with WidgetsBindingObserver {
  final _repo = getIt<ElectionVotingRepository>();
  final _biometric = getIt<BiometricAuthService>();
  final _given = TextEditingController();
  final _family = TextEditingController();
  final _father = TextEditingController();
  Map<String, dynamic>? _detail, _results, _previewResult;
  GeographicScopeSelection _scope = const GeographicScopeSelection();
  bool _loading = true, _busy = false, _biometricAvailable = false;
  String? _error;
  Map<String, String>? _pending;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _checkBiometric();
    _restorePending();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(silent: true);
    _syncTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _given.dispose();
    _family.dispose();
    _father.dispose();
    super.dispose();
  }

  int? get _scopeLevel {
    final t = _scope.deepest?.type;
    return t == null
        ? null
        : switch (t) {
          'country' => 1,
          'province' => 2,
          'county' => 3,
          _ => 4,
        };
  }

  Future<void> _checkBiometric() async {
    try {
      final ready =
          await _biometric.canAuthenticate &&
          await _biometric.isConfiguredLocally &&
          await _biometric.isEnabledOnServer();
      if (mounted) setState(() => _biometricAvailable = ready);
    } catch (_) {}
  }

  Future<void> _restorePending() async {
    final pending = await _repo.pending(widget.processId);
    if (pending == null || !mounted) return;
    _given.text = pending['given_name'] ?? '';
    _family.text = pending['family_name'] ?? '';
    _father.text = pending['father_name'] ?? '';
    try {
      final preview = await _repo.preview(
        widget.category.code,
        widget.processId,
        _typed,
      );
      if (mounted)
        setState(() {
          _pending = pending;
          _previewResult = preview;
        });
    } catch (_) {
      if (mounted) setState(() => _pending = pending);
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent)
      setState(() {
        _loading = true;
        _error = null;
      });
    try {
      final detail = await _repo.detail(widget.category.code, widget.processId);
      final results = await _repo.results(
        widget.category.code,
        widget.processId,
        level: _scopeLevel,
        geographicId: _scope.deepest?.id,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _results = results;
        _loading = false;
      });
      _syncTimer();
    } catch (e) {
      if (!mounted) return;
      final body = e is DioException ? e.response?.data : null;
      setState(() {
        _error =
            body is Map && body['message'] != null
                ? body['message'].toString()
                : 'دریافت اطلاعات انتخابات از سرور ناموفق بود.';
        _loading = false;
      });
    }
  }

  void _syncTimer() {
    _timer?.cancel();
    if (_detail?['state_code'] == 'VoteCasting' &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _timer = Timer.periodic(
        const Duration(minutes: 10),
        (_) => _load(silent: true),
      );
    }
  }

  Map<String, String> get _typed => {
    'given_name': _given.text.trim(),
    'family_name': _family.text.trim(),
    'father_name': _father.text.trim(),
  };
  Future<void> _preview() async {
    if (_typed.values.any((v) => v.isEmpty)) {
      _notice('هر سه مشخصهٔ نامزد را وارد کنید.');
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await _repo.preview(
        widget.category.code,
        widget.processId,
        _typed,
      );
      if (mounted)
        setState(() {
          _previewResult = result;
          _busy = false;
        });
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _notice(_errorText(e));
      }
    }
  }

  Future<void> _vote() async {
    if (_detail?['can_vote'] != true || _previewResult == null || _busy) return;
    final typed = Map<String, String>.from(_typed);
    final normalized = (_previewResult!['normalized'] as Map).map(
      (k, v) => MapEntry(k.toString(), v.toString()),
    );
    final matches =
        (_previewResult!['matches'] as List? ?? const [])
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
    final choice = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder:
          (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: SafeArea(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(18),
                children: [
                  Text(
                    'نام نهایی روی برگ رأی',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'نامزد را انتخاب کنید. این مشخصات در رأی و رسید ثبت می‌شود.',
                  ),
                  _choiceTile(ctx, 'املای واردشده', typed),
                  _choiceTile(ctx, 'املای نرمال‌شده', normalized),
                  ...matches.map(
                    (m) => _choiceTile(ctx, 'نام مشابه ثبت‌شده', {
                      'given_name': '${m['given_name']}',
                      'family_name': '${m['family_name']}',
                      'father_name': '${m['father_name']}',
                    }),
                  ),
                ],
              ),
            ),
          ),
    );
    if (choice == null || !mounted) return;
    if (_pending != null &&
        (choice['given_name'] != _pending!['given_name'] ||
            choice['family_name'] != _pending!['family_name'] ||
            choice['father_name'] != _pending!['father_name'])) {
      _notice(
        'یک درخواست رأی نیمه‌تمام وجود دارد؛ همان نامزد را برای تکمیل آن انتخاب کنید.',
      );
      return;
    }
    final confirmed = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('تأیید نهایی رأی'),
            content: Text(
              'رأی شما برای نامزد زیر ثبت خواهد شد:\n${choice['given_name']} ${choice['family_name']}، فرزند ${choice['father_name']}\n\nپس از ثبت، رأی قابل تغییر نیست.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('بازگشت'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'password'),
                child: const Text('تأیید با رمز'),
              ),
              if (_biometricAvailable)
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, 'biometric'),
                  child: const Text('اثر انگشت'),
                ),
            ],
          ),
    );
    if (confirmed == null || !mounted) return;
    String? password;
    if (confirmed == 'password') {
      password = await showDialog<String>(
        context: context,
        builder: (ctx) => const _PasswordDialog(),
      );
      if (password == null || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final issuance = _pending?['issuance'] ?? _uuid();
      final submission = _pending?['submission'] ?? _uuid();
      await _repo.savePending(widget.processId, choice, issuance, submission);
      final receipt =
          confirmed == 'biometric'
              ? await _repo.castWithBiometrics(
                electionType: widget.category.code,
                processId: widget.processId,
                names: choice,
                issuanceKey: issuance,
                submissionKey: submission,
              )
              : await _repo.castWithPassword(
                electionType: widget.category.code,
                processId: widget.processId,
                names: choice,
                password: password!,
                issuanceKey: issuance,
                submissionKey: submission,
              );
      final verified = await _repo.verifyReceipt(
        receipt['receipt_number']?.toString() ?? '',
      );
      await _repo.clearPending(widget.processId);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _pending = null;
      });
      await _load(silent: true);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('رأی ثبت شد'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      verified['valid'] == true
                          ? 'امضای رسید توسط سرور تأیید شد.'
                          : 'رسید صادر شد؛ تأیید امضا ناموفق بود.',
                    ),
                    Text('نامزد: ${receipt['choice_label'] ?? '—'}'),
                    const Text('رسید در فعالیت‌های حساب شما نیز ثبت شد.'),
                    const SizedBox(height: 8),
                    const Text('شمارهٔ رسید'),
                    SelectableText(
                      receipt['receipt_number']?.toString() ?? '—',
                      textDirection: TextDirection.ltr,
                    ),
                    const Text('هش رسید'),
                    SelectableText(
                      receipt['receipt_hash']?.toString() ?? '—',
                      textDirection: TextDirection.ltr,
                    ),
                    const Text('امضا'),
                    SelectableText(
                      receipt['signature']?.toString() ?? '—',
                      textDirection: TextDirection.ltr,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('متوجه شدم'),
                ),
              ],
            ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _notice(_errorText(e));
      }
    }
  }

  Widget _choiceTile(
    BuildContext context,
    String title,
    Map<String, String> names,
  ) => Card(
    child: ListTile(
      title: Text(title),
      subtitle: Text(
        '${names['given_name']} ${names['family_name']}، فرزند ${names['father_name']}',
      ),
      onTap: () => Navigator.pop(context, names),
    ),
  );

  String _uuid() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  String _errorText(Object e) {
    final b = e is DioException ? e.response?.data : null;
    if (b is Map && b['message'] != null) return b['message'].toString();
    return e is StateError ? e.message.toString() : 'عملیات انجام نشد.';
  }

  void _notice(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null)
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            TextButton(onPressed: _load, child: const Text('تلاش دوباره')),
          ],
        ),
      );
    final detail = _detail ?? const <String, dynamic>{};
    final totals = (_results?['totals'] as Map?) ?? const {};
    final candidates =
        (totals['candidates'] as List? ?? const []).whereType<Map>().toList();
    final areaRows =
        (_results?['items'] as List? ?? const []).whereType<Map>().toList();
    final canVote = widget.voting && detail['can_vote'] == true;
    return Directionality(
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
                    detail['title']?.toString() ?? 'انتخابات',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.election,
                      fontWeight: FontWeight.w800,
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
                    Text(
                      'وضعیت: ${detail['state_label'] ?? detail['state_code'] ?? ''}',
                    ),
                    if (detail['voting_opens_at'] != null)
                      Text('شروع رأی‌گیری: ${detail['voting_opens_at']}'),
                    if (detail['voting_closes_at'] != null)
                      Text('پایان رأی‌گیری: ${detail['voting_closes_at']}'),
                    if (detail['already_voted'] == true)
                      const Text('رأی شما قبلاً ثبت شده است.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'برای مشاهدهٔ نتایج در سطح‌های پایین‌تر، حوزه را انتخاب کنید.',
            ),
            GeographicScopeFilter(
              accent: AppTheme.election,
              onChanged: (s) {
                _scope = s;
                _load(silent: true);
              },
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'نتایج نامزدها · ${totals['votes'] ?? 0} رأی',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (candidates.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('هنوز رأیی برای نمایش ثبت نشده است.'),
                      ),
                    ...candidates.map(
                      (c) => ListTile(
                        dense: true,
                        title: Text(c['candidate']?.toString() ?? ''),
                        trailing: Text('${c['votes'] ?? 0}'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (areaRows.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'تفکیک حوزه‌های زیرمجموعه',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              ...areaRows.map((area) {
                final localCandidates =
                    (area['candidates'] as List? ?? const [])
                        .whereType<Map>()
                        .toList();
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${area['geographic_label'] ?? ''}: ${area['name'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (localCandidates.isEmpty)
                          const Text('هنوز رأیی ثبت نشده است.'),
                        ...localCandidates.map(
                          (c) => ListTile(
                            dense: true,
                            title: Text(c['candidate']?.toString() ?? ''),
                            trailing: Text('${c['votes'] ?? 0}'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
            if (canVote) ...[
              const SizedBox(height: 14),
              const Text(
                'نوشتن نام نامزد روی برگ رأی',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              TextField(
                controller: _given,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'نام'),
              ),
              TextField(
                controller: _family,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'نام خانوادگی'),
              ),
              TextField(
                controller: _father,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'نام پدر'),
                onSubmitted: (_) => _preview(),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _busy ? null : _preview,
                icon: const Icon(Icons.manage_search),
                label: const Text('بررسی املاهای مشابه'),
              ),
              if (_previewResult != null) ...[
                Card(
                  color: AppTheme.election.withValues(alpha: 0.06),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('املای نرمال‌شده'),
                        Text(
                          '${(_previewResult!['normalized'] as Map)['given_name']} ${(_previewResult!['normalized'] as Map)['family_name']}، فرزند ${(_previewResult!['normalized'] as Map)['father_name']}',
                        ),
                        Text(
                          'موارد مشابه یافت‌شده: ${(_previewResult!['matches'] as List? ?? const []).length}',
                        ),
                      ],
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: _busy ? null : _vote,
                  child: Text(
                    _busy ? 'در حال ثبت…' : 'انتخاب نامزد و ادامهٔ تأیید رأی',
                  ),
                ),
              ],
            ],
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();
  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('رمز عبور'),
    content: TextField(
      controller: _controller,
      obscureText: true,
      autofocus: true,
      decoration: const InputDecoration(labelText: 'رمز عبور'),
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
