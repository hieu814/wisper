import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:whisper_android_test/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'bundled model transcribes JFK sample through the Android native library',
      (tester) async {
    await tester.pumpWidget(const WhisperTestApp());
    await tester.tap(find.byKey(const Key('runSample')));
    final deadline = DateTime.now().add(const Duration(minutes: 4));
    var complete = false;
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 500));
      final status =
          tester.widget<SelectableText>(find.byKey(const Key('status'))).data!;
      if (status.startsWith('PASS:') ||
          status.startsWith('FAIL:') ||
          status.startsWith('CHECK:')) {
        expect(status, startsWith('PASS:'), reason: status);
        complete = true;
        break;
      }
      // Allow file I/O, platform channel responses, and the native worker to run.
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)));
    }
    expect(complete, isTrue, reason: 'Native transcription timed out');
    await tester.scrollUntilVisible(find.byKey(const Key('transcript')), 150);
    final transcript = tester
        .widget<SelectableText>(find.byKey(const Key('transcript')))
        .data!;
    expect(transcript.toLowerCase(), contains('fellow americans'));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
