Pod::Spec.new do |s|
  s.name = 'flutter_whisper_cpp'
  s.version = '0.1.0'
  s.summary = 'Offline Whisper speech transcription through Dart FFI.'
  s.description = 'Android and iOS bindings for whisper.cpp with background inference.'
  s.homepage = 'https://github.com/ggml-org/whisper.cpp'
  s.license = { :file => '../LICENSE' }
  s.author = 'flutter_whisper_cpp contributors'
  s.source = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.vendored_frameworks = 'Frameworks/FlutterWhisperCpp.xcframework'
  s.resource_bundles = { 'flutter_whisper_cpp_privacy' => ['Assets/PrivacyInfo.xcprivacy'] }
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.libraries = 'c++'
  # Retain symbols looked up dynamically by Dart in release builds.
  s.user_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -Wl,-u,_fw_transcribe -Wl,-u,_fw_free'
  }
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
