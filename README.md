# MyCacl / Calcly

MyCalc is a clean and modern calculator app built as a web app with HTML, CSS, and JavaScript, with a Flutter version included for Android, Windows, web, macOS, Linux, and iOS builds.

## Live Website

https://mycacl.harshrajjha2008.workers.dev/

## Web App

Cloudflare Pages settings for the current static web app:

```text
Framework preset: None
Build command: empty
Output directory: public
```

## Flutter Setup

Install Flutter first, then run:

```powershell
flutter create --platforms=android,web,windows,macos,linux,ios .
flutter pub get
```

## Build Commands

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
