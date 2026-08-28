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
    'سیاست تغییرات جغرافیایی',
    'جریمه بستن حساب',
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
                    SizedBox(
                      width: 180,
                      height: constraints.maxHeight,
                      child: _AdminNavigation(
                        sections: _sections,
                        selectedIndex: _selectedSection,
                        compact: false,
                        onSelected:
                            (index) => setState(() => _selectedSection = index),
                      ),
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
      8 => const _GeoPolicyEditor(),
      9 => const _ClosurePolicyEditor(),
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
            : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: sections.length,
              itemBuilder: (context, index) {
                final selected = index == selectedIndex;
                return ListTile(
                  dense: true,
                  selected: selected,
                  selectedTileColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  leading: Icon(
                    selected ? Icons.settings : Icons.settings_outlined,
                  ),
                  title: Text(
                    sections[index],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => onSelected(index),
                );
              },
            );

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child:
          compact
              ? Padding(padding: const EdgeInsets.all(8), child: navigation)
              : navigation,
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

class _GeoPolicyEditor extends StatefulWidget {
  const _GeoPolicyEditor();

  @override
  State<_GeoPolicyEditor> createState() => _GeoPolicyEditorState();
}

class _GeoPolicyEditorState extends State<_GeoPolicyEditor> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _stage = TextEditingController();
  final _maxChanges = TextEditingController();
  final _windowDays = TextEditingController();
  final _cooldownDays = TextEditingController();
  final _effectiveFrom = TextEditingController(
    text: '2026-08-24T00:00:00.000Z',
  );
  final _effectiveTo = TextEditingController();
  bool _isActive = true;
  int? _editingId;
  var _refresh = 0;

  @override
  void dispose() {
    for (final controller in [
      _code,
      _name,
      _description,
      _stage,
      _maxChanges,
      _windowDays,
      _cooldownDays,
      _effectiveFrom,
      _effectiveTo,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final stage = int.tryParse(_stage.text.trim());
    final cooldown = int.tryParse(_cooldownDays.text.trim());
    if (_code.text.trim().isEmpty ||
        _name.text.trim().isEmpty ||
        stage == null ||
        stage < 1 ||
        cooldown == null ||
        cooldown < 1 ||
        DateTime.tryParse(_effectiveFrom.text.trim()) == null ||
        (_effectiveTo.text.trim().isNotEmpty &&
            DateTime.tryParse(_effectiveTo.text.trim()) == null)) {
      _message('کد، نام، مرحله و تعداد روز معتبر را وارد کنید.');
      return;
    }
    final data = <String, dynamic>{
      'policy_code': _code.text.trim(),
      'policy_name': _name.text.trim(),
      'description':
          _description.text.trim().isEmpty ? null : _description.text.trim(),
      'policy_stage': stage,
      'max_changes_allowed': _nullableInt(_maxChanges),
      'window_days': _nullableInt(_windowDays),
      'cooldown_days': cooldown,
      'is_active': _isActive,
      'effective_from': _effectiveFrom.text.trim(),
      'effective_to':
          _effectiveTo.text.trim().isEmpty ? null : _effectiveTo.text.trim(),
    };
    final repository = GetIt.I<AdminRepository>();
    if (_editingId == null) {
      await repository.createGeoCooldownPolicy(data);
    } else {
      await repository.updateGeoCooldownPolicy(_editingId!, data);
    }
    _clear();
    setState(() => _refresh++);
    _message('سیاست تغییرات جغرافیایی ذخیره شد.');
  }

  int? _nullableInt(TextEditingController controller) =>
      controller.text.trim().isEmpty
          ? null
          : int.tryParse(controller.text.trim());

  void _edit(AdminGeoCooldownPolicy item) {
    _editingId = item.id;
    _code.text = item.policyCode;
    _name.text = item.policyName;
    _description.text = item.description ?? '';
    _stage.text = '${item.policyStage}';
    _maxChanges.text = '${item.maxChangesAllowed ?? ''}';
    _windowDays.text = '${item.windowDays ?? ''}';
    _cooldownDays.text = '${item.cooldownDays}';
    _effectiveFrom.text = item.effectiveFrom.toIso8601String();
    _effectiveTo.text = item.effectiveTo?.toIso8601String() ?? '';
    _isActive = item.isActive;
    setState(() {});
  }

  Future<void> _delete(AdminGeoCooldownPolicy item) async {
    await GetIt.I<AdminRepository>().deleteGeoCooldownPolicy(item.id);
    setState(() => _refresh++);
    _message('سیاست حذف شد.');
  }

  void _clear() {
    _editingId = null;
    for (final controller in [
      _code,
      _name,
      _description,
      _stage,
      _maxChanges,
      _windowDays,
      _cooldownDays,
      _effectiveFrom,
      _effectiveTo,
    ]) {
      controller.clear();
    }
    _effectiveFrom.text = '2026-08-24T00:00:00.000Z';
    _isActive = true;
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
              controller: _code,
              decoration: const InputDecoration(labelText: 'کد سیاست'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'نام سیاست'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'توضیحات'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _numberField('مرحله', _stage)),
                const SizedBox(width: 12),
                Expanded(child: _numberField('حداکثر تغییر', _maxChanges)),
              ],
            ),
            const SizedBox(height: 12),
            _dateField('شروع اجرا (ISO)', _effectiveFrom),
            const SizedBox(height: 12),
            _dateField('پایان اجرا (اختیاری، ISO)', _effectiveTo),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _numberField('پنجره روز', _windowDays)),
                const SizedBox(width: 12),
                Expanded(child: _numberField('دوره انتظار روز', _cooldownDays)),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('فعال'),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      _editingId == null ? 'ایجاد سیاست' : 'ویرایش سیاست',
                    ),
                  ),
                ),
                if (_editingId != null) ...[
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => setState(_clear),
                    child: const Text('انصراف'),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _AsyncRecordsCard<AdminGeoCooldownPolicy>(
          title: 'سیاست‌های تغییرات جغرافیایی',
          future: GetIt.I<AdminRepository>().geoCooldownPolicies(),
          emptyText: 'سیاستی ثبت نشده است.',
          itemBuilder:
              (context, item) => ListTile(
                title: Text('${item.policyName} — مرحله ${item.policyStage}'),
                subtitle: Text(
                  '${item.policyCode} | انتظار: ${item.cooldownDays} روز | '
                  '${item.isActive ? 'فعال' : 'غیرفعال'}',
                ),
                trailing: _PolicyActions(
                  onEdit: () => _edit(item),
                  onDelete: () => _delete(item),
                ),
              ),
        ),
      ],
    );
  }
}

