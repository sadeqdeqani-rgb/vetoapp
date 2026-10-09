import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/services/biometric_auth_service.dart';
import '../../../referendum/data/repositories/referendum_proposal_repository.dart';
import '../../../referendum/domain/entities/referendum_proposal.dart';

class CivicDetailItem {
  const CivicDetailItem({
    required this.title,
    this.subtitle,
    this.status,
    this.count,
    this.icon = Icons.ballot_outlined,
    this.statusIcon,
  });

  final String title;
  final String? subtitle;
  final String? status;
  final String? count;
  final IconData icon;
  final IconData? statusIcon;
}

class CivicDetailScreen extends StatefulWidget {
  const CivicDetailScreen({
    super.key,
    required this.title,
    required this.parentIcon,
    required this.items,
    this.description,
    this.proposalForm = false,
    this.accent = AppTheme.primary,
  });

  final String title;
  final IconData parentIcon;
  final List<CivicDetailItem> items;
  final String? description;
  final bool proposalForm;
  final Color accent;

  @override
  State<CivicDetailScreen> createState() => _CivicDetailScreenState();
}

class _CivicDetailScreenState extends State<CivicDetailScreen> {
  final _controllers = List.generate(4, (_) => TextEditingController());
  final _focusNodes = List.generate(4, (_) => FocusNode());

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(widget.parentIcon, color: widget.accent, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.primaryDark,
                      fontSize: 23,
                    ),
                  ),
                ),
              ],
            ),
            if (widget.description != null) ...[
              const SizedBox(height: 10),
              Text(widget.description!, style: const TextStyle(fontSize: 17)),
            ],
            const SizedBox(height: 16),
            if (widget.proposalForm)
              _ProposalForm(controllers: _controllers, focusNodes: _focusNodes),
            if (!widget.proposalForm)
              ...widget.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CivicItem(item: item, accent: widget.accent),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProposalForm extends StatefulWidget {
  const _ProposalForm({required this.controllers, required this.focusNodes});

  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;

  @override
  State<_ProposalForm> createState() => _ProposalFormState();
}

class _ProposalFormState extends State<_ProposalForm> {
  final _repository = getIt<ReferendumProposalRepository>();
  final _biometricAuth = getIt<BiometricAuthService>();
  bool _submitting = false;

  void _advanceOnSpace(int index, String value) {
    final controllers = widget.controllers;
    final focusNodes = widget.focusNodes;
    if (index >= controllers.length - 1 || !value.endsWith(' ')) return;

    final controller = controllers[index];
    final textWithoutTrailingSpace = value.trimRight();
    controller.value = TextEditingValue(
      text: textWithoutTrailingSpace,
      selection: TextSelection.collapsed(
        offset: textWithoutTrailingSpace.length,
      ),
    );
    focusNodes[index + 1].requestFocus();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final subject = widget.controllers
        .map((c) => c.text.trim())
        .where((part) => part.isNotEmpty)
        .join(' ');
    if (subject.length < 4) {
      _showMessage('موضوع را کامل وارد کنید.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final preview = await _repository.preview(subject);
      if (!mounted) return;
      if (preview.scopes.isEmpty) {
        _showMessage('دامنهٔ جغرافیایی حساب شما برای پیشنهاد موضوع کامل نیست.');
        return;
      }
      final acceptedNormalization = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('موضوع نرمال‌شده'),
              content: Text(
                'موضوعی که برای همه‌پرسی پیشنهاد می‌کنید:\n\n«${preview.normalizedSubject}»',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('ویرایش'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('ادامه'),
                ),
              ],
            ),
      );
      if (acceptedNormalization != true || !mounted) return;
      final scope = await showDialog<ProposalScope>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('دامنهٔ جغرافیایی'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children:
                      preview.scopes
                          .map(
                            (scope) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('${scope.label}: ${scope.name}'),
                              leading: const Icon(Icons.location_on_outlined),
                              onTap: () => Navigator.pop(context, scope),
                            ),
                          )
                          .toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('انصراف'),
                ),
              ],
            ),
      );
      if (scope == null || !mounted) return;
      final matches = await _repository.similar(
        subject: preview.normalizedSubject,
        scope: scope,
      );
      if (!mounted) return;
      final existing =
          matches.isEmpty
              ? null
              : await showDialog<ProposalCandidate>(
                context: context,
                builder:
                    (context) => SimpleDialog(
                      title: const Text('موضوع‌های مشابه'),
                      children: [
                        SimpleDialogOption(
                          onPressed:
                              () => Navigator.pop(
                                context,
                                const ProposalCandidate(
                                  processId: 0,
                                  title: '',
                                  normalizedSubject: '',
                                  similarity: 0,
                                  supportCount: 0,
                                ),
                              ),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.add_circle_outline),
                            title: Text(
                              'موضوع جدید: ${preview.normalizedSubject}',
                            ),
                            subtitle: const Text(
                              'با انتخاب این گزینه، ثبت موضوع شما اولین حمایت آن خواهد بود.',
                            ),
                          ),
                        ),
                        ...matches.map(
                          (candidate) => SimpleDialogOption(
                            onPressed: () => Navigator.pop(context, candidate),
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.topic_outlined),
                              title: Text(candidate.title),
                              subtitle: Text(
                                'موضوع موجود · ${candidate.supportCount} حمایت',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
              );
      if (matches.isNotEmpty && existing == null) return;
      if (!mounted) return;
      final selection = ProposalCommitSelection(
        subject:
            existing == null || existing.processId == 0
                ? preview.normalizedSubject
                : existing.normalizedSubject,
        geographicLevelCode: scope.levelCode,
        geographicId: scope.geographicId,
        existingProcessId:
            existing == null || existing.processId == 0
                ? null
                : existing.processId,
      );
      final biometricAvailable = await _canUseBiometric();
      if (!mounted) return;
      final confirmation = await showDialog<_ProposalConfirmation>(
        context: context,
        builder:
            (context) => _ProposalConfirmationDialog(
              subject: selection.subject,
              scope: scope,
              biometricAvailable: biometricAvailable,
            ),
      );
      if (confirmation == null || !mounted) return;
      final receipt =
          confirmation.useBiometric
              ? await _repository.createOrSupportWithBiometrics(selection)
              : await _repository.createOrSupportWithPassword(
                selection: selection,
                password: confirmation.password!,
              );
      if (!mounted) return;
      final processId = int.tryParse('${receipt['process_id'] ?? ''}');
      for (final controller in widget.controllers) {
        controller.clear();
      }
      await showDialog<void>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('حمایت ثبت شد'),
              content: SelectableText(
                'ثبت موضوع، اولین حمایت آن محسوب شد و رسید دیجیتال صادر شد.\n\nشناسهٔ رسید:\n${receipt['receipt_number'] ?? '—'}\n\nکد کلید: ${receipt['key_id'] ?? '—'}',
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
      if (processId != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'برای مشاهدهٔ موضوع، فهرست موضوع‌های در حال حمایت را باز کنید.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) _showMessage(_message(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
      return 'ارتباط با سرور انجام نشد؛ درخواست را دوباره ارسال کنید.';
    }
    return error is StateError
        ? error.message.toString()
        : 'ثبت موضوع انجام نشد.';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('من موضوع:', style: TextStyle(fontSize: 19)),
        const SizedBox(height: 10),
        ...widget.controllers.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: entry.value,
              focusNode: widget.focusNodes[entry.key],
              minLines: 1,
              maxLines: 2,
              onChanged: (value) => _advanceOnSpace(entry.key, value),
              decoration: InputDecoration(
                labelText: 'بخش ${entry.key + 1}',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon:
              _submitting
                  ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.send_outlined),
          label: const Text('پیشنهاد موضوع و ثبت اولین حمایت'),
        ),
      ],
    );
  }
}

