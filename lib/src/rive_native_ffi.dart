import 'dart:async';
import 'dart:ffi';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:rive_native/platform.dart';
import 'package:rive_native/rive_native.dart';
import 'package:rive_native/src/ffi/dynamic_library_helper.dart';
import 'package:rive_native/src/ffi/rive_renderer_ffi.dart';
import 'package:rive_native/src/rive.dart' as rive;

final DynamicLibrary nativeLib = DynamicLibraryHelper.nativeLib;

Set<int> _allTextures = {};
final bool Function(Pointer<Void>, bool, int) _nativeClear = nativeLib
    .lookup<NativeFunction<Bool Function(Pointer<Void>, Bool, Uint32)>>('clear')
    .asFunction();
final bool Function(Pointer<Void>, double) _nativeFlush = nativeLib
    .lookup<NativeFunction<Bool Function(Pointer<Void>, Float)>>('flush')
    .asFunction();
final Pointer<Void> Function(Pointer<Void>) _nativeTexture = nativeLib
    .lookup<NativeFunction<Pointer<Void> Function(Pointer<Void>)>>(
      'nativeTexture',
    )
    .asFunction();

base class _NativeRenderTexture extends RenderTexture {
  @override
  Pointer<Void> get nativeTexture => _nativeTexture(_rendererPtr);

  final MethodChannel methodChannel;
  int _textureId = -1;
  Pointer<Void> _rendererPtr = nullptr;

  _NativeRenderTexture(this.methodChannel);

  @override
  bool get isReady => _textureId != -1;

  @override
  void dispose() {
    if (_textureId != -1) {
      _disposeTexture(_textureId);
      _textureId = -1;
    }
  }

  int _width = 0;
  int _height = 0;
  int _actualWidth = 0;
  int _actualHeight = 0;

  int get actualWidth => _actualWidth;
  int get actualHeight => _actualHeight;
  bool needsResize(int width, int height) =>
      width != _width || height != _height;

  @override
  bool get isDisposed => _textureId == -1;

  final List<int> _deadTextures = [];

  void _disposeTextures() {
    _disposeTimer = null;
    var textures = _deadTextures.toList();
    _deadTextures.clear();
    for (final texture in textures) {
      methodChannel.invokeMethod('removeTexture', {'id': texture});
    }
  }

  Timer? _disposeTimer;
  void _disposeTexture(int id) {
    _deadTextures.add(id);
    if (_disposeTimer != null) {
      return;
    }

    _disposeTimer = Timer(const Duration(seconds: 1), _disposeTextures);
  }

  Future<void> makeRenderTexture(int width, int height) async {
    // Immediately update cached values in-case we redraw during udpate.
    _width = width;
    _height = height;
    final result = await methodChannel.invokeMethod('createTexture', {
      'width': width == 0 ? 1 : width,
      'height': height == 0 ? 1 : height,
    });
    _actualWidth = width;
    _actualHeight = height;
    int? textureId = result['textureId'] as int?;
    String renderer = result['renderer'] as String;
    _rendererPtr = Pointer<Void>.fromAddress(
        int.parse(renderer.substring(renderer.indexOf('x') + 1), radix: 16));

    if (textureId != null) {
      _allTextures.add(textureId);
    }
    if (_textureId != -1) {
      _allTextures.remove(_textureId);
      _disposeTexture(_textureId);
    }

    if (textureId == null) {
      _textureId = -1;
    } else {
      _textureId = textureId;
    }
  }

  @override
  Widget widget({RenderTexturePainter? painter, Key? key}) =>
      _RiveNativeView(this, painter, key: key);

  void _markDestroyed() {
    _rendererPtr = nullptr;
    final textureIdToDestroy = _textureId;
    if (textureIdToDestroy != -1) {
      _textureId = -1;
      _allTextures.remove(textureIdToDestroy);
      _disposeTexture(textureIdToDestroy);
      _width = _height = 0;
    }
  }

  @override
  bool clear(Color color, [bool write = true]) {
    // ignore: deprecated_member_use
    if (!_nativeClear(_rendererPtr, write, color.value)) {
      _markDestroyed();
      return false;
    }
    return true;
  }

  @override
  bool flush(double devicePixelRatio) {
    if (!_nativeFlush(_rendererPtr, devicePixelRatio)) {
      _markDestroyed();
      return false;
    }
    return true;
  }

  @override
  Renderer get renderer => FFIRiveRenderer(rive.Factory.rive, _rendererPtr);

  @override
  Future<ui.Image> toImage() {
    final scene = SceneBuilder();
    scene.addTexture(
      _textureId,
      // offset: Offset(-offset.dx, -offset.dy - 40),
      width: _width.toDouble(),
      height: _height.toDouble(),
      freeze: true,
    );

    final build = scene.build();
    return build.toImage(_width, _height);
    // final imageData =
    //     await imagemCapturada.toByteData(format: ImageByteFormat.png);
    // final imageBytes = imageData!.buffer
    //     .asUint8List(imageData.offsetInBytes, imageData.buffer.lengthInBytes);
    // return imageBytes;
  }
}

class _RiveNativeFFI extends RiveNative {
  final methodChannel = const MethodChannel('rive_native');
  @override
  RenderTexture makeRenderTexture() => _NativeRenderTexture(methodChannel);