class _ClosurePolicyEditor extends StatefulWidget {
  const _ClosurePolicyEditor();

  @override
  State<_ClosurePolicyEditor> createState() => _ClosurePolicyEditorState();
}

class _ClosurePolicyEditorState extends State<_ClosurePolicyEditor> {
  final _familyCode = TextEditingController(text: 'account_closure');
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _stage = TextEditingController();
  final _hours = TextEditingController();
  final _scope = TextEditingController(text: 'account_closure');
  final _effectiveFrom = TextEditingController(
    text: '2026-08-24T00:00:00.000Z',
  );
  final _effectiveTo = TextEditingController();
  bool _isActive = true;
  int? _editingId;
  var _refresh = 0;

  @override
  void dispose() {
    for (final controller in [
      _familyCode,
      _code,
      _name,
      _description,
      _stage,
      _hours,
      _scope,
      _effectiveFrom,
      _effectiveTo,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final stage = int.tryParse(_stage.text.trim());
    final hours = int.tryParse(_hours.text.trim());
    if (_familyCode.text.trim().isEmpty ||
        _code.text.trim().isEmpty ||
        _name.text.trim().isEmpty ||
        _scope.text.trim().isEmpty ||
        stage == null ||
        stage < 1 ||
        hours == null ||
        hours < 1 ||
        DateTime.tryParse(_effectiveFrom.text.trim()) == null ||
        (_effectiveTo.text.trim().isNotEmpty &&
            DateTime.tryParse(_effectiveTo.text.trim()) == null)) {
      _message('کدها، نام، مرحله و ساعات معتبر را وارد کنید.');
      return;
    }
    final data = <String, dynamic>{
      'policy_family_code': _familyCode.text.trim(),
      'policy_code': _code.text.trim(),
      'policy_name': _name.text.trim(),
      'description':
          _description.text.trim().isEmpty ? null : _description.text.trim(),
      'penalty_stage': stage,
      'penalty_hours': hours,
      'trigger_scope': _scope.text.trim(),
      'is_active': _isActive,
      'effective_from': _effectiveFrom.text.trim(),
      'effective_to':
          _effectiveTo.text.trim().isEmpty ? null : _effectiveTo.text.trim(),
    };
    final repository = GetIt.I<AdminRepository>();
    if (_editingId == null) {
      await repository.createClosurePenaltyPolicy(data);
    } else {
      await repository.updateClosurePenaltyPolicy(_editingId!, data);
    }
    _clear();
    setState(() => _refresh++);
    _message('سیاست جریمه بستن حساب ذخیره شد.');
  }

  void _edit(AdminClosurePenaltyPolicy item) {
    _editingId = item.id;
    _familyCode.text = item.policyFamilyCode;
    _code.text = item.policyCode;
    _name.text = item.policyName;
    _description.text = item.description ?? '';
    _stage.text = '${item.penaltyStage}';
    _hours.text = '${item.penaltyHours}';
    _scope.text = item.triggerScope;
    _effectiveFrom.text = item.effectiveFrom.toIso8601String();
    _effectiveTo.text = item.effectiveTo?.toIso8601String() ?? '';
    _isActive = item.isActive;
    setState(() {});
  }

  Future<void> _delete(AdminClosurePenaltyPolicy item) async {
    await GetIt.I<AdminRepository>().deleteClosurePenaltyPolicy(item.id);
    setState(() => _refresh++);
    _message('سیاست حذف شد.');
  }

  void _clear() {
    _editingId = null;
    _familyCode.text = 'account_closure';
    _code.clear();
    _name.clear();
    _description.clear();
    _stage.clear();
    _hours.clear();
    _scope.text = 'account_closure';
    _effectiveFrom.text = '2026-08-24T00:00:00.000Z';
    _effectiveTo.clear();
    _isActive = true;
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
              controller: _familyCode,
              decoration: const InputDecoration(labelText: 'کد خانواده سیاست'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              decoration: const InputDecoration(labelText: 'کد سیاست'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'نام سیاست'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'توضیحات'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _numberField('مرحله جریمه', _stage)),
                const SizedBox(width: 12),
                Expanded(child: _numberField('ساعات جریمه', _hours)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _scope,
              decoration: const InputDecoration(labelText: 'محدوده اجرا'),
            ),
            const SizedBox(height: 12),
            _dateField('شروع اجرا (ISO)', _effectiveFrom),
            const SizedBox(height: 12),
            _dateField('پایان اجرا (اختیاری، ISO)', _effectiveTo),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('فعال'),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      _editingId == null ? 'ایجاد سیاست' : 'ویرایش سیاست',
                    ),
                  ),
                ),
                if (_editingId != null) ...[
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => setState(_clear),
                    child: const Text('انصراف'),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _AsyncRecordsCard<AdminClosurePenaltyPolicy>(
          title: 'سیاست‌های جریمه بستن حساب',
          future: GetIt.I<AdminRepository>().closurePenaltyPolicies(),
          emptyText: 'سیاستی ثبت نشده است.',
          itemBuilder:
              (context, item) => ListTile(
                title: Text('${item.policyName} — مرحله ${item.penaltyStage}'),
                subtitle: Text(
                  '${item.policyCode} | جریمه: ${item.penaltyHours} ساعت | '
                  '${item.isActive ? 'فعال' : 'غیرفعال'}',
                ),
                trailing: _PolicyActions(
                  onEdit: () => _edit(item),
                  onDelete: () => _delete(item),
                ),
              ),
        ),
      ],
    );
  }
}

Widget _numberField(String label, TextEditingController controller) {
  return TextField(
    controller: controller,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(labelText: label),
  );
}

Widget _dateField(String label, TextEditingController controller) {
  return TextField(
    controller: controller,
    decoration: InputDecoration(labelText: label),
  );
}

class _PolicyActions extends StatelessWidget {
  const _PolicyActions({required this.onEdit, required this.onDelete});

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'ویرایش',
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: 'حذف',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline, color: Colors.red),
        ),
      ],
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
