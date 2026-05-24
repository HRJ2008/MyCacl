# Calcly Flutter

This is the Flutter version of the Calcly calculator.

## Required setup

Flutter is not installed on this machine right now. Install Flutter first, then run:

```powershell
flutter create --platforms=android,web,windows,macos,linux,ios .
flutter pub get
```

## Build commands

```powershell
# Web app
flutter build web

# Android APK
flutter build apk --release

# Android AAB / App Bundle
flutter build appbundle --release

# Windows EXE
flutter build windows --release

# macOS app
flutter build macos --release

# Linux app
flutter build linux --release

# iOS app
flutter build ios --release
```

Notes:
- Windows builds require Visual Studio C++ desktop workload.
- Android builds require Android Studio SDK and licenses accepted with `flutter doctor --android-licenses`.
- iOS and macOS builds require macOS with Xcode.
- Linux builds require Linux desktop build dependencies.
