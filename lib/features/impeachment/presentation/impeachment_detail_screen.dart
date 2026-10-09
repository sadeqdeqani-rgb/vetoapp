import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/services/biometric_auth_service.dart';
import '../../referendum/presentation/widgets/geographic_scope_filter.dart';
import '../data/impeachment_repository.dart';
import '../domain/impeachment_office.dart';

class ImpeachmentDetailScreen extends StatefulWidget {
  const ImpeachmentDetailScreen({
    super.key,
    required this.office,
    required this.processId,
    required this.kind,
  });
  final ImpeachmentOffice office;
  final int processId;
  final String kind;
  @override
  State<ImpeachmentDetailScreen> createState() =>
      _ImpeachmentDetailScreenState();
}

class _ImpeachmentDetailScreenState extends State<ImpeachmentDetailScreen>
    with WidgetsBindingObserver {
  final _repo = getIt<ImpeachmentRepository>();
  final _biometric = getIt<BiometricAuthService>();
  Map<String, dynamic>? _detail, _results;
  Map<String, String>? _pending;
  GeographicScopeSelection _scope = const GeographicScopeSelection();
  bool _loading = true, _busy = false, _biometricAvailable = false;
  String? _error;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _restorePending();
    _checkBiometric();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(silent: true);
    _syncRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refresh?.cancel();
    super.dispose();
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

  Future<void> _checkBiometric() async {
    try {
      final ok =
          await _biometric.canAuthenticate &&
          await _biometric.isConfiguredLocally &&
          await _biometric.isEnabledOnServer();
      if (mounted) setState(() => _biometricAvailable = ok);
    } catch (_) {}
  }

  Future<void> _restorePending() async {
    final value = await _repo.pending(widget.office.code, widget.processId);
    if (mounted && value != null) setState(() => _pending = value);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent)
      setState(() {
        _loading = true;
        _error = null;
      });
    try {
      final values = await Future.wait([
        _repo.detail(widget.office.code, widget.processId),
        _repo.results(
          widget.office.code,
          widget.processId,
          level: _level,
          geographicId: _scope.deepest?.id,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _detail = values[0];
        _results = values[1];
        _loading = false;
      });
      _syncRefresh();
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

  void _syncRefresh() {
    _refresh?.cancel();
    if ((_detail?['state_code'] == 'VoteCasting' || widget.kind == 'live') &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _refresh = Timer.periodic(
        const Duration(minutes: 10),
        (_) => _load(silent: true),
      );
    }
  }

  String _uuid() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 15) | 64;
    b[8] = (b[8] & 63) | 128;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  String _errorText(Object e) {
    final body = e is DioException ? e.response?.data : null;
    if (body is Map && body['message'] != null) return '${body['message']}';
    return e is StateError ? e.message.toString() : 'عملیات انجام نشد.';
  }

  Future<String?> _password() => showDialog<String>(
    context: context,
    builder: (_) => const _PasswordDialog(),
  );

  Future<void> _support() async {
    final password = await _password();
    if (password == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final receipt = await _repo.support(
        widget.office.code,
        widget.processId,
        password,
        _uuid(),
      );
      if (!mounted) return;
      setState(() => _busy = false);
      await _receiptDialog('حمایت از استیضاح ثبت شد', receipt);
      await _load(silent: true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _notice(_errorText(e));
      }
    }
  }

  Future<void> _vote(String choice) async {
    if (_detail?['can_vote'] != true || _busy) return;
    if (_pending != null && _pending!['choice'] != choice) {
      _notice('درخواست رأی قبلی را با همان گزینه پیگیری کنید.');
      return;
    }
    final method = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('تأیید نهایی رأی اعتماد'),
            content: Text(
              'گزینهٔ شما: ${choice == 'YES' ? 'موافق استیضاح و برکناری' : 'مخالف استیضاح و موافق ابقا'}\nپس از ثبت، رأی قابل تغییر نیست.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('بازگشت'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'password'),
                child: const Text('رمز عبور'),
              ),
              if (_biometricAvailable)
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, 'biometric'),
                  child: const Text('اثر انگشت'),
                ),
            ],
          ),
    );
    if (method == null || !mounted) return;
    final password = method == 'password' ? await _password() : null;
    if (method == 'password' && password == null || !mounted) return;
    final issuance = _pending?['issuance'] ?? _uuid();
    final submission = _pending?['submission'] ?? _uuid();
    setState(() {
      _busy = true;
      _pending = {
        'choice': choice,
        'issuance': issuance,
        'submission': submission,
      };
    });
    await _repo.savePending(
      widget.office.code,
      widget.processId,
      choice,
      issuance,
      submission,
    );
    try {
      final receipt = await _repo.cast(
        widget.office.code,
        widget.processId,
        choice,
        issuance,
        submission,
        password: password,
      );
      final verified = await _repo.verifyReceipt(
        '${receipt['receipt_number'] ?? ''}',
      );
      await _repo.clearPending(widget.office.code, widget.processId);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _pending = null;
      });
      await _load(silent: true);
      if (!mounted) return;
      await _receiptDialog(
        verified['valid'] == true ? 'رأی ثبت و رسید تأیید شد' : 'رأی ثبت شد',
        receipt,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _notice(_errorText(e));
      }
    }
  }

  Future<void> _receiptDialog(String title, Map<String, dynamic> receipt) =>
      showDialog<void>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: Text(title),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('شمارهٔ رسید دیجیتال'),
                    SelectableText(
                      '${receipt['receipt_number'] ?? '—'}',
                      textDirection: TextDirection.ltr,
                    ),
                    const SizedBox(height: 8),
                    const Text('هش رسید'),
                    SelectableText(
                      '${receipt['receipt_hash'] ?? '—'}',
                      textDirection: TextDirection.ltr,
                    ),
                    if (receipt['signature'] != null) ...[
                      const SizedBox(height: 8),
                      const Text('امضای رسید'),
                      SelectableText(
                        '${receipt['signature']}',
                        textDirection: TextDirection.ltr,
                      ),
                    ],
                    const SizedBox(height: 8),
                    const Text('رسید در فعالیت‌های حساب نیز ذخیره شد.'),
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
  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
  int _number(dynamic value) => int.tryParse('$value') ?? 0;

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
    final result = _results ?? const <String, dynamic>{};
    final totals =
        result['totals'] is Map
            ? Map<String, dynamic>.from(result['totals'] as Map)
            : <String, dynamic>{};
    final rows =
        result['items'] is List
            ? (result['items'] as List)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : <Map<String, dynamic>>[];
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
                    detail['title']?.toString() ?? 'استیضاح',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: const Color(0xFFC62828),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
              ],
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'حوزه: ${detail['geographic_label'] ?? ''} ${detail['geographic_name'] ?? ''}',
                    ),
                    Text('وضعیت: ${detail['state_code'] ?? ''}'),
                    Text(
                      'حمایت‌ها: ${_number(detail['support_count'])} از ${_number(detail['required_support_count'])}',
                    ),
                    if (detail['voting_opens_at'] != null)
                      Text('شروع رأی اعتماد: ${detail['voting_opens_at']}'),
                    if (detail['voting_closes_at'] != null)
                      Text('پایان رأی اعتماد: ${detail['voting_closes_at']}'),
                    if (detail['already_voted'] == true)
                      const Text('رأی شما قبلاً ثبت شده است.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('نتایج به تفکیک دامنهٔ جغرافیایی'),
            GeographicScopeFilter(
              accent: AppTheme.danger,
              onChanged: (scope) {
                _scope = scope;
                _load(silent: true);
              },
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: _count(
                        'موافق استیضاح و برکناری',
                        _number(totals['YES']),
                        const Color(0xFFC62828),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _count(
                        'مخالف استیضاح و ابقای مسئول',
                        _number(totals['NO']),
                        const Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (rows.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'حوزه‌های زیرمجموعه',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              ...rows.map(
                (row) => ListTile(
                  title: Text(
                    '${row['geographic_label'] ?? ''}: ${row['name'] ?? ''}',
                  ),
                  subtitle: Text(
                    'موافق برکناری: ${row['YES'] ?? 0} · مخالف و ابقا: ${row['NO'] ?? 0}',
                  ),
                ),
              ),
            ],
            if (detail['can_support'] == true &&
                widget.kind == 'supporting') ...[
              const SizedBox(height: 12),
              const Text(
                'با ثبت حمایت، یک رسید دیجیتال امضاشده دریافت می‌کنید.',
              ),
              FilledButton.icon(
                onPressed: _busy ? null : _support,
                icon: const Icon(Icons.volunteer_activism_outlined),
                label: Text(_busy ? 'در حال ثبت…' : 'حمایت از درخواست استیضاح'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC62828),
                ),
              ),
            ],
            if (detail['can_vote'] == true && widget.kind == 'eligible') ...[
              const SizedBox(height: 12),
              const Text(
                'رأی اعتماد خود را انتخاب کنید:',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              if (_pending != null)
                FilledButton(
                  onPressed: _busy ? null : () => _vote(_pending!['choice']!),
                  child: const Text('پیگیری ثبت رأی قبلی'),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : () => _vote('YES'),
                        icon: const Icon(Icons.person_remove_alt_1_outlined),
                        label: const Text('موافق برکناری'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFC62828),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : () => _vote('NO'),
                        icon: const Icon(Icons.verified_user_outlined),
                        label: const Text('مخالف و ابقا'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _count(String label, int number, Color color) => Column(
    children: [
      Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      Text(
        '$number',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 22,
        ),
      ),
    ],
  );
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();
  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _text = TextEditingController();
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('رمز عبور'),
    content: TextField(
      controller: _text,
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
        onPressed: () => Navigator.pop(context, _text.text),
        child: const Text('تأیید'),
      ),
    ],
  );
}
