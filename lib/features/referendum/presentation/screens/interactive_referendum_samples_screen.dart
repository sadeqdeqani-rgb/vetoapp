import 'package:flutter/material.dart';

enum InteractiveReferendumSampleKind {
  supporting,
  scheduled,
  eligible,
  liveResults,
  finalResults,
}

class InteractiveReferendumSamplesScreen extends StatelessWidget {
  const InteractiveReferendumSamplesScreen({
    super.key,
    required this.kind,
  });

  final InteractiveReferendumSampleKind kind;

  static const _accent = Color(0xFF2E7D32);

  String get _title => switch (kind) {
    InteractiveReferendumSampleKind.supporting =>
      'موضوعات در حال کسب حمایت',
    InteractiveReferendumSampleKind.scheduled =>
      'همه‌پرسی‌های زمان‌بندی‌شده',
    InteractiveReferendumSampleKind.eligible =>
      'شرکت در همه‌پرسی‌های فعال',
    InteractiveReferendumSampleKind.liveResults => 'نتایج زندهٔ همه‌پرسی‌ها',
    InteractiveReferendumSampleKind.finalResults =>
      'نتایج همه‌پرسی‌های پایان‌یافته',
  };

  List<_SampleItem> get _items => switch (kind) {
    InteractiveReferendumSampleKind.supporting => const [
      _SampleItem('قرارداد ۲۵ ساله با چین', supportCount: 37890),
      _SampleItem('تعطیلی ایران‌خودرو', supportCount: 3456789),
    ],
    InteractiveReferendumSampleKind.scheduled => const [
      _SampleItem('انحلال جمهوری اسلامی'),
      _SampleItem('محو اسرائیل'),
      _SampleItem('بستن تنگهٔ هرمز'),
      _SampleItem('غنی‌سازی اورانیوم'),
    ],
    InteractiveReferendumSampleKind.eligible => const [
      _SampleItem('حذف ولایت فقیه'),
      _SampleItem('حجاب اجباری'),
      _SampleItem('مذاکره با آمریکا'),
      _SampleItem('نظارت استصوابی'),
    ],
    InteractiveReferendumSampleKind.liveResults => const [
      _SampleItem('قرارداد ۲۵ ساله با چین'),
      _SampleItem('آزادی واردات خودرو'),
      _SampleItem('حذف ارز ترجیحی'),
    ],
    InteractiveReferendumSampleKind.finalResults => const [
      _SampleItem('آزادی زندانیان سیاسی'),
      _SampleItem(
        'رفع فیلترینگ اینستاگرام، یوتیوب، تلگرام، واتساپ، توییتر و فیسبوک',
      ),
    ],
  };

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      children: [
        Row(
          children: [
            const Icon(Icons.how_to_vote_outlined, color: _accent, size: 27),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                _title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: _accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'این موضوع‌ها و آمارها نمونه و غیرواقعی هستند و فقط برای آشنایی با محیط تعاملی نمایش داده می‌شوند.',
          textAlign: TextAlign.start,
        ),
        const SizedBox(height: 14),
        ..._items.map(
          (item) => _SampleCard(
            item: item,
            showInfo: kind == InteractiveReferendumSampleKind.supporting ||
                kind == InteractiveReferendumSampleKind.scheduled ||
                kind == InteractiveReferendumSampleKind.eligible,
          ),
        ),
      ],
    ),
  );
}

class _SampleItem {
  const _SampleItem(this.title, {this.supportCount});

  final String title;
  final int? supportCount;
}

class _SampleCard extends StatelessWidget {
  const _SampleCard({required this.item, required this.showInfo});

  final _SampleItem item;
  final bool showInfo;

  static const _accent = Color(0xFF2E7D32);

  Future<void> _showInfo(BuildContext context) => showDialog<void>(
    context: context,
    builder:
        (context) => AlertDialog(
          icon: const Icon(Icons.info_outline_rounded, color: _accent),
          title: Text(item.title, textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.supportCount != null) ...[
                Text('تعداد حمایت: ${_persianNumber(item.supportCount!)}'),
                const SizedBox(height: 10),
              ],
              const Text(
                'این نمونه صرفاً نمایشی است؛ آمار و وضعیت واقعی پس از شروع به کار سامانه از سرور دریافت خواهد شد.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('متوجه شدم'),
            ),
          ],
        ),
  );

  @override
  Widget build(BuildContext context) {
    final subtitle = item.supportCount == null
        ? 'نمونهٔ نمایشی'
        : 'تعداد حمایت: ${_persianNumber(item.supportCount!)}';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.only(
          start: 16,
          end: 8,
          top: 4,
          bottom: 4,
        ),
        title: Text(
          item.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(subtitle),
        trailing: showInfo
            ? IconButton(
                tooltip: 'اطلاعات و آمار',
                color: _accent,
                icon: const Icon(Icons.info_outline_rounded),
                onPressed: () => _showInfo(context),
              )
            : const Icon(Icons.how_to_vote_outlined, color: _accent),
      ),
    );
  }
}

String _persianNumber(int value) {
  const digits = '۰۱۲۳۴۵۶۷۸۹';
  return value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))|\d'),
    (match) => match[0] == null || match[0]!.isEmpty
        ? '٬'
        : digits[int.parse(match[0]!)],
  );
}
