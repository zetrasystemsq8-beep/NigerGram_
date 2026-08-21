# Flutter plugin embedding
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase Messaging
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.iid.** { *; }

# Supabase / Gotrue / Realtime (reflection-based JSON handling)
-keep class io.supabase.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# Firestore / gRPC
-keep class com.google.firebase.firestore.** { *; }
-keep class io.grpc.** { *; }
-dontwarn io.grpc.**

# Gson (used transitively by several of the above)
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# ✅ Play Core (needed for split install)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# ✅ ML Kit (text recognition + vision)
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# ✅ Google Tasks (used by Play Core split installs)
-keep class com.google.android.play.core.tasks.** { *; }
-dontwarn com.google.android.play.core.tasks.**
