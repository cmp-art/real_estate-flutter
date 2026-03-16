# Real Estate App - ProGuard Rules
# These rules are applied when building a release APK/AAB

# ========================================
# FLUTTER FRAMEWORK
# ========================================
# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.google.firebase.** { *; }

# ========================================
# SUPABASE & NETWORK
# ========================================
# Keep Supabase classes
-keep class io.supabase.** { *; }
-keep class com.supabase.** { *; }

# Gson (used by Supabase)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# OkHttp & Retrofit
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keep class retrofit2.** { *; }
-keepclasseswithmembers class * {
    @retrofit2.http.* <methods>;
}

# ========================================
# GOOGLE SERVICES
# ========================================
# Google Sign-In
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-keep class com.google.api.client.** { *; }

# Google Play Core (for deferred components and split install)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }

# Google Play Services
-keep class * extends java.util.ListResourceBundle {
    protected Object[][] getContents();
}
-keep public class com.google.android.gms.common.internal.safeparcel.SafeParcelable {
    public static final *** NULL;
}
-keepnames @com.google.android.gms.common.annotation.KeepName class *
-keepclassmembernames class * {
    @com.google.android.gms.common.annotation.KeepName *;
}

# ========================================
# GOOGLE MAPS & LOCATION
# ========================================
-keep class com.google.android.gms.maps.** { *; }
-keep interface com.google.android.gms.maps.** { *; }
-keep class com.google.maps.** { *; }

# ========================================
# IMAGE HANDLING
# ========================================
# Image Picker
-keep class androidx.core.content.FileProvider { *; }

# Glide / Coil (if using)
-keep public class * implements com.bumptech.glide.module.GlideModule
-keep class * extends com.bumptech.glide.module.AppGlideModule {
    <init>(...);
}
-keep public enum com.bumptech.glide.load.ImageHeaderParser$** {
    **[] $VALUES;
    public *;
}

# ========================================
# VIDEO HANDLING
# ========================================
# ExoPlayer (used by video_player)
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# ========================================
# PAYMENT CONFIGURATION - SELCOM
# ========================================
# Selcom Payment Gateway
-keep class com.selcom.** { *; }
-dontwarn com.selcom.**

# Stripe SDK (if using flutter_stripe)
-keep class com.stripe.** { *; }
-keep class com.stripe.android.** { *; }
-keep class com.stripe.android.pushProvisioning.** { *; }
-dontwarn com.stripe.**
-dontwarn com.stripe.android.**

# React Native Stripe SDK (if present)
-keep class com.reactnativestripesdk.** { *; }
-dontwarn com.reactnativestripesdk.**

# HTTP clients for payment processing
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**

# ========================================
# PHONE NUMBER PARSING
# ========================================
-keep class com.google.i18n.phonenumbers.** { *; }
-dontwarn com.google.i18n.phonenumbers.**

# ========================================
# DATABASE (SQLite/Sqflite)
# ========================================
-keep class androidx.sqlite.** { *; }
-keep class android.database.** { *; }

# ========================================
# SHARED PREFERENCES
# ========================================
-keep class androidx.preference.** { *; }
-keep class android.content.SharedPreferences { *; }

# ========================================
# GENERAL ANDROID
# ========================================
# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep custom view constructors
-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet);
}
-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet, int);
}

# Keep Activity subclasses
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider

# Keep Parcelables
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# ========================================
# KOTLIN
# ========================================
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings {
    <fields>;
}
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}
-assumenosideeffects class kotlin.jvm.internal.Intrinsics {
    static void checkParameterIsNotNull(java.lang.Object, java.lang.String);
}

# ========================================
# ANNOTATIONS
# ========================================
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# ========================================
# REFLECTION (for JSON serialization)
# ========================================
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt

# Keep data classes
-keep @interface kotlinx.serialization.Serializable
-keepclassmembers @kotlinx.serialization.Serializable class ** {
    *** Companion;
}
-keepclasseswithmembers class ** {
    kotlinx.serialization.KSerializer serializer(...);
}

# ========================================
# REMOVE LOGGING IN RELEASE
# ========================================
# Strip debug/verbose/info Android Log calls from release builds.
# This prevents internal strings from being readable in the APK binary.
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}
# w/e kept so Play Console crash reports still have useful context.

# Rename source file attribute so stack traces show line numbers but
# not the real class names — protects proprietary logic.
-renamesourcefileattribute SourceFile

# ========================================
# OPTIMIZATION SETTINGS
# ========================================
-optimizationpasses 5
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-verbose

# Allow optimization
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*

# ========================================
# WARNINGS TO IGNORE
# ========================================
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# ========================================
# CUSTOM MODELS
# ========================================
# If you have custom model classes, keep them
# Replace 'com.makaziestate.app.models' with your package
-keep class com.makaziestate.app.models.** { *; }
-keep class com.makaziestate.app.data.** { *; }

# ========================================
# NOTES
# ========================================
# This ProGuard configuration is optimized for:
# - Flutter apps
# - Supabase backend
# - Google Sign-In
# - Selcom Payment Gateway
# - Direct Advertising System
# - Image/Video handling
# - Maps & Location
#
# Add additional rules as needed for other plugins
# Test thoroughly with release builds before publishing