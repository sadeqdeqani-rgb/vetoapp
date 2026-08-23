import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/admin_entities.dart';
import '../../domain/repositories/admin_repository.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  static const _sections = <String>[
    'معرفی وتواپ',
    'قوانین و مقررات',
    'فیلم معرفی',
    'استان‌ها',
    'شهرستان‌ها',
    'شهرها',
    'روستاها',
    'محدوده کد ملی',
    'کاربر ادمین',
  ];

  int _selectedSection = 0;

  @override
  void initState() {
    super.initState();
    _ensureSession();
  }

  Future<void> _ensureSession() async {
    if (!await GetIt.I<AdminRepository>().hasSession() && mounted) {
      context.go('/admin/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final adminTheme = baseTheme.copyWith(
      textTheme: _adminTextTheme(baseTheme.textTheme),
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        labelStyle: _adminStyle(
          baseTheme.inputDecorationTheme.labelStyle,
          fallbackSize: 16,
        ),
        hintStyle: _adminStyle(
          baseTheme.inputDecorationTheme.hintStyle,
          fallbackSize: 16,
        ),
      ),
    );

    return Theme(
      data: adminTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: const Text('مدیریت سامانه')),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 800;
              return Row(
                children: [
                  if (!compact)
                    _AdminNavigation(
                      sections: _sections,
                      selectedIndex: _selectedSection,
                      compact: false,
                      onSelected:
                          (index) => setState(() => _selectedSection = index),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (compact)
                            _AdminNavigation(
                              sections: _sections,
                              selectedIndex: _selectedSection,
                              compact: true,
                              onSelected:
                                  (index) =>
                                      setState(() => _selectedSection = index),
                            ),
                          if (compact) const SizedBox(height: 16),
                          Text(
                            _sections[_selectedSection],
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 16),
                          _sectionBody(),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _sectionBody() {
    return switch (_selectedSection) {
      0 => const _ContentEditor(kind: _ContentKind.introduction),
      1 => const _ContentEditor(kind: _ContentKind.terms),
      2 => const _VideoEditor(),
      3 => const _GeographyEditor(type: 'province', label: 'استان'),
      4 => const _GeographyEditor(type: 'county', label: 'شهرستان'),
      5 => const _GeographyEditor(type: 'city', label: 'شهر'),
      6 => const _GeographyEditor(type: 'village', label: 'روستا'),
      7 => const _NationalIdEditor(),
      _ => const _AdminUserEditor(),
    };
  }
}

TextTheme _adminTextTheme(TextTheme source) {
  return TextTheme(
    displayLarge: _adminStyle(source.displayLarge, fallbackSize: 57),
    displayMedium: _adminStyle(source.displayMedium, fallbackSize: 45),
    displaySmall: _adminStyle(source.displaySmall, fallbackSize: 36),
    headlineLarge: _adminStyle(source.headlineLarge, fallbackSize: 32),
    headlineMedium: _adminStyle(source.headlineMedium, fallbackSize: 28),
    headlineSmall: _adminStyle(source.headlineSmall, fallbackSize: 24),
    titleLarge: _adminStyle(source.titleLarge, fallbackSize: 22),
    titleMedium: _adminStyle(source.titleMedium, fallbackSize: 16),
    titleSmall: _adminStyle(source.titleSmall, fallbackSize: 14),
    bodyLarge: _adminStyle(source.bodyLarge, fallbackSize: 16),
    bodyMedium: _adminStyle(source.bodyMedium, fallbackSize: 14),
    bodySmall: _adminStyle(source.bodySmall, fallbackSize: 12),
    labelLarge: _adminStyle(source.labelLarge, fallbackSize: 14),
    labelMedium: _adminStyle(source.labelMedium, fallbackSize: 12),
    labelSmall: _adminStyle(source.labelSmall, fallbackSize: 11),
  );
}

TextStyle _adminStyle(TextStyle? source, {required double fallbackSize}) {
  return (source ?? const TextStyle()).copyWith(
    fontSize: (source?.fontSize ?? fallbackSize) + 10,
    fontWeight: FontWeight.bold,
  );
}

class _AdminNavigation extends StatelessWidget {
  const _AdminNavigation({
    required this.sections,
    required this.selectedIndex,
    required this.compact,
    required this.onSelected,
  });

  final List<String> sections;
  final int selectedIndex;
  final bool compact;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final navigation =
        compact
            ? DropdownButtonFormField<int>(
              initialValue: selectedIndex,
              decoration: const InputDecoration(labelText: 'بخش مدیریتی'),
              items: [
                for (var i = 0; i < sections.length; i++)
                  DropdownMenuItem(value: i, child: Text(sections[i])),
              ],
              onChanged: (value) {
                if (value != null) onSelected(value);
              },
            )
            : NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: onSelected,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final section in sections)
                  NavigationRailDestination(
                    icon: const Icon(Icons.settings_outlined),
                    selectedIcon: const Icon(Icons.settings),
                    label: Text(section),
                  ),
              ],
            );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(padding: const EdgeInsets.all(8), child: navigation),
    );
  }
}

