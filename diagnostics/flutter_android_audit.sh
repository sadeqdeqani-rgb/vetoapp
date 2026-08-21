#!/usr/bin/env bash
# این اسکریپت فقط اطلاعات را می‌خواند و در گزارش ذخیره می‌کند؛ تغییری در سیستم ایجاد نمی‌کند.

set +e

REPORT="$HOME/workspace/vetoapp/diagnostics/flutter_android_audit_$(date +%F_%H-%M-%S).txt"

# tee خروجی را هم‌زمان در ترمینال و فایل گزارش می‌نویسد.
exec > >(tee "$REPORT") 2>&1

section() {
  printf '\n\n============================================================\n'
  printf '%s\n' "$1"
  printf '============================================================\n'
}

section "0) زمان و اطلاعات پایهٔ سیستم"
date
uname -a
printf '\n--- نسخهٔ Linux Mint / Ubuntu ---\n'
cat /etc/os-release

section "1) مسیر واقعی ابزارهای اجرایی"
# command -v مسیر ابزاری را که Shell واقعاً اجرا می‌کند نمایش می‌دهد.
for tool in flutter dart java javac gradle adb sdkmanager; do
  printf '\n--- %s ---\n' "$tool"
  command -v "$tool" || true
  type -a "$tool" || true
done

section "2) نسخهٔ ابزارهای اصلی"
# این فرمان‌ها فقط نسخه را می‌خوانند؛ دانلود یا به‌روزرسانی انجام نمی‌دهند.
printf '\n--- Flutter ---\n'
flutter --version 2>&1 || true

printf '\n--- Dart ---\n'
dart --version 2>&1 || true

printf '\n--- Java runtime ---\n'
java -version 2>&1 || true

printf '\n--- Java compiler ---\n'
javac -version 2>&1 || true

printf '\n--- ADB ---\n'
adb version 2>&1 || true

section "3) متغیرهای محیطی اثرگذار"
# فقط متغیرهای کلیدی را نشان می‌دهد؛ مقدار رمز/توکن احتمالی Proxy ماسک می‌شود.
env | grep -Ei '^(PATH|JAVA_HOME|ANDROID_HOME|ANDROID_SDK_ROOT|ANDROID_NDK_HOME|FLUTTER_ROOT|DART_HOME|GRADLE_USER_HOME|HTTP_PROXY|HTTPS_PROXY|ALL_PROXY|NO_PROXY|http_proxy|https_proxy|all_proxy|no_proxy)=' \
  | sed -E 's#(://)[^/@[:space:]]+@#\1***:***@#g' \
  | sort

section "4) تنظیمات Shell که ممکن است PATH یا Proxy را تغییر دهند"
# grep فقط خطوط مرتبط با Flutter، Android، Java، Gradle و Proxy را از فایل‌های رایج Shell می‌خواند.
for file in "$HOME/.profile" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.zshrc"; do
  if [ -f "$file" ]; then
    printf '\n--- %s ---\n' "$file"
    grep -nEi 'flutter|dart|android|sdk|java|gradle|proxy|path=' "$file" \
      | sed -E 's#(://)[^/@[:space:]]+@#\1***:***@#g' || true
  fi
done

section "5) Flutter SDK و فایل version آن"
# readlink -f مسیرهای symlink را به مسیر واقعی تبدیل می‌کند.
FLUTTER_BIN="$(command -v flutter 2>/dev/null || true)"
if [ -n "$FLUTTER_BIN" ]; then
  FLUTTER_BIN_REAL="$(readlink -f "$FLUTTER_BIN")"
  FLUTTER_HOME="$(dirname "$(dirname "$FLUTTER_BIN_REAL")")"
  printf 'flutter executable: %s\n' "$FLUTTER_BIN_REAL"
  printf 'flutter SDK root:   %s\n' "$FLUTTER_HOME"
  printf '\n--- فایل version Flutter ---\n'
  sed -n '1,120p' "$FLUTTER_HOME/version" 2>/dev/null || true
  printf '\n--- وضعیت Git Flutter SDK ---\n'
  git -C "$FLUTTER_HOME" remote -v 2>/dev/null || true
  git -C "$FLUTTER_HOME" status --short 2>/dev/null || true
  git -C "$FLUTTER_HOME" log -1 --oneline 2>/dev/null || true
