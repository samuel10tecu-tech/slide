plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "ch.geneve.slide"
    compileSdk = 35
    defaultConfig {
        applicationId = "ch.geneve.slide"
        minSdk = 26
        targetSdk = 35
        versionCode = 7
        versionName = "1.5.1"
    }
    signingConfigs {
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
}
