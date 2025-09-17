import 'dart:js_interop' as js;
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:meta/meta.dart';
import 'package:rive_native/rive_audio.dart';
import 'package:rive_native/rive_native.dart';
import 'package:rive_native/src/errors.dart';
import 'package:rive_native/src/rive_native_web.dart';
import 'package:rive_native/src/web/flutter_renderer_web.dart';
import 'package:rive_native/src/web/rive_audio_web.dart';
import 'package:rive_native/src/web/rive_renderer_web.dart';
import 'package:rive_native/src/web/rive_text_web.dart';

/// Load a list of bytes from a file on the local filesystem at [path].
Future<Uint8List?> localFileBytes(String path) =>
    throw UnsupportedError('Cannot load from a local file on the web.');

/// Helper function to convert a JS object to a Dart list of [ViewModelProperty].
List<ViewModelProperty> _parseViewModelProperties(js.JSObject result) {
  final properties = <ViewModelProperty>[];

  final length = (result.getProperty('length'.toJS) as js.JSNumber).toDartInt;
  for (int i = 0; i < length; i++) {
    final jsProp = result.getProperty(i.toJS) as js.JSObject;

    final name = (jsProp.getProperty('name'.toJS) as js.JSString).toDart;
    final type = (jsProp.getProperty('type'.toJS) as js.JSNumber).toDartInt;

    properties.add(ViewModelProperty(name, DataType.values[type]));
  }
  return properties;
}

class _WebAssetLoaderCallable {
  final AssetLoaderCallback assetLoader;
  final Factory riveFactory;
  late bool Function(int, int?, int) webLoader;

  _WebAssetLoaderCallable(this.assetLoader, this.riveFactory) {
    webLoader = (int assetPointer, int? bytesPointer, int size) {
      final dartBytes =
          bytesPointer != null ? _wasmHeapUint8(bytesPointer, size) : null;
      final assetType = (RiveWasm.riveFileAssetCoreType
              .callAsFunction(null, assetPointer.toJS) as js.JSNumber)
          .toDartInt;

      FileAsset fileAsset = switch (assetType) {
        ImageAsset.coreType => WebImageAsset(assetPointer, riveFactory),
        FontAsset.coreType => WebFontAsset(assetPointer, riveFactory),
        AudioAsset.coreType => WebAudioAsset(assetPointer, riveFactory),
        _ => WebUnknownAsset(assetPointer, riveFactory)
      };

      return assetLoader(fileAsset, dartBytes);
    };
  }

  static Uint8List _wasmHeapUint8(int ptr, int length) =>
      RiveWasm.heap(ptr, length);
}

Future<File?> decodeRiveFile(
  Uint8List bytes,
  Factory riveFactory, {
  AssetLoaderCallback? assetLoader,
}) async {
  final wasmBuffer = WasmBuffer.fromBytes(bytes);
  _WebAssetLoaderCallable? assetLoaderCallable = assetLoader != null
      ? _WebAssetLoaderCallable(assetLoader, riveFactory)
      : null;

  final result = (RiveWasm.loadRiveFile.callAsFunction(
    null,
    wasmBuffer.pointer,
    wasmBuffer.data.length.toJS,
    (riveFactory as WebFactory).pointer,
    (assetLoaderCallable != null) ? assetLoaderCallable.webLoader.toJS : null,
  ) as js.JSNumber)
      .toDartInt;
  wasmBuffer.dispose();
  await riveFactory.completedDecodingFile(result != 0);
  assetLoaderCallable = null;
  if (result == 0) {
    return null;
  }
  return WebRiveFile(result, riveFactory);
}

void batchAdvanceStateMachines(
    Iterable<StateMachine> stateMachines, double elapsedSeconds) {}

void batchAdvanceAndRenderStateMachines(Iterable<StateMachine> stateMachines,
    double elapsedSeconds, Renderer renderer) {}

abstract class WebFactory extends Factory {
  js.JSAny pointer;
  WebFactory(this.pointer);

  @override
  RenderPath makePath([bool initEmpty = false]) =>
      WebRenderPath(this, initEmpty);

  @override
  RenderPaint makePaint() => WebRenderPaint(this);

  @override
  RenderText makeText() => WebRenderText(this);

  @override
  IndexRenderBuffer? makeIndexBuffer(int elementCount) {
    if (elementCount <= 0) {
      return null;
    }
    return WebIndexRenderBuffer(this, elementCount);
  }

  @override
  VertexRenderBuffer? makeVertexBuffer(int elementCount) {
    if (elementCount <= 0) {
      return null;
    }
    return WebVertexRenderBuffer(this, elementCount);
  }

  @override
  Future<RenderImage?> decodeImage(Uint8List bytes) async {
    var imagePointer = RiveWasm.decodeImage
        .callAsFunction(null, pointer, bytes.toJS) as js.JSAny;
    return WebRenderImage(imagePointer);
  }

  @override
  Future<Font?> decodeFont(Uint8List bytes) async => Font.decode(bytes);

  @override
  Future<AudioSource?> decodeAudio(Uint8List bytes) async =>
      AudioEngine.loadSource(bytes);
}

Factory getRiveFactory() => WebRiveFactory.instance;

Factory getFlutterFactory() => WebFlutterFactory.instance;

int toPointer(js.JSAny? any) => (any as js.JSNumber).toDartInt;

sealed class WebFileAsset implements FileAssetInterface {
  final int _pointer;
  final Factory _riveFactory;
  int get pointer => _pointer;

  WebFileAsset(this._pointer, this._riveFactory);

  @override
  int get assetId =>
      (RiveWasm.riveFileAssetId.callAsFunction(null, pointer.toJS)
              as js.JSNumber)
          .toDartInt;

  @override
  String get cdnBaseUrl => RiveWasm.toDartString(
      (RiveWasm.riveFileAssetCdnBaseUrl.callAsFunction(null, pointer.toJS)
              as js.JSNumber)
          .toDartInt);

  @override
  String get cdnUuid => RiveWasm.toDartString(
      (RiveWasm.riveFileAssetCdnUuid.callAsFunction(null, pointer.toJS)
              as js.JSNumber)
          .toDartInt,
      deleteNative: true);

  @override
  String get fileExtension => RiveWasm.toDartString(
      (RiveWasm.riveFileAssetFileExtension.callAsFunction(null, pointer.toJS)
              as js.JSNumber)
          .toDartInt,
      deleteNative: true);

  @override
  String get name => RiveWasm.toDartString((RiveWasm.riveFileAssetName
          .callAsFunction(null, pointer.toJS) as js.JSNumber)
      .toDartInt);

  @override
  Factory get riveFactory => _riveFactory;
}

class WebImageAsset extends WebFileAsset implements ImageAsset {
  WebImageAsset(super.pointer, super._riveFactory);

  @override
  double get width =>
      (RiveWasm.imageAssetGetWidth.callAsFunction(null, pointer.toJS)
              as js.JSNumber)
          .toDartDouble;

  @override
  double get height =>
      (RiveWasm.imageAssetGetHeight.callAsFunction(null, pointer.toJS)
              as js.JSNumber)
          .toDartDouble;

  @override
  bool renderImage(RenderImage renderImage) =>
      _wasmBool(RiveWasm.riveFileAssetSetRenderImage.callAsFunction(
        null,
        pointer.toJS,
        (renderImage as WebRenderImage).pointer,
      ));

  @override
  Future<bool> decode(Uint8List bytes) async {
    final decodedImage = await riveFactory.decodeImage(bytes);
    if (decodedImage == null) {
      return false;
    }
    return renderImage(decodedImage);
  }
}

class WebFontAsset extends WebFileAsset implements FontAsset {
  WebFontAsset(super.pointer, super._riveFactory);

  @override
  bool font(Font font) =>
      _wasmBool(RiveWasm.riveFileAssetSetFont.callAsFunction(
        null,
        pointer.toJS,
        (font as FontWasm).fontPtr.toJS,
      ));

  @override
  Future<bool> decode(Uint8List bytes) async {
    final decodedFont = await riveFactory.decodeFont(bytes);
    if (decodedFont == null) {
      return false;
    }
    return font(decodedFont);
  }
}

class WebAudioAsset extends WebFileAsset implements AudioAsset {
  WebAudioAsset(super.pointer, super._riveFactory);

  @override
  bool audio(AudioSource audioSource) =>
      _wasmBool(RiveWasm.riveFileAssetSetAudioSource.callAsFunction(
        null,
        pointer.toJS,
        (audioSource as AudioSourceWasm).nativePtr.toJS,
      ));

  @override
  Future<bool> decode(Uint8List bytes) async {
    final decodedAudio = await riveFactory.decodeAudio(bytes);
    if (decodedAudio == null) {
      return false;
    }
    return audio(decodedAudio);
  }
}

class WebUnknownAsset extends WebFileAsset implements UnknownAsset {
  WebUnknownAsset(super.pointer, super._riveFactory);

  @override
  Future<bool> decode(Uint8List bytes) async {
    return false; // nothing to decode
  }
}

class WebRiveFile extends File {
  final Factory riveFactory;
  static final _finalizer = Finalizer((js.JSAny pointer) =>
      RiveWasm.deleteRiveFile.callAsFunction(null, pointer));
  int _pointer;

  static final _instances = <int, InternalViewModelInstanceValue?>{};

  @internal
  static void internalRegisterViewModelInstance(
      int ptr, InternalViewModelInstanceValue vmi) {
    _instances[ptr] = vmi;
  }

  @internal
  static void internalUnregisterViewModelInstance(int ptr) {
    _instances[ptr] = null;
  }

  static void _vmNumberCallback(int ptr, double value) {
    InternalViewModelInstanceValue? vmi = _instances[ptr];
    if (vmi is WebInternalViewModelInstanceNumber) {
      vmi.nativeValue = value;
    }
  }

  static void _vmBooleanCallback(int ptr, bool value) {
    InternalViewModelInstanceValue? vmi = _instances[ptr];
    if (vmi is WebInternalViewModelInstanceBoolean) {
      vmi.nativeValue = value;
    }
  }

  static void _vmColorCallback(int ptr, int value) {
    InternalViewModelInstanceValue? vmi = _instances[ptr];
    if (vmi is WebInternalViewModelInstanceColor) {
      vmi.nativeValue = value;
    }
  }

  static void _vmStringCallback(int ptr, String value) {
    InternalViewModelInstanceValue? vmi = _instances[ptr];
    if (vmi is WebInternalViewModelInstanceString) {
      vmi.nativeValue = value;
    }
  }

  static void _vmTriggerCallback(int ptr, int value) {
    InternalViewModelInstanceValue? vmi = _instances[ptr];
    if (vmi is WebInternalViewModelInstanceTrigger) {
      vmi.nativeValue = value;
    }
  }