enum _ContentKind { introduction, terms }

class _ContentEditor extends StatefulWidget {
  const _ContentEditor({required this.kind});

  final _ContentKind kind;

  @override
  State<_ContentEditor> createState() => _ContentEditorState();
}

class _ContentEditorState extends State<_ContentEditor> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _isActive = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      _message('عنوان و متن را وارد کنید.');
      return;
    }
    final draft = AdminContentDraft(
      title: _title.text.trim(),
      body: _body.text.trim(),
      isActive: _isActive,
    );
    final repository = GetIt.I<AdminRepository>();
    if (widget.kind == _ContentKind.introduction) {
      await repository.saveIntroduction(draft);
    } else {
      await repository.saveTerms(draft);
    }
    _message('نسخه به‌صورت آزمایشی ثبت شد.');
  }

  void _message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EditorCard(
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'عنوان'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _body,
              minLines: 10,
              maxLines: 18,
              decoration: const InputDecoration(labelText: 'متن کامل'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('فعال‌سازی نسخه'),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('ذخیره نسخه'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ContentRecordsList(
          title: 'نسخه‌های موجود',
          future:
              widget.kind == _ContentKind.introduction
                  ? GetIt.I<AdminRepository>().introductionRecords()
                  : GetIt.I<AdminRepository>().termsRecords(),
        ),
      ],
    );
  }
}

class _VideoEditor extends StatefulWidget {
  const _VideoEditor();

  @override
  State<_VideoEditor> createState() => _VideoEditorState();
}

class _VideoEditorState extends State<_VideoEditor> {
  final _title = TextEditingController();
  final _videoUrl = TextEditingController();
  final _posterUrl = TextEditingController();
  bool _isActive = false;

  @override
  void dispose() {
    _title.dispose();
    _videoUrl.dispose();
    _posterUrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty ||
        !_videoUrl.text.trim().startsWith('https://')) {
      _message('عنوان و URL معتبر HTTPS را وارد کنید.');
      return;
    }
    await GetIt.I<AdminRepository>().saveIntroductionVideo(
      AdminVideoDraft(
        title: _title.text.trim(),
        videoUrl: _videoUrl.text.trim(),
        posterUrl: _posterUrl.text.trim(),
        isActive: _isActive,
      ),
    );
    _message('اطلاعات ویدئو به‌صورت آزمایشی ثبت شد.');
  }

  void _message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EditorCard(
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'عنوان ویدئو'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _videoUrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'URL ویدئو (HTTPS)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _posterUrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL تصویر پوستر (اختیاری)',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('فعال‌سازی نسخه'),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.video_library_outlined),
              label: const Text('ذخیره ویدئو'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _VideoRecordsList(
          future: GetIt.I<AdminRepository>().introductionVideoRecords(),
        ),
      ],
    );
  }
}

class _GeographyEditor extends StatefulWidget {
  const _GeographyEditor({required this.type, required this.label});

  final String type;
  final String label;

  @override
  State<_GeographyEditor> createState() => _GeographyEditorState();
}

class _GeographyEditorState extends State<_GeographyEditor> {
  final _name = TextEditingController();
  final _parent = TextEditingController();
  final _code = TextEditingController();
  bool _isActive = true;

