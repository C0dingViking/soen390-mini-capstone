# Setting Up Google Maps API

## Configuration

Add your Google Maps API key to the Android configuration file:

**File**: `concordia_campus_guide/android/local.properties`

Add the following line:
```
GOOGLE_MAPS_API_KEY=YOUR_API_KEY
```

Replace `YOUR_API_KEY` with your actual Google Maps API key.

## How It Works (For Reference)

The Google Maps API key flows from the configuration file to the Android app through the Secrets Gradle Plugin:

### 1. Build Configuration

**File**: `android/build.gradle.kts`

The Secrets Gradle Plugin is added as a classpath dependency:

```kotlin
buildscript {
    dependencies {
        classpath("com.google.android.libraries.mapsplatform.secrets-gradle-plugin:secrets-gradle-plugin:2.0.1")
    }
}
```

**File**: `android/app/build.gradle.kts`

The plugin is applied to the app module:

```kotlin
plugins {
    id("com.android.application")
    // ...
    id("com.google.android.libraries.mapsplatform.secrets-gradle-plugin")
}
```

### 2. Android Manifest (`android/app/src/main/AndroidManifest.xml`)

The plugin reads `GOOGLE_MAPS_API_KEY` from `local.properties` and injects it into the manifest:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="${GOOGLE_MAPS_API_KEY}" />
```

During the build process, the Secrets Gradle Plugin automatically replaces `${GOOGLE_MAPS_API_KEY}` with the actual key value from `local.properties`, making it available to the Google Maps SDK at runtime.