  static void _vmEnumCallback(int ptr, int value) {
    InternalViewModelInstanceValue? vmi = _instances[ptr];
    if (vmi is WebInternalViewModelInstanceEnum) {
      vmi.nativeValue = value;
    }
  }

  static void _vmSymbolListIndexCallback(int ptr, int value) {
    InternalViewModelInstanceValue? vmi = _instances[ptr];
    if (vmi is WebInternalViewModelInstanceSymbolListIndex) {
      vmi.nativeValue = value;
    }
  }

  static void _vmAssetCallback(int ptr, int value) {
    InternalViewModelInstanceValue? vmi = _instances[ptr];
    if (vmi is WebInternalViewModelInstanceAsset) {
      vmi.nativeValue = value;
    }
  }

  static void _vmArtboardCallback(int ptr, int value) {
    InternalViewModelInstanceValue? vmi = _instances[ptr];
    if (vmi is WebInternalViewModelInstanceAsset) {
      vmi.nativeValue = value;
    }
  }

  WebRiveFile(this._pointer, this.riveFactory) {
    _finalizer.attach(this, _pointer.toJS, detach: this);
    RiveWasm.initBindingCallbacks.callAsFunctionEx(
      null,
      _vmNumberCallback.toJS,
      _vmBooleanCallback.toJS,
      _vmColorCallback.toJS,
      _vmStringCallback.toJS,
      _vmTriggerCallback.toJS,
      _vmEnumCallback.toJS,
      _vmSymbolListIndexCallback.toJS,
      _vmAssetCallback.toJS,
      _vmArtboardCallback.toJS,
    );
  }

  @override
  void dispose() {
    if (_pointer == 0) {
      return;
    }
    _finalizer.detach(this);
    RiveWasm.deleteRiveFile.callAsFunction(null, _pointer.toJS);
    _pointer = 0;
  }

  @override
  Artboard? artboard(String name, {bool frameOrigin = true}) =>
      RiveWasm.toNativeString(name, (namePointer) {
        final ptr = toPointer(RiveWasm.riveFileArtboardNamed.callAsFunction(
            null, _pointer.toJS, namePointer, _boolWasm(frameOrigin)));
        if (ptr == 0) {
          return null;
        }
        return WebRiveArtboard(ptr, riveFactory);
      });

  @override
  Artboard? artboardAt(int index, {bool frameOrigin = true}) {
    var ptr = toPointer(RiveWasm.riveFileArtboardByIndex.callAsFunction(
        null, _pointer.toJS, index.toJS, _boolWasm(frameOrigin)));
    if (ptr == 0) {
      return null;
    }
    return WebRiveArtboard(ptr, riveFactory);
  }

  @override
  Artboard? defaultArtboard({bool frameOrigin = true}) {
    var ptr = toPointer(RiveWasm.riveFileArtboardDefault
        .callAsFunction(null, _pointer.toJS, _boolWasm(frameOrigin)));
    if (ptr == 0) {
      return null;
    }
    return WebRiveArtboard(ptr, riveFactory);
  }

  @override
  BindableArtboard? artboardToBind(String name) =>
      RiveWasm.toNativeString(name, (namePointer) {
        final ptr = toPointer(RiveWasm.riveFileArtboardToBindNamed
            .callAsFunction(null, _pointer.toJS, namePointer));
        if (ptr == 0) {
          return null;
        }
        return WebBindableArtboard(ptr);
      });

  @override
  InternalDataContext? internalDataContext(
      int viewModelIndex, int instanceIndex) {
    var ptr = toPointer(RiveWasm.riveDataContext.callAsFunction(
        null, _pointer.toJS, viewModelIndex.toJS, instanceIndex.toJS));
    if (ptr == 0) {
      return null;
    }
    return WebRiveDataContext(ptr);
  }

  @override
  InternalViewModelInstance? copyViewModelInstance(
      int viewModelIndex, int instanceIndex) {
    var ptr = toPointer(RiveWasm.copyViewModelInstance.callAsFunction(
        null, _pointer.toJS, viewModelIndex.toJS, instanceIndex.toJS));
    if (ptr == 0) {
      return null;
    }
    return WebRiveInternalViewModelInstance(ptr);
  }

  @override
  int get viewModelCount =>
      (RiveWasm.riveFileViewModelCount.callAsFunction(null, _pointer.toJS)
              as js.JSNumber)
          .toDartInt;

  @override
  ViewModel? viewModelByIndex(int index) {
    var ptr = toPointer(RiveWasm.riveFileViewModelRuntimeByIndex
        .callAsFunction(null, _pointer.toJS, index.toJS));
    if (ptr == 0) {
      return null;
    }
    return WebViewModelRuntime(ptr);
  }

  @override
  ViewModel? viewModelByName(String name) => RiveWasm.toNativeString(
        name,
        (namePointer) {
          final ptr = toPointer(RiveWasm.riveFileViewModelRuntimeByName
              .callAsFunction(null, _pointer.toJS, namePointer));
          if (ptr == 0) {
            return null;
          }
          return WebViewModelRuntime(ptr);
        },
      );

  @override
  ViewModel? defaultArtboardViewModel(Artboard artboard) {
    var ptr = toPointer(RiveWasm.riveFileDefaultArtboardViewModelRuntime
        .callAsFunction(
            null, _pointer.toJS, (artboard as WebRiveArtboard).pointer.toJS));
    if (ptr == 0) {
      return null;
    }
    return WebViewModelRuntime(ptr);
  }

  @override
  List<DataEnum> get enums {
    final result =
        RiveWasm.fileEnums.callAsFunction(null, _pointer.toJS) as js.JSObject;
    final dataEnums = <DataEnum>[];
    final length = (result.getProperty('length'.toJS) as js.JSNumber).toDartInt;
    for (int i = 0; i < length; i++) {
      final jsProp = result.getProperty(i.toJS) as js.JSObject;
      final name = (jsProp.getProperty('name'.toJS) as js.JSString).toDart;
      final values = (jsProp.getProperty('values'.toJS) as js.JSArray)
          .toDart
          .cast<String>();
      dataEnums.add(DataEnum(name, values));
    }
    return dataEnums;
  }
}

class WebViewModelRuntime implements ViewModel {
  int get pointer => _pointer;
  int _pointer;

  static final _finalizer = Finalizer(
    (js.JSAny pointer) =>
        RiveWasm.deleteViewModelRuntime.callAsFunction(null, pointer),
  );

  WebViewModelRuntime(this._pointer) {
    _finalizer.attach(this, _pointer.toJS, detach: this);
  }

  @override
  int get propertyCount => (RiveWasm.viewModelRuntimePropertyCount
          .callAsFunction(null, _pointer.toJS) as js.JSNumber)
      .toDartInt;

  @override
  int get instanceCount => (RiveWasm.viewModelRuntimeInstanceCount
          .callAsFunction(null, _pointer.toJS) as js.JSNumber)
      .toDartInt;

  @override
  String get name {
    final stringPointer = (RiveWasm.viewModelRuntimeName
            .callAsFunction(null, _pointer.toJS) as js.JSNumber)
        .toDartInt;
    if (stringPointer == 0) {
      return '';
    }
    return RiveWasm.toDartString(stringPointer);
  }

  @override
  List<ViewModelProperty> get properties {
    final result = RiveWasm.viewModelRuntimeProperties
        .callAsFunction(null, pointer.toJS) as js.JSObject;
    return _parseViewModelProperties(result);
  }

  @override
  ViewModelInstance? createInstanceByIndex(int index) {
    final ptr = toPointer(RiveWasm.createVMIRuntimeFromIndex
        .callAsFunction(null, _pointer.toJS, index.toJS));
    if (ptr == 0) {
      return null;
    }
    return WebViewModelInstanceRuntime(ptr);
  }

  @override
  ViewModelInstance? createInstanceByName(String name) =>
      RiveWasm.toNativeString(
        name,
        (namePointer) {
          var ptr = toPointer(RiveWasm.createVMIRuntimeFromName
              .callAsFunction(null, _pointer.toJS, namePointer));

          if (ptr == 0) {
            return null;
          }
          return WebViewModelInstanceRuntime(ptr);
        },
      );

  @override
  ViewModelInstance? createDefaultInstance() {
    var ptr = toPointer(
        RiveWasm.createDefaultVMIRuntime.callAsFunction(null, _pointer.toJS));
    if (ptr == 0) {
      return null;
    }
    return WebViewModelInstanceRuntime(ptr);
  }

  @override
  ViewModelInstance? createInstance() {
    var ptr = toPointer(
        RiveWasm.createVMIRuntime.callAsFunction(null, _pointer.toJS));
    if (ptr == 0) {
      return null;
    }
    return WebViewModelInstanceRuntime(ptr);
  }

  @override
  void dispose() {
    if (_pointer == 0) {
      return;
    }
    var pointer = _pointer;
    _pointer = 0;
    _finalizer.detach(this);
    RiveWasm.deleteViewModelRuntime.callAsFunction(null, pointer.toJS);
  }
}

