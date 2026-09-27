import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared_widgets/pdf_attachment_button.dart';
import 'about_sections.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final initialIndex =
        GoRouterState.of(context).uri.queryParameters['tab'] == 'creators'
            ? 1
            : 0;
    return DefaultTabController(
      length: aboutSections.length,
      initialIndex: initialIndex,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorColor: AppTheme.primary,
                labelColor: AppTheme.primaryDark,
                tabs: [Tab(text: 'اهداف سامانه'), Tab(text: 'سازندگان سامانه')],
              ),
            ),
            Expanded(
              child: TabBarView(
                children:
                    aboutSections
                        .map((section) => _AboutSectionView(section: section))
                        .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutSectionView extends StatelessWidget {
  const _AboutSectionView({required this.section});
  final AboutSection section;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            section.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.primaryDark,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 18),
          Text(section.body, style: const TextStyle(fontSize: 18, height: 1.9)),
          if (section.attachments.isNotEmpty) ...[
            const SizedBox(height: 22),
            const Text(
              'ضمیمه‌ها',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ...section.attachments.map(
              (attachment) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: PdfAttachmentButton(
                  title: attachment.title,
                  assetPath: attachment.assetPath,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
