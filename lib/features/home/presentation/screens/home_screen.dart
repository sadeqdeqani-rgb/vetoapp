import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dartz/dartz.dart' show Either;

import '../../../../core/di/injection.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../content/domain/entities/public_content.dart';
import '../../../content/domain/usecases/get_public_content.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<Either<Failure, PublicContent>> _introductionFuture;
  late final Future<Either<Failure, PublicIntroductionVideo>> _videoFuture;

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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryDark],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.22),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.people_alt_outlined,
                    color: Colors.white,
                    size: 30,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'تعداد کاربران ثبت نام شده در سامانه',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '۱۲٬۴۸۰ نفر',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _FilterCard(),
            const SizedBox(height: 20),
            FutureBuilder<Either<Failure, PublicContent>>(
              future: _introductionFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Text('در حال دریافت معرفی سامانه...');
                }
                return snapshot.data!.fold(
                  (failure) => Text(
                    failure.message,
                    style: const TextStyle(color: Colors.red),
                  ),
                  (content) => Text(
                    content.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 22,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.go('/about'),
                    icon: const Icon(Icons.info_outline_rounded),
                    label: FutureBuilder<Either<Failure, PublicContent>>(
                      future: _introductionFuture,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Text('در حال دریافت معرفی...');
                        }
                        return snapshot.data!.fold(
                          (failure) => Text(failure.message),
                          (content) => Text(content.title),
                        );
                      },
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () => context.go('/about'),
                    icon: const Icon(Icons.play_circle_outline_rounded),
                    label: FutureBuilder<
                      Either<Failure, PublicIntroductionVideo>
                    >(
                      future: _videoFuture,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Text('در حال دریافت ویدیو...');
                        }
                        return snapshot.data!.fold(
                          (failure) => Text(failure.message),
                          (video) => Text(video.title),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'آخرین رویدادهای وِتواَپ',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const _ActivityRow(
              icon: Icons.how_to_vote_outlined,
              title: '۳ همه‌پرسی در حال برگزاری',
              color: AppTheme.success,
            ),
            const SizedBox(height: 10),
            const _ActivityRow(
              icon: Icons.poll_outlined,
              title: '۲ انتخابات در حال رأی‌گیری',
              color: Color(0xFFC77C00),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          const Icon(Icons.tune_rounded, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'کشور / استان / شهرستان / شهر / روستا',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const Icon(Icons.keyboard_arrow_down_rounded),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const Icon(Icons.arrow_back_ios_new_rounded, size: 15),
        ],
      ),
    );
  }
}