class WebViewModelInstanceRuntime
    with ViewModelInstanceCallbackMixin
    implements ViewModelInstance {
  int get pointer => _pointer;
  int _pointer;

  late WebViewModelInstanceRuntime _rootViewModelInstance;

  static final _finalizer = Finalizer(
    (js.JSAny pointer) =>
        RiveWasm.deleteVMIRuntime.callAsFunction(null, pointer),
  );

  WebViewModelInstanceRuntime(
    this._pointer, {
    WebViewModelInstanceRuntime? rootViewModelInstance,
  }) {
    _finalizer.attach(this, _pointer.toJS, detach: this);

    if (rootViewModelInstance == null) {
      _rootViewModelInstance = this;
    } else {
      _rootViewModelInstance = rootViewModelInstance;
    }
  }

  int _findPointerByPath(String path, js.JSFunction function) =>
      RiveWasm.toNativeString(
        path,
        (pathPointer) {
          final ptr = toPointer(
              function.callAsFunction(null, _pointer.toJS, pathPointer));

          return ptr;
        },
      );

  @override
  String get name {
    final stringPointer = (RiveWasm.vmiRuntimeName
            .callAsFunction(null, _pointer.toJS) as js.JSNumber)
        .toDartInt;
    if (stringPointer == 0) {
      return '';
    }
    return RiveWasm.toDartString(stringPointer);
  }

  @override
  List<ViewModelProperty> get properties {
    final result = RiveWasm.vmiRuntimeProperties
        .callAsFunction(null, pointer.toJS) as js.JSObject;
    return _parseViewModelProperties(result);
  }

  @override
  ViewModelInstanceNumber? number(String path) {
    var ptr = _findPointerByPath(path, RiveWasm.vmiRuntimeGetNumberProperty);
    if (ptr == 0) {
      return null;
    }
    return WebViewModelInstanceNumberRuntime(ptr, _rootViewModelInstance);
  }

  @override
  ViewModelInstanceString? string(String path) {
    var ptr = _findPointerByPath(path, RiveWasm.vmiRuntimeGetStringProperty);
    if (ptr == 0) {
      return null;
    }
    return WebViewModelInstanceStringRuntime(ptr, _rootViewModelInstance);
  }

  @override
  ViewModelInstanceBoolean? boolean(String path) {
    var ptr = _findPointerByPath(path, RiveWasm.vmiRuntimeGetBooleanProperty);
    if (ptr == 0) {
      return null;
    }
    return WebViewModelInstanceBooleanRuntime(ptr, _rootViewModelInstance);
  }

  @override
  ViewModelInstanceColor? color(String path) {
    var ptr = _findPointerByPath(path, RiveWasm.vmiRuntimeGetColorProperty);
    if (ptr == 0) {
      return null;
    }
    return WebViewModelInstanceColorRuntime(ptr, _rootViewModelInstance);
  }

  @override
  ViewModelInstanceEnum? enumerator(String path) {
    var ptr = _findPointerByPath(path, RiveWasm.vmiRuntimeGetEnumProperty);
    if (ptr == 0) {
      return null;
    }
    return WebViewModelInstanceEnumRuntime(ptr, _rootViewModelInstance);
  }

  @override
  ViewModelInstanceTrigger? trigger(String path) {
    var ptr = _findPointerByPath(path, RiveWasm.vmiRuntimeGetTriggerProperty);
    if (ptr == 0) {
      return null;
    }
    return WebViewModelInstanceTriggerRuntime(ptr, _rootViewModelInstance);
  }

  @override
  ViewModelInstanceAssetImage? image(String path) {
    var ptr =
        _findPointerByPath(path, RiveWasm.vmiRuntimeGetAssetImageProperty);
    if (ptr == 0) {
      return null;
    }
    return WebViewModelInstanceAssetImageRuntime(ptr, _rootViewModelInstance);
  }

  @override
  ViewModelInstance? viewModel(String path) {
    var ptr = _findPointerByPath(path, RiveWasm.vmiRuntimeGetViewModelProperty);
    if (ptr == 0) {
      return null;
    }
    return WebViewModelInstanceRuntime(
      ptr,
      rootViewModelInstance: _rootViewModelInstance,
    );
  }

  @override
  ViewModelInstanceList? list(String path) {
    var ptr = _findPointerByPath(path, RiveWasm.vmiRuntimeGetListProperty);
    if (ptr == 0) {
      return null;
    }
    return WebViewModelInstanceListRuntime(ptr, _rootViewModelInstance);
  }

  @override
  ViewModelInstanceArtboard? artboard(String path) {
    final ptr =
        _findPointerByPath(path, RiveWasm.vmiRuntimeGetArtboardProperty);
    if (ptr == 0) {
      return null;
    }
    return WebViewModelInstanceArtboardRuntime(ptr, _rootViewModelInstance);
  }

  @override
  void dispose() {
    clearCallbacks();

    if (_pointer == 0) {
      return;
    }
    var pointer = _pointer;
    _pointer = 0;
    _finalizer.detach(this);
    RiveWasm.deleteVMIRuntime.callAsFunction(null, pointer.toJS);
  }

  @override
  bool get isDisposed => _pointer == 0;
}

abstract class WebViewModelInstanceValueRuntime
    implements ViewModelInstanceValue {
  int get pointer => _pointer;
  int _pointer;

  static final _finalizer = Finalizer(
    (js.JSAny pointer) =>
        RiveWasm.deleteVMIValueRuntime.callAsFunction(null, pointer),
  );

  final ViewModelInstance _rootViewModelInstance;

  @override
  ViewModelInstance get rootViewModelInstance => _rootViewModelInstance;

  WebViewModelInstanceValueRuntime(this._pointer, this._rootViewModelInstance) {
    _finalizer.attach(this, _pointer.toJS, detach: this);
  }

  @override
  void dispose() {
    if (_pointer == 0) {
      return;
    }
    var pointer = _pointer;
    _pointer = 0;
    _finalizer.detach(this);
    RiveWasm.deleteVMIValueRuntime.callAsFunction(null, pointer.toJS);
  }
}

abstract class WebViewModelInstanceObservableValueRuntime<T>
    extends WebViewModelInstanceValueRuntime
    with ViewModelInstanceObservableValueMixin<T> {
  WebViewModelInstanceObservableValueRuntime(
    super._pointer,
    super._rootViewModelInstance,
  );

  @override
  bool get hasChanged => _wasmBool(
      RiveWasm.vmiValueRuntimeHasChanged.callAsFunction(null, pointer.toJS));

  @override
  void clearChanges() =>
      RiveWasm.vmiValueRuntimeClearChanges.callAsFunction(null, pointer.toJS);

  @override
  void dispose() {
    clearListeners();
    super.dispose();
  }
}

class WebViewModelInstanceNumberRuntime
    extends WebViewModelInstanceObservableValueRuntime<double>
    implements ViewModelInstanceNumber {
  WebViewModelInstanceNumberRuntime(
    super._pointer,
    super._rootViewModelInstance,
  );

  @override
  double get nativeValue =>
      (RiveWasm.getVMINumberRuntimeValue.callAsFunction(null, pointer.toJS)
              as js.JSNumber)
          .toDartDouble;

  @override
  set nativeValue(double value) => RiveWasm.setVMINumberRuntimeValue
      .callAsFunction(null, pointer.toJS, value.toJS);
}

class WebViewModelInstanceStringRuntime
    extends WebViewModelInstanceObservableValueRuntime<String>
    implements ViewModelInstanceString {
  WebViewModelInstanceStringRuntime(
    super._pointer,
    super._rootViewModelInstance,
  );

  @override
  String get nativeValue {
    var stringPointer = (RiveWasm.getVMIStringRuntimeValue
            .callAsFunction(null, pointer.toJS) as js.JSNumber)
        .toDartInt;
    if (stringPointer == 0) {
      return '';
    }
    return RiveWasm.toDartString(stringPointer);
  }

  @override
  set nativeValue(String value) => RiveWasm.toNativeString(
        value,
        (valuePointer) {
          RiveWasm.setVMIStringRuntimeValue
              .callAsFunction(null, _pointer.toJS, valuePointer);
        },
      );
}

class WebViewModelInstanceBooleanRuntime
    extends WebViewModelInstanceObservableValueRuntime<bool>
    implements ViewModelInstanceBoolean {
  WebViewModelInstanceBooleanRuntime(
    super._pointer,
    super._rootViewModelInstance,
  );

  @override
  bool get nativeValue => _wasmBool(
      RiveWasm.getVMIBooleanRuntimeValue.callAsFunction(null, pointer.toJS));

  @override
  set nativeValue(bool value) => RiveWasm.setVMIBooleanRuntimeValue
      .callAsFunction(null, pointer.toJS, value.toJS);
}

class WebViewModelInstanceColorRuntime
    extends WebViewModelInstanceObservableValueRuntime<Color>
    implements ViewModelInstanceColor {
  WebViewModelInstanceColorRuntime(
    super._pointer,
    super._rootViewModelInstance,
  );

  @override
  Color get nativeValue {
    final color = (RiveWasm.getVMIColorRuntimeValue
            .callAsFunction(null, pointer.toJS) as js.JSNumber)
        .toDartInt;
    return Color(color);
  }

  @override
  set nativeValue(Color value) => RiveWasm.setVMIColorRuntimeValue
      // ignore: deprecated_member_use
      .callAsFunction(null, pointer.toJS, value.value.toJS);
}

class WebViewModelInstanceEnumRuntime
    extends WebViewModelInstanceObservableValueRuntime<String>
    implements ViewModelInstanceEnum {
  WebViewModelInstanceEnumRuntime(
    super._pointer,
    super._rootViewModelInstance,
  );

  @override
  String get nativeValue => RiveWasm.toDartString(
      (RiveWasm.getVMIEnumRuntimeValue.callAsFunction(null, pointer.toJS)
              as js.JSNumber)
          .toDartInt,
      deleteNative: true);

  @override
  set nativeValue(String value) => RiveWasm.toNativeString(
        value,
        (valuePointer) {
          RiveWasm.setVMIEnumRuntimeValue
              .callAsFunction(null, _pointer.toJS, valuePointer);
        },
      );
}

class WebViewModelInstanceTriggerRuntime
    extends WebViewModelInstanceObservableValueRuntime<bool>
    implements ViewModelInstanceTrigger {
  WebViewModelInstanceTriggerRuntime(
    super._pointer,
    super._rootViewModelInstance,
  );

  @override
  void trigger() {
    RiveWasm.triggerVMITriggerRuntime.callAsFunction(null, pointer.toJS);
  }

  @override
  bool get nativeValue {
    return false;
  }

  @override
  set nativeValue(bool value) {
    if (value) {
      trigger();
    }
  }
}

class WebViewModelInstanceAssetImageRuntime
    extends WebViewModelInstanceValueRuntime
    implements ViewModelInstanceAssetImage {
  WebViewModelInstanceAssetImageRuntime(
    super._pointer,
    super._rootViewModelInstance,
  );

  @override
  set value(covariant WebRenderImage? value) {
    RiveWasm.setVMIAssetImageRuntimeValue.callAsFunction(
      null,
      _pointer.toJS,
      value?.pointer ?? 0.toJS,
    );
  }
}

class WebViewModelInstanceArtboardRuntime
    extends WebViewModelInstanceValueRuntime
    implements ViewModelInstanceArtboard {
  WebViewModelInstanceArtboardRuntime(
    super._pointer,
    super._rootViewModelInstance,
  );

  @override
  set value(covariant WebBindableArtboard value) {
    RiveWasm.setVMIArtboardRuntimeValue.callAsFunction(
      null,
      _pointer.toJS,
      value.pointer.toJS,
    );
  }
}

