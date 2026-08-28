/// تنظیمات مخصوص مشاهده و تست فرانت‌اند.
///
/// DI این پرچم را با kDebugMode ترکیب می‌کند تا فیک در buildهای Release
/// هرگز فعال نشود.
const bool enableFrontendFakeAuth = bool.fromEnvironment(
  'VETO_ENABLE_FRONTEND_FAKE_AUTH',
  defaultValue: true,
);