  Future<void> initialize() async {
    if (Platform.instance.isTesting || Platform.instance.isLinux) {
      return;
    }
    final result = await methodChannel.invokeMethod('getRenderContext', {});

    String rendererContext = result['rendererContext'] as String;
    if (rendererContext == 'android') {
      // on android we grab the global riveFactory.
      final Pointer<Void> Function() riveFactory = nativeLib
          .lookup<NativeFunction<Pointer<Void> Function()>>(
            'riveFactory',
          )
          .asFunction();
      (rive.Factory.rive as FFIRiveFactory).pointer = riveFactory();
    } else {
      (rive.Factory.rive as FFIRiveFactory).pointer = Pointer<Void>.fromAddress(
          int.parse(rendererContext.substring(rendererContext.indexOf('x') + 1),
              radix: 16));
    }
  }
}

Future<RiveNative?> makeRiveNative() async {
  WidgetsFlutterBinding.ensureInitialized();
  final riveNative = _RiveNativeFFI();
  await riveNative.initialize();
  return riveNative;
}

class _RiveNativeView extends LeafRenderObjectWidget {
  final _NativeRenderTexture renderTexture;
  final RenderTexturePainter? painter;
  const _RiveNativeView(this.renderTexture, this.painter, {super.key});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RiveNativeViewRenderObject(renderTexture, painter)
      ..devicePixelRatio = MediaQuery.devicePixelRatioOf(context)
      ..tickerModeEnabled = TickerMode.of(context);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RiveNativeViewRenderObject renderObject,
  ) {
    renderObject
      ..renderTexture = renderTexture
      ..painter = painter
      ..devicePixelRatio = MediaQuery.devicePixelRatioOf(context)
      ..tickerModeEnabled = TickerMode.of(context);
  }

  @override
  void didUnmountRenderObject(
    covariant _RiveNativeViewRenderObject renderObject,
  ) {
    renderObject.painter = null;
  }
}

class _RiveNativeViewRenderObject
    extends RiveNativeRenderBox<RenderTexturePainter>
    with WidgetsBindingObserver {
  _NativeRenderTexture _renderTexture;

  _RiveNativeViewRenderObject(
    this._renderTexture,
    RenderTexturePainter? renderTexturePainter,
  ) {
    painter = renderTexturePainter;

    //add an observer to monitor the widget lyfecycle changes
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      markNeedsLayout();
    }
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  bool get shouldAdvance => _shouldAdvance;
  bool _shouldAdvance = false;

  @override
  void frameCallback(Duration duration) {
    super.frameCallback(duration);
    _paintTexture(elapsedSeconds);
  }

  void _paintTexture(double elapsedSeconds, {bool forceShouldAdvance = false}) {
    final painter = rivePainter;
    if (painter == null || !renderTexture.isReady || !hasSize) {
      return;
    }
    final width = (size.width * devicePixelRatio).roundToDouble();
    final height = (size.height * devicePixelRatio).roundToDouble();
    if (!_renderTexture.clear(painter.background, painter.clear)) {
      markNeedsPaint();
      return;
    }
    final shouldAdvance = painter.paint(
      _renderTexture,
      devicePixelRatio,
      ui.Size(width, height),
      elapsedSeconds,
    );
    if (shouldAdvance && shouldAdvance != _shouldAdvance) {
      restartTickerIfStopped();
    }
    _shouldAdvance = forceShouldAdvance == true || shouldAdvance;
    if (!_renderTexture.flush(devicePixelRatio)) {
      markNeedsPaint();
      return;
    }
    if (painter.paintsCanvas) {
      markNeedsPaint();
    }
  }

  _NativeRenderTexture get renderTexture => _renderTexture;
  set renderTexture(_NativeRenderTexture value) {
    if (_renderTexture == value) {
      return;
    }
    _renderTexture = value;
    markNeedsPaint();
  }

  // TODO (Gordon): This needs to be tested for Android once the Rive Renderer
  // is working there. The `freeze` option that is set for `context.addLayer`
  // I believe is only relevant for Android.
  var _isResizing = false;

  @override
  void performLayout() {
    final width = (size.width * devicePixelRatio).round();
    final height = (size.height * devicePixelRatio).round();
    if (_renderTexture.needsResize(width, height) ||
        _renderTexture.isDisposed) {
      _isResizing = true;
      // TODO (Gordon): Maybe this can be a cancelable future if we're
      // laying out continuously
      _renderTexture.makeRenderTexture(width, height).then((_) {
        // Check if the render object is still attached and not disposed
        if (!attached) {
          return;
        }
        _isResizing = false;
        rivePainter?.textureChanged();
        _renderTexture.textureChanged();
        // Force the advance as sometimes advancing a state machine
        // by 0 will return false. This results in the graphic settling
        // prematurely when the window/widget is resized, or re enetering from
        // a background state (Android).
        _paintTexture(0, forceShouldAdvance: true);
        // Texture id will have changed...
        markNeedsPaint();
      });
      // TODO (Gordon): This may not be needed
      // Forces an extra call to markNeedsPaint to help when resizing
      // while the future is completing.
      markNeedsPaint();
    }
  }

  @override
  ui.Size computeDryLayout(BoxConstraints constraints) => constraints.smallest;

  // QUESTION (GORDON): Looks like this is needed when doing `context.addLayer`.
  @override
  bool get alwaysNeedsCompositing => true;

  @override
  bool get isRepaintBoundary => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_renderTexture.isReady) {
      return;
    }
    context.addLayer(
      TextureLayer(
        rect: Rect.fromLTWH(
          offset.dx,
          offset.dy,
          _renderTexture.actualWidth.toDouble() / devicePixelRatio,
          _renderTexture.actualHeight.toDouble() / devicePixelRatio,
        ),
        textureId: _renderTexture._textureId,
        freeze: _isResizing,
        filterQuality: FilterQuality.low,
      ),
    );
    final painter = rivePainter;
    if (painter != null && painter.paintsCanvas) {
      painter.paintCanvas(context.canvas, offset, size);
    }
  }
}
