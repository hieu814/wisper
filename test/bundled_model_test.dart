import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_whisper_cpp/src/bundled_model.dart';
import 'package:flutter_whisper_cpp/src/model_info.dart';

class ModelBundle extends CachingAssetBundle {
  ModelBundle(this.bytes);
  final Uint8List bytes;
  int loads = 0;
  @override
  Future<ByteData> load(String key) async {
    expect(key, bundledModelAsset);
    loads++;
    return ByteData.sublistView(bytes);
  }
}

void main() {
  late Directory storage;
  setUp(() async {
    storage = await Directory.systemTemp.createTemp('whisper-model-test-');
  });
  tearDown(() async {
    final parent =
        '${Directory.systemTemp.absolute.path}${Platform.pathSeparator}';
    expect(storage.absolute.path.startsWith(parent), isTrue);
    await storage.delete(recursive: true);
  });
  test('extracts real model, reuses verified cache, and repairs corruption',
      () async {
    final bytes = await File('assets/models/$bundledModelName').readAsBytes();
    final bundle = ModelBundle(bytes);
    final path = await materializeBundledModel(bundle, storage);
    expect(await File(path).length(), bundledModelSize);
    expect(bundle.loads, 1);
    expect(await materializeBundledModel(bundle, storage), path);
    expect(bundle.loads, 1);
    final damaged = Uint8List.fromList(bytes)..[0] ^= 0xff;
    await File(path).writeAsBytes(damaged, flush: true);
    expect(await materializeBundledModel(bundle, storage), path);
    expect(bundle.loads, 2);
    expect(await File(path).length(), bundledModelSize);
  });
  test('rejects a damaged bundled asset and removes incomplete files',
      () async {
    final bundle = ModelBundle(Uint8List.fromList([0, 1, 2]));
    await expectLater(
        materializeBundledModel(bundle, storage), throwsFormatException);
    final files =
        await storage.list(recursive: true).where((e) => e is File).toList();
    expect(files, isEmpty);
  });
}
