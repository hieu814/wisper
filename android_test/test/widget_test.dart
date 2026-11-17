import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whisper_android_test/main.dart';

void main() {
  testWidgets('custom input must have a WAV path before native work starts',
      (tester) async {
    await tester.pumpWidget(const WhisperTestApp());
    await tester.tap(find.text('Transcribe WAV at path'));
    await tester.pump();
    expect(find.text('Enter an absolute path to a WAV in this app sandbox.'),
        findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('runSample')))
            .onPressed,
        isNotNull);
  });
}
