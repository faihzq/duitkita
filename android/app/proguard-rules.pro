## Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

## Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

## Keep Crashlytics
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

## Image Cropper (UCrop)
-keep class com.yalantis.ucrop.** { *; }
-dontwarn com.yalantis.ucrop.**

## Play Core (deferred components)
-dontwarn com.google.android.play.core.**

## Credential Manager — google_sign_in 7.x signs in through androidx.credentials,
## not the old GoogleSignInClient. The Play Services provider is resolved by
## reflection, so R8 sees no reference to it and strips it; the credential and
## token types are likewise reconstructed from Bundles by name. Without these,
## Google sign-in fails only in minified builds — debug and emulator runs work.
-if class androidx.credentials.CredentialManager
-keep class androidx.credentials.playservices.** {
  *;
}
-keep class com.google.android.libraries.identity.googleid.** { *; }
