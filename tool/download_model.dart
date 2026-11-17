import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_whisper_cpp/src/model_info.dart';

Future<bool> valid(File file) async =>
    await file.exists() &&
    await file.length() == bundledModelSize &&
    (await sha256.bind(file.openRead()).first).toString() == bundledModelSha256;

Future<void> main() async {
  final root = File.fromUri(Platform.script).parent.parent.path;
  final target = File('$root/assets/models/$bundledModelName');
  if (await valid(target)) {
    stdout.writeln('Bundled model already verified: ${target.path}');
    return;
  }
  await target.parent.create(recursive: true);
  final temp =
      File('${target.path}.${DateTime.now().microsecondsSinceEpoch}.part');
  final cached = File('$root/.models/$bundledModelName');
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
  try {
    if (await valid(cached)) {
      await cached.copy(temp.path);
    } else {
      stdout.writeln('Downloading English tiny model (32 MB)...');
      final request = await client.getUrl(Uri.parse(bundledModelUrl));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
            'Model download returned HTTP ${response.statusCode}');
      }
      await response.timeout(const Duration(minutes: 2)).pipe(temp.openWrite());
    }
    if (!await valid(temp)) throw StateError('Model size or SHA-256 mismatch');
    await temp.rename(target.path);
    stdout.writeln('Bundled model ready: ${target.path}');
  } finally {
    client.close(force: true);
    if (await temp.exists()) await temp.delete();
  }
}
