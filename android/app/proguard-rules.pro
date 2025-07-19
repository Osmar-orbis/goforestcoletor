# =======================================================
# === ARQUIVO proguard-rules.pro - VERSÃO FINAL OFICIAL ===
# =======================================================

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

# Manter classes do Google Play Core
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# =======================================================
# === REGRAS OFICIAIS E COMPLETAS PARA O FLUTTER STRIPE ===
# =======================================================
-keepclasseswithmembers class com.stripe.android.** {
    public <init>(...);
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
-keepclassmembers public class * extends java.lang.Enum {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator CREATOR;
}

-keepclassmembers class ** { @com.stripe.android.core.networking.StripeJsonSerializable *; }
-keepclassmembers class ** { @com.stripe.android.core.model.StripeModel *; }
-keepclassmembers class ** { @kotlin.Metadata *; }

# Necessário para Bouncy Castle, uma dependência de criptografia do Stripe
-dontwarn org.bouncycastle.**

# =======================================================
# === REGRAS ADICIONAIS PARA CORRIGIR O ERRO DE BUILD ===
# =======================================================
# Mantém as classes de pushProvisioning do Stripe que estavam sendo removidas.
-keep class com.stripe.android.pushProvisioning.** { *; }
-dontwarn com.stripe.android.pushProvisioning.**

# Mantém classes do SDK do React Native Stripe para evitar conflitos de dependência.
-keep class com.reactnativestripesdk.** { *; }
-dontwarn com.reactnativestripesdk.**
