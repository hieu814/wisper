import 'dart:io';
import 'dart:isolate';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'model_info.dart';

Future<bool> _valid(String path) async {
  final file = File(path);
  if (!await file.exists() || await file.length() != bundledModelSize) {
    return false;
  }
  return (await sha256.bind(file.openRead()).first).toString() ==
      bundledModelSha256;
}

/// Extracts a package asset to a native-readable, versioned model file.
Future<String> materializeBundledModel(
    AssetBundle bundle, Directory storage) async {
  final directory = Directory('${storage.path}/flutter_whisper_cpp');
  await directory.create(recursive: true);
  final path =
      '${directory.path}/${bundledModelSha256.substring(0, 12)}-$bundledModelName';
  if (await Isolate.run(() => _valid(path))) return path;
  final data = await bundle.load(bundledModelAsset);
  final temp = File('$path.${DateTime.now().microsecondsSinceEpoch}.part');
  try {
    await temp.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true);
    final tempPath = temp.path;
    if (!await Isolate.run(() => _valid(tempPath))) {
      throw const FormatException(
          'Bundled Whisper model failed SHA-256 validation');
    }
    await temp.rename(path);
    return path;
  } finally {
    if (await temp.exists()) await temp.delete();
  }
}