  @override
  void dispose() {
    _name.dispose();
    _parent.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final id = int.tryParse(_code.text.trim());
    final parentId = int.tryParse(_parent.text.trim());
    if (_name.text.trim().isEmpty ||
        id == null ||
        (widget.type != 'province' && parentId == null)) {
      _message('نام ${widget.label} و کد داخلی را وارد کنید.');
      return;
    }
    await GetIt.I<AdminRepository>().saveGeography(
      AdminGeoItem(
        id: id,
        name: _name.text.trim(),
        type: widget.type,
        parentId: widget.type == 'province' ? 1 : parentId,
        isActive: _isActive,
      ),
    );
    _message('${widget.label} به‌صورت آزمایشی ثبت شد.');
  }

  void _message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EditorCard(
          children: [
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: 'نام ${widget.label}'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'کد داخلی'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _parent,
              decoration: const InputDecoration(labelText: 'شناسه داخلی والد'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('رکورد فعال'),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.account_tree_outlined),
              label: Text('ذخیره ${widget.label}'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _GeoRecordsList(
          label: widget.label,
          future: GetIt.I<AdminRepository>().geographyRecords(widget.type),
        ),
      ],
    );
  }
}

class _NationalIdEditor extends StatefulWidget {
  const _NationalIdEditor();

  @override
  State<_NationalIdEditor> createState() => _NationalIdEditorState();
}

class _NationalIdEditorState extends State<_NationalIdEditor> {
  final _prefix = TextEditingController();
  final _firstFrom = TextEditingController(text: '000');
  final _firstTo = TextEditingController(text: '999');
  final _secondFrom = TextEditingController(text: '000');
  final _secondTo = TextEditingController(text: '999');

  @override
  void dispose() {
    for (final controller in [
      _prefix,
      _firstFrom,
      _firstTo,
      _secondFrom,
      _secondTo,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final prefix = _prefix.text.trim();
    final values =
        [
          _firstFrom,
          _firstTo,
          _secondFrom,
          _secondTo,
        ].map((controller) => int.tryParse(controller.text.trim())).toList();
    if (!RegExp(r'^\d{3}$').hasMatch(prefix) ||
        values.any((value) => value == null || value < 0 || value > 999)) {
      _message('Prefix سه‌رقمی و محدوده‌های 000 تا 999 را وارد کنید.');
      return;
    }
    await GetIt.I<AdminRepository>().saveNationalIdEligibility(
      NationalIdEligibilityDraft(
        prefix: prefix,
        firstFrom: values[0]!,
        firstTo: values[1]!,
        secondFrom: values[2]!,
        secondTo: values[3]!,
      ),
    );
    _message('محدوده کد ملی به‌صورت آزمایشی ثبت شد.');
  }

  void _message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EditorCard(
          children: [
            TextField(
              controller: _prefix,
              maxLength: 3,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Prefix سه‌رقمی'),
            ),
            Row(
              children: [
                Expanded(child: _rangeField('محدوده اول از', _firstFrom)),
                const SizedBox(width: 12),
                Expanded(child: _rangeField('محدوده اول تا', _firstTo)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _rangeField('محدوده دوم از', _secondFrom)),
                const SizedBox(width: 12),
                Expanded(child: _rangeField('محدوده دوم تا', _secondTo)),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.pin_outlined),
              label: const Text('ذخیره محدوده'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _NationalIdRecordsList(
          future: GetIt.I<AdminRepository>().nationalIdRecords(),
        ),
      ],
    );
  }

  Widget _rangeField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _AdminUserEditor extends StatefulWidget {
  const _AdminUserEditor();

  @override
  State<_AdminUserEditor> createState() => _AdminUserEditorState();
}

class _AdminUserEditorState extends State<_AdminUserEditor> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_username.text.trim().isEmpty ||
        _password.text.length < 12 ||
        _password.text != _confirm.text) {
      _message('نام کاربری و رمز عبور یکسان حداقل ۱۲ کاراکتری را وارد کنید.');
      return;
    }
    await GetIt.I<AdminRepository>().createAdminUser(
      username: _username.text.trim(),
      password: _password.text,
    );
    _password.clear();
    _confirm.clear();
    _message('در نسخه متصل، رمز فقط در Backend هش خواهد شد.');
  }

  void _message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _EditorCard(
      children: [
        const Text(
          'رمز عبور نباید در Flutter یا لاگ ذخیره شود و باید فقط در Backend هش شود.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _username,
          decoration: const InputDecoration(labelText: 'نام کاربری ادمین'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'رمز عبور'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirm,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'تکرار رمز عبور'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('ایجاد کاربر ادمین'),
        ),
      ],
    );
  }
}

class _ContentRecordsList extends StatelessWidget {
  const _ContentRecordsList({required this.title, required this.future});

