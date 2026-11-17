# Android Studio library test app

This standalone Flutter app depends on `flutter_whisper_cpp` in the parent folder.
It includes JFK sample audio and uses the library's bundled English model, so the
sample test requires no downloads, recording permissions, or manually copied files.

## Open in Android Studio

1. Install/enable the Flutter plugin (which also installs the Dart plugin).
2. Choose **File > Open** and select this `android_test` folder, not its inner
   `android` folder. Configure the Flutter SDK when prompted (on this computer:
   `C:\src\flutter`).
3. Run `flutter pub get` in the Android Studio terminal.
4. Select an arm64 Android phone or an x86_64/arm64 Android emulator, API 21+.
5. Open `lib/main.dart` and click Run/Debug.
6. Tap **Run bundled JFK sample**. Expect a green PASS status and text containing
   "fellow Americans", followed by segment timestamps.

The screen shows errors, elapsed time, language, model path, and the transcript.
The first run copies/verifies the included model in application support storage.
All inference runs offline. Model loading happens on each transcription request.

For native/Gradle inspection, open `android/` as an Android Studio project after
running `flutter pub get`. Run the Flutter app from the outer project for Dart
breakpoints and hot reload. Both model and native library come from the parent
package: changes there are tested without copying code.

## Command line

From this folder:

```sh
flutter pub get
flutter run
flutter build apk --debug
```

Automated native integration test (requires a running Android device/emulator):

```sh
flutter devices
flutter test integration_test/transcription_test.dart -d DEVICE_ID
```

Local widget validation without a device:

```sh
flutter analyze
flutter test test
```

## Custom audio

Use **Transcribe WAV at path** for a mono 16 kHz PCM16 WAV inside the app sandbox.
After running the sample, the path field contains the sample's cache path. Android
Studio's Device Explorer can place another file in that same app-owned directory
on a debuggable build. Use a filesystem path, not a `content://` URI.

## Toolchain and fresh checkouts

The app uses compile/target SDK 35, NDK 28.2.13676358, CMake 3.22.1, AGP 8.6.1,
Gradle 8.10.2, and supports arm64-v8a/x86_64 only. Java 17 or 21 can run Gradle.
The Android SDK manager may install missing native components during the first
build. The bundled model is English-only.

On a new checkout, first run these commands from the **parent library folder**:

```sh
flutter pub get
dart run tool/setup.dart
```

Then return here and run `flutter pub get`. The 32 MB model is ignored by Git;
setup restores it automatically. The sample WAV is stored in this test app.

The app ID is `dev.whisper.test.whisper_android_test`, so it can be installed next
to the original example. Debug APK: `build/app/outputs/flutter-apk/app-debug.apk`.
Sample source: whisper.cpp's `samples/jfk.wav` (public-domain JFK speech).