class WebViewModelInstanceListRuntime extends WebViewModelInstanceValueRuntime
    implements ViewModelInstanceList {
  WebViewModelInstanceListRuntime(
    super._pointer,
    super._rootViewModelInstance,
  );

  @override
  int get length =>
      (RiveWasm.getVMIListRuntimeSize.callAsFunction(null, _pointer.toJS)
              as js.JSNumber)
          .toDartInt;

  @override
  void add(covariant WebViewModelInstanceRuntime instance) =>
      RiveWasm.vmiListRuntimeAddInstance
          .callAsFunction(null, _pointer.toJS, instance.pointer.toJS);

  @override
  void remove(covariant WebViewModelInstanceRuntime instance) =>
      RiveWasm.vmiListRuntimeRemoveInstance
          .callAsFunction(null, _pointer.toJS, instance.pointer.toJS);

  @override
  bool insert(int index, covariant WebViewModelInstanceRuntime instance) {
    RangeError.checkNotNegative(index, "index");
    if (index >= length) {
      throw RangeError.range(index, 0, length - 1, "index");
    }
    return _wasmBool(RiveWasm.vmiListRuntimeAddInstanceAt.callAsFunction(
      null,
      _pointer.toJS,
      instance.pointer.toJS,
      index.toJS,
    ));
  }

  @override
  void removeAt(int index) {
    RangeError.checkNotNegative(index, "index");
    if (index >= length) {
      throw RangeError.range(index, 0, length - 1, "index");
    }
    RiveWasm.vmiListRuntimeRemoveInstanceAt
        .callAsFunction(null, _pointer.toJS, index.toJS);
  }

  @override
  ViewModelInstance instanceAt(int index) {
    RangeError.checkNotNegative(index, "index");
    if (index >= length) {
      throw RangeError.range(index, 0, length - 1, "index");
    }
    var ptr = (RiveWasm.vmiListRuntimeInstanceAt
            .callAsFunction(null, _pointer.toJS, index.toJS) as js.JSNumber)
        .toDartInt;
    if (ptr == 0) {
      throw RiveError.nullNativePointer();
    }
    return WebViewModelInstanceRuntime(ptr,
        rootViewModelInstance:
            _rootViewModelInstance as WebViewModelInstanceRuntime);
  }

  @override
  void swap(int a, int b) {
    RangeError.checkNotNegative(a, "a");
    RangeError.checkNotNegative(b, "b");
    final length = this.length;
    if (a >= length) {
      throw RangeError.range(a, 0, length - 1, "a");
    }
    if (b >= length) {
      throw RangeError.range(b, 0, length - 1, "b");
    }
    RiveWasm.vmiListRuntimeSwap
        .callAsFunction(null, _pointer.toJS, a.toJS, b.toJS);
  }

  @override
  ViewModelInstance first() => instanceAt(0);

  @override
  ViewModelInstance last() => instanceAt(length - 1);

  @override
  ViewModelInstance? firstOrNull() => length > 0 ? first() : null;

  @override
  ViewModelInstance? lastOrNull() => length > 0 ? last() : null;

  @override
  ViewModelInstance operator [](int index) => instanceAt(index);

  @override
  void operator []=(
    int index,
    covariant WebViewModelInstanceRuntime value,
  ) =>
      insert(index, value);
}

class WebRiveArtboard extends Artboard {
  @override
  final Factory riveFactory;

  static final _finalizer = Finalizer(
    (js.JSAny pointer) =>
        RiveWasm.deleteArtboardInstance.callAsFunction(null, pointer),
  );

  int get pointer => _pointer;
  int _pointer;

  WebRiveArtboard(this._pointer, this.riveFactory) {
    _finalizer.attach(this, _pointer.toJS, detach: this);
  }

  @override
  String get name => RiveWasm.toDartString(
        (RiveWasm.artboardName.callAsFunction(null, pointer.toJS)
                as js.JSNumber)
            .toDartInt,
        deleteNative: true,
      );

  @override
  void dispose() {
    if (_pointer == 0) {
      return;
    }
    var pointer = _pointer;
    _pointer = 0;
    _finalizer.detach(this);
    RiveWasm.deleteArtboardInstance.callAsFunction(null, pointer.toJS);
  }

  @override
  void draw(covariant WebRiveRenderer renderer) {
    assert(riveFactory.isValidRenderer(renderer));
    RiveWasm.artboardDraw
        .callAsFunction(null, pointer.toJS, renderer.jsRendererPtr);
  }

  @override
  void reset() {
    RiveWasm.artboardReset.callAsFunction(null, pointer.toJS);
  }

  @override
  StateMachine? defaultStateMachine() {
    var smiPointer = toPointer(RiveWasm.riveArtboardStateMachineDefault
        .callAsFunction(null, _pointer.toJS));
    if (smiPointer == 0) {
      return null;
    }
    return WebStateMachine(smiPointer);
  }

  @override
  StateMachine? stateMachine(String name) => RiveWasm.toNativeString(
        name,
        (namePointer) {
          final smiPointer = toPointer(RiveWasm.riveArtboardStateMachineNamed
              .callAsFunction(null, pointer.toJS, namePointer));

          if (smiPointer == 0) {
            return null;
          }
          return WebStateMachine(smiPointer);
        },
      );

  @override
  StateMachine? stateMachineAt(int index) =>
      WebStateMachine((RiveWasm.riveArtboardStateMachineAt
              .callAsFunction(null, pointer.toJS, index.toJS) as js.JSNumber)
          .toDartInt);

  @override
  AABB get bounds {
    RiveWasm.artboardBounds
        .callAsFunction(null, pointer.toJS, RiveWasm.scratchBufferPtr);
    final floats = RiveWasm.scratchBufferFloat;

    return AABB.fromValues(floats[0], floats[1], floats[2], floats[3]);
  }

  @override
  AABB get worldBounds {
    RiveWasm.artboardWorldBounds
        .callAsFunction(null, pointer.toJS, RiveWasm.scratchBufferPtr);
    final floats = RiveWasm.scratchBufferFloat;

    return AABB.fromValues(floats[0], floats[1], floats[2], floats[3]);
  }

  @override
  void addToRenderPath(covariant WebRenderPath renderPath, Mat2D transform) =>
      RiveWasm.artboardAddToRenderPath.callAsFunctionEx(
        null,
        pointer.toJS,
        renderPath.pointer,
        transform[0].toJS,
        transform[1].toJS,
        transform[2].toJS,
        transform[3].toJS,
        transform[4].toJS,
        transform[5].toJS,
      );

  @override
  int animationCount() =>
      (RiveWasm.artboardAnimationCount.callAsFunction(null, pointer.toJS)
              as js.JSNumber)
          .toDartInt;

  @override
  int stateMachineCount() =>
      (RiveWasm.artboardStateMachineCount.callAsFunction(null, pointer.toJS)
              as js.JSNumber)
          .toDartInt;

  @override
  Animation animationAt(int index) {
    return WebAnimation((RiveWasm.artboardAnimationAt
            .callAsFunction(null, pointer.toJS, index.toJS) as js.JSNumber)
        .toDartInt);
  }

  @override
  Animation? animationNamed(String name) => RiveWasm.toNativeString(
        name,
        (namePointer) {
          final ptr = (RiveWasm.artboardAnimationNamed.callAsFunction(
                  null, pointer.toJS, namePointer) as js.JSNumber)
              .toDartInt;

          if (ptr == 0) {
            return null;
          }

          return WebAnimation(ptr);
        },
      );

  @override
  bool get frameOrigin => _wasmBool(
      RiveWasm.artboardGetFrameOrigin.callAsFunction(null, pointer.toJS));

  @override
  set frameOrigin(bool value) => RiveWasm.artboardSetFrameOrigin
      .callAsFunction(null, pointer.toJS, _boolWasm(value));

  @override
  Component? component(String name) => RiveWasm.toNativeString(
        name,
        (namePointer) {
          final ptr = (RiveWasm.artboardComponentNamed.callAsFunction(
                  null, _pointer.toJS, namePointer) as js.JSNumber)
              .toDartInt;

          if (ptr == 0) {
            return null;
          }

          return WebComponent(ptr);
        },
      );

  @override
  String getText(String runName, {String? path}) => RiveWasm.toNativeString(
        runName,
        (runNamePointer) {
          final nativePath = path?.toWasmUtf8();
          final stringPointer = (RiveWasm.artboardGetText.callAsFunction(
            null,
            _pointer.toJS,
            runNamePointer,
            nativePath?.pointer,
          ) as js.JSNumber)
              .toDartInt;
          if (stringPointer == 0) {
            return '';
          }
          final result = RiveWasm.toDartString(stringPointer);
          nativePath?.dispose();
          return result;
        },
      );

  @override
  bool setText(String runName, String value, {String? path}) =>
      RiveWasm.toNativeString(
        runName,
        (runNamePointer) {
          final nativeValue = value.toWasmUtf8();
          final nativePath = path?.toWasmUtf8();
          final result = _wasmBool(
            RiveWasm.artboardSetText.callAsFunction(
              null,
              _pointer.toJS,
              runNamePointer,
              nativeValue.pointer,
              nativePath?.pointer,
            ),
          );

          nativeValue.dispose();
          nativePath?.dispose();
          return result;
        },
      );

  @override
  Mat2D get renderTransform {
    RiveWasm.artboardGetRenderTransform
        .callAsFunction(null, _pointer.toJS, RiveWasm.scratchBufferPtr);
    final floats = RiveWasm.scratchBufferFloat;
    return Mat2D()
      ..values[0] = floats[0]
      ..values[1] = floats[1]
      ..values[2] = floats[2]
      ..values[3] = floats[3]
      ..values[4] = floats[4]
      ..values[5] = floats[5];
  }

  @override
  set renderTransform(Mat2D value) =>
      RiveWasm.artboardSetRenderTransform.callAsFunctionEx(
        null,
        _pointer.toJS,
        value[0].toJS,
        value[1].toJS,
        value[2].toJS,
        value[3].toJS,
        value[4].toJS,
        value[5].toJS,
      );

  // Flags AdvanceFlags.advanceNested and AdvanceFlags.newFrame set to true
  // by default
  @override
  bool advance(double seconds, {int flags = 9}) =>
      (RiveWasm.riveArtboardAdvance.callAsFunction(
              null, _pointer.toJS, seconds.toJS, flags.toJS) as js.JSNumber)
          .toDartInt ==
      1;

  @override
  double get opacity =>
      (RiveWasm.riveArtboardGetOpacity.callAsFunction(null, _pointer.toJS)
              as js.JSNumber)
          .toDartDouble;

  @override
  set opacity(double value) => RiveWasm.riveArtboardSetOpacity
      .callAsFunction(null, _pointer.toJS, value.toJS);

  @override
  double get width =>
      (RiveWasm.riveArtboardGetWidth.callAsFunction(null, _pointer.toJS)
              as js.JSNumber)
          .toDartDouble;

  @override
  set width(double value) => RiveWasm.riveArtboardSetWidth
      .callAsFunction(null, _pointer.toJS, value.toJS);

  @override
  double get height =>
      (RiveWasm.riveArtboardGetHeight.callAsFunction(null, _pointer.toJS)
              as js.JSNumber)
          .toDartDouble;

  @override
  set height(double value) => RiveWasm.riveArtboardSetHeight
      .callAsFunction(null, _pointer.toJS, value.toJS);

  @override
  double get heightOriginal => (RiveWasm.riveArtboardGetOriginalHeight
          .callAsFunction(null, _pointer.toJS) as js.JSNumber)
      .toDartDouble;

  @override
  double get widthOriginal =>
      (RiveWasm.riveArtboardGetOriginalWidth.callAsFunction(null, _pointer.toJS)
              as js.JSNumber)
          .toDartDouble;

