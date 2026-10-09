import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection.dart';
import '../data/impeachment_repository.dart';
import '../domain/impeachment_office.dart';

class ImpeachmentRequestScreen extends StatefulWidget {
  const ImpeachmentRequestScreen({super.key, required this.office});
  final ImpeachmentOffice office;
  @override
  State<ImpeachmentRequestScreen> createState() => _ImpeachmentRequestScreenState();
}

class _ImpeachmentRequestScreenState extends State<ImpeachmentRequestScreen> {
  final _repo = getIt<ImpeachmentRepository>();
  bool _busy = false;
  bool _checkingActive = true;
  Map<String, dynamic>? _active;
  String? _error;

  @override
  void initState() { super.initState(); _loadCurrent(); }

  Future<void> _loadCurrent() async {
    try {
      final process = await _repo.current(widget.office.code);
      if (mounted) setState(() { _active = process; _checkingActive = false; });
    } catch (_) {
      if (mounted) setState(() => _checkingActive = false);
    }
  }

  String _uuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> _request() async {
    final password = await showDialog<String>(context: context, builder: (_) => const _PasswordDialog());
    if (password == null || !mounted) return;
    setState(() { _busy = true; _error = null; });
    try {
      final receipt = await _repo.request(widget.office.code, password, _uuid());
      if (!mounted) return;
      setState(() => _busy = false);
      await _showReceipt(receipt);
      await _loadCurrent();
    } catch (e) {
      if (!mounted) return;
      final body = e is DioException ? e.response?.data : null;
      setState(() { _busy = false; _error = body is Map && body['message'] != null ? '${body['message']}' : e is StateError ? e.message.toString() : 'ثبت درخواست ناموفق بود.'; });
    }
  }

  Future<void> _showReceipt(Map<String, dynamic> value) => showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('درخواست استیضاح ثبت شد'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('این درخواست به‌عنوان نخستین حمایت وارد مرحلهٔ کسب حدنصاب شد.'),
          const SizedBox(height: 10), const Text('شمارهٔ رسید دیجیتال'),
          SelectableText(value['receipt_number']?.toString() ?? '—', textDirection: TextDirection.ltr),
          const SizedBox(height: 6), const Text('هش رسید'),
          SelectableText(value['receipt_hash']?.toString() ?? '—', textDirection: TextDirection.ltr),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('متوجه شدم'))],
      ));

  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: ListView(padding: const EdgeInsets.all(20), children: [
    Text(widget.office.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: const Color(0xFFC62828), fontWeight: FontWeight.w800)),
    const SizedBox(height: 12),
    Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('درخواست برای ${widget.office.scopeLabel} ثبت می‌شود. نخستین درخواست در همان لحظه یک حمایت محسوب می‌شود. با رسیدن حمایت‌ها به ۲۰٪ جمعیت ثابت‌شدهٔ حوزه، درخواست به‌طور خودکار وارد صف زمان‌بندی می‌شود.'))),
    const SizedBox(height: 10),
    if (_checkingActive) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
    else if (_active != null) ...[
      Card(color: const Color(0x10C62828), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('برای این مسئول در حوزهٔ شما یک فرایند فعال وجود دارد؛ درخواست تازه ثبت نمی‌شود.', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6), Text('${_active!['title'] ?? ''} · وضعیت: ${_active!['state_code'] ?? ''}'),
        const SizedBox(height: 8), FilledButton(onPressed: () {
          final state = '${_active!['state_code']}';
          final kind = state == 'Supporting' ? 'supporting' : state == 'Waiting' ? 'scheduled' : state == 'VoteCasting' ? 'eligible' : 'live';
          context.push('/impeachment/${widget.office.code}/detail/${_active!['process_id']}', extra: {'kind': kind});
        }, child: const Text('مشاهدهٔ فرایند فعال')),
      ]))),
    ] else ...[
      if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
      FilledButton.icon(onPressed: _busy ? null : _request, icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_task_outlined), label: Text(_busy ? 'در حال ثبت…' : 'ثبت نخستین درخواست استیضاح'), style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828))),
    ],
  ]));
}

class _PasswordDialog extends StatefulWidget { const _PasswordDialog(); @override State<_PasswordDialog> createState() => _PasswordDialogState(); }
class _PasswordDialogState extends State<_PasswordDialog> {
  final _text = TextEditingController();
  @override void dispose() { _text.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AlertDialog(title: const Text('تأیید درخواست'), content: TextField(controller: _text, obscureText: true, autofocus: true, decoration: const InputDecoration(labelText: 'رمز عبور')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')), FilledButton(onPressed: () => Navigator.pop(context, _text.text), child: const Text('تأیید'))]);
}
