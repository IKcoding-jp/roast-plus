plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}


val signingEnvVars: Map<String, String> by lazy {
    val map = mutableMapOf<String, String>()
    val candidateFiles = listOf(
        rootProject.file("../app_config.env"),
        rootProject.file("app_config.env"),
        file("../../app_config.env"),
        file("../app_config.env")
    ).distinct()

    val envFile = candidateFiles.firstOrNull { it.exists() && it.isFile }
    envFile?.forEachLine { line ->
        val trimmed = line.trim()
        if (trimmed.isEmpty() || trimmed.startsWith("#")) return@forEachLine
        val separatorIndex = trimmed.indexOf('=')
        if (separatorIndex <= 0) return@forEachLine

        val key = trimmed.substring(0, separatorIndex).trim()
        var value = trimmed.substring(separatorIndex + 1).trim()
        val commentIndex = value.indexOf('#')
        if (commentIndex >= 0) {
            value = value.substring(0, commentIndex).trim()
        }
        if (key.isNotEmpty() && value.isNotEmpty()) {
            map[key] = value
        }
    }

    map.toMap()
}

fun loadSigningCredential(name: String): String {
    val envValue = System.getenv(name)?.trim()
    if (!envValue.isNullOrEmpty()) {
        return envValue
    }

    val fileValue = signingEnvVars[name]?.trim()
    if (!fileValue.isNullOrEmpty()) {
        println("Using $name from app_config.env")
        return fileValue
    }

    throw GradleException("${name} must be provided either as an environment variable or in app_config.env")
}

android {
    namespace = "com.ikcoding.roastplus"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Enable core library desugaring
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // 警告を抑制
    lint {
        disable += "InvalidPackage"
        checkReleaseBuilds = false
    }


    // 署名設定
    signingConfigs {
        create("release") {
            val keystorePassword = loadSigningCredential("KEYSTORE_PASSWORD")
            val keyPasswordValue = loadSigningCredential("KEY_PASSWORD")
            storeFile = file("roastplus-new-key.keystore")
            storePassword = keystorePassword
            keyAlias = "roastplus-key-alias"
            keyPassword = keyPasswordValue
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.ikcoding.roastplus"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // ネットワークセキュリティ設定ファイルを指定
        manifestPlaceholders["networkSecurityConfig"] = "@xml/network_security_config"
        
        // 環境変数からAPIキーを取得
        manifestPlaceholders["googleSignInClientId"] = System.getenv("GOOGLE_SIGN_IN_CLIENT_ID") ?: "330871937318-ua3q3aikt2vkd6p30288mm1d62df53pl.apps.googleusercontent.com"
        manifestPlaceholders["admobAppId"] = System.getenv("ADMOB_ANDROID_APP_ID") ?: "ca-app-pub-3940256099942544~3347511713"
    }

    buildTypes {
        release {
            // リリース用の署名設定を使用
            signingConfig = signingConfigs.getByName("release")
            
            // リリースビルドでのSSL/TLS設定
            manifestPlaceholders["usesCleartextTraffic"] = "false"
            
            // リリースビルドの最適化
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
        
        debug {
            // デバッグビルドでのSSL/TLS設定
            manifestPlaceholders["usesCleartextTraffic"] = "true"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Add core library desugaring dependency
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    
    // Firebase BOM
    implementation(platform("com.google.firebase:firebase-bom:34.2.0"))
    
    // Firebase Analytics
    implementation("com.google.firebase:firebase-analytics")
    
    // Google Play Services
    implementation("com.google.android.gms:play-services-auth:21.2.0")
    implementation("com.google.android.gms:play-services-base:18.5.0")
    implementation("com.google.android.gms:play-services-identity:18.0.1")
    
    // Google Play Services の追加依存関係
    implementation("com.google.android.gms:play-services-gcm:17.0.0")
}

