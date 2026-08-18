pluginManagement {
    resolutionStrategy {
        eachPlugin {
            if (requested.id.id.startsWith("org.jetbrains.kotlin")) {
                useVersion("2.4.0")
            }
        }
    }
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        maven(url = "file:///home/sadeq/development/flutter_local_maven")
        maven(url = "https://maven.aliyun.com/repository/google")
        maven(url = "https://maven.aliyun.com/repository/gradle-plugin")
        maven(url = "https://maven.aliyun.com/repository/public")
        google()
        mavenCentral()
    }
}

// مجبور کردن کل پروژه به استفاده از نسخه واحد Kotlin در تمام سطوح
dependencyResolutionManagement {
    repositories {
        maven(url = "file:///home/sadeq/development/flutter_local_maven")
        maven(url = "https://maven.aliyun.com/repository/google")
        maven(url = "https://maven.aliyun.com/repository/public")
        google()
        mavenCentral()
    }
    versionCatalogs {
        create("libs") {
            library("kotlin-stdlib", "org.jetbrains.kotlin", "kotlin-stdlib").version("2.4.0")
        }
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    // اضافه کردن صریح پلاگین کاتلین برای اطمینان از Resolve شدن درست
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
}

include(":app")