  @override
  void resetArtboardSize() {
    width = widthOriginal;
    height = heightOriginal;
  }

  @override
  CallbackHandler onLayoutChanged(void Function() callback) {
    RiveWasm.setArtboardLayoutChangedCallback.callAsFunction(
      null,
      _pointer.toJS,
      callback.toJS,
    );
    return const EmptyCallbackHandler();
  }

  @override
  CallbackHandler onTestBounds(int Function(Vec2D pos, bool skip) callback) {
    RiveWasm.setArtboardTestBoundsCallback.callAsFunction(
      null,
      _pointer.toJS,
      (double x, double y, bool skip) {
        return callback(Vec2D.fromValues(x, y), skip).toJS;
      }.toJS,
    );
    return const EmptyCallbackHandler();
  }

  @override
  CallbackHandler onIsAncestor(int Function(int artboardId) callback) {
    RiveWasm.setArtboardIsAncestorCallback.callAsFunction(
      null,
      _pointer.toJS,
      (int artboardId) {
        return callback(artboardId).toJS;
      }.toJS,
    );
    return const EmptyCallbackHandler();
  }

  @override
  CallbackHandler onRootTransform(
      double Function(Vec2D pos, bool xAxis) callback) {
    RiveWasm.setArtboardRootTransformCallback.callAsFunction(
      null,
      _pointer.toJS,
      (double x, double y, bool xAxis) {
        return callback(Vec2D.fromValues(x, y), xAxis).toJS;
      }.toJS,
    );
    return const EmptyCallbackHandler();
  }

  @override
  CallbackHandler onEvent(void Function(int) callback) {
    RiveWasm.setArtboardEventCallback.callAsFunction(
      null,
      _pointer.toJS,
      callback.toJS,
    );
    return const EmptyCallbackHandler();
  }

  @override
  AABB get layoutBounds {
    RiveWasm.artboardLayoutBounds
        .callAsFunction(null, pointer.toJS, RiveWasm.scratchBufferPtr);

    final floats = RiveWasm.scratchBufferFloat;

    return AABB.fromValues(floats[0], floats[1], floats[2], floats[3]);
  }

  @override
  CallbackHandler onLayoutDirty(void Function() callback) {
    RiveWasm.setArtboardLayoutDirtyCallback.callAsFunction(
      null,
      _pointer.toJS,
      callback.toJS,
    );
    return const EmptyCallbackHandler();
  }

  @override
  void syncStyleChanges() =>
      RiveWasm.artboardSyncStyleChanges.callAsFunction(null, _pointer.toJS);

  @override
  dynamic takeLayoutNode() =>
      (RiveWasm.artboardTakeLayoutNode.callAsFunction(null, _pointer.toJS)
              as js.JSNumber)
          .toDartInt;

  @override
  void widthOverride(double width, int widthUnitValue, bool isRow) =>
      RiveWasm.artboardWidthOverride.callAsFunction(
          null, _pointer.toJS, width.toJS, widthUnitValue.toJS, isRow.toJS);

  @override
  void heightOverride(double height, int heightUnitValue, bool isRow) =>
      RiveWasm.artboardHeightOverride.callAsFunction(
          null, _pointer.toJS, height.toJS, heightUnitValue.toJS, isRow.toJS);

  @override
  void parentIsRow(bool isRow) => RiveWasm.artboardParentIsRow
      .callAsFunction(null, _pointer.toJS, isRow.toJS);

  @override
  void widthIntrinsicallySizeOverride(bool intrinsic) =>
      RiveWasm.artboardWidthIntrinsicallySizeOverride
          .callAsFunction(null, _pointer.toJS, intrinsic.toJS);

  @override
  void heightIntrinsicallySizeOverride(bool intrinsic) =>
      RiveWasm.artboardHeightIntrinsicallySizeOverride
          .callAsFunction(null, _pointer.toJS, intrinsic.toJS);

  @override
  void updateLayoutBounds(bool animate) => RiveWasm.updateLayoutBounds
      .callAsFunction(null, _pointer.toJS, animate.toJS);

  @override
  void cascadeLayoutStyle(int direction) => RiveWasm.cascadeLayoutStyle
      .callAsFunction(null, _pointer.toJS, direction.toJS);

  @override
  void internalBindViewModelInstance(InternalViewModelInstance instance,
      InternalDataContext dataContext, bool isRoot) {
    RiveWasm.artboardDataContextFromInstance.callAsFunction(
        null,
        _pointer.toJS,
        (instance as WebRiveInternalViewModelInstance).pointer.toJS,
        (dataContext as WebRiveDataContext).pointer.toJS,
        isRoot.toJS);
  }

  @override
  void internalSetDataContext(InternalDataContext dataContext) {
    RiveWasm.artboardInternalDataContext.callAsFunction(
        null, _pointer.toJS, (dataContext as WebRiveDataContext).pointer.toJS);
  }

  @override
  InternalDataContext? get internalGetDataContext {
    var ptr = toPointer(
        RiveWasm.artboardDataContext.callAsFunction(null, _pointer.toJS));
    if (ptr == 0) {
      return null;
    }
    return WebRiveDataContext(ptr);
  }

  @override
  void internalClearDataContext() {
    RiveWasm.artboardClearDataContext.callAsFunction(null, _pointer.toJS);
  }

  @override
  void internalUnbind() {
    RiveWasm.artboardUnbind.callAsFunction(null, _pointer.toJS);
  }

  @override
  void internalUpdateDataBinds() {
    RiveWasm.artboardUpdateDataBinds.callAsFunction(
      null,
      _pointer.toJS,
    );
  }

  @override
  bool hasComponentDirt() => _wasmBool(RiveWasm.riveArtboardHasComponentDirt
      .callAsFunction(null, _pointer.toJS) as js.JSNumber);

  @override
  bool updatePass() {
    return _wasmBool(RiveWasm.riveArtboardUpdatePass
        .callAsFunction(null, _pointer.toJS) as js.JSNumber);
  }

  @override
  void bindViewModelInstance(
      covariant WebViewModelInstanceRuntime viewModelInstance) {
    RiveWasm.artboardSetVMIRuntime.callAsFunction(
      null,
      _pointer.toJS,
      viewModelInstance.pointer.toJS,
    );
  }
}

bool _wasmBool(js.JSAny? value) => (value as js.JSNumber).toDartInt == 1;
js.JSNumber _boolWasm(bool value) => (value ? 1 : 0).toJS;

class WebBindableArtboard extends BindableArtboard {
  static final _finalizer = Finalizer(
    (js.JSAny pointer) =>
        RiveWasm.deleteBindableArtboard.callAsFunction(null, pointer),
  );

  int get pointer => _pointer;
  int _pointer;

  WebBindableArtboard(this._pointer) {
    _finalizer.attach(this, _pointer.toJS, detach: this);
  }

  @override
  void dispose() {
    if (_pointer == 0) {
      return;
    }
    final pointer = _pointer;
    _pointer = 0;
    _finalizer.detach(this);
    RiveWasm.deleteBindableArtboard.callAsFunction(null, pointer.toJS);
  }
}

class WebStateMachine extends StateMachine with EventListenerMixin {
  static final _finalizer = Finalizer(
    (js.JSAny pointer) =>
        RiveWasm.deleteStateMachineInstance.callAsFunction(null, pointer),
  );

  int get pointer => _pointer;
  int _pointer;

  ViewModelInstance? _boundRuntimeViewModelInstance;

  WebStateMachine(this._pointer) {
    _finalizer.attach(this, _pointer.toJS, detach: this);
  }

  @override
  String get name => RiveWasm.toDartString(
        (RiveWasm.stateMachineInstanceName.callAsFunction(null, pointer.toJS)
                as js.JSNumber)
            .toDartInt,
        deleteNative: true,
      );

  @override
  bool advance(double elapsedSeconds, bool newFrame) => _wasmBool(
        RiveWasm.stateMachineInstanceAdvance.callAsFunction(
          null,
          pointer.toJS,
          elapsedSeconds.toJS,
          newFrame.toJS,
        ),
      );

  @override
  bool advanceAndApply(double elapsedSeconds) {
    _handleEvents();
    final result = _wasmBool(
      RiveWasm.stateMachineInstanceAdvanceAndApply.callAsFunction(
        null,
        pointer.toJS,
        elapsedSeconds.toJS,
      ),
    );
    _boundRuntimeViewModelInstance?.handleCallbacks();
    return result;
  }

  @override
  void dispose() {
    removeAllEventListeners();
    if (_pointer == 0) {
      return;
    }
    RiveWasm.deleteStateMachineInstance.callAsFunction(null, _pointer.toJS);
    _pointer = 0;
    _finalizer.detach(this);
  }

  @override
  CallbackHandler onInputChanged(void Function(int index) callback) {
    RiveWasm.setStateMachineInputChangedCallback.callAsFunction(
      null,
      _pointer.toJS,
      callback.toJS,
    );
    return const EmptyCallbackHandler();
  }

  int _inputWrapper(js.JSFunction nativeFunction, String name,
          {String? path}) =>
      RiveWasm.toNativeString(
        name,
        (namePointer) {
          final wasmPath = path?.toWasmUtf8();
          final ptr = (nativeFunction.callAsFunction(
            null,
            _pointer.toJS,
            namePointer,
            wasmPath?.pointer,
          ) as js.JSNumber)
              .toDartInt;

          wasmPath?.dispose();
          return ptr;
        },
      );

  @override
  BooleanInput? boolean(String name, {String? path}) {
    final ptr =
        _inputWrapper(RiveWasm.stateMachineInstanceBoolean, name, path: path);
    return ptr == 0 ? null : WebBooleanInput(ptr);
  }

  @override
  NumberInput? number(String name, {String? path}) {
    final ptr =
        _inputWrapper(RiveWasm.stateMachineInstanceNumber, name, path: path);
    return ptr == 0 ? null : WebNumberInput(ptr);
  }

  @override
  TriggerInput? trigger(String name, {String? path}) {
    final ptr =
        _inputWrapper(RiveWasm.stateMachineInstanceTrigger, name, path: path);
    return ptr == 0 ? null : WebTriggerInput(ptr);
  }

  @override
  Input? inputAt(int index) {
    var inputPointer = (RiveWasm.stateMachineInput
            .callAsFunction(null, _pointer.toJS, index.toJS) as js.JSNumber)
        .toDartInt;
    if (inputPointer == 0) {
      return null;
    }
    switch (RiveWasm.stateMachineInputType
        .callAsFunction(null, inputPointer.toJS)) {
      case 56:
        return WebNumberInput(inputPointer);
      case 58:
        return WebTriggerInput(inputPointer);
      case 59:
        return WebBooleanInput(inputPointer);
      default:
        return null;
    }
  }

  @override
  bool get isDone => _wasmBool(
      RiveWasm.stateMachineInstanceDone.callAsFunction(null, _pointer.toJS));

