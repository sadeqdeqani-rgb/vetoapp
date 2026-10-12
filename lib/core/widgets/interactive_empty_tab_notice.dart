import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_message_dialog.dart';

/// A guest-preview route placeholder for sections that have no public data yet.
/// The page stays inside the interactive environment and returns to its parent
/// route after the notice is dismissed.
class InteractiveEmptyTabNotice extends StatefulWidget {
  const InteractiveEmptyTabNotice({super.key});

  @override
  State<InteractiveEmptyTabNotice> createState() =>
      _InteractiveEmptyTabNoticeState();
}

class _InteractiveEmptyTabNoticeState extends State<InteractiveEmptyTabNotice> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showNotice());
  }

  Future<void> _showNotice() async {
    if (!mounted) return;
    await showAppMessageDialog<void>(
      context: context,
      title: 'محیط تعاملی',
      message:
          'این‌جا یک محیط تعاملی برای آشنایی با روش کار سامانه است. اطلاعات این بخش پس از شروع به کار سامانه بارگذاری خواهد شد.',
      barrierDismissible: false,
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('بازگشت به محیط'),
        ),
      ],
    );
    if (!mounted) return;
    final router = GoRouter.of(context);
    if (router.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