fi

section "6) Android SDK و packageهای نصب‌شده"
# مسیرهای رایج SDK بررسی می‌شوند؛ این بخش به اینترنت متصل نمی‌شود.
for sdk in "${ANDROID_SDK_ROOT:-}" "${ANDROID_HOME:-}" "$HOME/Android/Sdk"; do
  [ -n "$sdk" ] || continue
  if [ -d "$sdk" ]; then
    printf '\n--- Android SDK: %s ---\n' "$sdk"
    printf 'Build-tools:\n'
    find "$sdk/build-tools" -mindepth 1 -maxdepth 1 -type d -printf '  %f\n' 2>/dev/null | sort
    printf 'Platforms:\n'
    find "$sdk/platforms" -mindepth 1 -maxdepth 1 -type d -printf '  %f\n' 2>/dev/null | sort
    printf 'NDK:\n'
    find "$sdk/ndk" -mindepth 1 -maxdepth 1 -type d -printf '  %f\n' 2>/dev/null | sort
    printf 'Cmdline tools:\n'
    find "$sdk/cmdline-tools" -mindepth 1 -maxdepth 2 -type d -printf '  %P\n' 2>/dev/null | sort
  fi
done

section "7) Gradle سراسری، Wrapper پروژه و تنظیمات پنهان"
printf '\n--- Gradle wrapper properties ---\n'
sed -n '1,160p' "$HOME/workspace/vetoapp/android/gradle/wrapper/gradle-wrapper.properties" 2>/dev/null || true

printf '\n--- Gradle wrapper version ---\n'
cd "$HOME/workspace/vetoapp/android" && ./gradlew --version --no-daemon 2>&1 || true

printf '\n--- فایل‌ها و اسکریپت‌های init در ~/.gradle ---\n'
find "$HOME/.gradle" -maxdepth 3 -type f \( -name 'init.gradle' -o -name 'init.gradle.kts' -o -name '*.init.gradle' -o -name '*.init.gradle.kts' \) -print 2>/dev/null

printf '\n--- gradle.properties سراسری کاربر ---\n'
sed -n '1,200p' "$HOME/.gradle/gradle.properties" 2>/dev/null || true

section "8) تنظیمات Android پروژهٔ VetoApp"
cd "$HOME/workspace/vetoapp/android" || exit 0

printf '\n--- settings.gradle.kts ---\n'
nl -ba settings.gradle.kts

printf '\n--- app/build.gradle.kts ---\n'
nl -ba app/build.gradle.kts

printf '\n--- gradle.properties پروژه ---\n'
nl -ba gradle.properties 2>/dev/null || true

printf '\n--- gradle-wrapper.properties ---\n'
nl -ba gradle/wrapper/gradle-wrapper.properties 2>/dev/null || true

printf '\n--- local.properties (فقط مسیرهای SDK؛ بدون دادهٔ حساس) ---\n'
grep -E '^(flutter\.sdk|sdk\.dir|ndk\.dir)=' local.properties 2>/dev/null || true

section "9) جست‌وجوی تمام منابع Kotlin / AGP / Gradle در پروژه"
# grep تمام ارجاع‌های نسخه و pluginهای اثرگذار را، بدون ورود به cacheها، پیدا می‌کند.
grep -RInE \
  'org\.jetbrains\.kotlin|kotlin\.gradle|kotlinVersion|kotlin_version|useVersion|com\.android\.(application|library)|android\.builtInKotlin|gradle-[0-9]' \
  "$HOME/workspace/vetoapp/android" \
  --exclude-dir=.gradle \
  --exclude='*.lock' 2>/dev/null || true

section "10) pluginهای Flutter و وابستگی‌های Android آن‌ها"
cd "$HOME/workspace/vetoapp" || exit 0
printf '\n--- Flutter plugins ---\n'
sed -n '1,260p' .flutter-plugins-dependencies 2>/dev/null || true

printf '\n--- dependency_overrides و dependencies از pubspec.yaml ---\n'
grep -nE '^(environment:|dependencies:|dev_dependencies:|dependency_overrides:|  [A-Za-z0-9_-]+:)' pubspec.yaml 2>/dev/null || true

section "11) نتیجه"
printf 'گزارش در این مسیر ذخیره شد:\n%s\n' "$REPORT"
