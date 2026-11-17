#!/usr/bin/env bash
# Run on macOS with Xcode and CMake >=3.22. No code signing required.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
command -v cmake >/dev/null
command -v xcodebuild >/dev/null
[[ -f "$ROOT/native/vendor/whisper.cpp/include/whisper.h" ]] || {
  echo "Run dart run tool/setup.dart first" >&2; exit 1;
}
BUILD="$(mktemp -d "${TMPDIR:-/tmp}/flutter-whisper.XXXXXX")"
mkdir -p "$BUILD/headers" "$ROOT/ios/Frameworks"
cp "$ROOT/src/flutter_whisper_cpp.h" "$BUILD/headers/"
# Build each architecture independently so GGML selects the right CPU backend.
for TARGET in device-arm64 sim-arm64 sim-x86_64; do
  SDK=iphonesimulator
  ARCH=arm64
  [[ "$TARGET" != device-arm64 ]] || SDK=iphoneos
  [[ "$TARGET" != sim-x86_64 ]] || ARCH=x86_64
  cmake -S "$ROOT/src" -B "$BUILD/$TARGET" -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT="$SDK" \
    -DCMAKE_OSX_ARCHITECTURES="$ARCH" -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO
  cmake --build "$BUILD/$TARGET" --config Release --target flutter_whisper_cpp --parallel
  LIBS=()
  while IFS= read -r -d '' LIB; do LIBS+=("$LIB"); done < <(find "$BUILD/$TARGET" -name '*.a' -print0)
  [[ ${#LIBS[@]} -gt 0 ]]
  mkdir -p "$BUILD/merged/$TARGET"
  xcrun libtool -static -o "$BUILD/merged/$TARGET/libFlutterWhisperCpp.a" "${LIBS[@]}"
done
mkdir -p "$BUILD/merged/simulator"
xcrun lipo -create "$BUILD/merged/sim-arm64/libFlutterWhisperCpp.a" \
  "$BUILD/merged/sim-x86_64/libFlutterWhisperCpp.a" \
  -output "$BUILD/merged/simulator/libFlutterWhisperCpp.a"
xcodebuild -create-xcframework \
  -library "$BUILD/merged/device-arm64/libFlutterWhisperCpp.a" -headers "$BUILD/headers" \
  -library "$BUILD/merged/simulator/libFlutterWhisperCpp.a" -headers "$BUILD/headers" \
  -output "$BUILD/FlutterWhisperCpp.xcframework"
ditto "$BUILD/FlutterWhisperCpp.xcframework" "$ROOT/ios/Frameworks/FlutterWhisperCpp.xcframework"
echo "Created $ROOT/ios/Frameworks/FlutterWhisperCpp.xcframework"
echo "Intermediate files: $BUILD"
