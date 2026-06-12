# ─── Flutter defaults ───
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ─── Jitsi Meet SDK ───
-keep class org.jitsi.** { *; }
-keep class org.webrtc.** { *; }
-dontwarn org.jitsi.**
-dontwarn org.webrtc.**

# ─── React Native (bundled with Jitsi) ───
-keep class com.facebook.react.** { *; }
-dontwarn com.facebook.react.**
-keep class com.facebook.hermes.** { *; }
-dontwarn com.facebook.hermes.**

# ─── OkHttp (used by Jitsi internals) ───
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }

# ─── Firebase ───
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ─── Supabase / GoTrue ───
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# ─── Google Play Core (deferred components) ───
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
