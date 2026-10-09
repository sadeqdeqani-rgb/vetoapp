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
    'استان‌ها',
    'شهرستان‌ها',
    'شهرها',
    'روستاها',
    'محدوده کد ملی',
    'گزارش‌های کد ملی و سن',
    'سیاست تغییرات جغرافیایی',
    'جریمه بستن حساب',
    'کاربر ادمین',
    'سیاست چرخهٔ فرایندها',
    'محتوای خانه و وضعیت سامانه',
  ];

  int _selectedSection = 0;
  bool _confirmingExit = false;

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

  Future<void> _confirmAdminExit() async {
    if (_confirmingExit || !mounted) return;
    _confirmingExit = true;
    try {
      final accepted = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('خروج از پنل مدیریت'),
              content: const Text(
                'از پنل ادمین خارج شوید و به صفحهٔ ورود بروید؟',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('ادامهٔ کار'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('خروج'),
                ),
              ],
            ),
      );
      if (accepted != true || !mounted) return;
      try {
        await GetIt.I<AdminRepository>().logout();
      } catch (_) {
        // The repository clears the local admin session even when the API fails.
      }
      if (mounted) context.go('/admin/login');
    } finally {
      _confirmingExit = false;
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
        child: PopScope<void>(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _confirmAdminExit();
          },
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
                              (index) =>
                                  setState(() => _selectedSection = index),
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
                                    (index) => setState(
                                      () => _selectedSection = index,
                                    ),
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
      ),
    );
  }

  Widget _sectionBody() {
    return switch (_selectedSection) {
      0 => const _GeographyEditor(type: 'province', label: 'استان'),
      1 => const _GeographyEditor(type: 'county', label: 'شهرستان'),
      2 => const _GeographyEditor(type: 'city', label: 'شهر'),
      3 => const _GeographyEditor(type: 'village', label: 'روستا'),
      4 => const _NationalIdEditor(),
      5 => const _AgeEligibilityReportsEditor(),
      6 => const _GeoPolicyEditor(),
      7 => const _ClosurePolicyEditor(),
      8 => const _AdminUserEditor(),
      9 => const _ProcessLifecyclePolicyEditor(),
      _ => const _HomeManagementEditor(),
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

class _ContentEditor extends StatefulWidget {
  const _ContentEditor();

  @override
  State<_ContentEditor> createState() => _ContentEditorState();
}

class _ContentEditorState extends State<_ContentEditor> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _isActive = false;
  bool _isSaving = false;
  late Future<List<AdminContentRecord>> _recordsFuture =
      GetIt.I<AdminRepository>().termsRecords();

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
    setState(() => _isSaving = true);
    try {
      await repository.saveTerms(draft);
      final records = await repository.termsRecords();
      if (!mounted) return;
      setState(() => _recordsFuture = Future.value(records));
      AdminContentRecord? savedRecord;
      for (final record in records) {
        if (record.title == draft.title && record.body == draft.body) {
          savedRecord = record;
          break;
        }
      }
      if (draft.isActive &&
          (savedRecord == null ||
              !savedRecord.isActive ||
              savedRecord.publishedAt == null)) {
        _message(
          'نسخه ذخیره شد، اما انتشار آن تأیید نشد. از «انتشار در اپ» استفاده کنید.',
        );
      } else if (draft.isActive) {
        _message('نسخهٔ قوانین و مقررات در اپ منتشر شد.');
      } else {
        _message('نسخه به‌صورت پیش‌نویس ذخیره شد.');
      }
    } catch (_) {
      if (mounted) {
        _message('ذخیرهٔ قوانین ناموفق بود؛ اتصال پنل به سرور را بررسی کنید.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _publish(AdminContentRecord record) async {
    final repository = GetIt.I<AdminRepository>();
    setState(() => _isSaving = true);
    try {
      await repository.publishTerms(record.id);
      final records = await repository.termsRecords();
      if (!mounted) return;
      setState(() => _recordsFuture = Future.value(records));
      final published = records.where((item) => item.id == record.id);
      if (published.isNotEmpty &&
          published.first.isActive &&
          published.first.publishedAt != null) {
        _message('نسخهٔ ${record.versionNumber} در اپ منتشر شد.');
      } else {
        _message('سرور انتشار نسخه را تأیید نکرد.');
      }
    } catch (_) {
      if (mounted) {
        _message(
          'انتشار نسخه ناموفق بود؛ نشست ادمین یا اتصال سرور را بررسی کنید.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
              decoration: const InputDecoration(
                labelText: 'عنوان قوانین و مقررات',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _body,
              minLines: 10,
              maxLines: 18,
              decoration: const InputDecoration(
                labelText: 'متن قوانین و مقررات',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('انتشار این نسخه در اپ'),
              value: _isActive,
              onChanged:
                  _isSaving
                      ? null
                      : (value) => setState(() => _isActive = value),
            ),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_isSaving ? 'در حال ذخیره…' : 'ذخیره نسخهٔ قوانین'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ContentRecordsList(
          title: 'نسخه‌های قوانین و مقررات',
          future: _recordsFuture,
          onPublish: _isSaving ? null : _publish,
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

class _AgeEligibilityReportsEditor extends StatefulWidget {
  const _AgeEligibilityReportsEditor();

  @override
  State<_AgeEligibilityReportsEditor> createState() =>
      _AgeEligibilityReportsEditorState();
}

class _AgeEligibilityReportsEditorState
    extends State<_AgeEligibilityReportsEditor> {
  late Future<List<NationalIdAgeEligibilityReport>> _reports =
      GetIt.I<AdminRepository>().nationalIdAgeEligibilityReports();

  void _reload() => setState(() {
    _reports = GetIt.I<AdminRepository>().nationalIdAgeEligibilityReports();
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _EditorCard(
        children: [
          Text('گزارش‌های ثبت‌شده برای بررسی کد ملی و تاریخ تولد'),
          SizedBox(height: 8),
          Text(
            'اطلاعات هویتی کامل فقط در این بخش احراز هویت‌شدهٔ پنل ادمین نمایش داده می‌شود. اصلاح محدوده‌ها را پس از بررسی، دستی در بخش «محدوده کد ملی» انجام دهید.',
          ),
        ],
      ),
      const SizedBox(height: 12),
      _AsyncRecordsCard<NationalIdAgeEligibilityReport>(
        title: 'گزارش‌های ثبت‌نام',
        future: _reports,
        emptyText: 'گزارشی ثبت نشده است.',
        itemBuilder:
            (context, report) => _AgeEligibilityReportTile(
              key: ValueKey(report.id),
              report: report,
              onSaved: _reload,
            ),
      ),
    ],
  );
}

class _AgeEligibilityReportTile extends StatefulWidget {
  const _AgeEligibilityReportTile({
    super.key,
    required this.report,
    required this.onSaved,
  });
  final NationalIdAgeEligibilityReport report;
  final VoidCallback onSaved;

  @override
  State<_AgeEligibilityReportTile> createState() =>
      _AgeEligibilityReportTileState();
}

class _AgeEligibilityReportTileState extends State<_AgeEligibilityReportTile> {
  late final TextEditingController _note = TextEditingController(
    text: widget.report.adminNote ?? '',
  );
  late String _status = widget.report.statusCode;
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String _statusLabel(String value) => switch (value) {
    'Reviewed' => 'بررسی‌شده',
    'Rejected' => 'ردشده',
    _ => 'در انتظار',
  };

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await GetIt.I<AdminRepository>().reviewNationalIdAgeEligibilityReport(
        widget.report.id,
        _status,
        _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('بررسی گزارش ذخیره شد.')));
      widget.onSaved();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ذخیرهٔ گزارش ناموفق بود: $error')),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
    leading: const Icon(Icons.badge_outlined),
    title: Text('گزارش ${widget.report.id} — ${_statusLabel(_status)}'),
    subtitle: Text(
      'ثبت: ${widget.report.createdAt.toLocal()} | پیش‌شماره: ${widget.report.nationalId.substring(0, widget.report.nationalId.length >= 3 ? 3 : widget.report.nationalId.length)}',
    ),
    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    children: [
      SelectableText(
        'کد ملی: ${widget.report.nationalId}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      SelectableText('تاریخ تولد ثبت‌شده: ${widget.report.birthDate}'),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: _status,
        decoration: const InputDecoration(labelText: 'وضعیت بررسی'),
        items: const [
          DropdownMenuItem(value: 'Pending', child: Text('در انتظار')),
          DropdownMenuItem(value: 'Reviewed', child: Text('بررسی‌شده')),
          DropdownMenuItem(value: 'Rejected', child: Text('ردشده')),
        ],
        onChanged:
            _saving
                ? null
                : (value) {
                  if (value != null) setState(() => _status = value);
                },
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _note,
        minLines: 2,
        maxLines: 5,
        decoration: const InputDecoration(labelText: 'یادداشت ادمین'),
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: _saving ? null : _save,
        icon:
            _saving
                ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : const Icon(Icons.save_outlined),
        label: const Text('ذخیرهٔ بررسی'),
      ),
    ],
  );
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
  const _ContentRecordsList({
    required this.title,
    required this.future,
    this.onPublish,
  });

  final String title;
  final Future<List<AdminContentRecord>> future;
  final Future<void> Function(AdminContentRecord record)? onPublish;

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
              if (!item.isActive && onPublish != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => onPublish!(item),
                      icon: const Icon(Icons.publish_outlined),
                      label: const Text('انتشار این نسخه در اپ'),
                    ),
                  ),
                ),
            ],
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
        cooldown < 0 ||
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
    try {
      if (_editingId == null) {
        await repository.createGeoCooldownPolicy(data);
      } else {
        await repository.updateGeoCooldownPolicy(_editingId!, data);
      }
      _clear();
      setState(() => _refresh++);
      _message('سیاست تغییرات جغرافیایی ذخیره شد.');
    } catch (error) {
      _message('ذخیرهٔ سیاست تغییرات جغرافیایی ناموفق بود: $error');
    }
  }

  Future<void> _enableTrialPolicy() async {
    final now = DateTime.now().toUtc().toIso8601String();
    final repository = GetIt.I<AdminRepository>();
    final data = <String, dynamic>{
      'policy_code': 'geo_reassignment_trial',
      'policy_name': 'سیاست آزمایشی تغییر نامحدود حوزه',
      'description':
          'برای آزمایش اپ؛ تغییر حوزه بدون دوره انتظار و محدودیت دفعات.',
      'policy_stage': 1,
      'max_changes_allowed': null,
      'window_days': null,
      'cooldown_days': 0,
      'is_active': true,
      'effective_from': now,
      'effective_to': null,
    };
    try {
      final matches =
          (await repository.geoCooldownPolicies())
              .where((item) => item.policyCode == 'geo_reassignment_trial')
              .toList();
      final existing = matches.isEmpty ? null : matches.first;
      if (existing == null) {
        await repository.createGeoCooldownPolicy(data);
      } else {
        await repository.updateGeoCooldownPolicy(existing.id, data);
      }
      if (!mounted) return;
      setState(() => _refresh++);
      _message('سیاست آزمایشی تغییر حوزه فعال شد.');
    } catch (error) {
      _message('ایجاد سیاست آزمایشی تغییر حوزه ناموفق بود: $error');
    }
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

  Future<void> _setActive(AdminGeoCooldownPolicy item, bool value) async {
    try {
      await GetIt.I<AdminRepository>().updateGeoCooldownPolicy(item.id, {
        'is_active': value,
      });
      if (!mounted) return;
      setState(() => _refresh++);
      _message(value ? 'سیاست فعال شد.' : 'سیاست غیرفعال شد.');
    } catch (error) {
      _message('تغییر وضعیت سیاست ذخیره نشد: $error');
      if (mounted) setState(() => _refresh++);
    }
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
            OutlinedButton.icon(
              onPressed: _enableTrialPolicy,
              icon: const Icon(Icons.science_outlined),
              label: const Text('ایجاد و فعال‌سازی سیاست آزمایشی نامحدود'),
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
                  isActive: item.isActive,
                  onActiveChanged: (value) => _setActive(item, value),
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
        hours < 0 ||
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
    try {
      if (_editingId == null) {
        await repository.createClosurePenaltyPolicy(data);
      } else {
        await repository.updateClosurePenaltyPolicy(_editingId!, data);
      }
      _clear();
      setState(() => _refresh++);
      _message('سیاست جریمه بستن حساب ذخیره شد.');
    } catch (error) {
      _message('ذخیرهٔ سیاست جریمه بستن حساب ناموفق بود: $error');
    }
  }

  Future<void> _enableTrialPolicy() async {
    final now = DateTime.now().toUtc().toIso8601String();
    final repository = GetIt.I<AdminRepository>();
    final data = <String, dynamic>{
      'policy_family_code': 'account_closure',
      'policy_code': 'account_closure_trial',
      'policy_name': 'سیاست آزمایشی بستن حساب بدون انتظار',
      'description':
          'برای آزمایش اپ؛ ثبت‌نام تازه بلافاصله پس از بستن حساب مجاز است.',
      'penalty_stage': 1,
      'penalty_hours': 0,
      'trigger_scope': 'account_closure',
      'is_active': true,
      'effective_from': now,
      'effective_to': null,
    };
    try {
      final matches =
          (await repository.closurePenaltyPolicies())
              .where((item) => item.policyCode == 'account_closure_trial')
              .toList();
      final existing = matches.isEmpty ? null : matches.first;
      if (existing == null) {
        await repository.createClosurePenaltyPolicy(data);
      } else {
        await repository.updateClosurePenaltyPolicy(existing.id, data);
      }
      if (!mounted) return;
      setState(() => _refresh++);
      _message('سیاست آزمایشی بستن حساب فعال شد.');
    } catch (error) {
      _message('ایجاد سیاست آزمایشی بستن حساب ناموفق بود: $error');
    }
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

  Future<void> _setActive(AdminClosurePenaltyPolicy item, bool value) async {
    try {
      await GetIt.I<AdminRepository>().updateClosurePenaltyPolicy(item.id, {
        'is_active': value,
      });
      if (!mounted) return;
      setState(() => _refresh++);
      _message(value ? 'سیاست جریمه فعال شد.' : 'سیاست جریمه غیرفعال شد.');
    } catch (error) {
      _message('تغییر وضعیت سیاست جریمه ذخیره نشد: $error');
      if (mounted) setState(() => _refresh++);
    }
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
            OutlinedButton.icon(
              onPressed: _enableTrialPolicy,
              icon: const Icon(Icons.science_outlined),
              label: const Text('ایجاد و فعال‌سازی سیاست آزمایشی بدون انتظار'),
            ),
            const SizedBox(height: 12),
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
                  isActive: item.isActive,
                  onActiveChanged: (value) => _setActive(item, value),
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
  const _PolicyActions({
    required this.isActive,
    required this.onActiveChanged,
    required this.onEdit,
    required this.onDelete,
  });

  final bool isActive;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch(value: isActive, onChanged: onActiveChanged),
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

class _ProcessLifecyclePolicyEditor extends StatefulWidget {
  const _ProcessLifecyclePolicyEditor();

  @override
  State<_ProcessLifecyclePolicyEditor> createState() =>
      _ProcessLifecyclePolicyEditorState();
}

class _ProcessLifecyclePolicyEditorState
    extends State<_ProcessLifecyclePolicyEditor> {
  final _thresholdPercent = TextEditingController(text: '20');
  final _minSupportCount = TextEditingController(text: '0');
  final _supportDays = TextEditingController(text: '30');
  final _waitingDays = TextEditingController(text: '30');
  final _votingDays = TextEditingController(text: '7');
  final _publicationHours = TextEditingController(text: '24');
  late Future<List<AdminProcessLifecyclePolicy>> _policies =
      GetIt.I<AdminRepository>().processLifecyclePolicies();
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _thresholdPercent.dispose();
    _minSupportCount.dispose();
    _supportDays.dispose();
    _waitingDays.dispose();
    _votingDays.dispose();
    _publicationHours.dispose();
    super.dispose();
  }

  void _loadActive(List<AdminProcessLifecyclePolicy> policies) {
    if (_loaded) return;
    _loaded = true;
    AdminProcessLifecyclePolicy? active;
    for (final policy in policies) {
      if (policy.isActive) {
        active = policy;
        break;
      }
    }
    if (active == null) return;
    final wholePercent = active.thresholdRatePpm ~/ 10000;
    final fraction = (active.thresholdRatePpm % 10000)
        .toString()
        .padLeft(4, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    _thresholdPercent.text =
        fraction.isEmpty ? '$wholePercent' : '$wholePercent.$fraction';
    _minSupportCount.text = '${active.minSupportCount}';
    _supportDays.text = '${active.supportPeriodDays}';
    _waitingDays.text = '${active.waitingPeriodDays}';
    _votingDays.text = '${active.votingPeriodDays}';
    _publicationHours.text = '${active.publicationDelayHours}';
  }

  int? _value(TextEditingController controller) =>
      int.tryParse(controller.text.trim());

  int? _thresholdPpm() {
    final match = RegExp(
      r'^(\d{1,3})(?:\.(\d{1,4}))?$',
    ).firstMatch(_thresholdPercent.text.trim());
    if (match == null) return null;
    final whole = int.parse(match.group(1)!);
    final fraction = int.parse((match.group(2) ?? '').padRight(4, '0'));
    return whole * 10000 + fraction;
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _save() async {
    final thresholdPpm = _thresholdPpm();
    final minimum = _value(_minSupportCount);
    final supportDays = _value(_supportDays);
    final waitingDays = _value(_waitingDays);
    final votingDays = _value(_votingDays);
    final publicationHours = _value(_publicationHours);
    if (thresholdPpm == null ||
        minimum == null ||
        supportDays == null ||
        waitingDays == null ||
        votingDays == null ||
        publicationHours == null) {
      _message('همهٔ فیلدها باید عدد صحیح باشند.');
      return;
    }
    if (thresholdPpm < 1 ||
        thresholdPpm > 1000000 ||
        minimum < 0 ||
        supportDays < 1 ||
        waitingDays < 1 ||
        votingDays < 1 ||
        publicationHours < 1) {
      _message(
        'درصد حدنصاب باید از ۰٫۰۰۰۱ تا ۱۰۰ و حداکثر چهار رقم اعشار باشد؛ مدت‌ها نیز باید مثبت باشند.',
      );
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('ثبت نسخهٔ تازهٔ سیاست'),
            content: const Text(
              'این تنظیمات به‌صورت نسخهٔ تازه فعال می‌شوند. نسخه‌های پیشین برای فرایندهایی که با آن‌ها آغاز شده‌اند حفظ می‌شوند.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('بازگشت'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ثبت و فعال‌سازی'),
              ),
            ],
          ),
    );
    if (accepted != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await GetIt.I<AdminRepository>().createProcessLifecyclePolicy({
        'threshold_rate_ppm': thresholdPpm,
        'min_support_count': minimum,
        'support_period_days': supportDays,
        'waiting_period_days': waitingDays,
        'voting_period_days': votingDays,
        'publication_delay_hours': publicationHours,
      });
      _loaded = false;
      setState(
        () => _policies = GetIt.I<AdminRepository>().processLifecyclePolicies(),
      );
      _message('نسخهٔ تازهٔ سیاست چرخه فعال شد.');
    } catch (error) {
      _message('ذخیرهٔ سیاست انجام نشد: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<AdminProcessLifecyclePolicy>>(
    future: _policies,
    builder: (context, snapshot) {
      if (snapshot.hasData) _loadActive(snapshot.data!);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _EditorCard(
            children: [
              Text(
                'این اعداد پارامترهای چرخهٔ همه‌پرسی، انتخابات و استیضاح هستند. هر بار ذخیره، نسخهٔ تازه‌ای می‌سازد و سیاست فرایندهای آغازشده را تغییر نمی‌دهد.',
              ),
              SizedBox(height: 12),
              Text(
                'حدنصاب حمایت با گردکردن رو به بالا محاسبه می‌شود. مهلت هر مرحله از زمان ورود همان فرایند به آن مرحله شروع می‌شود.',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _EditorCard(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _thresholdPercent,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'حدنصاب حمایت (درصد؛ نمونه: 20)',
                        suffixText: '%',
                      ),
                    ),
                  ),
                ],
              ),
              _numberField(
                'حداقل تعداد حمایت (۰ یعنی بدون حداقل جداگانه)',
                _minSupportCount,
              ),
              _numberField('مهلت کسب حدنصاب (روز)', _supportDays),
              _numberField('مدت انتظار پس از کسب حدنصاب (روز)', _waitingDays),
              _numberField('مدت رأی‌گیری (روز)', _votingDays),
              _numberField(
                'فاصلهٔ پایان رأی‌گیری تا انتشار صندوق (ساعت)',
                _publicationHours,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saving || snapshot.hasError ? null : _save,
                icon:
                    _saving
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.save_outlined),
                label: const Text('ایجاد نسخه و فعال‌سازی'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AsyncRecordsCard<AdminProcessLifecyclePolicy>(
            title: 'نسخه‌های ثبت‌شدهٔ سیاست چرخه',
            future: _policies,
            emptyText: 'هنوز نسخه‌ای ثبت نشده است.',
            itemBuilder:
                (context, policy) => ListTile(
                  leading: Icon(
                    policy.isActive ? Icons.check_circle : Icons.history,
                    color: policy.isActive ? Colors.green : null,
                  ),
                  title: Text(
                    'نسخهٔ ${policy.versionNumber}${policy.isActive ? ' — فعال' : ''}',
                  ),
                  subtitle: Text(
                    'حدنصاب ${_formatLifecyclePercent(policy.thresholdRatePpm)} | '
                    'حمایت ${policy.supportPeriodDays} روز | انتظار ${policy.waitingPeriodDays} روز | '
                    'رأی‌گیری ${policy.votingPeriodDays} روز | انتشار ${policy.publicationDelayHours} ساعت',
                  ),
                ),
          ),
        ],
      );
    },
  );
}

String _formatLifecyclePercent(int ratePpm) {
  final whole = ratePpm ~/ 10000;
  final fraction = (ratePpm % 10000)
      .toString()
      .padLeft(4, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty ? '$whole%' : '$whole.$fraction%';
}

class _HomeManagementEditor extends StatefulWidget {
  const _HomeManagementEditor();
  @override
  State<_HomeManagementEditor> createState() => _HomeManagementEditorState();
}

class _HomeManagementEditorState extends State<_HomeManagementEditor> {
  static const sections = <String, String>{
    'goals': 'اهداف وتواپ',
    'identity': 'مکانیسم احراز هویت',
    'activation': 'نحوه فعال سازی سامانه',
    'validation': 'فرآیند اعتبارسنجی سامانه',
    'technical': 'زیرساخت فنی',
    'creators': 'هویت سازندگان',
  };
  static const states = [
    'در حال کسب نصاب برای فعالسازی بخش همه‌پرسی',
    'بخش همه‌پرسی فعال است',
    'بخش‌های همه‌پرسی و انتخابات فعال است',
    'بخش‌های همه‌پرسی، انتخابات و استیضاح فعال هستند',
  ];
  final body = TextEditingController();
  String sectionKey = 'goals';
  bool published = true;
  late Future<List<Map<String, dynamic>>> sectionData =
      GetIt.I<AdminRepository>().homeSections();
  late Future<Map<String, dynamic>> stateData =
      GetIt.I<AdminRepository>().homeState();
  late Future<List<Map<String, dynamic>>> eventData =
      GetIt.I<AdminRepository>().homeEvents();

  @override
  void dispose() {
    body.dispose();
    super.dispose();
  }

  void message(String value) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> selectSection(String key) async {
    final rows = await GetIt.I<AdminRepository>().homeSections();
    Map<String, dynamic>? match;
    for (final row in rows) {
      if (row['section_key'] == key) match = row;
    }
    if (!mounted) return;
    setState(() {
      sectionKey = key;
      body.text = match == null ? '' : match['body_text'].toString();
      published =
          match == null ||
          match['is_published'] == true ||
          match['is_published'] == 1;
    });
  }

  Future<bool> confirm(String title, String text, String accept) async =>
      await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(title),
              content: Text(text),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('بازگشت'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(accept),
                ),
              ],
            ),
      ) ==
      true;

  Future<void> saveSection() async {
    if (body.text.trim().isEmpty) {
      message('متن بخش را وارد کنید.');
      return;
    }
    if (!await confirm(
      'ذخیرهٔ محتوای معرفی',
      'متن ' + sections[sectionKey]! + ' ذخیره شود؟',
      'ذخیره',
    ))
      return;
    await GetIt.I<AdminRepository>().saveHomeSection(sectionKey, {
      'title': sections[sectionKey],
      'body_text': body.text.trim(),
      'is_published': published,
    });
    if (!mounted) return;
    setState(() => sectionData = GetIt.I<AdminRepository>().homeSections());
    message('متن معرفی ذخیره شد.');
  }

  Future<void> advance(int current) async {
    if (current < 2) return;
    final next = current + 1;
    if (!await confirm(
      'تأیید انتقال وضعیت',
      'وضعیت از «' +
          states[current - 1] +
          '» به «' +
          states[next - 1] +
          '» تغییر کند؟ اقدام در گزارش مدیر ثبت می‌شود.',
      'تأیید انتقال',
    ))
      return;
    try {
      await GetIt.I<AdminRepository>().changeHomeState(next);
      if (!mounted) return;
      setState(() => stateData = GetIt.I<AdminRepository>().homeState());
      message('وضعیت سامانه تغییر کرد.');
    } catch (_) {
      message(
        current == 1
            ? 'نصاب ۴۴ میلیون کاربر هنوز تکمیل نشده است.'
            : 'انتقال وضعیت انجام نشد.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _EditorCard(
              children: [
                const Text('محتوای خانه و وضعیت سامانه'),
                const TabBar(
                  isScrollable: true,
                  tabs: [
                    Tab(text: 'محتوای معرفی'),
                    Tab(text: 'قوانین و مقررات'),
                  ],
                ),
              ],
            ),
            Builder(
              builder: (context) {
                final tabController = DefaultTabController.of(context);
                return AnimatedBuilder(
                  animation: tabController,
                  builder: (context, _) {
                    if (tabController.index == 1) {
                      return const _ContentEditor();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        _EditorCard(
                          children: [
                            DropdownButtonFormField<String>(
                              value: sectionKey,
                              decoration: const InputDecoration(
                                labelText: 'بخش معرفی',
                              ),
                              items:
                                  sections.entries
                                      .map(
                                        (entry) => DropdownMenuItem(
                                          value: entry.key,
                                          child: Text(entry.value),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (value) {
                                if (value != null) selectSection(value);
                              },
                            ),
                            TextField(
                              controller: body,
                              minLines: 4,
                              maxLines: 10,
                              decoration: const InputDecoration(
                                labelText: 'متن بخش',
                              ),
                            ),
                            SwitchListTile(
                              value: published,
                              onChanged:
                                  (value) => setState(() => published = value),
                              title: const Text('نمایش در اپ'),
                            ),
                            FilledButton(
                              onPressed: saveSection,
                              child: const Text('ذخیرهٔ متن'),
                            ),
                            FutureBuilder<List<Map<String, dynamic>>>(
                              future: sectionData,
                              builder:
                                  (context, snapshot) => Wrap(
                                    spacing: 8,
                                    children:
                                        (snapshot.data ?? [])
                                            .map(
                                              (row) => ActionChip(
                                                label: Text(
                                                  row['title'].toString(),
                                                ),
                                                onPressed:
                                                    () => selectSection(
                                                      row['section_key']
                                                          .toString(),
                                                    ),
                                              ),
                                            )
                                            .toList(),
                                  ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _EditorCard(
        children: [
          const Text('وضعیت سامانه'),
          FutureBuilder<Map<String, dynamic>>(
            future: stateData,
            builder: (context, snapshot) {
              final current =
                  ((snapshot.data?['state_value'] as num?)?.toInt() ?? 1).clamp(
                    1,
                    4,
                  );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'وضعیت ' + current.toString() + ': ' + states[current - 1],
                  ),
                  if (current == 1)
                    const Text(
                      'انتقال به وضعیت همه‌پرسی با رسیدن شمار کاربران فعال به نصاب، خودکار انجام می‌شود.',
                    ),
                  if (current >= 2 && current < 4)
                    OutlinedButton(
                      onPressed: () => advance(current),
                      child: Text(
                        'انتقال به وضعیت ' + (current + 1).toString(),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      const SizedBox(height: 12),
      _EditorCard(
        children: [
          const Text('رویدادهای فعال دریافت‌شده از سامانه'),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: eventData,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final events = snapshot.data ?? const [];
              if (events.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('در حال حاضر رویداد فعالی از سامانه دریافت نشد.'),
                );
              }
              return Column(
                children:
                    events.map((event) {
                      final kind = '${event['kind'] ?? ''}';
                      final (label, icon) = switch (kind) {
                        'referendum' => (
                          'همه‌پرسی',
                          Icons.how_to_vote_outlined,
                        ),
                        'election' => ('انتخابات', Icons.ballot_outlined),
                        'impeachment' => ('استیضاح', Icons.gavel_outlined),
                        _ => ('رویداد', Icons.event_outlined),
                      };
                      return ListTile(
                        leading: Icon(icon),
                        title: Text('${event['title'] ?? label}'),
                        subtitle: Text(label),
                      );
                    }).toList(),
              );
            },
          ),
        ],
      ),
    ],
  );
}
