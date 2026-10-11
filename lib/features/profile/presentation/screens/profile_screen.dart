import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/router/app_back_handler_registry.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/iranian_date.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../core/widgets/app_tap_tile.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../auth/data/services/biometric_auth_service.dart';
import '../../data/datasources/profile_remote_data_source.dart';
import '../../domain/entities/profile.dart';
import '../cubit/profile_cubit.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static final ButtonStyle _filledStyle = FilledButton.styleFrom(
    backgroundColor: AppTheme.profile,
    foregroundColor: AppTheme.surface,
  );
  static final ButtonStyle _textStyle = TextButton.styleFrom(
    foregroundColor: AppTheme.profile,
  );
  static final ButtonStyle _outlinedStyle = OutlinedButton.styleFrom(
    foregroundColor: AppTheme.profile,
    side: const BorderSide(color: AppTheme.profile),
  );

  final _oldPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _repeatPassword = TextEditingController();
  final _closePassword = TextEditingController();
  final _receiptLookupController = TextEditingController();
  final _remote = getIt<ProfileRemoteDataSource>();

  int _view = 0;
  int _backTarget = 0;
  int _previewSelection = 0;
  bool _busy = false;
  bool _oldVerified = false;
  Map<String, dynamic>? _geo;
  Map<String, dynamic>? _closure;
  Map<String, dynamic>? _country;
  Map<String, dynamic>? _province;
  Map<String, dynamic>? _county;
  Map<String, dynamic>? _settlement;
  List<Map<String, dynamic>>? _receipts;
  String? _receiptsError;
  int _receiptSection = 0;
  bool _receiptLookupBusy = false;
  String? _receiptLookupError;
  Map<String, dynamic>? _receiptLookupResult;
  Map<String, dynamic>? _notifications;
  Timer? _notificationRefreshTimer;
  bool _notificationRefreshInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.read<AuthCubit>().state is! Guest) {
        context.read<ProfileCubit>().load();
      }
    });
  }

  @override
  void dispose() {
    _notificationRefreshTimer?.cancel();
    AppBackHandlerRegistry.unregister(this);
    _oldPassword.dispose();
    _newPassword.dispose();
    _repeatPassword.dispose();
    _closePassword.dispose();
    _receiptLookupController.dispose();
    super.dispose();
  }

  Future<void> _message(
    String message, {
    AppMessageTone tone = AppMessageTone.info,
  }) async {
    if (!mounted) return;
    await showAppMessageDialog<void>(
      context: context,
      message: message,
      tone: tone,
      actions: [
        FilledButton(
          style: _filledStyle,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('متوجه شدم'),
        ),
      ],
    );
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      final message =
          error is Failure
              ? error.message
              : error.toString().replaceFirst('Exception: ', '');
      await _message(message, tone: AppMessageTone.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openView(int view) async {
    if (view != 6) _notificationRefreshTimer?.cancel();
    _setView(view);
    if (view == 3) {
      await _perform(() async => _geo = await _remote.getGeography());
    } else if (view == 4) {
      await _perform(() async => _closure = await _remote.getClosurePolicy());
    } else if (view == 5) {
      _receiptSection = 0;
      _receipts = null;
      _receiptsError = null;
      _receiptLookupResult = null;
      _receiptLookupError = null;
      setState(() {});
      await _loadReceipts();
    } else if (view == 6) {
      _notificationRefreshTimer?.cancel();
      _notifications = null;
      setState(() {});
      await _perform(
        () async => _notifications = await _remote.getNotifications(),
      );
      if (mounted && _view == 6) {
        _notificationRefreshTimer = Timer.periodic(
          const Duration(seconds: 60),
          (_) => unawaited(_refreshNotificationsQuietly()),
        );
      }
    }
  }

  Future<void> _loadReceipts() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final receipts = await _remote.getReceipts();
      if (mounted) setState(() => _receipts = receipts);
    } catch (error) {
      final message =
          error is Failure
              ? error.message
              : error.toString().replaceFirst('Exception: ', '');
      if (mounted) setState(() => _receiptsError = message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshNotificationsQuietly() async {
    if (!mounted || _view != 6 || _notificationRefreshInFlight) return;
    _notificationRefreshInFlight = true;
    try {
      final updated = await _remote.getNotifications();
      if (mounted && _view == 6) setState(() => _notifications = updated);
    } catch (_) {
      // Keep the last inbox snapshot; the next scheduled refresh will retry.
    } finally {
      _notificationRefreshInFlight = false;
    }
  }

  Future<void> _markNotificationRead(Map<String, dynamic> item) async {
    if (item['is_read'] == true) return;
    final id = item['notification_id']?.toString();
    if (id == null || id.isEmpty) return;
    await _perform(() async {
      await _remote.markNotificationRead(id);
      if (!mounted || _notifications == null) return;
      final rows = _notifications!['items'];
      if (rows is List) {
        for (final row in rows.whereType<Map<String, dynamic>>()) {
          if (row['notification_id']?.toString() == id) row['is_read'] = true;
        }
      }
      final unread = (_notifications!['unread_count'] as num?)?.toInt() ?? 0;
      setState(
        () => _notifications!['unread_count'] = unread > 0 ? unread - 1 : 0,
      );
    });
  }

  void _setView(int view) {
    if (!mounted) return;
    if (view != 6) _notificationRefreshTimer?.cancel();
    _backTarget = view == 2 || view == 3 ? 1 : 0;
    setState(() => _view = view);
    if (view == 0) {
      AppBackHandlerRegistry.unregister(this);
      return;
    }
    AppBackHandlerRegistry.register(this, () {
      if (!mounted || _view == 0) return false;
      final target = _backTarget;
      if (target != 6) _notificationRefreshTimer?.cancel();
      setState(() => _view = target);
      if (target == 0) AppBackHandlerRegistry.unregister(this);
      return true;
    });
  }

  void _goBack() => _setView(_backTarget);

  Future<void> _accountDetails(Profile profile) async {
    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(22),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(24),
              decoration: AppTheme.cardDecoration,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.account_circle_outlined,
                    size: 48,
                    color: AppTheme.profile,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'اطلاعات حساب',
                    textAlign: TextAlign.center,
                    style: AppTheme.getTitleStyle(color: AppTheme.profile),
                  ),
                  const SizedBox(height: 20),
                  _detail(
                    Icons.phone_outlined,
                    'شماره همراه',
                    profile.phoneNumber,
                  ),
                  const SizedBox(height: 14),
                  _detail(Icons.badge_outlined, 'کد ملی', profile.nationalCode),
                  const SizedBox(height: 20),
                  Center(
                    child: FilledButton(
                      style: _filledStyle,
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('بستن'),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _detail(IconData icon, String title, String value) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.background,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.divider),
    ),
    child: Column(
      children: [
        CircleAvatar(
          backgroundColor: AppTheme.profile.withValues(alpha: .12),
          child: Icon(icon, color: AppTheme.profile),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        Text(
          value,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );

  Future<void> _biometricDetails(Profile profile) async {
    final biometric = getIt<BiometricAuthService>();
    await _perform(() async {
      final enabled = await biometric.isEnabledOnServer();
      final configuredLocally = await biometric.isConfiguredLocally;
      if (enabled && configuredLocally) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                title: const Text('غیرفعال‌کردن ورود بیومتریک'),
                content: const Text(
                  'ورود با اثر انگشت در این حساب و دستگاه غیرفعال شود؟',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('انصراف'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('غیرفعال‌کردن'),
                  ),
                ],
              ),
        );
        if (confirmed != true) return;
        await biometric.disable();
        await _message(
          'ورود بیومتریک غیرفعال شد.',
          tone: AppMessageTone.success,
        );
        return;
      }

      if (!await biometric.canAuthenticate) {
        await _message(
          'برای فعال‌سازی، ابتدا اثر انگشت یا روش بیومتریک قوی را در تنظیمات امنیتی گوشی ثبت کنید.',
          tone: AppMessageTone.warning,
        );
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: Text(
                enabled
                    ? 'انتقال ورود بیومتریک به این گوشی'
                    : 'فعال‌سازی ورود بیومتریک',
              ),
              content: Text(
                enabled
                    ? 'در هر حساب فقط یک دستگاه بیومتریک فعال است. با ادامه، دستگاه قبلی غیرفعال و ورود بیومتریک به این گوشی منتقل می‌شود. کلید خصوصی در گوشی می‌ماند.'
                    : 'پس از فعال‌سازی، برای ورود در این دستگاه اثر انگشت تأیید می‌شود. کلید خصوصی در گوشی می‌ماند و رمز عبور ذخیره نمی‌شود.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('انصراف'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('ادامه'),
                ),
              ],
            ),
      );
      if (confirmed != true) return;
      await biometric.enable(profile.phoneNumber);
      await _message(
        'ورود با اثر انگشت برای این دستگاه فعال شد.',
        tone: AppMessageTone.success,
      );
    });
  }

  Future<void> _verifyOldPassword() => _perform(() async {
    if (_oldPassword.text.isEmpty) {
      await _message('رمز فعلی را وارد کنید.', tone: AppMessageTone.warning);
      return;
    }
    await _remote.verifyPassword(_oldPassword.text);
    if (mounted) setState(() => _oldVerified = true);
  });

  Future<void> _changePassword() => _perform(() async {
    if (_newPassword.text.length < 8) {
      await _message(
        'رمز جدید باید دست‌کم ۸ کاراکتر باشد.',
        tone: AppMessageTone.warning,
      );
      return;
    }
    if (_newPassword.text != _repeatPassword.text) {
      await _message(
        'رمز جدید و تکرار آن یکسان نیستند.',
        tone: AppMessageTone.warning,
      );
      return;
    }
    await _remote.changePassword(_oldPassword.text, _newPassword.text);
    _oldPassword.clear();
    _newPassword.clear();
    _repeatPassword.clear();
    if (mounted) setState(() => _oldVerified = false);
    _setView(1);
    await _message(
      'رمز عبور با موفقیت تغییر کرد.',
      tone: AppMessageTone.success,
    );
  });

  Future<List<Map<String, dynamic>>> _children(
    String type,
    int? parentId,
  ) async {
    final response = await getIt<Dio>().get<Map<String, dynamic>>(
      '/api/v1/geographical-areas',
      queryParameters: {
        'child_type': type,
        if (parentId != null) 'parent_id': parentId,
      },
    );
    final rows = response.data?['data'];
    return rows is List ? rows.whereType<Map<String, dynamic>>().toList() : [];
  }

  Future<Map<String, dynamic>?> _chooseArea(
    String type,
    int? parentId,
    String title,
  ) async {
    return _performSelection(type, parentId, title);
  }

  Future<Map<String, dynamic>?> _performSelection(
    String type,
    int? parentId,
    String title,
  ) async {
    try {
      final choices = await _children(type, parentId);
      if (!mounted) return null;
      String filter = '';
      return await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder:
            (sheetContext) => StatefulBuilder(
              builder: (sheetContext, update) {
                final visible =
                    choices
                        .where(
                          (row) =>
                              (row['name'] ?? '').toString().contains(filter),
                        )
                        .toList();
                return SafeArea(
                  child: SizedBox(
                    height: MediaQuery.sizeOf(sheetContext).height * .72,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Column(
                        children: [
                          Text(
                            title,
                            style: AppTheme.getTitleStyle(
                              color: AppTheme.profile,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            autofocus: true,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              hintText: 'جست‌وجو',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (value) => update(() => filter = value),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: visible.length,
                              itemBuilder: (_, index) {
                                final area = visible[index];
                                return ListTile(
                                  title: Text(
                                    area['name'].toString(),
                                    textAlign: TextAlign.center,
                                  ),
                                  onTap:
                                      () => Navigator.pop(sheetContext, area),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      );
    } catch (error) {
      await _message(
        'دریافت حوزه‌ها انجام نشد: $error',
        tone: AppMessageTone.error,
      );
      return null;
    }
  }

  Future<void> _choose(String type) async {
    final parent =
        type == 'province'
            ? (_country?['id'] as int?)
            : type == 'county'
            ? (_province?['id'] as int?)
            : (_county?['id'] as int?);
    final chosen = await _chooseArea(type, parent, switch (type) {
      'country' => 'انتخاب کشور',
      'province' => 'انتخاب استان',
      'county' => 'انتخاب شهرستان',
      _ => 'انتخاب شهر / روستا',
    });
    if (chosen == null || !mounted) return;
    setState(() {
      if (type == 'country') {
        _country = chosen;
        _province = null;
        _county = null;
        _settlement = null;
      }
      if (type == 'province') {
        _province = chosen;
        _county = null;
        _settlement = null;
      }
      if (type == 'county') {
        _county = chosen;
        _settlement = null;
      }
      if (type == 'locality') _settlement = chosen;
    });
  }

  Future<void> _saveGeography() => _perform(() async {
    if (_settlement == null) return;
    final accepted = await showAppMessageDialog<bool>(
      context: context,
      title: 'تأیید تغییر حوزه',
      message:
          'حوزهٔ کاربری به ${_settlement!['name']} تغییر کند؟ پس از ثبت، زمان تغییر بعدی طبق سیاست سامانه محاسبه می‌شود.',
      tone: AppMessageTone.warning,
      actions: [
        TextButton(
          style: _textStyle,
          onPressed: () => Navigator.pop(context, false),
          child: const Text('انصراف'),
        ),
        FilledButton(
          style: _filledStyle,
          onPressed: () => Navigator.pop(context, true),
          child: const Text('تأیید تغییر'),
        ),
      ],
    );
    if (accepted != true || !mounted) return;
    await _remote.changeGeography(_settlement!['id'] as int);
    _geo = await _remote.getGeography();
    _country = _province = _county = _settlement = null;
    if (mounted) setState(() {});
    if (mounted) await context.read<ProfileCubit>().load();
    await _message(
      'حوزهٔ جغرافیایی با موفقیت تغییر کرد.',
      tone: AppMessageTone.success,
    );
  });

  Future<void> _closeAccount() => _perform(() async {
    if (_closePassword.text.isEmpty) {
      await _message(
        'برای بستن حساب، رمز عبور خود را وارد کنید.',
        tone: AppMessageTone.warning,
      );
      return;
    }
    final accepted = await showAppMessageDialog<bool>(
      context: context,
      title: 'تأیید نهایی بستن حساب',
      message:
          'با بستن حساب دسترسی شما پایان می‌یابد. بازگشت به سامانه تابع زمان انتظار اعلام‌شده است. آیا مطمئن هستید؟',
      tone: AppMessageTone.warning,
      actions: [
        TextButton(
          style: _textStyle,
          onPressed: () => Navigator.pop(context, false),
          child: const Text('انصراف'),
        ),
        FilledButton(
          style: _filledStyle,
          onPressed: () => Navigator.pop(context, true),
          child: const Text('بستن حساب'),
        ),
      ],
    );
    if (accepted != true || !mounted) return;
    await _remote.closeAccount(_closePassword.text);
    _closePassword.clear();
    if (!mounted) return;
    await context.read<AuthCubit>().logout();
    if (mounted) context.go('/gateway');
  });

  Future<void> _logout() async {
    final accepted = await showAppMessageDialog<bool>(
      context: context,
      title: 'خروج از حساب',
      message: 'از حساب کاربری خود خارج می‌شوید؟',
      tone: AppMessageTone.warning,
      actions: [
        TextButton(
          style: _textStyle,
          onPressed: () => Navigator.pop(context, false),
          child: const Text('انصراف'),
        ),
        FilledButton(
          style: _filledStyle,
          onPressed: () => Navigator.pop(context, true),
          child: const Text('خروج'),
        ),
      ],
    );
    if (accepted != true || !mounted) return;
    await context.read<AuthCubit>().logout();
    if (mounted) context.go('/gateway');
  }

  String _when(dynamic iso) {
    final date = DateTime.tryParse(iso?.toString() ?? '')?.toLocal();
    if (date == null) return 'نامشخص';
    String two(int value) =>
        IranianDate.persianDigits(value.toString().padLeft(2, '0'));
    return '${IranianDate.formatGregorian(date)}، ساعت ${two(date.hour)}:${two(date.minute)}';
  }

  Widget _panel(String title, List<Widget> children) => Container(
    padding: const EdgeInsets.all(20),
    decoration: AppTheme.cardDecoration,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTheme.getTitleStyle(color: AppTheme.profile),
        ),
        const SizedBox(height: 18),
        ...children,
      ],
    ),
  );

  Widget _passwordPage() => _panel('تغییر رمز عبور', [
    Text(
      _oldVerified
          ? 'رمز جدید و تکرار آن را وارد کنید.'
          : 'برای ادامه، ابتدا رمز فعلی خود را وارد کنید.',
      textAlign: TextAlign.center,
    ),
    const SizedBox(height: 16),
    if (!_oldVerified) ...[
      TextField(
        controller: _oldPassword,
        obscureText: true,
        textAlign: TextAlign.center,
        decoration: const InputDecoration(labelText: 'رمز فعلی'),
      ),
      const SizedBox(height: 16),
      FilledButton(
        style: _filledStyle,
        onPressed: _busy ? null : _verifyOldPassword,
        child: const Text('مرحله بعد'),
      ),
      TextButton(
        style: _textStyle,
        onPressed: () => context.push('/forgot-password'),
        child: const Text('رمز را فراموش کرده‌ام'),
      ),
    ] else ...[
      TextField(
        controller: _newPassword,
        obscureText: true,
        textAlign: TextAlign.center,
        decoration: const InputDecoration(labelText: 'رمز جدید'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _repeatPassword,
        obscureText: true,
        textAlign: TextAlign.center,
        decoration: const InputDecoration(labelText: 'تکرار رمز جدید'),
      ),
      const SizedBox(height: 16),
      FilledButton(
        style: _filledStyle,
        onPressed: _busy ? null : _changePassword,
        child: const Text('ثبت رمز جدید'),
      ),
    ],
  ]);

  Widget _geoPage() {
    final geo = _geo;
    if (geo == null) {
      return _busy
          ? const Center(child: CircularProgressIndicator())
          : _panel('موقعیت جغرافیایی', [
            const Text('اطلاعات حوزه دریافت نشد.', textAlign: TextAlign.center),
            TextButton(
              style: _textStyle,
              onPressed: () => _openView(3),
              child: const Text('تلاش دوباره'),
            ),
          ]);
    }
    final policy =
        geo['policy'] is Map<String, dynamic>
            ? geo['policy'] as Map<String, dynamic>
            : <String, dynamic>{};
    final allowed = policy['can_change'] == true;
    return _panel('موقعیت جغرافیایی', [
      const Text('حوزهٔ فعلی شما', textAlign: TextAlign.center),
      const SizedBox(height: 12),
      for (final entry
          in {
            'کشور': geo['country'],
            'استان': geo['province'],
            'شهرستان': geo['county'],
            'شهر / روستا': geo['settlement'],
          }.entries)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Text(
            '${entry.key}: ${entry.value ?? 'نامشخص'}',
            textAlign: TextAlign.center,
          ),
        ),
      const Divider(height: 30),
      Text(
        policy['message']?.toString() ??
            (allowed
                ? 'در حال حاضر امکان تغییر حوزه وجود دارد. زمان انتظار پس از تغییر: ${policy['cooldown_days']} روز.'
                : 'زمان مجاز تغییر بعدی: ${_when(policy['next_change_at'])}'),
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.profile),
      ),
      if (allowed) ...[
        const SizedBox(height: 18),
        for (final field in [
          ('country', 'کشور', _country),
          ('province', 'استان', _province),
          ('county', 'شهرستان', _county),
          ('locality', 'شهر / روستا', _settlement),
        ]) ...[
          OutlinedButton(
            style: _outlinedStyle,
            onPressed:
                _busy ||
                        (field.$1 == 'province' && _country == null) ||
                        (field.$1 == 'county' && _province == null) ||
                        (field.$1 == 'locality' && _county == null)
                    ? null
                    : () => _choose(field.$1),
            child: Text(
              '${field.$2}: ${field.$3?['name'] ?? 'انتخاب کنید'}',
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
        ],
        FilledButton(
          style: _filledStyle,
          onPressed: _busy || _settlement == null ? null : _saveGeography,
          child: const Text('ثبت تغییر حوزه'),
        ),
      ],
    ]);
  }

  Widget _managePage() {
    if (_closure == null) {
      return _busy
          ? const Center(child: CircularProgressIndicator())
          : _panel('بستن حساب', [
            const Text(
              'سیاست بستن حساب دریافت نشد.',
              textAlign: TextAlign.center,
            ),
            TextButton(
              style: _textStyle,
              onPressed: () => _openView(4),
              child: const Text('تلاش دوباره'),
            ),
          ]);
    }
    final policy = _closure!;
    return _panel('بستن حساب', [
      Text(
        policy['can_close'] == true
            ? 'در صورت بستن حساب، مطابق سیاست فعلی تا ${policy['penalty_hours']} ساعت امکان بازگشت نخواهید داشت. زمان تقریبی مجاز: ${_when(policy['next_registration_at'])}.'
            : policy['message']?.toString() ?? 'سیاست بستن حساب در دسترس نیست.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 18),
      if (policy['can_close'] == true) ...[
        TextField(
          controller: _closePassword,
          obscureText: true,
          textAlign: TextAlign.center,
          decoration: const InputDecoration(labelText: 'رمز عبور حساب'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          style: _filledStyle,
          onPressed: _busy ? null : _closeAccount,
          child: const Text('ادامه برای بستن حساب'),
        ),
      ],
    ]);
  }

  Future<void> _lookupReceipt() async {
    final number = _receiptLookupController.text.trim();
    if (number.isEmpty) {
      setState(() {
        _receiptLookupError = 'شمارهٔ رسید را وارد کنید.';
        _receiptLookupResult = null;
      });
      return;
    }
    setState(() {
      _receiptLookupBusy = true;
      _receiptLookupError = null;
      _receiptLookupResult = null;
    });
    try {
      final result = await _remote.verifyReceipt(number);
      if (mounted) setState(() => _receiptLookupResult = result);
    } catch (error) {
      final message =
          error is Failure
              ? error.message
              : error.toString().replaceFirst('Exception: ', '');
      if (mounted) setState(() => _receiptLookupError = message);
    } finally {
      if (mounted) setState(() => _receiptLookupBusy = false);
    }
  }

  Widget _receiptsPage() => Column(
    children: [
      SegmentedButton<int>(
        segments: const [
          ButtonSegment(
            value: 0,
            label: Text('رسیدهای من'),
            icon: Icon(Icons.receipt_long_outlined),
          ),
          ButtonSegment(
            value: 1,
            label: Text('استعلام رسید'),
            icon: Icon(Icons.fact_check_outlined),
          ),
        ],
        selected: {_receiptSection},
        onSelectionChanged:
            (selection) => setState(() => _receiptSection = selection.first),
      ),
      const SizedBox(height: 14),
      if (_receiptSection == 0)
        _receiptsListSection()
      else
        _receiptLookupSection(),
    ],
  );

  Widget _receiptLookupSection() => _panel('استعلام رسید دیجیتال', [
    const Text(
      'شمارهٔ رسید را وارد کنید تا محتوای ثبت‌شده و اعتبار امضای آن بررسی شود. رسید می‌تواند متعلق به هر کاربری باشد.',
      textAlign: TextAlign.center,
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _receiptLookupController,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.text,
      decoration: const InputDecoration(labelText: 'شمارهٔ رسید دیجیتال'),
    ),
    const SizedBox(height: 12),
    FilledButton.icon(
      style: _filledStyle,
      onPressed: _receiptLookupBusy ? null : _lookupReceipt,
      icon:
          _receiptLookupBusy
              ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : const Icon(Icons.search),
      label: const Text('استعلام'),
    ),
    if (_receiptLookupError != null) ...[
      const SizedBox(height: 12),
      Text(
        _receiptLookupError!,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.red),
      ),
    ],
    if (_receiptLookupResult case final result?) ...[
      const Divider(height: 28),
      Text(
        result['valid'] == true
            ? 'امضای دیجیتال معتبر است.'
            : 'امضای دیجیتال معتبر نیست.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: result['valid'] == true ? AppTheme.success : AppTheme.danger,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 10),
      _receiptFact(
        'موضوع / رویداد',
        result['payload'] is Map
            ? (result['payload'] as Map)['event_title']
            : null,
      ),
      if (result['payload'] is Map &&
          (result['payload'] as Map)['receipt_type_code'] == 'VOTE')
        _receiptFact(
          'رأی ثبت‌شده',
          (result['payload'] as Map)['ballot_choice_label'],
        ),
      if (result['payload'] is Map)
        _receiptFact(
          'شمارهٔ ترتیب رأی',
          (result['payload'] as Map)['sequence_no'],
        ),
      _receiptFact('الگوریتم امضا', result['algorithm']),
      _receiptFact('اثر انگشت رسید', result['receipt_hash']),
    ],
  ]);

  Widget _receiptFact(String label, dynamic value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text('$label: ${value ?? '—'}', textAlign: TextAlign.center),
  );

  Widget _receiptsListSection() {
    final receipts = _receipts;
    if (receipts == null) {
      return _panel('فعالیت‌های من', [
        if (_busy)
          const Center(child: CircularProgressIndicator())
        else ...[
          Text(
            _receiptsError ?? 'رسیدها دریافت نشدند.',
            textAlign: TextAlign.center,
          ),
          TextButton(
            style: _textStyle,
            onPressed: _loadReceipts,
            child: const Text('تلاش دوباره'),
          ),
        ],
      ]);
    }
    if (receipts.isEmpty) {
      return _panel('فعالیت‌های من', const [
        Icon(Icons.receipt_long_outlined, size: 42, color: AppTheme.profile),
        SizedBox(height: 12),
        Text('شما تا کنون فعالیتی نداشتید.', textAlign: TextAlign.center),
      ]);
    }

    return _panel('فعالیت‌های من', [
      const Text(
        'رسیدهای دیجیتال صادرشده برای حساب شما',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      for (final receipt in receipts)
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: AppTheme.background,
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0x1F202B83),
              child: Icon(Icons.receipt_long_outlined, color: AppTheme.profile),
            ),
            title: Text(receipt['title']?.toString() ?? 'رسید دیجیتال'),
            subtitle: Text(
              '${_receiptTypeLabel(receipt['receipt_type_code'])} • ${_when(receipt['issued_at'])}',
            ),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => _showReceipt(receipt),
          ),
        ),
      TextButton.icon(
        style: _textStyle,
        onPressed: () => _openView(5),
        icon: const Icon(Icons.refresh),
        label: const Text('به‌روزرسانی'),
      ),
    ]);
  }

  String _receiptTypeLabel(dynamic code) => switch (code?.toString()) {
    'SUPPORT' => 'رسید حمایت از موضوع',
    'VOTE' => 'رسید ثبت رأی',
    _ => 'رسید دیجیتال',
  };

  Future<void> _showReceipt(Map<String, dynamic> receipt) async {
    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(receipt['title']?.toString() ?? 'رسید دیجیتال'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _receiptTypeLabel(receipt['receipt_type_code']),
                    textAlign: TextAlign.center,
                  ),
                  if (receipt['receipt_type_code'] == 'VOTE' &&
                      receipt['choice_label'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'گزینهٔ ثبت‌شده: ${receipt['choice_label']}',
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'زمان صدور: ${_when(receipt['issued_at'])}',
                    textAlign: TextAlign.center,
                  ),
                  const Divider(height: 24),
                  const Text('شناسهٔ رسید', textAlign: TextAlign.center),
                  SelectableText(
                    receipt['receipt_number']?.toString() ?? '—',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'اثر انگشت رمزنگاری‌شده',
                    textAlign: TextAlign.center,
                  ),
                  SelectableText(
                    receipt['receipt_hash']?.toString() ?? '—',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                  ),
                  const SizedBox(height: 10),
                  const Text('امضای دیجیتال', textAlign: TextAlign.center),
                  SelectableText(
                    receipt['signature']?.toString() ?? '—',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'کلید امضا: ${receipt['key_id'] ?? '—'}',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            actions: [
              FilledButton(
                style: _filledStyle,
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('بستن'),
              ),
            ],
          ),
    );
  }

  Widget _notificationsPage() {
    final data = _notifications;
    if (data == null) {
      return _panel('اعلانات', [
        if (_busy)
          const Center(child: CircularProgressIndicator())
        else ...[
          const Text('اعلانات دریافت نشدند.', textAlign: TextAlign.center),
          TextButton(
            style: _textStyle,
            onPressed: () => _openView(6),
            child: const Text('تلاش دوباره'),
          ),
        ],
      ]);
    }
    final rawItems = data['items'];
    final items =
        rawItems is List
            ? rawItems.whereType<Map<String, dynamic>>().toList(growable: false)
            : const <Map<String, dynamic>>[];
    if (items.isEmpty) {
      return _panel('اعلانات', [
        const Icon(
          Icons.notifications_none_rounded,
          size: 42,
          color: AppTheme.profile,
        ),
        const SizedBox(height: 12),
        const Text(
          'اعلان جدیدی برای شما وجود ندارد.',
          textAlign: TextAlign.center,
        ),
        TextButton.icon(
          style: _textStyle,
          onPressed: () => _openView(6),
          icon: const Icon(Icons.refresh),
          label: const Text('به‌روزرسانی'),
        ),
      ]);
    }
    return _panel('اعلانات', [
      Text(
        'اعلان خوانده‌نشده: ${data['unread_count'] ?? 0}',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      for (final item in items)
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: AppTheme.background,
          child: ListTile(
            leading: Icon(
              item['is_read'] == true
                  ? Icons.notifications_none_rounded
                  : Icons.notifications_active_outlined,
              color: AppTheme.profile,
            ),
            title: Text(item['title']?.toString() ?? 'اعلان سامانه'),
            subtitle: Text(
              '${item['body'] ?? ''}\n${_when(item['delivered_at'])}',
            ),
            isThreeLine: true,
            onTap: () => _markNotificationRead(item),
          ),
        ),
      TextButton.icon(
        style: _textStyle,
        onPressed: () => _openView(6),
        icon: const Icon(Icons.refresh),
        label: const Text('به‌روزرسانی'),
      ),
    ]);
  }

  Widget _accountManagementPage(Profile profile) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _ProfileAction(
        icon: Icons.badge_outlined,
        title: 'اطلاعات حساب',
        subtitle: 'کد ملی و شماره همراه',
        onTap: () => _accountDetails(profile),
      ),
      _ProfileAction(
        icon: Icons.lock_outline_rounded,
        title: 'تغییر رمز عبور',
        subtitle: 'امنیت ورود به سامانه',
        onTap: () => _openView(2),
      ),
      _ProfileAction(
        icon: Icons.fingerprint_rounded,
        title: 'مشخصات بیومتریک',
        subtitle: 'فعال‌سازی یا غیرفعال‌کردن ورود بیومتریک',
        onTap: () => _biometricDetails(profile),
      ),
      _ProfileAction(
        icon: Icons.location_on_outlined,
        title: 'موقعیت جغرافیایی',
        subtitle: 'کشور، استان، شهرستان، شهر و روستا',
        onTap: () => _openView(3),
      ),
    ],
  );

  Widget _menu() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _ProfileAction(
        icon: Icons.manage_accounts_outlined,
        title: 'مدیریت حساب',
        subtitle: 'اطلاعات حساب، رمز عبور و مشخصات بیومتریک',
        onTap: () => _openView(1),
      ),
      _ProfileAction(
        icon: Icons.receipt_long_outlined,
        title: 'فعالیت‌های من',
        subtitle: 'مشاهدهٔ رسیدهای دیجیتال',
        onTap: () => _openView(5),
      ),
      _ProfileAction(
        icon: Icons.notifications_none_rounded,
        title: 'اعلانات',
        subtitle: 'پیام‌ها و به‌روزرسانی‌های سامانه',
        onTap: () => _openView(6),
      ),
      _ProfileAction(
        icon: Icons.no_accounts_outlined,
        title: 'بستن حساب',
        subtitle: 'غیرفعال‌کردن حساب کاربری',
        onTap: () => _openView(4),
      ),
      _ProfileAction(
        icon: Icons.logout_rounded,
        title: 'خروج از حساب',
        subtitle: 'پایان نشست کاربری',
        onTap: _logout,
      ),
    ],
  );

  Widget _interactivePreview() => Directionality(
    textDirection: TextDirection.rtl,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'حساب کاربری',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 23,
              color: AppTheme.profile,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.profile,
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Color(0x33FFFFFF),
                  child: Icon(
                    Icons.person_outline,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'پیش‌نمایش بخش کاربری',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _PreviewProfileAction(
            selected: _previewSelection == 0,
            icon: Icons.manage_accounts_outlined,
            title: 'مدیریت حساب',
            subtitle: 'اطلاعات حساب، رمز عبور و مشخصات بیومتریک',
            onTap: () => setState(() => _previewSelection = 0),
          ),
          _PreviewProfileAction(
            selected: _previewSelection == 1,
            icon: Icons.receipt_long_outlined,
            title: 'فعالیت‌های من',
            subtitle: 'مشاهدهٔ رسیدهای دیجیتال',
            onTap: () => setState(() => _previewSelection = 1),
          ),
          _PreviewProfileAction(
            selected: _previewSelection == 2,
            icon: Icons.notifications_none_rounded,
            title: 'اعلانات',
            subtitle: 'پیام‌ها و به‌روزرسانی‌های سامانه',
            onTap: () => setState(() => _previewSelection = 2),
          ),
          _PreviewProfileAction(
            selected: _previewSelection == 3,
            icon: Icons.no_accounts_outlined,
            title: 'بستن حساب',
            subtitle: 'غیرفعال‌کردن حساب کاربری',
            onTap: () => setState(() => _previewSelection = 3),
          ),
          const SizedBox(height: 10),
          _panel('نسخهٔ تعاملی', [
            Text(switch (_previewSelection) {
              0 =>
                'اطلاعات حساب، تغییر رمز، مشخصات بیومتریک و موقعیت جغرافیایی در این بخش قرار دارند.',
              1 =>
                'رسیدهای دیجیتال فعالیت‌های کاربر در این بخش نمایش داده می‌شوند.',
              2 => 'اعلانات سامانه در این بخش نمایش داده می‌شوند.',
              _ => 'بستن حساب در نسخهٔ تعاملی فعال نیست.',
            }, textAlign: TextAlign.center),
          ]),
          _PreviewProfileAction(
            selected: false,
            icon: Icons.logout_rounded,
            title: 'بازگشت به درگاه ورود',
            subtitle: 'خروج از محیط تعاملی',
            onTap: _exitInteractive,
          ),
        ],
      ),
    ),
  );

  Future<void> _exitInteractive() async {
    await context.read<AuthCubit>().exitGuestMode();
    if (mounted) context.go('/gateway');
  }

  @override
  Widget build(BuildContext context) {
    if (context.watch<AuthCubit>().state is Guest) {
      return _interactivePreview();
    }

    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        final profile = state is ProfileLoaded ? state.profile : null;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_view != 0) ...[
                  Row(
                    children: [
                      IconButton(
                        color: AppTheme.profile,
                        onPressed: _goBack,
                        icon: const Icon(Icons.arrow_forward),
                        tooltip: 'بازگشت',
                      ),
                      Expanded(
                        child: Text(
                          switch (_view) {
                            1 => 'مدیریت حساب',
                            2 => 'تغییر رمز عبور',
                            3 => 'موقعیت جغرافیایی',
                            4 => 'بستن حساب',
                            5 => 'فعالیت‌های من',
                            6 => 'اعلانات',
                            _ => 'حساب کاربری',
                          },
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontSize: 23, color: AppTheme.profile),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (_view == 5)
                  _receiptsPage()
                else if (state is ProfileError)
                  _panel('اطلاعات حساب', [
                    Text(state.message, textAlign: TextAlign.center),
                    TextButton(
                      style: _textStyle,
                      onPressed: () => context.read<ProfileCubit>().load(),
                      child: const Text('تلاش دوباره'),
                    ),
                  ])
                else if (profile == null)
                  const Center(child: CircularProgressIndicator())
                else
                  switch (_view) {
                    1 => _accountManagementPage(profile),
                    2 => _passwordPage(),
                    3 => _geoPage(),
                    4 => _managePage(),
                    5 => _receiptsPage(),
                    6 => _notificationsPage(),
                    _ => _menu(),
                  },
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PreviewProfileAction extends StatelessWidget {
  const _PreviewProfileAction({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: selected ? AppTheme.profile : AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppTheme.profile : AppTheme.divider,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? Colors.white : AppTheme.profile),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: selected ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 16,
                        color:
                            selected
                                ? Colors.white.withValues(alpha: .9)
                                : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: selected ? Colors.white : AppTheme.profile,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => AppTapTile(
    icon: icon,
    title: title,
    subtitle: subtitle,
    accent: AppTheme.profile,
    onTap: onTap,
  );
}