  final String title;
  final Future<List<AdminContentRecord>> future;

  @override
  Widget build(BuildContext context) {
    return _AsyncRecordsCard<AdminContentRecord>(
      title: title,
      future: future,
      emptyText: 'هیچ نسخه‌ای ثبت نشده است.',
      itemBuilder:
          (context, item) => ExpansionTile(
            leading: Icon(
              item.isActive ? Icons.check_circle : Icons.description_outlined,
              color: item.isActive ? Colors.green : null,
            ),
            title: Text('${item.title} — نسخه ${item.versionNumber}'),
            subtitle: Text(
              'شناسه: ${item.id} | ${item.isActive ? 'فعال' : 'غیرفعال'}'
              '${item.publishedAt == null ? '' : ' | منتشرشده'}',
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SelectableText(item.body),
                ),
              ),
            ],
          ),
    );
  }
}

class _VideoRecordsList extends StatelessWidget {
  const _VideoRecordsList({required this.future});

  final Future<List<AdminVideoRecord>> future;

  @override
  Widget build(BuildContext context) {
    return _AsyncRecordsCard<AdminVideoRecord>(
      title: 'ویدئوهای موجود',
      future: future,
      emptyText: 'هیچ ویدئویی ثبت نشده است.',
      itemBuilder:
          (context, item) => ListTile(
            leading: Icon(
              item.isActive ? Icons.play_circle : Icons.video_library_outlined,
              color: item.isActive ? Colors.green : null,
            ),
            title: Text('${item.title} — نسخه ${item.versionNumber}'),
            subtitle: Text(
              'شناسه: ${item.id} | ${item.isActive ? 'فعال' : 'غیرفعال'}\n${item.videoUrl}',
            ),
          ),
    );
  }
}

class _GeoRecordsList extends StatelessWidget {
  const _GeoRecordsList({required this.label, required this.future});

  final String label;
  final Future<List<AdminGeoItem>> future;

  @override
  Widget build(BuildContext context) {
    return _AsyncRecordsCard<AdminGeoItem>(
      title: '$label‌های موجود',
      future: future,
      emptyText: 'رکوردی پیدا نشد.',
      itemBuilder:
          (context, item) => ListTile(
            leading: Icon(
              item.isActive ? Icons.check_circle : Icons.block,
              color: item.isActive ? Colors.green : Colors.red,
            ),
            title: Text('${item.name} — شناسه ${item.id}'),
            subtitle: Text(
              'والد: ${item.parentId ?? '—'} | ${item.isActive ? 'فعال' : 'غیرفعال'}',
            ),
          ),
    );
  }
}

class _NationalIdRecordsList extends StatelessWidget {
  const _NationalIdRecordsList({required this.future});

  final Future<List<NationalIdEligibilityRecord>> future;

  @override
  Widget build(BuildContext context) {
    return _AsyncRecordsCard<NationalIdEligibilityRecord>(
      title: 'Prefixهای موجود',
      future: future,
      emptyText: 'Prefixی پیدا نشد.',
      itemBuilder:
          (context, item) => ListTile(
            leading: const Icon(Icons.pin_outlined),
            title: Text('Prefix ${item.prefix}'),
            subtitle: Text(
              'محدوده اول: ${item.firstFrom} تا ${item.firstTo} | '
              'محدوده دوم: ${item.secondFrom} تا ${item.secondTo}',
            ),
          ),
    );
  }
}

class _AsyncRecordsCard<T> extends StatelessWidget {
  const _AsyncRecordsCard({
    required this.title,
    required this.future,
    required this.itemBuilder,
    required this.emptyText,
  });

  final String title;
  final Future<List<T>> future;
  final Widget Function(BuildContext, T) itemBuilder;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FutureBuilder<List<T>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return ListTile(
                leading: const Icon(Icons.error_outline, color: Colors.red),
                title: Text('خطا در خواندن $title'),
                subtitle: Text('${snapshot.error}'),
              );
            }
            final records = snapshot.data ?? <T>[];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const Divider(),
                if (records.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(emptyText),
                  )
                else
                  ...records.map((record) => itemBuilder(context, record)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EditorCard extends StatelessWidget {
  const _EditorCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}