  @override
  bool hitTest(Vec2D position) => _wasmBool(RiveWasm.stateMachineInstanceHitTest
      .callAsFunction(null, _pointer.toJS, position.x.toJS, position.y.toJS));

  @override
  HitResult pointerDown(Vec2D position) =>
      HitResult.values[(RiveWasm.stateMachineInstancePointerDown.callAsFunction(
                  null, _pointer.toJS, position.x.toJS, position.y.toJS)
              as js.JSNumber)
          .toDartInt];

  @override
  HitResult pointerExit(Vec2D position) =>
      HitResult.values[(RiveWasm.stateMachineInstancePointerExit.callAsFunction(
                  null, _pointer.toJS, position.x.toJS, position.y.toJS)
              as js.JSNumber)
          .toDartInt];

  @override
  HitResult pointerMove(Vec2D position, {double? timeStamp}) =>
      HitResult.values[(RiveWasm.stateMachineInstancePointerMove.callAsFunction(
              null,
              _pointer.toJS,
              position.x.toJS,
              position.y.toJS,
              (timeStamp ?? 0).toJS) as js.JSNumber)
          .toDartInt];

  @override
  HitResult pointerUp(Vec2D position) =>
      HitResult.values[(RiveWasm.stateMachineInstancePointerUp.callAsFunction(
                  null, _pointer.toJS, position.x.toJS, position.y.toJS)
              as js.JSNumber)
          .toDartInt];

  @override
  HitResult dragStart(Vec2D position, {double? timeStamp}) =>
      HitResult.values[(RiveWasm.stateMachineInstanceDragStart.callAsFunction(
              null,
              _pointer.toJS,
              position.x.toJS,
              position.y.toJS,
              (timeStamp ?? 0).toJS) as js.JSNumber)
          .toDartInt];

  @override
  HitResult dragEnd(Vec2D position, {double? timeStamp}) =>
      HitResult.values[(RiveWasm.stateMachineInstanceDragEnd.callAsFunction(
              null,
              _pointer.toJS,
              position.x.toJS,
              position.y.toJS,
              (timeStamp ?? 0).toJS) as js.JSNumber)
          .toDartInt];

  @override
  void internalBindViewModelInstance(InternalViewModelInstance instance) {
    RiveWasm.stateMachineDataContextFromInstance.callAsFunction(
        null,
        _pointer.toJS,
        (instance as WebRiveInternalViewModelInstance).pointer.toJS);
  }

  @override
  void internalDataContext(InternalDataContext dataContext) {
    RiveWasm.stateMachineDataContext.callAsFunction(
        null, _pointer.toJS, (dataContext as WebRiveDataContext).pointer.toJS);
  }

  @override
  CallbackHandler onDataBindChanged(void Function() callback) {
    RiveWasm.setStateMachineDataBindChangedCallback.callAsFunction(
      null,
      _pointer.toJS,
      callback.toJS,
    );

    return ClosureCallbackHandler(() {
      RiveWasm.setStateMachineDataBindChangedCallback.callAsFunction(
        null,
        _pointer.toJS,
        null,
      );
    });
  }

  @override
  void bindViewModelInstance(
      covariant WebViewModelInstanceRuntime viewModelInstance) {
    _boundRuntimeViewModelInstance = viewModelInstance;
    RiveWasm.stateMachineSetVMIRuntime.callAsFunction(
      null,
      _pointer.toJS,
      viewModelInstance.pointer.toJS,
    );
  }

  void _handleEvents() {
    final listeners = eventListeners.toList();
    // Only fetch reported events if a listener is present.
    if (listeners.isNotEmpty) {
      final events = reportedEvents();
      for (var listener in listeners) {
        events.forEach(listener);
      }
    }
  }

  @override
  List<Event> reportedEvents() {
    final count = (RiveWasm.stateMachineGetReportedEventCount
            .callAsFunction(null, _pointer.toJS) as js.JSNumber)
        .toDartInt;
    List<Event> events = [];
    for (var index = 0; index < count; index++) {
      final eventReportObject = RiveWasm.stateMachineReportedEventAt
          .callAsFunction(null, _pointer.toJS, index.toJS) as js.JSObject;
      ReportedEventWeb eventReport = ReportedEventWeb(
        (eventReportObject.getProperty('event'.toJS) as js.JSNumber).toDartInt,
        (eventReportObject.getProperty('secondsDelay'.toJS) as js.JSNumber)
            .toDartDouble,
        (eventReportObject.getProperty('type'.toJS) as js.JSNumber).toDartInt,
      );
      final eventType = EventType.from[eventReport.type];
      if (eventType == null) {
        // An event of this type is not handled at runtime, immediately dispose
        // native resources and continue to the next event.
        RiveWasm.deleteEvent
            .callAsFunction(null, eventReport.eventPointer.toJS);
        continue;
      }
      Event event = switch (eventType) {
        EventType.general => WebGeneralEvent(eventReport),
        EventType.openURL => WebOpenURLEvent(eventReport),
      };
      events.add(event);
    }
    return events;
  }
}

final class ReportedEventWeb {
  int eventPointer;
  final double secondsDelay;
  final int type;

  ReportedEventWeb(this.eventPointer, this.secondsDelay, this.type);
}

final class CustomPropertyWeb {
  int propertyPointer;
  final int namePointer;
  final int type;

  CustomPropertyWeb(this.propertyPointer, this.namePointer, this.type);
}

sealed class WebEvent with EventPropertyMixin implements EventInterface {
  static final _finalizer = Finalizer(
    (js.JSAny pointer) => RiveWasm.deleteEvent.callAsFunction(null, pointer),
  );
  final ReportedEventWeb _native;
  WebEvent._(this._native) {
    _finalizer.attach(this, pointer.toJS, detach: this);
  }

  int get pointer => _native.eventPointer;

  Map<String, CustomProperty>? _cachedProperties;

  @override
  Map<String, CustomProperty> get properties {
    if (_cachedProperties == null) {
      _populateProperties();
    }
    return _cachedProperties!;
  }

  void _populateProperties() {
    _cachedProperties = {};
    final count = (RiveWasm.getEventCustomPropertyCount
            .callAsFunction(null, pointer.toJS) as js.JSNumber)
        .toDartInt;
    for (var index = 0; index < count; index++) {
      final propertyObject = RiveWasm.getEventCustomProperty
          .callAsFunction(null, pointer.toJS, index.toJS) as js.JSObject;
      final propertyStruct = CustomPropertyWeb(
        (propertyObject.getProperty('property'.toJS) as js.JSNumber).toDartInt,
        (propertyObject.getProperty('name'.toJS) as js.JSNumber).toDartInt,
        (propertyObject.getProperty('type'.toJS) as js.JSNumber).toDartInt,
      );
      final propertyType = CustomPropertyType.from[propertyStruct.type];
      CustomProperty? property = switch (propertyType) {
        null => null,
        CustomPropertyType.number => WebCustomNumberProperty(propertyStruct),
        CustomPropertyType.boolean => WebCustomBooleanProperty(propertyStruct),
        CustomPropertyType.string => WebCustomStringProperty(propertyStruct),
      };
      if (property != null) {
        _cachedProperties![property.name] = property;
      }
    }
  }

  @override
  String get name {
    final stringPointer = (RiveWasm.getEventName
            .callAsFunction(null, pointer.toJS) as js.JSNumber)
        .toDartInt;
    if (stringPointer == 0) {
      return '';
    }
    return RiveWasm.toDartString(stringPointer);
  }

  @override
  double get secondsDelay => _native.secondsDelay;

  @override
  EventType get type => EventType.from[_native.type] ?? EventType.general;

  @override
  void dispose() {
    if (pointer == 0) {
      return;
    }
    RiveWasm.deleteEvent.callAsFunction(null, pointer.toJS);
    _native.eventPointer = 0;
    _finalizer.detach(this);
  }
}

class WebGeneralEvent extends WebEvent implements GeneralEvent {
  WebGeneralEvent(super._native) : super._();

  @override
  String toString() {
    return 'GeneralEvent{type: $type, name: $name, properties: $properties}';
  }
}

class WebOpenURLEvent extends WebEvent implements OpenUrlEvent {
  WebOpenURLEvent(super._native) : super._();

  @override
  OpenUrlTarget get target {
    final targetInt = (RiveWasm.getOpenUrlEventTarget
            .callAsFunction(null, pointer.toJS) as js.JSNumber)
        .toDartInt;
    final value = OpenUrlTarget.from[targetInt];
    return value ?? OpenUrlTarget.blank;
  }

  @override
  String get url {
    final stringPointer = (RiveWasm.getOpenUrlEventUrl
            .callAsFunction(null, pointer.toJS) as js.JSNumber)
        .toDartInt;
    if (stringPointer == 0) {
      return '';
    }
    return RiveWasm.toDartString(stringPointer);
  }

  @override
  String toString() {
    return 'OpenURLEvent{type: $type, name: $name, url: $url, target: $target, properties: $properties}';
  }
}

sealed class WebCustomProperty<T> implements CustomPropertyInterface<T> {
  static final _finalizer = Finalizer(
    (js.JSAny pointer) =>
        RiveWasm.deleteCustomProperty.callAsFunction(null, pointer),
  );

  final CustomPropertyWeb _native;
  WebCustomProperty(this._native) {
    _finalizer.attach(this, pointer.toJS, detach: this);
  }

  int get pointer => _native.propertyPointer;

  @override
  String get name {
    final stringPointer = _native.namePointer;
    if (stringPointer == 0) {
      return '';
    }
    return RiveWasm.toDartString(stringPointer);
  }

  @override
  CustomPropertyType get type => CustomPropertyType.from[_native.type]!;

  @override
  String toString() {
    return 'CustomProperty{type: $type, name: $name, value: $value}';
  }

  @override
  void dispose() {
    if (_native.propertyPointer == 0) {
      return;
    }
    RiveWasm.deleteCustomProperty.callAsFunction(null, pointer.toJS);
    _native.propertyPointer = 0;
    _finalizer.detach(this);
  }
}

class WebCustomNumberProperty extends WebCustomProperty<double>
    implements CustomNumberProperty {
  WebCustomNumberProperty(super._native);
  @override
  double get value =>
      (RiveWasm.getCustomPropertyNumber.callAsFunction(null, pointer.toJS)
              as js.JSNumber)
          .toDartDouble;
}

class WebCustomBooleanProperty extends WebCustomProperty<bool>
    implements CustomBooleanProperty {
  WebCustomBooleanProperty(super._native);
  @override
  bool get value => _wasmBool(
      RiveWasm.getCustomPropertyBoolean.callAsFunction(null, pointer.toJS));
}

