import 'dart:io';
import 'download_model.dart' as model;

// Fixed upstream commit: whisper.cpp v1.8.3.
const revision = '2eeeba56e9edd762b4b38467bab96c2517163158';
Future<void> main() async {
  final root = File.fromUri(Platform.script).parent.parent.path;
  final target = Directory('$root/native/vendor/whisper.cpp');
  Future<String> git(List<String> args) async {
    final result = await Process.run('git', args, workingDirectory: root);
    if (result.exitCode != 0) throw StateError('${result.stderr}');
    return '${result.stdout}'.trim();
  }

  if (!target.existsSync()) {
    target.parent.createSync(recursive: true);
    await git([
      'clone',
      '--depth',
      '1',
      '--branch',
      'v1.8.3',
      'https://github.com/ggml-org/whisper.cpp.git',
      target.path
    ]);
  }
  final actual = await git(['-C', target.path, 'rev-parse', 'HEAD']);
  if (actual != revision) throw StateError('Expected $revision, found $actual');
  stdout.writeln('whisper.cpp v1.8.3 ready at ${target.path}');
  await model.main();
}
