import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'وتواپ، ابزار انقلاب سوم و تحقق جمهوری دوم در ایران',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 23,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.divider),
              ),
              child: const Text(
                'وتواپ، ابزار انقلاب سوم و استقرار جمهوری دوم در ایران\n'
                'وتواپ ابزاری برای تحقق یک جمهوری تمام عیار در ایران است.\n'
                'این ابزار به دنبال تحقق حاکمیت مردم بر سرنوشت خود آنهاست.\n'
                'در وِتواَپ امکان برگزاری همه پرسی، انتخابات و استیضاح به صورت '
                'آزادانه وجود خواهد داشت.\n\n'
                'هدف از توسعه این اپلیکیشن، طراحی مسیر انقلاب سوم در ایران ـ '
                'پس از انقلاب مشروطه و انقلاب ۵۷ ـ برای انحلال و پایان جمهوری '
                'اسلامی و آغاز جمهوری دوم در ایران است.\n'
                'این اپلیکیشن، برای شروع به کار نیاز به ثبت نام اولیه توسط چهل '
                'و چهار میلیون کاربر ایرانی دارد.\n\n'
                'یک همه پرسی، زمانی در وِتواَپ آغاز می شود که یک پنجم از کاربران '
                'درخواست برگزاری همه پرسی در مورد آن موضوع را در وِتواَپ اعلام کنند.\n'
                'کاربران، در پیشنهاد موضوع برای همه پرسی، هیچ محدودیتی ندارند و '
                'هیچ نظارت و کنترلی بر رفتار مردم در وِتواَپ صورت نمی گیرد.\n\n'
                'همه پرسی در وِتواَپ، علاوه بر این که در سطح کشوری و مسائل کلان '
                'امکان طرح دارد، در سایر سطوح و مسائل استانی، شهرستانی و شهری / '
                'روستایی نیز قابل طرح به صورت همه پرسی است.\n\n'
                'در فرآیند انتخابات در وِتواَپ نظارت استصوابی وجود نخواهد داشت و '
                'مردم می توانند به صورت آزادانه و بی قید و شرط هر فرد یا افرادی '
                'به ریاست جمهوری، نمایندگی مجلس و یا عضویت در شوراهای محلی انتخاب کنند.\n\n'
                'چنان چه یک پنجم از کاربران یک حوزه رأی گیری، درخواست استیضاح '
                'یک مقام حاکمیتی را در وِتواَپ مطرح کنند فرآیند استیضاح برای آن '
                'فرد آغاز می شود.\n'
                'با تصمیم نهایی اکثریت کاربران، مشخص خواهد شد که آیا آن مقام '
                'حاکمیتی، می تواند کار خود را ادامه دهد و یا از کار برکنار خواهد شد.\n\n'
                'وِتواَپ برای احراز هویت و ثبت نام کاربران به سرور ثبت احوال متصل '
                'نمی‌شود و نیازی به داده‌های وزارت کشور جمهوری اسلامی ایران ندارد.\n'
                'این سامانه برای صحت سنجی و احراز هویت سنی، مبتنی بر دستورالعمل '
                'های داخلی مبتنی بر الگوریتم های ریاضی مندرج در کد ملی عمل می کند. '
                'لذا از این حیث، کاملاً می تواند مستقل از دولت مرکزی عمل کند.',
                style: TextStyle(fontSize: 17, height: 1.9),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: () => context.go('/about'),
                icon: const Icon(Icons.play_circle_outline_rounded),
                label: const Text('مشاهده ویدیوی معرفی وتواپ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