class WebCustomStringProperty extends WebCustomProperty<String>
    implements CustomStringProperty {
  WebCustomStringProperty(super._native);
  @override
  String get value {
    final stringPointer = (RiveWasm.getCustomPropertyString
            .callAsFunction(null, pointer.toJS) as js.JSNumber)
        .toDartInt;
    if (stringPointer == 0) {
      return '';
    }
    return RiveWasm.toDartString(stringPointer);
  }
}

abstract class WebInput extends Input {
  static final _finalizer = Finalizer(
    (js.JSAny pointer) => RiveWasm.deleteInput.callAsFunction(null, pointer),
  );

  int get pointer => _pointer;
  int _pointer;

  WebInput(this._pointer) {
    _finalizer.attach(this, _pointer.toJS, detach: this);
  }

  @override
  void dispose() {
    if (_pointer == 0) {
      return;
    }
    RiveWasm.deleteInput.callAsFunction(null, _pointer.toJS);
    _pointer = 0;
    _finalizer.detach(this);
  }

  @override
  String get name {
    var stringPointer = (RiveWasm.stateMachineInputName
            .callAsFunction(null, pointer.toJS) as js.JSNumber)
        .toDartInt;
    if (stringPointer == 0) {
      return '';
    }
    return RiveWasm.toDartString(stringPointer);
  }
}

class WebNumberInput extends WebInput implements NumberInput {
  WebNumberInput(super.pointer);

  @override
  double get value =>
      (RiveWasm.getNumberValue.callAsFunction(null, pointer.toJS)
              as js.JSNumber)
          .toDartDouble;

  @override
  set value(double value) =>
      RiveWasm.setNumberValue.callAsFunction(null, pointer.toJS, value.toJS);
}

class WebTriggerInput extends WebInput implements TriggerInput {
  WebTriggerInput(super.pointer);

  @override
  void fire() => RiveWasm.fireTrigger.callAsFunction(null, pointer.toJS);
}

class WebBooleanInput extends WebInput implements BooleanInput {
  WebBooleanInput(super.pointer);

  @override
  bool get value =>
      _wasmBool(RiveWasm.getBooleanValue.callAsFunction(null, pointer.toJS));

  @override
  set value(bool value) =>
      RiveWasm.setBooleanValue.callAsFunction(null, pointer.toJS, value.toJS);
}

class WebComponent extends Component {
  static final _finalizer = Finalizer(
    (js.JSAny pointer) =>
        RiveWasm.deleteComponent.callAsFunction(null, pointer),
  );

  int get pointer => _pointer;
  int _pointer;

  WebComponent(this._pointer) {
    _finalizer.attach(this, _pointer.toJS, detach: this);
  }

  @override
  void dispose() {
    if (_pointer == 0) {
      return;
    }
    RiveWasm.deleteComponent.callAsFunction(null, _pointer.toJS);
    _pointer = 0;
    _finalizer.detach(this);
  }

  @override
  AABB get localBounds {
    RiveWasm.componentGetLocalBounds.callAsFunction(
      null,
      pointer.toJS,
      RiveWasm.scratchBufferPtr,
    );
    final floats = RiveWasm.scratchBufferFloat;
    return AABB.fromLTRB(floats[0], floats[1], floats[2], floats[3]);
  }

  @override
  Mat2D get worldTransform {
    RiveWasm.componentGetWorldTransform.callAsFunction(
      null,
      pointer.toJS,
      RiveWasm.scratchBufferPtr,
    );
    final floats = RiveWasm.scratchBufferFloat;

    return Mat2D()
      ..values[0] = floats[0]
      ..values[1] = floats[1]
      ..values[2] = floats[2]
      ..values[3] = floats[3]
      ..values[4] = floats[4]
      ..values[5] = floats[5];
  }

  @override
  set worldTransform(Mat2D value) =>
      RiveWasm.componentSetWorldTransform.callAsFunctionEx(
        null,
        pointer.toJS,
        value[0].toJS,
        value[1].toJS,
        value[2].toJS,
        value[3].toJS,
        value[4].toJS,
        value[5].toJS,
      );

  @override
  double get scaleX =>
      (RiveWasm.componentGetScaleX.callAsFunction(null, pointer.toJS)
              as js.JSNumber)
          .toDartDouble;

  @override
  set scaleX(double value) => RiveWasm.componentSetScaleX
      .callAsFunction(null, pointer.toJS, value.toJS);

  @override
  double get scaleY =>
      (RiveWasm.componentGetScaleY.callAsFunction(null, pointer.toJS)
              as js.JSNumber)
          .toDartDouble;

  @override
  set rotation(double value) => RiveWasm.componentSetRotation
      .callAsFunction(null, pointer.toJS, value.toJS);

  @override
  double get rotation =>
      (RiveWasm.componentGetRotation.callAsFunction(null, pointer.toJS)
              as js.JSNumber)
          .toDartDouble;

  @override
  set scaleY(double value) => RiveWasm.componentSetScaleY
      .callAsFunction(null, pointer.toJS, value.toJS);

  @override
  double get x =>
      (RiveWasm.componentGetX.callAsFunction(null, pointer.toJS) as js.JSNumber)
          .toDartDouble;

  @override
  set x(double value) =>
      RiveWasm.componentSetX.callAsFunction(null, pointer.toJS, value.toJS);

  @override
  double get y =>
      (RiveWasm.componentGetY.callAsFunction(null, pointer.toJS) as js.JSNumber)
          .toDartDouble;

  @override
  set y(double value) =>
      RiveWasm.componentSetY.callAsFunction(null, pointer.toJS, value.toJS);

  @override
  void setLocalFromWorld(Mat2D worldTransform) =>
      RiveWasm.componentSetLocalFromWorld.callAsFunctionEx(
        null,
        pointer.toJS,
        worldTransform[0].toJS,
        worldTransform[1].toJS,
        worldTransform[2].toJS,
        worldTransform[3].toJS,
        worldTransform[4].toJS,
        worldTransform[5].toJS,
      );
}

class WebAnimation extends Animation {
  static final _finalizer = Finalizer((js.JSAny pointer) =>
      RiveWasm.animationInstanceDelete.callAsFunction(null, pointer));

  int get pointer => _pointer;
  int _pointer;

  WebAnimation(this._pointer) {
    _finalizer.attach(this, _pointer.toJS, detach: this);
  }

  @override
  String get name => RiveWasm.toDartString(
        (RiveWasm.animationInstanceName.callAsFunction(null, pointer.toJS)
                as js.JSNumber)
            .toDartInt,
        deleteNative: true,
      );

  @override
  double get time =>
      (RiveWasm.animationInstanceGetTime.callAsFunction(null, pointer.toJS)
              as js.JSNumber)
          .toDartDouble;

  @override
  double get duration =>
      (RiveWasm.animationInstanceGetDuration.callAsFunction(null, pointer.toJS)
              as js.JSNumber)
          .toDartDouble;

  @override
  set time(double value) => RiveWasm.animationInstanceSetTime
      .callAsFunction(null, pointer.toJS, value.toJS);

  @override
  bool advance(double elapsedSeconds) =>
      _wasmBool(RiveWasm.animationInstanceAdvance
          .callAsFunction(null, pointer.toJS, elapsedSeconds.toJS));

  @override
  bool advanceAndApply(double elapsedSeconds) =>
      _wasmBool(RiveWasm.animationInstanceAdvanceAndApply
          .callAsFunction(null, pointer.toJS, elapsedSeconds.toJS));

  @override
  void apply({double mix = 1.0}) => RiveWasm.animationInstanceApply
      .callAsFunction(null, pointer.toJS, mix.toJS);

  @override
  void dispose() {
    if (_pointer == 0) {
      return;
    }
    RiveWasm.animationInstanceDelete.callAsFunction(null, _pointer.toJS);
    _pointer = 0;
    _finalizer.detach(this);
  }

  @override
  double globalToLocalTime(double seconds) =>
      (RiveWasm.animationInstanceGetLocalSeconds
              .callAsFunction(null, pointer.toJS, seconds.toJS) as js.JSNumber)
          .toDartDouble;
}

class WebRiveDataContext extends InternalDataContext {
  static final _finalizer = Finalizer((js.JSAny pointer) =>
      RiveWasm.deleteDataContext.callAsFunction(null, pointer));
  int get pointer => _pointer;
  int _pointer;
  WebRiveDataContext(this._pointer);

  @override
  InternalViewModelInstance get viewModelInstance {
    var ptr = toPointer(RiveWasm.riveDataContextViewModelInstance
        .callAsFunction(null, _pointer.toJS));
    return WebRiveInternalViewModelInstance(ptr);
  }

  @override
  void dispose() {
    if (_pointer == 0) {
      return;
    }
    RiveWasm.deleteDataContext.callAsFunction(null, _pointer.toJS);
    _pointer = 0;
    _finalizer.detach(this);
  }
}

class WebInternalViewModelInstanceValue<T>
    extends InternalViewModelInstanceValue<T> {
  static final _finalizer = Finalizer((js.JSAny pointer) =>
      RiveWasm.deleteViewModelInstanceValue.callAsFunction(null, pointer));

  int get pointer => _pointer;
  int _pointer;
  void Function(T value)? _callback;

  WebInternalViewModelInstanceValue(this._pointer) {
    _finalizer.attach(this, _pointer.toJS, detach: this);

    instancePointerAddress = getInstancePointer();
    WebRiveFile.internalRegisterViewModelInstance(instancePointerAddress, this);
  }
  @override
  void onChanged(void Function(T value) callback) {
    _callback = callback;
  }

  int getInstancePointer() {
    return 0;
  }

  @override
  void dispose() {
    if (_pointer == 0) {
      return;
    }
    RiveWasm.deleteViewModelInstanceValue.callAsFunction(null, _pointer.toJS);
    _pointer = 0;
    _finalizer.detach(this);
  }

  @override
  advanced() {
    RiveWasm.setViewModelInstanceAdvanced.callAsFunction(null, _pointer.toJS);
  }

  @override
  set value(T val) {
    if (suppressCallback) {
      return;
    }
    suppressCallback = true;
    applyValue(val);
    suppressCallback = false;
  }

  @override
  set nativeValue(T val) {
    if (suppressCallback) {
      return;
    }
    suppressCallback = true;
    if (_callback != null) {
      _callback!(val);
    }
    suppressCallback = false;
  }

  void applyValue(T val) {}
}

class WebRiveInternalViewModelInstance extends InternalViewModelInstance {
  static final _finalizer = Finalizer((js.JSAny pointer) =>
      RiveWasm.deleteViewModelInstance.callAsFunction(null, pointer));
  int get pointer => _pointer;
  int _pointer;
  WebRiveInternalViewModelInstance(this._pointer);

  @override
  InternalViewModelInstanceViewModel propertyViewModel(int index) {
    var ptr = toPointer(RiveWasm.viewModelInstancePropertyValue
        .callAsFunction(null, _pointer.toJS, index.toJS));
    return WebRiveInternalViewModelInstanceViewModel(ptr);
  }

