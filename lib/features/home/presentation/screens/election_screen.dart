import 'package:flutter/material.dart';

import '../../../election/presentation/election_process_list_screen.dart';
import '../../../election/domain/election_category.dart';
import '../../../../core/theme/app_theme.dart';

enum _ElectionSection {
  scheduled('مشاهدهٔ انتخابات زمان‌بندی‌شده'),
  eligible('شرکت در انتخابات فعال'),
  live('نتایج زندهٔ انتخابات'),
  finalized('نتایج انتخابات پایان‌یافته');

  const _ElectionSection(this.label);
  final String label;
}

class ElectionScreen extends StatefulWidget {
  const ElectionScreen({super.key, this.interactivePreview = false});

  final bool interactivePreview;

  @override
  State<ElectionScreen> createState() => _ElectionScreenState();
}

class _ElectionScreenState extends State<ElectionScreen> {
  ElectionCategory? _category;
  _ElectionSection? _section;

  @override
  void initState() {
    super.initState();
    if (widget.interactivePreview) {
      _category = ElectionCategory.presidential;
      _section = _ElectionSection.live;
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = _category;
    final section = _section;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
            child: Column(
              children: [
                DropdownButtonFormField<ElectionCategory>(
                  initialValue: category,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'نوع انتخابات',
                    prefixIcon: Icon(Icons.account_tree_outlined),
                  ),
                  hint: const Text('یک سطح انتخاباتی انتخاب کنید'),
                  items:
                      ElectionCategory.values
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(
                                item.title,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                  onChanged:
                      (value) => setState(() {
                        _category = value;
                        _section = null;
                      }),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<_ElectionSection>(
                  initialValue: section,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'بخش انتخابات',
                    prefixIcon: Icon(Icons.view_list_outlined),
                  ),
                  hint: const Text('ابتدا نوع انتخابات را انتخاب کنید'),
                  items:
                      _ElectionSection.values
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(
                                item.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                  onChanged:
                      category == null
                          ? null
                          : (value) => setState(() => _section = value),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                category == null || section == null
                    ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'برای مشاهدهٔ اطلاعات، نوع انتخابات و سپس بخش مورد نظر را انتخاب کنید.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                    : widget.interactivePreview
                    ? category == ElectionCategory.presidential &&
                            section == _ElectionSection.live
                        ? const _InteractivePresidentialResults()
                        : const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'این شبیه‌سازی برای انتخابات ریاست جمهوری و نتایج زنده آماده شده است.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                    : ElectionProcessListScreen(
                      key: ValueKey('${category.code}-${section.name}'),
                      category: category,
                      kind: switch (section) {
                        _ElectionSection.scheduled =>
                          ElectionListKind.scheduled,
                        _ElectionSection.eligible => ElectionListKind.eligible,
                        _ElectionSection.live => ElectionListKind.live,
                        _ElectionSection.finalized =>
                          ElectionListKind.finalized,
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

class _InteractivePresidentialResults extends StatelessWidget {
  const _InteractivePresidentialResults();

  // Sorted alphabetically by family name. The vote counts are illustrative.
  static const _candidates = <(String, int)>[
    ('محمود احمدی‌نژاد', 1284560),
    ('حامد اسماعیلیون', 352180),
    ('منصوره معصومی اصل', 98740),
    ('محمدرضا باهنر', 186320),
    ('مسعود پزشکیان', 2016780),
    ('رضا پهلوی', 742150),
    ('علیرضا پناهیان', 245670),
    ('مصطفی تاجزاده', 312450),
    ('سید یاسر جبراییلی', 174830),
    ('سعید جلیلی', 932410),
    ('احمد جنتی', 65420),
    ('سید احمد خاتمی', 81730),
    ('سید مجتبی خامنه‌ای', 85320),
    ('صادق دهقانی', 112640),
    ('محمدرضا رائفی‌پور', 289510),
    ('مریم رجوی', 125640),
    ('حسین رزاق', 94310),
    ('محسن رضایی میرقائد', 421870),
    ('بابک زنجانی', 138920),
    ('کاظم صدیقی', 59310),
    ('حسن عباسی', 207540),
    ('مسیح علینژاد', 518360),
    ('محمد باقر قالیباف', 1105240),
    ('مجید قرقانی', 103280),
    ('مهدی کروبی', 276910),
    ('علی کریمی', 638420),
    ('محسن مقصودلو', 194760),
    ('میر حسین موسوی', 1438900),
    ('مصطفی میرسلیم', 76920),
    ('صدیقه وسمقی', 151830),
    ('فائزه هاشمی', 337260),
  ];

  static int get _totalVotes =>
      _candidates.fold(0, (total, candidate) => total + candidate.$2);
  static int get _maximumVotes => _candidates
      .map((candidate) => candidate.$2)
      .reduce((a, b) => a > b ? a : b);

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
    children: [
      Card(
        color: AppTheme.election.withValues(alpha: 0.09),
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'نمونهٔ تعاملی؛ اطلاعات و آرا غیرواقعی هستند',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 6),
              Text(
                'نامزدها بر اساس نام خانوادگی مرتب شده‌اند. شمار آرا فقط برای نمایش نحوهٔ ارائهٔ نتایج است.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Expanded(child: Text('مجموع آرای نمونه')),
              Text(
                _formatPersianNumber(_totalVotes),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 4),
      ..._candidates.indexed.map((entry) {
        final index = entry.$1;
        final candidate = entry.$2;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppTheme.election.withValues(
                        alpha: 0.12,
                      ),
                      child: Text('${index + 1}'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        candidate.$1,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      _formatPersianNumber(candidate.$2),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: candidate.$2 / _maximumVotes,
                  color: AppTheme.election,
                  backgroundColor: AppTheme.election.withValues(alpha: 0.12),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 4),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('رأی نمونه', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        );
      }),
    ],
  );

  static String _formatPersianNumber(int value) {
    final grouped = value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '٬',
    );
    const digits = '۰۱۲۳۴۵۶۷۸۹';
    return grouped.replaceAllMapped(
      RegExp(r'\d'),
      (match) => digits[int.parse(match.group(0)!)],
    );
  }
}
