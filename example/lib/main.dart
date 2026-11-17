import 'package:flutter/material.dart';
import 'package:flutter_whisper_cpp/flutter_whisper_cpp.dart';

void main() => runApp(const MaterialApp(home: TranscriptionDemo()));

class TranscriptionDemo extends StatefulWidget {
  const TranscriptionDemo({super.key});
  @override
  State<TranscriptionDemo> createState() => _TranscriptionDemoState();
}

class _TranscriptionDemoState extends State<TranscriptionDemo> {
  final model = TextEditingController();
  final audio = TextEditingController();
  var busy = false;
  var output =
      'Bundled English model ready. Enter a WAV path in the app sandbox.';

  Future<void> transcribe() async {
    setState(() {
      busy = true;
      output = 'Transcribing?';
    });
    try {
      final whisper = model.text.trim().isEmpty
          ? await Whisper.loadBundled()
          : Whisper(modelPath: model.text.trim());
      final result = await whisper.transcribeWav(path: audio.text.trim());
      if (mounted) {
        setState(() {
          output =
              '${result.language}\n${result.text}\n\n${result.segments.map((s) => '${s.start} ? ${s.end}: ${s.text}').join('\n')}';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => output = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  void dispose() {
    model.dispose();
    audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Offline Whisper')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          TextField(
              controller: model,
              decoration: const InputDecoration(
                  labelText: 'Model path (optional: bundled English model)')),
          TextField(
              controller: audio,
              decoration: const InputDecoration(
                  labelText: '16 kHz mono PCM16 WAV path')),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: busy ? null : transcribe,
              child: Text(busy ? 'Working?' : 'Transcribe')),
          const SizedBox(height: 16),
          SelectableText(output),
        ]),
      );
}
