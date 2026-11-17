import 'dart:typed_data';

/// Decodes mono 16 kHz PCM16 WAV, including padded metadata chunks.
Float32List decodeWhisperWav(Uint8List bytes) {
  Never invalid(String message) => throw FormatException(message);
  if (bytes.length < 12) invalid('Truncated WAV header');
  final data = ByteData.sublistView(bytes);
  String tag(int offset) =>
      String.fromCharCodes(bytes.sublist(offset, offset + 4));
  if (tag(0) != 'RIFF' || tag(8) != 'WAVE') {
    invalid('Expected a RIFF/WAVE file');
  }
  final end = data.getUint32(4, Endian.little) + 8;
  if (end > bytes.length || end < 12) invalid('Truncated RIFF container');
  var formatFound = false;
  final audio = <Uint8List>[];
  for (var offset = 12; offset < end;) {
    if (offset + 8 > end) invalid('Truncated WAV chunk header');
    final size = data.getUint32(offset + 4, Endian.little);
    final start = offset + 8;
    if (start + size > end) invalid('Truncated WAV chunk');
    switch (tag(offset)) {
      case 'fmt ':
        if (formatFound) invalid('Duplicate WAV format chunk');
        if (size < 16 ||
            data.getUint16(start, Endian.little) != 1 ||
            data.getUint16(start + 2, Endian.little) != 1 ||
            data.getUint32(start + 4, Endian.little) != 16000 ||
            data.getUint32(start + 8, Endian.little) != 32000 ||
            data.getUint16(start + 12, Endian.little) != 2 ||
            data.getUint16(start + 14, Endian.little) != 16) {
          invalid('Expected mono 16000 Hz signed PCM16 WAV');
        }
        formatFound = true;
      case 'data':
        if (size.isOdd) invalid('Misaligned PCM16 data');
        audio.add(Uint8List.sublistView(bytes, start, start + size));
    }
    offset = start + size + (size & 1);
    if (offset > end) invalid('Missing WAV chunk padding');
  }
  if (!formatFound || audio.isEmpty) {
    invalid('Missing WAV format or audio data');
  }
  final length = audio.fold<int>(0, (n, chunk) => n + chunk.length ~/ 2);
  if (length == 0) invalid('WAV contains no samples');
  final samples = Float32List(length);
  var index = 0;
  for (final chunk in audio) {
    final pcm = ByteData.sublistView(chunk);
    for (var i = 0; i < chunk.length; i += 2) {
      samples[index++] = pcm.getInt16(i, Endian.little) / 32768;
    }
  }
  return samples;
}
