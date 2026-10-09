import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import 'about_sections.dart';

const _sectionOrder = [
  'goals',
  'identity',
  'activation',
  'validation',
  'technical',
  'creators',
];
const _defaultSectionTitles = <String, String>{
  'goals': 'اهداف وتواپ',
  'identity': 'مکانیسم احراز هویت',
  'activation': 'نحوه فعال سازی سامانه',
  'validation': 'فرآیند اعتبارسنجی سامانه',
  'technical': 'زیرساخت فنی',
  'creators': 'هویت سازندگان',
};

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  late Future<List<AboutSection>> _sections = _loadSections();

  Future<List<AboutSection>> _loadSections() async {
    final response = await getIt<Dio>().get<Map<String, dynamic>>(
      '/api/v1/home/introduction',
    );
    final rows = response.data?['data'];
    if (rows is! List) throw const FormatException('محتوای معرفی دریافت نشد.');
    final sections =
        rows
            .whereType<Map>()
            .map((row) {
              final key = '${row['section_key'] ?? ''}';
              final fallback =
                  aboutSections
                      .where((section) => section.key == key)
                      .firstOrNull;
              final title = '${row['title'] ?? ''}'.trim();
              final body = '${row['body_text'] ?? ''}'.trim();
              return AboutSection(
                key: key,
                title:
                    title.isEmpty ? (_defaultSectionTitles[key] ?? '') : title,
                body: body.isEmpty ? (fallback?.body ?? '') : body,
              );
            })
            .where(
              (section) => section.title.isNotEmpty && section.body.isNotEmpty,
            )
            .toList();
    sections.sort(
      (a, b) => _sectionOrder
          .indexOf(a.key ?? '')
          .compareTo(_sectionOrder.indexOf(b.key ?? '')),
    );
    return sections;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: FutureBuilder<List<AboutSection>>(
        future: _sections,
        builder: (context, snapshot) {
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData)
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('دریافت محتوای معرفی ممکن نشد.'),
                  TextButton(
                    onPressed:
                        () => setState(() => _sections = _loadSections()),
                    child: const Text('تلاش دوباره'),
                  ),
                ],
              ),
            );
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Text(
                'معرفی وتواپ',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ...snapshot.data!.map(
                (section) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.info_outline,
                        color: AppTheme.primary,
                      ),
                      title: Text(section.title),
                      trailing: const Icon(Icons.chevron_left),
                      onTap:
                          () => context.push('/about/detail', extra: section),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
