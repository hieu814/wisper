import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_whisper_cpp/src/wav.dart';

Uint8List wav(
    {int rate = 16000,
    int channels = 1,
    int bits = 16,
    List<int> samples = const [-32768, 0, 32767],
    bool metadata = false}) {
  final bytes = BytesBuilder();
  void tag(String value) => bytes.add(value.codeUnits);
  void u16(int value) => bytes.add(
      (ByteData(2)..setUint16(0, value, Endian.little)).buffer.asUint8List());
  void u32(int value) => bytes.add(
      (ByteData(4)..setUint32(0, value, Endian.little)).buffer.asUint8List());
  tag('RIFF');
  u32(36 + samples.length * 2 + (metadata ? 10 : 0));
  tag('WAVE');
  if (metadata) {
    tag('JUNK');
    u32(1);
    bytes.add([42, 0]);
  }
  tag('fmt ');
  u32(16);
  u16(1);
  u16(channels);
  u32(rate);
  u32(rate * channels * bits ~/ 8);
  u16(channels * bits ~/ 8);
  u16(bits);
  tag('data');
  u32(samples.length * 2);
  for (final value in samples) {
    u16(value & 0xffff);
  }
  return bytes.toBytes();
}

void main() {
  test('decodes signed PCM with normalized endpoints', () {
    expect(decodeWhisperWav(wav()), [-1.0, 0.0, 32767 / 32768]);
  });
  test('skips odd metadata chunks with padding', () {
    expect(decodeWhisperWav(wav(metadata: true)), [-1.0, 0.0, 32767 / 32768]);
  });
  test('rejects audio requiring conversion', () {
    for (final bytes in [wav(rate: 44100), wav(channels: 2), wav(bits: 8)]) {
      expect(() => decodeWhisperWav(bytes), throwsFormatException);
    }
  });
  test('rejects malformed headers, lengths, format, and empty audio', () {
    final wrongTag = wav()..[0] = 0;
    final truncated = wav().sublist(0, 40);
    final chunkOverflow = wav();
    ByteData.sublistView(chunkOverflow).setUint32(40, 9999, Endian.little);
    final wrongEncoding = wav();
    ByteData.sublistView(wrongEncoding).setUint16(20, 3, Endian.little);
    for (final bytes in [
      Uint8List(0),
      wrongTag,
      truncated,
      chunkOverflow,
      wrongEncoding,
      wav(samples: [])
    ]) {
      expect(() => decodeWhisperWav(bytes), throwsFormatException);
    }
  });
}
