#!/usr/bin/env bash
# ============================================================
# ساخت Maven Repository محلی برای فلتر به دلیل محدودیت تحریمی
# ============================================================
set -euo pipefail

ENGINE_HASH="5f77625673248ee5846fbcaf5d3e1a3878386fd7"
SDK_ENGINE="/home/sadeq/development/flutter/bin/cache/artifacts/engine"
REPO_DIR="/home/sadeq/development/flutter_local_maven"
FLUTTER_ROOT="/home/sadeq/development/flutter"
POM_GENERATOR="$FLUTTER_ROOT/engine/src/flutter/tools/androidx/generate_pom_file.py"

if [ ! -f "$POM_GENERATOR" ]; then
  echo "خطا: ابزار رسمی تولید POM Flutter پیدا نشد: $POM_GENERATOR" >&2
  exit 1
fi

# پاکسازی و ساخت دوباره
rm -rf "$REPO_DIR"
mkdir -p "$REPO_DIR/io/flutter"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# --- تابع ساخت یک artifact Maven از flutter.jar ---
make_abi_artifact() {
  local variant="$1"    # build variant: debug یا release
  local abi_base="$2"   # نام ABI پایه در Maven (مثل arm64_v8a)
  local src_dir="$3"    # پوشهٔ منبع در SDK engine
  local abi="${abi_base}_${variant}"
  local version="1.0.0-$ENGINE_HASH"

  local art_dir="$REPO_DIR/io/flutter/$abi/$version"
  local native_dir="$TMP_DIR/$abi"
  mkdir -p "$art_dir"

  # ABI artifact باید فقط native library داشته باشد؛ flutter.jar علاوه بر
  # libflutter.so شامل کلاس‌های embedding Java نیز هست و باعث Duplicate class
  # هنگام استفادهٔ هم‌زمان با flutter_embedding_debug می‌شود.
  mkdir -p "$native_dir"
  unzip -q "$src_dir/flutter.jar" 'lib/*' -d "$native_dir"
  (cd "$native_dir" && jar cf "$art_dir/$abi-$version.jar" lib)

  # 2) ABIها وابستگی Android/Flutter ندارند؛ POM ساده کافی است.
  cat > "$art_dir/$abi-$version.pom" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>io.flutter</groupId>
  <artifactId>$abi</artifactId>
  <version>$version</version>
  <packaging>jar</packaging>
</project>
EOF

  echo "✔ ساخته شد: $abi ($version)"
}

# --- ساخت artifactهای ABI برای debug و release ---
for variant in debug release; do
  if [ "$variant" = "debug" ]; then
    arm_dir="$SDK_ENGINE/android-arm"
    arm64_dir="$SDK_ENGINE/android-arm64"
    x64_dir="$SDK_ENGINE/android-x64"
  else
    arm_dir="$SDK_ENGINE/android-arm-release"
    arm64_dir="$SDK_ENGINE/android-arm64-release"
    x64_dir="$SDK_ENGINE/android-x64-release"
  fi

  make_abi_artifact "$variant" "arm64_v8a" "$arm64_dir"
  make_abi_artifact "$variant" "armeabi_v7a" "$arm_dir"
  make_abi_artifact "$variant" "x86_64" "$x64_dir"
done

# گزارش
echo ""
echo "✅ مخزن Maven محلی آماده است:"
find "$REPO_DIR" -type f | sort


# ============================================================
# بخش ۲: ساخت flutter_embedding برای debug و release
# ============================================================
EMBEDDING_VERSION="1.0.0-$ENGINE_HASH"
make_embedding_artifact() {
    local variant="$1"
    local embedding_name="flutter_embedding_${variant}"
    local embedding_art_dir="$REPO_DIR/io/flutter/$embedding_name/$EMBEDDING_VERSION"
    mkdir -p "$embedding_art_dir"
    local embedding_jar=""

    if [ "$variant" = "debug" ]; then
        embedding_jar=$(find ~/.gradle/caches/modules-2/files-2.1/io.flutter/flutter_embedding_debug -name "*.jar" 2>/dev/null | head -1 || true)
    fi

    if [ -n "$embedding_jar" ]; then
        cp "$embedding_jar" "$embedding_art_dir/$embedding_name-$EMBEDDING_VERSION.jar"
    else
        local embedding_src="$SDK_ENGINE/android-arm64"
        if [ "$variant" = "release" ]; then
            embedding_src="$SDK_ENGINE/android-arm64-release"
        fi
        local embedding_tmp="$TMP_DIR/embedding-$variant"
        mkdir -p "$embedding_tmp"
        unzip -q "$embedding_src/flutter.jar" -d "$embedding_tmp"
        rm -rf "$embedding_tmp/lib"
        (cd "$embedding_tmp" && jar cf "$embedding_art_dir/$embedding_name-$EMBEDDING_VERSION.jar" .)
    fi

    # Flutter Embedding به AndroidX Window، Core، Lifecycle، ReLinker و
    # چند کتابخانهٔ دیگر وابسته است. POM خالی باعث می‌شود Gradle فقط JAR را
    # ببیند و خطای NoClassDefFoundError در زمان اجرای FlutterView رخ دهد.
    #
    # از generator رسمی Flutter استفاده می‌کنیم تا فهرست وابستگی‌ها از
    # engine/tools/androidx/files.json خوانده شود و با نسخهٔ همین Engine
    # هماهنگ بماند.
    python3 "$POM_GENERATOR" \
      --engine-artifact-id "$embedding_name" \
      --engine-version "$ENGINE_HASH" \
      --destination "$embedding_art_dir" \
      --include-embedding-dependencies true

    # generator نام POM را بر اساس artifact id می‌سازد؛ Maven repository
    # محلی ما، مثل سایر artifactهای این اسکریپت، نام versioned می‌خواهد.
    mv "$embedding_art_dir/$embedding_name.pom" \
      "$embedding_art_dir/$embedding_name-$EMBEDDING_VERSION.pom"

    # این بررسی جلوی تولید ناقص repository را می‌گیرد.
    test -s "$embedding_art_dir/$embedding_name-$EMBEDDING_VERSION.pom"
    echo "✔ ساخته شد: $embedding_name ($EMBEDDING_VERSION)"
}

make_embedding_artifact debug
make_embedding_artifact release

# گزارش نهایی
echo ""
echo "✅ مخزن Maven محلی کامل شد:"
find "$REPO_DIR" -type f | sort
