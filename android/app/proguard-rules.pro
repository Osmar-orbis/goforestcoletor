# Manter classes do Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Manter classes do Firebase
-keep class com.google.firebase.** { *; }
-keepnames class com.google.android.gms.** { *; }
-keep class com.google.android.gms.** { *; }
-keepattributes Signature

# === REGRAS PARA CORRIGIR O SEU ERRO ===
# Manter classes do Google Play Core (que estavam faltando)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**