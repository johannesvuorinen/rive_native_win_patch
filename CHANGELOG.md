## 0.0.11

- Updates the Rive C++ runtime and renderer for the latest features, bug fixes, and performance improvements.

### Fixes

- Fixed a crash in `preCommitCallback` for iOS and macOS.

### Build & Platform Updates

- Builds the native iOS and macOS libraries with Xcode 16.1 (bumped up from 15.4)

## 0.0.10+1

- Fixed hash verification

## 0.0.10

- Updates the Rive C++ runtime and renderer for the latest features, bug fixes, and performance improvements.
- Expose `localBounds` on `Component`.

### Fixes

- Fixes an issue where graphics might settle (pause) too soon, by forcing an advance when the `elapsedSeconds` is zero.
- Fixes a potential crash in Android when a native pointer is no longer valid
- Fixed a crash when shutting down on Windows
- Fixed deleting the wrong texture from the wrong WebGL context

## 0.0.9

- Updates the Rive C++ runtime and renderer for the latest features, bug fixes, and performance improvements.

### Fixes

- Add missing `pointerExit` event logic.
- Fixed [507](https://github.com/rive-app/rive-flutter/issues/507) - Tests fail on Linux and Windows as native libs are not discoverable.
- Fixed incorrect key forwarding to child widgets.

## 0.0.8

- Expose `width` and `height` getters for `ImageAsset`. See issue [501](https://github.com/rive-app/rive-flutter/issues/501). This is only exposed to support older workflows. We now recommend using [Data Binding images](https://rive.app/docs/runtimes/data-binding#images). You can also alternatively expose the width and height of the component through data binding and listen to changes.

### Fixes

- Fixed a memory leak when listening to Rive Events that had Audio events. See issue [494](https://github.com/rive-app/rive-flutter/issues/494)
- Fixed a memory issue on WASM where large .riv files could invalidate our backing TypedArray views. This fix recreates these views if they are detached. See: https://github.com/emscripten-core/emscripten/issues/7294

## 0.0.7

- Updates the Rive C++ runtime and renderer for the latest bug fixes and performance improvements.

### Fixes

- Fixed running out of GL contexts by recycling HTML canvases
- Fixed an issue on Web (Rive Renderer) where certain graphics would settle (pause) too soon when exiting a settled state.
- Fixed an issue where the state machine would settle/pause too soon when resizing the widget (or native window) and when re entering from a backgrounded state (Android). See issue [496](https://github.com/rive-app/rive-flutter/issues/496)

### Build & Platform Updates

- Linux: Initial Linux support (Flutter renderer).
- Fixed testing libraries not available when using `rive_native` as a Pub package. `rive_native` now copies the native libraries to the local app `build` directory.

## 0.0.6

- Updates the Rive C++ runtime and renderer for the latest bug fixes and performance improvements.

### Fixes

- A dual mutex deadlock on iOS/macOS during window/texture resizing under certain conditions.
- An issue where the Rive Renderer requests a repaint on a disposed render object.

## 0.0.5

### Fixes

- Fixed a crash on iOS for the Flutter renderer on cleanup.

## 0.0.4

- Updates the Rive C++ runtime and renderer for the latest bug fixes and performance improvements.

### New Features

- **Data binding artboards**:
  You can now data bind artboards and update them programatically. Access a `ViewModelInstanceArtboard` by its path using `artboard(String path)` on a view model instance. To update, set the `value` by passing in a `BindableArtboard`. Create a `BindableArtboard` from a Rive file: `riveFile.artboardToBind(String name)` See the [runtime](https://rive.app/docs/runtimes/data-binding) docs for data binding artboards.
- **Detect Rive Renderer support**:
  You can now detect Rive Renderer support by doing `Factory.rive.isSupported` after `RiveNative.init()`.

### Fixes

- Fixed a crash when using the Flutter renderer.
- Allow Rive Native to still work even if the Rive Renderer context does not initialize.

## 0.0.3

- Updates the Rive C++ runtime and renderer for the latest bug fixes and performance improvements.

### New Features

- **Data binding lists**:
  You can now get a list property on a `ViewModelInstance` by its path using `list(String path)`. On this property you can perform common list operations, such as, `add`/`remove`/`insert`. See [Editor](https://rive.app/docs/editor/data-binding/lists) and [runtime](https://rive.app/docs/runtimes/data-binding) docs for data binding lists.

### Fixes

- Fixed a crash on Android when backgrounding the app using the Rive Renderer. See issue [481](https://github.com/rive-app/rive-flutter/issues/481).

### Build & Platform Updates

- Android: add `x86`/`x86_64` arch support.
- Android: support 16 KB page sizes, see issue [479](https://github.com/rive-app/rive-flutter/issues/479).
- Android: bump `compileSdk` from 34 to 35.

## 0.0.2

- Updates the Rive C++ runtime and renderer for the latest bug fixes and performance improvements.

### New Features

- **Data binding images:**  
  You can now get an image property on a `ViewModelInstance` by its path using `image(String path)`, and set its `value`.
  - Use `Factory.rive.decodeImage` or `Factory.flutter.decodeImage` to create a `RenderImage`.
  - Set the `value` to `null` to clear the image and free up resources.
- Exposes the `name` string getter on `Artboad`, `Animation`, and `StateMachine`

### Fixes

- Fixed a build issue when creating an Android AAR module. `rive_native` now accounts for the `plugins_build_output` directory when running the build scripts.
- Fixed an issue where Pub would remove a required Makefile during package publishing. The Makefile is necessary for manually building `rive_native` libraries using `dart run rive_native:setup --build`.

## 0.0.1

- Updates the Rive C++ runtime and renderer for the latest bug fixes and performance improvements.

### Fixes

- Fixed a build issue when building directly from Xcode for iOS and macOS.
- Various rendering and runtime fixes.

## 0.0.1-dev.8

### New Features

- Data binding 🚀. See the [data binding documentation](https://rive.app/docs/runtimes/data-binding) and the updated example app for more info.

### Fixes

- Platform dependent CMakeList.txt instructions. Fixes Android and Windows rive_native setup for certain Windows environments. See issue [471](https://github.com/rive-app/rive-flutter/issues/471)
- Support for [Workspaces](https://dart.dev/tools/pub/workspaces) in `rive_native:setup`, see issue [467](https://github.com/rive-app/rive-flutter/issues/467). Thanks [tpucci](https://github.com/tpucci) for the contribution.
- Textures now use pre-multiplied alpha, which may fix dark edges around alpha textures [ad7c295](https://github.com/rive-app/rive-android/commit/ad7c29530cbeb7f7f1575e236f584dfc7ccd7de9)
- Fixed an OpenGL buffer race condition [b001b21](https://github.com/rive-app/rive-android/commit/b001b2144aa765db1926360f34c16ece913c3756)

## 0.0.1-dev.7

### New Features

- Initial support for text follow path (early access)

### Fixes

- Lates Rive Runtime and Renderer fixes and improvements
  - Fixes rendering glitches on certain device hardware
- **Android and Windows building**: Fixed executing the download scripts from the wrong path in `CMakeLists.txt`. See issue [460](https://github.com/rive-app/rive-flutter/issues/460), Dart does not allow executing `pub` commands from the pub cache directory.
- **iOS and macOS build flavor support**: Fixed an issue where rive_native could not build when using Flutter flavors, see issue [460](https://github.com/rive-app/rive-flutter/issues/460).
- **Reduce Pub package size and fix building**: Reduce dependencies included when publishing to Pub, and fix manual library building

## 0.0.1-dev.6

### New Features

- **Android Support**: Added support for Android (arm, arm64) with Rive Renderer and Flutter Renderer (Skia/Impeller).
- **iOS Emulator Support**: Added support for running on iOS emulators.
- **Layout Support**: Introduced [Layout](https://rive.app/docs/editor/layouts/layouts-overview) support.
- **Scrolling Support**: Added [Scrolling](https://rive.app/docs/editor/layouts/scrolling) support.
- **N-Slicing Support**: Added [N-Slicing](https://rive.app/docs/editor/layouts/n-slicing) support.
- **Feathering**: Added support for Feathering.
- **Nested Inputs**: Added [nested inputs](https://rive.app/docs/runtimes/state-machines#nested-inputs) accessible via the optional `path` parameter in `StateMachine.number`, `StateMachine.boolean`, and `StateMachine.trigger`.
- **Nested Text Runs**: Added support for [nested text runs](https://rive.app/docs/runtimes/text#read%2Fupdate-nested-text-runs-at-runtime), accessible via the optional `path` parameter in `artboard.getText(textRunName, path: path)`.
- **Text Run Setters**: Added setters for [text runs](https://rive.app/docs/runtimes/text) (including nested text runs) using `artboard.setText(textRunName, updatedValue, path: path)`.
- **Rive Events**: Added support for [Rive Events](https://rive.app/docs/runtimes/rive-events).
- **Out-of-Band Assets**: Added support for [out-of-band assets](https://rive.app/docs/runtimes/loading-assets).
- **Procedural Rendering**: Introduced `RiveProceduralRenderingWidget` and `ProceduralPainter`.

### Fixes

- **Windows Build Scripts**: Fixed build scripts for Windows.
- **Latest Rive C++ runtime**: Updates to the latest core runtime with various improvements and fixes.

### Breaking Changes

- **StateMachinePainter**: `StateMachinePainter` and `RivePainter.stateMachine` no longer require a `stateMachineName` parameter. It is now optional. If `null`, the default state machine will be used.
- **Rive Widgets**: `RiveArtboardWidget` and `RiveFileWidget` now require a `RivePainter`.

---

## 0.0.1-dev.5

- Initial prerelease 🎉
