import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Copies the included sample into this app's sandbox for native file access.
Future<String> prepareSampleWav() async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/whisper-test-jfk.wav');
  final data = await rootBundle.load('assets/audio/jfk.wav');
  await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true);
  return file.path;
}
