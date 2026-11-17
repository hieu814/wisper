# flutter_whisper_cpp

Offline speech-to-text for Flutter on Android and iOS, powered by
[whisper.cpp](https://github.com/ggml-org/whisper.cpp), pinned to v1.8.3
(commit `2eeeba56e9edd762b4b38467bab96c2517163158`).

- Asynchronous inference on a Dart isolate.
- Normalized float PCM or mono 16 kHz PCM16 WAV input.
- Transcription, language detection, translation to English, and segment timestamps.
- CPU inference; no server, API key, microphone access, or network permission required.

## Set up

This is a source plugin, currently configured for local/path use. Native sources
and generated frameworks are ignored by version control and must be prepared
before building. Setup also prepares the bundled English tiny model (about 32 MB).

```sh
flutter pub get
dart run tool/setup.dart
```

The setup command requires Git and internet access on a fresh checkout, clones
the pinned upstream release, verifies its commit, and downloads/verifies the
bundled model. Existing verified files are reused. It refuses an existing checkout at a different
revision. Run it from a writable checkout of this package.

### Android

Requires API 21+, compile SDK 35, NDK `28.2.13676358`, CMake `3.22.1`, and a
compatible Gradle/Android Gradle Plugin installation (the example uses AGP 8.6.1,
Gradle 8.10.2, and Java 17). Install the SDK components with Android Studio's SDK
Manager. Gradle compiles the native library automatically. Supported ABIs are
`arm64-v8a` and `x86_64`. NDK r28 plus the linker page-size setting support 16 KB
pages. There is no 32-bit ARM build. Restrict your app to matching ABIs in
`android/app/build.gradle` (the example already does this):

```groovy
android {
    defaultConfig {
        ndk { abiFilters "arm64-v8a", "x86_64" }
    }
}
```

### iOS

Requires iOS 13+, macOS, Xcode with the iOS SDK, CocoaPods, and CMake >=3.22.
Build the static XCFramework **before** running CocoaPods or building the app:

```sh
dart run tool/setup.dart
bash tool/build_ios.sh
cd example
flutter pub get
flutter build ios --release --no-codesign
```

The script builds arm64 devices and arm64/x86_64 simulators independently and
merges their static libraries. CocoaPods links the resulting
`ios/Frameworks/FlutterWhisperCpp.xcframework`; its linker flags retain Dart FFI
symbols in release builds. Rebuild it after changing the native bridge or upstream
revision. CPU-only builds avoid runtime Metal resource dependencies.

## Use in an app

```yaml
dependencies:
  flutter_whisper_cpp:
    path: /path/to/flutter_whisper_cpp
```

```dart
import 'package:flutter_whisper_cpp/flutter_whisper_cpp.dart';

// Call after WidgetsFlutterBinding.ensureInitialized() or runApp().
final whisper = await Whisper.loadBundled(threads: 4);

final result = await whisper.transcribeWav(
  path: '/absolute/app-sandbox/speech.wav',
  language: 'en', // Default: auto. Multilingual models support other codes.
);
print(result.text);
for (final segment in result.segments) {
  print('${segment.start} - ${segment.end}: ${segment.text}');
}
```

For already decoded audio:

```dart
// Float32List: mono, 16,000 samples/second, normalized to [-1, 1].
final result = await whisper.transcribe(samples: pcm, language: 'auto');
```

Use `translate: true` to translate speech to English with a multilingual model.
English-only `.en` models support English transcription. The result's `language`
is the source language. Invalid model/inference requests raise `WhisperException`;
malformed WAV files raise `FormatException`; file I/O errors retain Dart's file
exceptions. Unsupported platforms raise `UnsupportedError`.

## Models and audio

The English tiny model is already included in `assets/models/ggml-tiny.en-q5_1.bin`
in this workspace and declared as a package asset. An app using this package as a
path dependency bundles it automatically. `Whisper.loadBundled()` copies it into
application support storage, verifies its SHA-256 on a background isolate, and
reuses that file. No model path, runtime download, or app asset entry is needed.
It adds roughly 32 MB before compression. Call it on the main isolate after
initializing Flutter bindings.

On a new checkout run `dart run tool/setup.dart`, or restore just the model with:

```sh
dart run tool/download_model.dart
```

The binary is ignored by Git; the preparation command downloads it automatically
and checks its exact size and SHA-256 before installing it. Do not skip this step
before building a fresh checkout. The bundled model supports **English only**.
For another language, provide a multilingual model explicitly:

```dart
final whisper = Whisper(modelPath: '/app/storage/ggml-tiny.bin');
```


Download a GGML model from the [upstream model collection](https://huggingface.co/ggerganov/whisper.cpp/tree/main),
for example `ggml-tiny.en-q5_1.bin` for a small English model. Use `ggml-tiny.bin`
for multilingual speech. Choose models according to device memory and accuracy
needs. Model names ending in `.en` are English-only. This API expects whisper.cpp
GGML files, not Python `.pt` or GGUF files.

Pass actual filesystem paths accessible to your app. If bundling a model in
Flutter assets, copy its bytes to an app-owned file first. For downloads or file
pickers, also copy external/content-URI inputs into the app sandbox. The runtime library does not download models, record microphones, decode
compressed audio, or resample. The setup script handles the bundled model download.
Add microphone permissions in your app only if you add recording separately.

Convert other audio formats before passing them to the plugin:

```sh
ffmpeg -i input.mp3 -ar 16000 -ac 1 -c:a pcm_s16le speech.wav
```

`Whisper.loadBundled()` caches the prepared model path in memory; reuse the
returned `Whisper` instance to share its request queue. Each request loads and
releases its model. Calls on one `Whisper` instance are
queued; reuse that instance to avoid concurrent model allocations. Independent
instances may run concurrently and consume extra memory. PCM input is copied
when submitted; avoid queuing many large recordings. WAV reading and decoding
happen on the worker isolate. There is no persistent model cache, live streaming,
progress reporting, or cancellation API. For long recordings, split audio in the
app and account for offsets when combining timestamps.

## Example and validation

`example/` uses the bundled English model when its model path field is empty.
Copy a WAV into the app sandbox, enter its path, and tap **Transcribe**.
The optional model path field allows custom models.

```sh
flutter analyze
flutter test
```

`tool/native_smoke.py <shared-library> [model.bin samples/jfk.wav]` exercises the
actual C ABI, error paths, memory release, and optionally JFK sample transcription.
The sample is available at `native/vendor/whisper.cpp/samples/jfk.wav` after setup.
The optional model/WAV arguments must be supplied together. A host CMake build
can produce a library for this check; the Dart API still supports only mobile.

The GitHub Actions workflow is configured to build the example Android APK and
iOS device/simulator apps. These jobs have not been run in this workspace.
The iOS native build must be verified on macOS; it cannot run on Windows.

The package is not configured for pub.dev publication. Before publishing, add
project ownership metadata, include upstream sources/licenses in the published
archive, and distribute a built XCFramework or provide an automated build step.
See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for upstream licensing.

Local validation: `flutter analyze` passed, the Dart tests passed, and
the native bridge compiled on Windows and transcribed the upstream JFK sample
with `ggml-tiny.en-q5_1.bin`. The Android release APK also built successfully; its arm64-v8a and x86_64 native
libraries have exported FFI symbols and 16 KB ELF alignment. iOS compilation and
on-device runtime testing remain unverified in this Windows workspace.
