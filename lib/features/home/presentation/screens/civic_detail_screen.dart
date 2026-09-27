import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

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

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
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
            if (widget.proposalForm) _ProposalForm(controllers: _controllers),
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

class _ProposalForm extends StatelessWidget {
  const _ProposalForm({required this.controllers});

  final List<TextEditingController> controllers;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('من موضوع:', style: TextStyle(fontSize: 19)),
        const SizedBox(height: 10),
        ...controllers.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: entry.value,
              minLines: 1,
              maxLines: 2,
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
          onPressed:
              () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('پیشنهاد شما ثبت شد.')),
              ),
          icon: const Icon(Icons.send_outlined),
          label: const Text('پیشنهاد می‌کنم.'),
        ),
      ],
    );
  }
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
