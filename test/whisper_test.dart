import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_whisper_cpp/flutter_whisper_cpp.dart';

void main() {
  test('validates options before allocating native memory', () {
    expect(() => Whisper(modelPath: ''), throwsArgumentError);
    expect(() => Whisper(modelPath: 'model', threads: 0), throwsRangeError);
    final whisper = Whisper(modelPath: 'model');
    expect(
        () => whisper.transcribe(samples: Float32List(0)), throwsArgumentError);
    expect(
        () => whisper.transcribe(samples: Float32List(1), language: 'english'),
        throwsArgumentError);
    expect(() => whisper.transcribeWav(path: ''), throwsArgumentError);
  });
  test('decodes timestamped results without allowing segment mutation', () {
    final result = WhisperResult.fromJson({
      'text': ' Hello',
      'language': 'en',
      'segments': [
        {'text': ' Hello', 'startMs': 120, 'endMs': 1500}
      ],
    });
    expect(result.text, ' Hello');
    expect(result.segments.single.start, const Duration(milliseconds: 120));
    expect(result.segments.single.end, const Duration(milliseconds: 1500));
    expect(() => result.segments.clear(), throwsUnsupportedError);
  });
  test('reports unsupported platforms and keeps queue usable after errors',
      () async {
    if (Platform.isAndroid || Platform.isIOS) return;
    final whisper = Whisper(modelPath: 'model');
    final first = whisper.transcribe(samples: Float32List(1));
    final second = whisper.transcribe(samples: Float32List(1));
    await expectLater(first, throwsUnsupportedError);
    await expectLater(second, throwsUnsupportedError);
  });
}