class _ProposalConfirmation {
  const _ProposalConfirmation.password(this.password) : useBiometric = false;
  const _ProposalConfirmation.biometric()
    : password = null,
      useBiometric = true;
  final String? password;
  final bool useBiometric;
}

class _ProposalConfirmationDialog extends StatefulWidget {
  const _ProposalConfirmationDialog({
    required this.subject,
    required this.scope,
    required this.biometricAvailable,
  });
  final String subject;
  final ProposalScope scope;
  final bool biometricAvailable;

  @override
  State<_ProposalConfirmationDialog> createState() =>
      _ProposalConfirmationDialogState();
}

class _ProposalConfirmationDialogState
    extends State<_ProposalConfirmationDialog> {
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('تأیید نهایی'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'موضوع «${widget.subject}» در دامنهٔ ${widget.scope.label} «${widget.scope.name}» ثبت می‌شود. ثبت موضوع، اولین حمایت آن نیز هست.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: _obscure,
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
                const _ProposalConfirmation.biometric(),
              ),
          icon: const Icon(Icons.fingerprint_rounded, size: 30),
        ),
      FilledButton(
        onPressed:
            _password.text.isEmpty
                ? null
                : () => Navigator.pop(
                  context,
                  _ProposalConfirmation.password(_password.text),
                ),
        child: const Text('تأیید با رمز'),
      ),
    ],
  );
}

class _CivicItem extends StatefulWidget {
  const _CivicItem({required this.item, required this.accent});

  final CivicDetailItem item;
  final Color accent;

  @override
  State<_CivicItem> createState() => _CivicItemState();
}

class _CivicItemState extends State<_CivicItem> {
  bool _selected = false;
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = _selected || _hovered || _pressed;
    final accent = widget.accent;
    final foreground = active ? Colors.white : AppTheme.textPrimary;
    return Card(
      elevation: 0,
      color: active ? accent : accent.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color:
              active
                  ? Colors.white.withValues(alpha: 0.7)
                  : accent.withValues(alpha: 0.22),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onHover: (value) => setState(() => _hovered = value),
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp:
            (_) => setState(() {
              _pressed = false;
              _selected = true;
            }),
        onTapCancel: () => setState(() => _pressed = false),
        child: ListTile(
          leading: Icon(
            widget.item.icon,
            color: active ? Colors.white : accent,
          ),
          title: Text(
            widget.item.title,
            style: TextStyle(fontSize: 18, color: foreground),
          ),
          subtitle: Text(
            [
              if (widget.item.count != null)
                'تعداد حمایت: ${widget.item.count}',
              if (widget.item.status != null) widget.item.status!,
              if (widget.item.subtitle != null) widget.item.subtitle!,
            ].join('  ·  '),
            style: TextStyle(
              color: active ? Colors.white.withValues(alpha: 0.9) : null,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.item.statusIcon != null)
                Icon(
                  widget.item.statusIcon,
                  color: active ? Colors.white : accent,
                ),
              IconButton(
                tooltip: 'اطلاعات و آمار',
                onPressed:
                    () => showDialog<void>(
                      context: context,
                      builder:
                          (_) => AlertDialog(
                            title: Text(widget.item.title),
                            content: const Text(
                              'اطلاعات و آمار این موضوع در نسخهٔ نمایشی نمایش داده می‌شود.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('بستن'),
                              ),
                            ],
                          ),
                    ),
                icon: Icon(
                  Icons.info_outline_rounded,
                  color: active ? Colors.white : accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
