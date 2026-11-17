# Offline Whisper example

Prepare the plugin as described in the [package README](../README.md).
Run `flutter run` on Android or iOS. The English model is bundled automatically;
leave the model path field empty to use it. Copy a mono 16 kHz PCM16 WAV into the
app sandbox, enter its absolute path, and tap Transcribe.

The optional model path field accepts a custom model. The demo does not record
microphone audio or download models at runtime.
