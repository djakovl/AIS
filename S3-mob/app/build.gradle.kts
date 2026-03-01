import java.util.Properties
import java.io.FileInputStream

plugins {
    alias(libs.plugins.android.application)
}

android {
    namespace = "com.sirius.s3client"
    compileSdk = 36

    defaultConfig {
        val properties = Properties()
        val localPropertiesFile = rootProject.file("local.properties")
        if (localPropertiesFile.exists()) {
            properties.load(FileInputStream(localPropertiesFile))
        }

        val baseUrl = System.getenv("BASE_URL") ?: properties.getProperty("BASE_URL") ?: ""
        buildConfigField("String", "BASE_URL", "\"$baseUrl\"")

        val prefsName = System.getenv("PREFS_NAME") ?: properties.getProperty("PREFS_NAME") ?: ""
        buildConfigField("String", "PREFS_NAME", "\"$prefsName\"")

        val keySession = System.getenv("KEY_SESSION") ?: properties.getProperty("KEY_SESSION") ?: ""
        buildConfigField("String", "KEY_SESSION", "\"$keySession\"")

        val keyCsrf = System.getenv("KEY_CSRF") ?: properties.getProperty("KEY_CSRF") ?: ""
        buildConfigField("String", "KEY_CSRF", "\"$keyCsrf\"")

        applicationId = "com.sirius.s3client"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildFeatures {
        buildConfig = true
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
}

dependencies {

    // Source: https://mvnrepository.com/artifact/com.google.code.gson/gson
    implementation("com.google.code.gson:gson:2.13.2")

    // Source: https://mvnrepository.com/artifact/com.squareup.retrofit2/converter-gson
    implementation("com.squareup.retrofit2:converter-gson:3.0.0")

    // Source: https://mvnrepository.com/artifact/com.squareup.retrofit2/retrofit
    implementation("com.squareup.retrofit2:retrofit:3.0.0")

    // Source: https://mvnrepository.com/artifact/com.squareup.okhttp3/logging-interceptor
    implementation("com.squareup.okhttp3:logging-interceptor:5.3.2")

    // Source: https://mvnrepository.com/artifact/androidx.security/security-crypto
    implementation("androidx.security:security-crypto:1.1.0")

    // Source: https://mvnrepository.com/artifact/com.github.bumptech.glide/glide
    implementation("com.github.bumptech.glide:glide:5.0.5")

    implementation(libs.appcompat)
    implementation(libs.material)
    implementation(libs.activity)
    implementation(libs.constraintlayout)
    testImplementation(libs.junit)
    androidTestImplementation(libs.ext.junit)
    androidTestImplementation(libs.espresso.core)
}