  @override
  InternalViewModelInstanceNumber propertyNumber(int index) {
    var ptr = toPointer(RiveWasm.viewModelInstancePropertyValue
        .callAsFunction(null, _pointer.toJS, index.toJS));
    return WebInternalViewModelInstanceNumber(ptr);
  }

  @override
  InternalViewModelInstanceBoolean propertyBoolean(int index) {
    var ptr = toPointer(RiveWasm.viewModelInstancePropertyValue
        .callAsFunction(null, _pointer.toJS, index.toJS));
    return WebInternalViewModelInstanceBoolean(ptr);
  }

  @override
  InternalViewModelInstanceColor propertyColor(int index) {
    var ptr = toPointer(RiveWasm.viewModelInstancePropertyValue
        .callAsFunction(null, _pointer.toJS, index.toJS));
    return WebInternalViewModelInstanceColor(ptr);
  }

  @override
  InternalViewModelInstanceString propertyString(int index) {
    var ptr = toPointer(RiveWasm.viewModelInstancePropertyValue
        .callAsFunction(null, _pointer.toJS, index.toJS));
    return WebInternalViewModelInstanceString(ptr);
  }

  @override
  InternalViewModelInstanceTrigger propertyTrigger(int index) {
    var ptr = toPointer(RiveWasm.viewModelInstancePropertyValue
        .callAsFunction(null, _pointer.toJS, index.toJS));
    return WebInternalViewModelInstanceTrigger(ptr);
  }

  @override
  InternalViewModelInstanceEnum propertyEnum(int index) {
    var ptr = toPointer(RiveWasm.viewModelInstancePropertyValue
        .callAsFunction(null, _pointer.toJS, index.toJS));
    return WebInternalViewModelInstanceEnum(ptr);
  }

  @override
  InternalViewModelInstanceList propertyList(int index) {
    var ptr = toPointer(RiveWasm.viewModelInstancePropertyValue
        .callAsFunction(null, _pointer.toJS, index.toJS));
    return WebInternalViewModelInstanceList(ptr);
  }

  @override
  InternalViewModelInstanceSymbolListIndex propertySymbolListIndex(int index) {
    var ptr = toPointer(RiveWasm.viewModelInstancePropertyValue
        .callAsFunction(null, _pointer.toJS, index.toJS));
    return WebInternalViewModelInstanceSymbolListIndex(ptr);
  }

  @override
  InternalViewModelInstanceAsset propertyAsset(int index) {
    var ptr = toPointer(RiveWasm.viewModelInstancePropertyValue
        .callAsFunction(null, _pointer.toJS, index.toJS));
    return WebInternalViewModelInstanceAsset(ptr);
  }

  @override
  InternalViewModelInstanceArtboard propertyArtboard(int index) {
    var ptr = toPointer(RiveWasm.viewModelInstancePropertyValue
        .callAsFunction(null, _pointer.toJS, index.toJS));
    return WebInternalViewModelInstanceArtboard(ptr);
  }

  @override
  void dispose() {
    if (_pointer == 0) {
      return;
    }
    RiveWasm.deleteViewModelInstance.callAsFunction(null, _pointer.toJS);
    _pointer = 0;
    _finalizer.detach(this);
  }
}

class WebRiveInternalViewModelInstanceViewModel
    extends WebInternalViewModelInstanceValue<void>
    implements InternalViewModelInstanceViewModel {
  WebRiveInternalViewModelInstanceViewModel(super.pointer);

  @override
  InternalViewModelInstance get referenceViewModelInstance {
    var ptr = toPointer(RiveWasm.viewModelInstanceReferenceViewModel
        .callAsFunction(null, _pointer.toJS));
    return WebRiveInternalViewModelInstance(ptr);
  }
}

class WebInternalViewModelInstanceNumber
    extends WebInternalViewModelInstanceValue<double>
    implements InternalViewModelInstanceNumber {
  WebInternalViewModelInstanceNumber(super.pointer);

  @override
  applyValue(double val) {
    RiveWasm.setViewModelInstanceNumberValue
        .callAsFunction(null, _pointer.toJS, val.toJS);
  }

  @override
  getInstancePointer() {
    return (RiveWasm.setViewModelInstanceNumberCallback.callAsFunction(
      null,
      _pointer.toJS,
    ) as js.JSNumber)
        .toDartInt;
  }
}

class WebInternalViewModelInstanceColor
    extends WebInternalViewModelInstanceValue<int>
    implements InternalViewModelInstanceColor {
  WebInternalViewModelInstanceColor(super.pointer);

  @override
  applyValue(int val) {
    RiveWasm.setViewModelInstanceColorValue
        .callAsFunction(null, _pointer.toJS, val.toJS);
  }

  @override
  getInstancePointer() {
    return (RiveWasm.setViewModelInstanceColorCallback.callAsFunction(
      null,
      _pointer.toJS,
    ) as js.JSNumber)
        .toDartInt;
  }
}

class WebInternalViewModelInstanceString
    extends WebInternalViewModelInstanceValue<String>
    implements InternalViewModelInstanceString {
  WebInternalViewModelInstanceString(super.pointer);

  @override
  applyValue(String val) => RiveWasm.toNativeString(
        val,
        (valPointer) {
          RiveWasm.setViewModelInstanceStringValue
              .callAsFunction(null, _pointer.toJS, valPointer);
        },
      );

  @override
  getInstancePointer() {
    return (RiveWasm.setViewModelInstanceStringCallback.callAsFunction(
      null,
      _pointer.toJS,
    ) as js.JSNumber)
        .toDartInt;
  }
}

class WebInternalViewModelInstanceBoolean
    extends WebInternalViewModelInstanceValue<bool>
    implements InternalViewModelInstanceBoolean {
  WebInternalViewModelInstanceBoolean(super.pointer);

  @override
  applyValue(bool val) {
    RiveWasm.setViewModelInstanceBooleanValue
        .callAsFunction(null, _pointer.toJS, val.toJS);
  }

  @override
  getInstancePointer() {
    return (RiveWasm.setViewModelInstanceBooleanCallback.callAsFunction(
      null,
      _pointer.toJS,
    ) as js.JSNumber)
        .toDartInt;
  }
}

class WebInternalViewModelInstanceTrigger
    extends WebInternalViewModelInstanceValue<int>
    implements InternalViewModelInstanceTrigger {
  WebInternalViewModelInstanceTrigger(super.pointer);

  @override
  applyValue(int val) {
    RiveWasm.setViewModelInstanceTriggerValue
        .callAsFunction(null, _pointer.toJS, val.toJS);
  }

  @override
  getInstancePointer() {
    return (RiveWasm.setViewModelInstanceTriggerCallback.callAsFunction(
      null,
      _pointer.toJS,
    ) as js.JSNumber)
        .toDartInt;
  }
}

class WebInternalViewModelInstanceEnum
    extends WebInternalViewModelInstanceValue<int>
    implements InternalViewModelInstanceEnum {
  WebInternalViewModelInstanceEnum(super.pointer);

  @override
  applyValue(int val) {
    RiveWasm.setViewModelInstanceEnumValue
        .callAsFunction(null, _pointer.toJS, val.toJS);
  }

  @override
  getInstancePointer() {
    return (RiveWasm.setViewModelInstanceEnumCallback.callAsFunction(
      null,
      _pointer.toJS,
    ) as js.JSNumber)
        .toDartInt;
  }
}

class WebInternalViewModelInstanceSymbolListIndex
    extends WebInternalViewModelInstanceValue<int>
    implements InternalViewModelInstanceSymbolListIndex {
  WebInternalViewModelInstanceSymbolListIndex(super.pointer);

  @override
  applyValue(int val) {
    RiveWasm.setViewModelInstanceSymbolListIndexValue
        .callAsFunction(null, _pointer.toJS, val.toJS);
  }

  @override
  getInstancePointer() {
    return (RiveWasm.setViewModelInstanceSymbolListIndexCallback.callAsFunction(
      null,
      _pointer.toJS,
    ) as js.JSNumber)
        .toDartInt;
  }
}

class WebInternalViewModelInstanceList
    extends WebInternalViewModelInstanceValue<void>
    implements InternalViewModelInstanceList {
  WebInternalViewModelInstanceList(super.pointer);

  @override
  InternalViewModelInstance referenceViewModelInstance(int index) {
    var ptr = toPointer(RiveWasm.viewModelInstanceListItemViewModel
        .callAsFunction(null, _pointer.toJS, index.toJS));
    return WebRiveInternalViewModelInstance(ptr);
  }
}

class WebInternalViewModelInstanceAsset
    extends WebInternalViewModelInstanceValue<int>
    implements InternalViewModelInstanceAsset {
  WebInternalViewModelInstanceAsset(super.pointer);

  @override
  applyValue(int val) {
    RiveWasm.setViewModelInstanceAssetValue
        .callAsFunction(null, _pointer.toJS, val.toJS);
  }

  @override
  getInstancePointer() {
    return (RiveWasm.setViewModelInstanceAssetCallback.callAsFunction(
      null,
      _pointer.toJS,
    ) as js.JSNumber)
        .toDartInt;
  }
}

class WebInternalViewModelInstanceArtboard
    extends WebInternalViewModelInstanceValue<int>
    implements InternalViewModelInstanceArtboard {
  WebInternalViewModelInstanceArtboard(super.pointer);

  @override
  applyValue(int val) {
    RiveWasm.setViewModelInstanceArtboardValue
        .callAsFunction(null, _pointer.toJS, val.toJS);
  }

  @override
  getInstancePointer() {
    return (RiveWasm.setViewModelInstanceArtboardCallback.callAsFunction(
      null,
      _pointer.toJS,
    ) as js.JSNumber)
        .toDartInt;
  }
}

class WebRiveInternalDataBind extends InternalDataBind {
  int get pointer => _pointer;
  int _pointer;
  WebRiveInternalDataBind(this._pointer);

  @override
  int get dirt => (RiveWasm.riveDataBindDirt.callAsFunction(null, pointer.toJS)
          as js.JSNumber)
      .toDartInt;

  @override
  set dirt(int value) => RiveWasm.riveDataBindSetDirt
      .callAsFunction(null, pointer.toJS, value.toJS);

  @override
  int get flags =>
      (RiveWasm.riveDataBindFlags.callAsFunction(null, pointer.toJS)
              as js.JSNumber)
          .toDartInt;

  @override
  void updateSourceBinding() {
    RiveWasm.riveDataBindUpdateSourceBinding.callAsFunction(null, pointer.toJS);
  }

  @override
  void update(int dirt) {
    RiveWasm.riveDataBindUpdate.callAsFunction(null, pointer.toJS, dirt.toJS);
  }

  @override
  void dispose() {
    if (_pointer == 0) {
      return;
    }
    _pointer = 0;
  }
}
