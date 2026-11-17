import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_whisper_cpp/flutter_whisper_cpp.dart';
import 'sample.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WhisperTestApp());
}

class WhisperTestApp extends StatelessWidget {
  const WhisperTestApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Whisper Android Test',
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: const TestScreen(),
      );
}

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});
  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final path = TextEditingController();
  WhisperResult? result;
  String status =
      'Ready. Run the included sample to test offline transcription.';
  String? modelPath;
  int? elapsedMs;
  bool busy = false;
  bool? passed;

  Future<void> run({required bool sample}) async {
    if (!sample && path.text.trim().isEmpty) {
      setState(() =>
          status = 'Enter an absolute path to a WAV in this app sandbox.');
      return;
    }
    setState(() {
      busy = true;
      result = null;
      passed = null;
      elapsedMs = null;
      status = 'Preparing bundled model and audio...';
    });
    final timer = Stopwatch()..start();
    try {
      final whisper = await Whisper.loadBundled();
      final audioPath = sample ? await prepareSampleWav() : path.text.trim();
      if (!mounted) return;
      setState(() {
        modelPath = whisper.modelPath;
        if (sample) path.text = audioPath;
        status = 'Transcribing offline...';
      });
      final output =
          await whisper.transcribeWav(path: audioPath, language: 'en');
      timer.stop();
      if (!mounted) return;
      final samplePassed =
          output.text.toLowerCase().contains('fellow americans');
      setState(() {
        result = output;
        elapsedMs = timer.elapsedMilliseconds;
        passed = sample ? samplePassed : null;
        status = sample
            ? (samplePassed
                ? 'PASS: expected sample speech recognized.'
                : 'CHECK: sample phrase was not recognized.')
            : 'Transcription complete.';
      });
    } catch (error, stack) {
      debugPrint('Whisper Android test: $error\n$stack');
      if (mounted) {
        setState(() {
          passed = false;
          status = 'FAIL: $error';
        });
      }
    } finally {
      timer.stop();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    path.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Whisper Android Test')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const Text(
              'English tiny model included. No download or microphone required.'),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('runSample'),
            onPressed: busy ? null : () => run(sample: true),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Run bundled JFK sample'),
          ),
          const SizedBox(height: 16),
          TextField(
              controller: path,
              enabled: !busy,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Optional custom WAV path',
                  helperText:
                      'Mono 16 kHz PCM16; file must be accessible to this app.')),
          const SizedBox(height: 8),
          OutlinedButton(
              onPressed: busy ? null : () => run(sample: false),
              child: const Text('Transcribe WAV at path')),
          const SizedBox(height: 20),
          if (busy) const LinearProgressIndicator(),
          const SizedBox(height: 12),
          SelectableText(status,
              key: const Key('status'),
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: passed == null
                      ? null
                      : (passed!
                          ? Colors.green.shade800
                          : Colors.red.shade800))),
          if (elapsedMs != null) Text('Elapsed: ${elapsedMs! / 1000} seconds'),
          if (modelPath != null) ...[
            const SizedBox(height: 12),
            SelectableText('Model: $modelPath'),
          ],
          if (result != null) ...[
            const Divider(height: 32),
            Text('Language: ${result!.language}'),
            const SizedBox(height: 8),
            SelectableText(result!.text, key: const Key('transcript')),
            TextButton.icon(
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: result!.text)),
                icon: const Icon(Icons.copy),
                label: const Text('Copy transcript')),
            const Text('Segments',
                style: TextStyle(fontWeight: FontWeight.bold)),
            for (final segment in result!.segments)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SelectableText(
                      '${segment.start} - ${segment.end}\n${segment.text}')),
          ],
        ]),
      );
}
