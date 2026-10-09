import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'about_sections.dart';

class AboutDetailScreen extends StatelessWidget {
  const AboutDetailScreen({super.key, required this.section});

  final AboutSection section;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
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
              Text(
                section.body,
                style: const TextStyle(fontSize: 18, height: 1.9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
