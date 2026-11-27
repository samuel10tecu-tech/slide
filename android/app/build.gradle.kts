plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "ch.geneve.slide"
    compileSdk = 36
    defaultConfig {
        applicationId = "ch.geneve.slide"
        minSdk = 26
        targetSdk = 36
        versionCode = 8
        versionName = "1.6"
    }
    signingConfigs {
        // Upload key for Google Play. The keystore and passwords come from the environment
        // (GitHub secrets in CI, 1Password locally) and are never committed.
        create("upload") {
            val path = System.getenv("SLIDE_UPLOAD_KEYSTORE")
            if (path != null && file(path).exists()) {
                storeFile = file(path)
                storePassword = System.getenv("SLIDE_UPLOAD_STORE_PASSWORD")
                keyAlias = System.getenv("SLIDE_UPLOAD_KEY_ALIAS") ?: "upload"
                keyPassword = System.getenv("SLIDE_UPLOAD_KEY_PASSWORD") ?: System.getenv("SLIDE_UPLOAD_STORE_PASSWORD")
            }
        }
        create("slideDebug") {
            val store = file(System.getenv("SLIDE_KEYSTORE") ?: "slide-debug.keystore")
            if (store.exists()) {
                storeFile = store
                storePassword = "android"
                keyAlias = "slide"
                keyPassword = "android"
            }
        }
    }
    buildTypes {
        debug {
            val store = file(System.getenv("SLIDE_KEYSTORE") ?: "slide-debug.keystore")
            if (store.exists()) {
                signingConfig = signingConfigs.getByName("slideDebug")
            }
        }
        release {
            val path = System.getenv("SLIDE_UPLOAD_KEYSTORE")
            if (path != null && file(path).exists()) {
                signingConfig = signingConfigs.getByName("upload")
            }
        }
    }
    buildFeatures { compose = true }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    packaging { resources.excludes += "/META-INF/{AL2.0,LGPL2.1}" }
}

kotlin { jvmToolchain(17) }

dependencies {
    val bom = platform("androidx.compose:compose-bom:2024.10.01")
    implementation(bom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("org.osmdroid:osmdroid-android:6.1.20")
    testImplementation("junit:junit:4.13.2")
    // Real org.json on the JVM test classpath (Android only ships stubs there).
    testImplementation("org.json:json:20240303")
}
