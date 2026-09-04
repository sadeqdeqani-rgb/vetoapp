import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dartz/dartz.dart' show Either;

import '../../../../core/di/injection.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../content/domain/entities/public_content.dart';
import '../../../content/domain/usecases/get_public_content.dart';
import 'about_sections.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  late final Future<Either<Failure, PublicContent>> _introductionFuture;
  late final Future<Either<Failure, PublicIntroductionVideo>>
  _videoFuture;

  @override
  void initState() {
    super.initState();
    _introductionFuture = getIt<GetPublicIntroductionUseCase>()();
    _videoFuture = getIt<GetPublicIntroductionVideoUseCase>()();
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
            FutureBuilder<Either<Failure, PublicContent>>(
              future: _introductionFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return snapshot.data!.fold(
                  (failure) => Text(
                    failure.message,
                    style: const TextStyle(color: Colors.red),
                  ),
                  (content) => Text(
                    content.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 23,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.divider),
              ),
              child: FutureBuilder<Either<Failure, PublicContent>>(
                future: _introductionFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return snapshot.data!.fold(
                    (failure) => Text(
                      failure.message,
                      style: const TextStyle(color: Colors.red),
                    ),
                    (content) => Text(
                      content.body,
                      style: const TextStyle(fontSize: 17, height: 1.9),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            ...aboutSections.map(
              (section) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AboutSectionButton(section: section),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: () => context.go('/about'),
                icon: const Icon(Icons.play_circle_outline_rounded),
                label: FutureBuilder<Either<Failure, PublicIntroductionVideo>>(
                  future: _videoFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Text('در حال دریافت ویدیوی معرفی...');
                    }
                    return snapshot.data!.fold(
                      (failure) => Text(failure.message),
                      (video) => Text(video.title),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutSectionButton extends StatelessWidget {
  const _AboutSectionButton({required this.section});

  final AboutSection section;

  @override
  Widget build(BuildContext context) {
    final icon =
        section.title == 'ضرورت'
            ? Icons.help_outline_rounded
            : Icons.people_outline_rounded;

    return Material(
      color: AppTheme.primary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/about/detail', extra: section),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 2),
              Icon(icon, color: AppTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  section.title,
                  style: const TextStyle(
                    color: AppTheme.primaryDark,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_left_rounded,
                color: AppTheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
