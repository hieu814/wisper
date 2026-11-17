# Bundled English model

`ggml-tiny.en-q5_1.bin` is prepared by `dart run tool/setup.dart` or
`dart run tool/download_model.dart`. It is bundled automatically through the
package pubspec and adds approximately 32 MB before app compression.

Source: https://huggingface.co/ggerganov/whisper.cpp/blob/main/ggml-tiny.en-q5_1.bin
SHA-256: c77c5766f1cef09b6b7d47f21b546cbddd4157886b3b5d6d4f709e91e66c7c2b

This is an English-only model. Use a separate multilingual model for other
languages or translation. The binary is ignored by Git; setup restores it on
new checkouts. The model is distributed under the MIT license; see the upstream
model repository and THIRD_PARTY_NOTICES.md.
