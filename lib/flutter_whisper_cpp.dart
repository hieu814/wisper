library flutter_whisper_cpp;

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'src/bundled_model.dart';
import 'src/wav.dart';

/// A timestamped transcription segment.
class WhisperSegment {
  const WhisperSegment(
      {required this.text, required this.start, required this.end});
  final String text;
  final Duration start;
  final Duration end;
}

/// A transcription and its detected source language.
class WhisperResult {
  const WhisperResult(
      {required this.text, required this.language, required this.segments});
  final String text;
  final String language;
  final List<WhisperSegment> segments;

  factory WhisperResult.fromJson(Map<String, dynamic> json) => WhisperResult(
        text: json['text'] as String,
        language: json['language'] as String,
        segments: List.unmodifiable((json['segments'] as List).map((value) {
          final segment = value as Map<String, dynamic>;
          return WhisperSegment(
              text: segment['text'] as String,
              start: Duration(milliseconds: segment['startMs'] as int),
              end: Duration(milliseconds: segment['endMs'] as int));
        })),
      );
}

class WhisperException implements Exception {
  const WhisperException(this.message);
  final String message;
  @override
  String toString() => 'WhisperException: $message';
}

/// Offline, CPU-based transcription on Android and iOS.
///
/// Each request loads and releases the model on a background isolate. Calls on
/// this instance run sequentially to bound memory use. No dispose is needed.
class Whisper {
  Whisper({required this.modelPath, this.threads = 4}) {
    if (modelPath.isEmpty || modelPath.contains('\u0000')) {
      throw ArgumentError.value(
          modelPath, 'modelPath', 'Expected a filesystem path');
    }
    if (threads < 1 || threads > 64) {
      throw RangeError.range(threads, 1, 64, 'threads');
    }
  }
  static Future<String>? _bundledPath;

  /// Prepares the bundled English tiny model in application support storage.
  /// Call after WidgetsFlutterBinding.ensureInitialized(), on the main isolate.
  /// No network access is needed. The extracted file is reused across launches.
  static Future<Whisper> loadBundled({int threads = 4}) async {
    if (threads < 1 || threads > 64) {
      throw RangeError.range(threads, 1, 64, 'threads');
    }
    _bundledPath ??= _prepareBundled();
    try {
      return Whisper(modelPath: await _bundledPath!, threads: threads);
    } catch (_) {
      _bundledPath = null;
      rethrow;
    }
  }

  static Future<String> _prepareBundled() async {
    final directory = await getApplicationSupportDirectory();
    return materializeBundledModel(rootBundle, directory);
  }

  final String modelPath;
  final int threads;
  Future<void> _pending = Future<void>.value();

  /// Transcribes normalized mono 16 kHz PCM. Input is copied before queuing.
  Future<WhisperResult> transcribe(
      {required Float32List samples,
      String language = 'auto',
      bool translate = false}) {
    _validateLanguage(language);
    if (samples.isEmpty || samples.length > 0x7fffffff) {
      throw ArgumentError('PCM must contain 1..2147483647 samples');
    }
    final copy = Float32List.fromList(samples);
    return _enqueue(copy, null, language, translate);
  }

  /// Reads a mono 16 kHz PCM16 WAV from a filesystem path off the UI isolate.
  Future<WhisperResult> transcribeWav(
      {required String path,
      String language = 'auto',
      bool translate = false}) {
    _validateLanguage(language);
    if (path.isEmpty) throw ArgumentError.value(path, 'path');
    return _enqueue(null, path, language, translate);
  }

  void _validateLanguage(String language) {
    if (!RegExp(r'^(auto|[a-z]{2,3})$').hasMatch(language)) {
      throw ArgumentError.value(
          language, 'language', 'Use auto or a language code such as en');
    }
  }

  Future<WhisperResult> _enqueue(
      Float32List? samples, String? wav, String language, bool translate) {
    final model = modelPath;
    final threadCount = threads;
    final result = _pending.then((_) => Isolate.run(() =>
        _transcribe(model, threadCount, samples, wav, language, translate)));
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }
}

typedef _NativeTranscribe = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Float>, Int32, Pointer<Utf8>, Int32, Int32);
typedef _DartTranscribe = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Float>, int, Pointer<Utf8>, int, int);

WhisperResult _transcribe(String model, int threads, Float32List? pcm,
    String? wav, String language, bool translate) {
  if (!Platform.isAndroid && !Platform.isIOS) {
    throw UnsupportedError('Whisper supports Android and iOS only');
  }
  if (!File(model).existsSync()) {
    throw WhisperException('Model file does not exist: $model');
  }
  final samples = pcm ?? decodeWhisperWav(File(wav!).readAsBytesSync());
  if (samples.isEmpty || samples.length > 0x7fffffff) {
    throw const WhisperException('Invalid PCM length');
  }
  final library = Platform.isAndroid
      ? DynamicLibrary.open('libflutter_whisper_cpp.so')
      : DynamicLibrary.process();
  final transcribe = library
      .lookupFunction<_NativeTranscribe, _DartTranscribe>('fw_transcribe');
  final release = library.lookupFunction<Void Function(Pointer<Void>),
      void Function(Pointer<Void>)>('fw_free');
  final arena = Arena();
  Pointer<Utf8> output = nullptr;
  try {
    final input = arena<Float>(samples.length);
    input.asTypedList(samples.length).setAll(0, samples);
    output = transcribe(
        model.toNativeUtf8(allocator: arena),
        input,
        samples.length,
        language.toNativeUtf8(allocator: arena),
        threads,
        translate ? 1 : 0);
    if (output == nullptr) {
      throw const WhisperException('Native allocation failed');
    }
    final json = jsonDecode(output.toDartString()) as Map<String, dynamic>;
    if (json['error'] != null) throw WhisperException(json['error'] as String);
    return WhisperResult.fromJson(json);
  } finally {
    if (output != nullptr) release(output.cast());
    arena.releaseAll();
  }
}
