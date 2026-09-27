import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/auth_card.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';

// این پیش‌نمایش اسلایدی برای استفادهٔ بعدی نگه داشته شده و در مسیر ورود فعلی نمایش داده نمی‌شود.
class SystemPreviewPage extends StatefulWidget {
  const SystemPreviewPage({super.key});
  @override
  State<SystemPreviewPage> createState() => _SystemPreviewPageState();
}

class _SystemPreviewPageState extends State<SystemPreviewPage> {
  static const _slides = <_PreviewSlide>[
    _PreviewSlide(
      'خانه',
      'خانه و مسیرهای مشارکت',
      Icons.home_outlined,
      AppTheme.primary,
      ['معرفی سامانه', 'تعداد کاربران ثبت‌نام‌شده', 'کشور، استان و شهرستان'],
    ),
    _PreviewSlide(
      'همه‌پرسی',
      'پیشنهاد موضوع، مشاهده و شرکت در همه‌پرسی',
      Icons.how_to_vote_outlined,
      AppTheme.success,
      ['پیشنهاد موضوع', 'حمایت از موضوعات', 'ثبت رأی در موضوعات فعال'],
    ),
    _PreviewSlide(
      'انتخابات',
      'مشاهده نتایج زنده انتخابات',
      Icons.ballot_outlined,
      AppTheme.election,
      ['انتخابات ریاست جمهوری', 'نتایج زنده', 'نتایج پایان‌یافته'],
    ),
    _PreviewSlide(
      'استیضاح',
      'استیضاح و برکناری کارگزاران حاکمیت',
      Icons.gavel_outlined,
      AppTheme.danger,
      ['درخواست استیضاح', 'رأی اعتماد', 'نتایج نهایی'],
    ),
    _PreviewSlide(
      'کاربری',
      'تنظیمات پروفایل کاربری',
      Icons.person_outline,
      AppTheme.profile,
      ['حساب کاربری', 'اطلاعات حساب', 'موقعیت جغرافیایی'],
    ),
  ];
  final _controller = PageController();
  int _index = 0;
  bool _entering = false;

  Future<void> _change(int index) async {
    if (index < 0 || index >= _slides.length || index == _index) return;
    await _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _enter() async {
    if (_entering) return;
    setState(() => _entering = true);
    await context.read<AuthCubit>().continueAsGuest();
    if (!mounted) return;
    if (context.read<AuthCubit>().state is Guest) {
      context.go('/');
      return;
    }
    setState(() => _entering = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ورود به نسخهٔ نمایشی انجام نشد. دوباره تلاش کنید.'),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_index];
    return AuthScaffold(
      maxWidth: 860,
      onBack: () => context.go('/gateway'),
      child: AuthFormCard(
        title: 'آشنایی با محیط سامانه',
        maxWidth: 860,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'پنج نمای زیر بر پایهٔ اجزای نسخهٔ تعاملی وِتواَپ آماده شده‌اند.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'نمای قبلی',
                  onPressed: _index == 0 ? null : () => _change(_index - 1),
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
                Row(
                  children: List.generate(
                    _slides.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: i == _index ? 20 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i == _index ? slide.color : AppTheme.divider,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'نمای بعدی',
                  onPressed:
                      _index == _slides.length - 1
                          ? null
                          : () => _change(_index + 1),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 420,
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => _InteractivePreview(slide: _slides[i]),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              slide.label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: slide.color,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              slide.description,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _entering ? null : _enter,
              icon:
                  _entering
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.surface,
                        ),
                      )
                      : const Icon(Icons.play_circle_outline_rounded),
              label: Text(
                _entering ? 'در حال ورود...' : 'ورود به نسخهٔ تعاملی',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewSlide {
  const _PreviewSlide(
    this.label,
    this.description,
    this.icon,
    this.color,
    this.items,
  );
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> items;
}

class _InteractivePreview extends StatelessWidget {
  const _InteractivePreview({required this.slide});
  final _PreviewSlide slide;
  @override
  Widget build(BuildContext context) => Center(
    child: AspectRatio(
      aspectRatio: .72,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: slide.color.withValues(alpha: .45),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.shadow.withValues(alpha: .16),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            children: [
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: slide.color,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(slide.icon, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      slide.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ...slide.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: slide.color.withValues(alpha: .26),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(slide.icon, color: slide.color, size: 20),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            item,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_left_rounded),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: const [
                    Icon(Icons.home_outlined, size: 19),
                    Icon(Icons.how_to_vote_outlined, size: 19),
                    Icon(Icons.ballot_outlined, size: 19),
                    Icon(Icons.gavel_outlined, size: 19),
                    Icon(Icons.person_outline, size: 19),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
