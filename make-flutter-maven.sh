#!/usr/bin/env bash
# ============================================================
# ساخت Maven Repository محلی برای فلتر به دلیل محدودیت تحریمی
# ============================================================
set -euo pipefail

ENGINE_HASH="5f77625673248ee5846fbcaf5d3e1a3878386fd7"
SDK_ENGINE="/home/sadeq/development/flutter/bin/cache/artifacts/engine"
REPO_DIR="/home/sadeq/development/flutter_local_maven"

# پاکسازی و ساخت دوباره
rm -rf "$REPO_DIR"
mkdir -p "$REPO_DIR/io/flutter"

# --- تابع ساخت یک artifact Maven از flutter.jar ---
make_abi_artifact() {
  local abi="$1"        # نام ABI در Maven (مثل arm64_v8a_debug)
  local src_dir="$2"    # پوشهٔ منبع در SDK engine
  local version="1.0.0-$ENGINE_HASH"

  local art_dir="$REPO_DIR/io/flutter/$abi/$version"
  mkdir -p "$art_dir"

  # 1) کپی flutter.jar به عنوان JAR artifact (حاوی libflutter.so)
  cp "$src_dir/flutter.jar" "$art_dir/$abi-$version.jar"

  # 2) تولید POM ساده (بدون وابستگی، فقط jar)
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

# --- ساخت سه artifact ABI ---
make_abi_artifact "arm64_v8a_debug" "$SDK_ENGINE/android-arm64"
make_abi_artifact "armeabi_v7a_debug" "$SDK_ENGINE/android-arm"
make_abi_artifact "x86_64_debug" "$SDK_ENGINE/android-x64"

# گزارش
echo ""
echo "✅ مخزن Maven محلی آماده است:"
find "$REPO_DIR" -type f | sort


# ============================================================
# بخش ۲: ساخت flutter_embedding_debug از کش موجود Gradle
# ============================================================
EMBEDDING_VERSION="1.0.0-$ENGINE_HASH"
EMBEDDING_ART_DIR="$REPO_DIR/io/flutter/flutter_embedding_debug/$EMBEDDING_VERSION"
mkdir -p "$EMBEDDING_ART_DIR"

# پیدا کردن JAR موجود در کش Gradle
EMBEDDING_JAR=$(find ~/.gradle/caches/modules-2/files-2.1/io.flutter/flutter_embedding_debug -name "*.jar" 2>/dev/null | head -1)

if [ -n "$EMBEDDING_JAR" ]; then
    cp "$EMBEDDING_JAR" "$EMBEDDING_ART_DIR/flutter_embedding_debug-$EMBEDDING_VERSION.jar"
    cat > "$EMBEDDING_ART_DIR/flutter_embedding_debug-$EMBEDDING_VERSION.pom" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>io.flutter</groupId>
  <artifactId>flutter_embedding_debug</artifactId>
  <version>$EMBEDDING_VERSION</version>
  <packaging>jar</packaging>
</project>
EOF
    echo "✔ ساخته شد: flutter_embedding_debug ($EMBEDDING_VERSION)"
else
    echo "⚠️ flutter_embedding_debug JAR در کش پیدا نشد"
fi

# گزارش نهایی
echo ""
echo "✅ مخزن Maven محلی کامل شد:"
find "$REPO_DIR" -type f | sort
