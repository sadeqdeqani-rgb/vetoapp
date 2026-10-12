import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppMessageTone { info, success, warning, error }

/// A shared, centered card dialog for messages and short forms in app flows.
class AppMessageDialog extends StatelessWidget {
  const AppMessageDialog({
    super.key,
    this.title,
    required this.message,
    this.tone = AppMessageTone.info,
    this.accentColor,
    this.actions = const [],
    this.content,
  });

  final String? title;
  final String message;
  final AppMessageTone tone;
  final Color? accentColor;
  final List<Widget> actions;
  final Widget? content;

  Color get _color =>
      accentColor ??
      switch (tone) {
        AppMessageTone.info => AppTheme.primary,
        AppMessageTone.success => AppTheme.success,
        AppMessageTone.warning => AppTheme.profile,
        AppMessageTone.error => AppTheme.danger,
      };

  IconData get _icon => switch (tone) {
    AppMessageTone.info => Icons.info_outline_rounded,
    AppMessageTone.success => Icons.check_circle_outline_rounded,
    AppMessageTone.warning => Icons.warning_amber_rounded,
    AppMessageTone.error => Icons.error_outline_rounded,
  };

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
        decoration: AppTheme.cardDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: _color.withValues(alpha: .10),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, color: _color, size: 32),
            ),
            if (title != null) ...[
              const SizedBox(height: 14),
              Text(
                title!,
                textAlign: TextAlign.center,
                style: AppTheme.getTitleStyle(fontSize: 20, color: _color),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTheme.getTitleStyle(
                fontSize: 17,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.normal,
              ).copyWith(height: 1.7),
            ),
            if (content != null) ...[const SizedBox(height: 18), content!],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

Future<T?> showAppMessageDialog<T>({
  required BuildContext context,
  String? title,
  required String message,
  AppMessageTone tone = AppMessageTone.info,
  Color? accentColor,
  List<Widget> actions = const [],
  Widget? content,
  bool barrierDismissible = true,
}) => showDialog<T>(
  context: context,
  // The app uses a nested Navigator for its main tabs. Actions close the
  // nearest Navigator, so the dialog must be pushed onto that same Navigator.
  useRootNavigator: false,
  barrierDismissible: barrierDismissible,
  builder:
      (_) => AppMessageDialog(
        title: title,
        message: message,
        tone: tone,
        accentColor: accentColor,
        actions: actions,
        content: content,
      ),
);

Widget appDialogButton(
  BuildContext context, {
  required String label,
  required VoidCallback onPressed,
  bool primary = false,
}) =>
    primary
        ? FilledButton(onPressed: onPressed, child: Text(label))
        : TextButton(onPressed: onPressed, child: Text(label));
