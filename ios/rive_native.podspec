#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint rive_native.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name = "rive_native"
  s.version = "0.0.1"
  s.summary = "Rive Flutter's native iOS plugin"
  s.description = <<-DESC
Rive Flutter's native macOS plugin.
                       DESC
  s.homepage = "https://rive.app"
  s.license = { :file => "../LICENSE" }
  s.author = { "Rive" => "support@rive.app" }
  s.source = { :path => "." }
  s.source_files = "Classes/**/*"
  s.public_header_files = "Classes/**/*.h"
  s.dependency "Flutter"
  s.platform = :ios, "9.0"
  s.ios.framework  = ['AudioToolbox', 'AVFAudio']
  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { "DEFINES_MODULE" => "YES", "EXCLUDED_ARCHS[sdk=iphonesimulator*]" => "i386",
                            "USER_HEADER_SEARCH_PATHS" => '"$(PODS_TARGET_SRCROOT)/../native/include"',
                            "LIBRARY_SEARCH_PATHS[config=Release*]" => '"$(PODS_TARGET_SRCROOT)/../native/build/iphoneos/bin/release"',
                            "LIBRARY_SEARCH_PATHS[config=Profile*]" => '"$(PODS_TARGET_SRCROOT)/../native/build/iphoneos/bin/release"',
                            # "LIBRARY_SEARCH_PATHS[config=Debug*]" => '"$(PODS_TARGET_SRCROOT)/../native/build/iphoneos/bin/debug"',
                            "LIBRARY_SEARCH_PATHS[sdk=iphoneos*][config=Debug*]" => '"$(PODS_TARGET_SRCROOT)/../native/build/iphoneos/bin/release"',
                            "LIBRARY_SEARCH_PATHS[sdk=iphonesimulator*][config=Debug*]" => '"$(PODS_TARGET_SRCROOT)/../native/build/iphoneos/bin/emulator"',
                            "OTHER_LDFLAGS[config=Release*]" => "-Wl,-force_load,$(PODS_TARGET_SRCROOT)/../native/build/iphoneos/bin/release/librive_native.a -lrive -lrive_pls_renderer -lrive_yoga -lrive_harfbuzz -lrive_sheenbidi -lrive_decoders -llibpng -lzlib -llibjpeg -llibwebp -lminiaudio",
                            "OTHER_LDFLAGS[config=Profile*]" => "-Wl,-force_load,$(PODS_TARGET_SRCROOT)/../native/build/iphoneos/bin/release/librive_native.a -lrive -lrive_pls_renderer -lrive_yoga -lrive_harfbuzz -lrive_sheenbidi -lrive_decoders -llibpng -lzlib -llibjpeg -llibwebp -lminiaudio",
                            # "OTHER_LDFLAGS[config=Debug*]" => "-Wl,-force_load,$(PODS_TARGET_SRCROOT)/../native/build/iphoneos/bin/debug/librive_native.a -lrive -lrive_pls_renderer -lrive_yoga -lrive_harfbuzz -lrive_sheenbidi -lrive_decoders -llibpng -lzlib -llibjpeg -llibwebp -lminiaudio",
                            "OTHER_LDFLAGS[sdk=iphoneos*][config=Debug*]" => "-Wl,-force_load,$(PODS_TARGET_SRCROOT)/../native/build/iphoneos/bin/release/librive_native.a -lrive -lrive_pls_renderer -lrive_yoga -lrive_harfbuzz -lrive_sheenbidi -lrive_decoders -llibpng -lzlib -llibjpeg -llibwebp -lminiaudio",
                            "OTHER_LDFLAGS[sdk=iphonesimulator*][config=Debug*]" => "-Wl,-force_load,$(PODS_TARGET_SRCROOT)/../native/build/iphoneos/bin/emulator/librive_native.a -lrive -lrive_pls_renderer -lrive_yoga -lrive_harfbuzz -lrive_sheenbidi -lrive_decoders -llibpng -lzlib -llibjpeg -llibwebp -lminiaudio",
                            "CLANG_CXX_LANGUAGE_STANDARD" => "c++17",
                            "CLANG_CXX_LIBRARY" => "libc++" }

  # Add the frameworks
  # s.frameworks = 'AVFoundation', 'AudioToolbox'

  script = <<-SCRIPT
  #!/bin/sh
  set -e
  
  MARKER="${PODS_TARGET_SRCROOT}/rive_marker_ios_setup_complete"
  DEV_MARKER="${PODS_TARGET_SRCROOT}/rive_marker_ios_development"

  if [ -f "$MARKER" ] || [ -f "$DEV_MARKER" ]; then
    echo "[rive_native] Setup already complete. Skipping."
  else
    echo "[rive_native] Setup marker not found. Running setup script..."
    echo "[rive_native] If this fails, make sure you have Dart installed and available in your PATH."
    echo "[rive_native] You can run the setup manually with:"
    echo "  dart run rive_native:setup --verbose --platform ios"

    # Try to read FLUTTER_ROOT from Generated.xcconfig
    GENERATED_XCCONFIG="${SRCROOT}/../Flutter/Generated.xcconfig"
    if [ -f "$GENERATED_XCCONFIG" ]; then
      FLUTTER_ROOT=$(grep FLUTTER_ROOT "$GENERATED_XCCONFIG" | cut -d '=' -f2 | tr -d '[:space:]')
    fi

    if [ -n "$FLUTTER_ROOT" ] && [ -x "$FLUTTER_ROOT/bin/dart" ]; then
      echo "[rive_native] Using dart from FLUTTER_ROOT: $FLUTTER_ROOT"
      "$FLUTTER_ROOT/bin/dart" run rive_native:setup --verbose --platform ios
    else
      echo "[rive_native] FLUTTER_ROOT not set or dart not found in FLUTTER_ROOT. Using system dart..."
      dart run rive_native:setup --verbose --platform ios
    fi
  fi
  SCRIPT
  
  s.script_phases = [
    {
      :name => 'Rive Native Compile',
      :script => script,
      :execution_position => :before_compile,
      :output_files => ['${PODS_TARGET_SRCROOT}/rive_marker_ios_setup_complete']
    }
  ]
end
