plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

import java.io.File
import java.io.FileInputStream
import java.security.KeyStore
import java.util.Properties




val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties: Properties by lazy {
    Properties().apply {
        if (keyPropertiesFile.exists()) {
            FileInputStream(keyPropertiesFile).use { load(it) }
        }
    }
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

data class SigningCredentials(
    val storePassword: String,
    val keyPassword: String,
    val source: String
)

fun resolveSigningCredentials(keystoreFile: File, keyAlias: String): SigningCredentials {
    val candidates = mutableListOf<SigningCredentials>()

    val propertiesStore = keyProperties.getProperty("storePassword")?.trim()?.takeIf { it.isNotEmpty() }
    val propertiesKey = keyProperties.getProperty("keyPassword")?.trim()?.takeIf { it.isNotEmpty() }
    if (propertiesStore != null && propertiesKey != null) {
        candidates += SigningCredentials(propertiesStore, propertiesKey, "key.properties")
    }

    val fileStore = signingEnvVars["KEYSTORE_PASSWORD"]?.trim()?.takeIf { it.isNotEmpty() }
    val fileKey = signingEnvVars["KEY_PASSWORD"]?.trim()?.takeIf { it.isNotEmpty() }
    if (fileStore != null && fileKey != null) {
        candidates += SigningCredentials(fileStore, fileKey, "app_config.env")
    }

    val envStore = System.getenv("KEYSTORE_PASSWORD")?.trim()?.takeIf { it.isNotEmpty() }
    val envKey = System.getenv("KEY_PASSWORD")?.trim()?.takeIf { it.isNotEmpty() }
    if (envStore != null && envKey != null) {
        candidates += SigningCredentials(envStore, envKey, "environment variables")
    }

    if (candidates.isEmpty()) {
        throw GradleException("Signing credentials not found. Provide KEYSTORE_PASSWORD and KEY_PASSWORD via environment variables or app_config.env")
    }

    val errors = mutableListOf<String>()
    val keystoreType = "PKCS12"

    candidates.forEach { candidate ->
        try {
            FileInputStream(keystoreFile).use { input ->
                val keyStore = KeyStore.getInstance(keystoreType)
                keyStore.load(input, candidate.storePassword.toCharArray())
                val key = keyStore.getKey(keyAlias, candidate.keyPassword.toCharArray())
                if (key == null) {
                    throw IllegalStateException("Alias $keyAlias not found in keystore")
                }
            }
            println("Using signing credentials from ${candidate.source}")
            return candidate
        } catch (e: Exception) {
            val message = e.message ?: e::class.java.simpleName
            println("Could not use signing credentials from ${candidate.source}: $message")
            errors += "- ${candidate.source}: $message"
        }
    }

    throw GradleException(
        "Failed to open keystore with provided credentials.\n" + errors.joinToString("\n")
    )
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
            val keystorePathOverride = keyProperties.getProperty("storeFile")?.trim()
            val keystoreFile = keystorePathOverride?.takeIf { it.isNotEmpty() }?.let { path ->
                val candidate = file(path)
                if (candidate.exists()) candidate else File(path)
            } ?: file("roastplus-new-key.keystore")
            if (!keystoreFile.exists()) {
                throw GradleException("Keystore file ${keystoreFile.absolutePath} was not found")
            }
            val keyAliasOverride = keyProperties.getProperty("keyAlias")?.trim()?.takeIf { it.isNotEmpty() }
                ?: "roastplus-key-alias"
            val credentials = resolveSigningCredentials(keystoreFile, keyAliasOverride)
            println("Using keystore from ${keystoreFile.absolutePath} with alias ${keyAliasOverride}")
            storeFile = keystoreFile
            storePassword = credentials.storePassword
            keyAlias = keyAliasOverride
            keyPassword = credentials.keyPassword
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
        // Google Sign-In クライアントIDは環境設定を優先し、無ければPlay署名用のフォールバックを使用
        val fallbackPlayGoogleSignInClientId = "330871937318-tofmig3lifv78brac91eucdfmfucs4nc.apps.googleusercontent.com"
        val googleSignInClientId = System.getenv("GOOGLE_SIGN_IN_CLIENT_ID")?.trim()?.takeIf { it.isNotEmpty() }
            ?: signingEnvVars["GOOGLE_SIGN_IN_CLIENT_ID"]?.trim()?.takeIf { it.isNotEmpty() }
            ?: fallbackPlayGoogleSignInClientId
        if (googleSignInClientId == fallbackPlayGoogleSignInClientId) {
            println("Using fallback Google Play signing client ID for Google Sign-In")
        }
        manifestPlaceholders["googleSignInClientId"] = googleSignInClientId
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
