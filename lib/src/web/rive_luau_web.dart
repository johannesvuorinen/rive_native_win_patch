import 'dart:collection';
import 'dart:js_interop' as js;
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:rive_native/rive_luau.dart';
import 'package:rive_native/rive_native.dart';
import 'package:rive_native/src/console_reader.dart';
import 'package:rive_native/src/rive_native_web.dart';
import 'package:rive_native/src/web/rive_renderer_web.dart';
import 'package:rive_native/src/web/rive_web.dart';
import 'package:rive_native/utilities.dart';

late js.JSFunction _riveLuaNewState;
late js.JSFunction _riveLuaClose;
late js.JSFunction _riveLuaLoad;
late js.JSFunction _riveLuaRegisterModule;
late js.JSFunction _riveLuaUnregisterModule;
late js.JSFunction _riveLuaRegisterScript;
late js.JSFunction _riveLuaSetField;
late js.JSFunction _riveLuaGetField;
late js.JSFunction _riveLuaToNumber;
late js.JSFunction _riveLuaToInteger;
late js.JSFunction _riveLuaToBoolean;
late js.JSFunction _riveLuaType;
late js.JSFunction _riveLuaToUnsigned;
late js.JSFunction _riveLuaToString;
late js.JSFunction _riveLuaPushNumber;
late js.JSFunction _riveLuaPushValue;
late js.JSFunction _riveLuaPushRenderer;
late js.JSFunction _riveLuaPushArtboard;
late js.JSFunction _riveLuaPushViewModelInstanceValue;
late js.JSFunction _riveLuaScriptedRendererEnd;
late js.JSFunction _riveLuaSetTop;
late js.JSFunction _riveLuaReplace;
late js.JSFunction _riveLuaGetTop;
late js.JSFunction _riveLuaInsert;
late js.JSFunction _riveLuaPushNil;
late js.JSFunction _riveLuaPushUnsigned;
late js.JSFunction _riveLuaPushInteger;
late js.JSFunction _riveLuaPushString;
late js.JSFunction _riveLuaPushBoolean;
late js.JSFunction _riveLuaPushClosure;
late js.JSFunction _riveLuaCall;
late js.JSFunction _riveLuaPCall;
late js.JSFunction _riveStackDump;
late js.JSFunction _riveLuaRef;
late js.JSFunction _riveLuaUnref;
late js.JSFunction _riveLuaRawGeti;
late js.JSFunction _riveLuaConsole;
late js.JSFunction _riveLuaConsoleClear;
late js.JSFunction _riveLuaGC;
late js.JSFunction _riveLuaScriptedDataValueType;
late js.JSFunction _riveLuaScriptedDataValueNumberValue;
late js.JSFunction _riveLuaScriptedDataValueStringValue;
late js.JSFunction _riveLuaScriptedDataValueBooleanValue;
late js.JSFunction _riveLuaScriptedDataValueColorValue;
late js.JSFunction _riveLuaPushDataValueNumber;
late js.JSFunction _riveLuaPushDataValueString;
late js.JSFunction _riveLuaPushDataValueBoolean;
late js.JSFunction _riveLuaPushDataValueColor;
late js.JSFunction _riveLuaToDataValue;
late js.JSFunction _riveLuaToPath;
late js.JSFunction _riveLuaPushPath;
late js.JSFunction _riveLuaRenderPath;
late js.JSFunction _riveLuaRegisterStateWithFile;
late js.JSFunction _riveLuaPushVector;
late js.JSFunction _riveLuaToVector;
late js.JSFunction _riveLuaPushPointerEvent;
late js.JSFunction _riveLuaPointerEventHitResult;
late js.JSFunction _riveLuaCreateTable;
late js.JSFunction _riveLuaRemove;
late js.JSFunction _riveLuaSetMetaTable;
late js.JSFunction _riveLuaEqual;
late js.JSFunction _riveLuaLessThan;
late js.JSFunction _riveLuaWhere;

bool _wasmBool(js.JSAny? value) => (value as js.JSNumber).toDartInt == 1;

class LuauStateWasm extends LuauState {
  static void link(js.JSObject module) {
    _riveLuaNewState = module['riveLuaNewState'] as js.JSFunction;
    _riveLuaClose = module['_riveLuaCloseState'] as js.JSFunction;
    _riveLuaLoad = module['_luau_load'] as js.JSFunction;
    _riveLuaRegisterModule = module['_riveLuaRegisterModule'] as js.JSFunction;
    _riveLuaUnregisterModule =
        module['_riveLuaUnregisterModule'] as js.JSFunction;
    _riveLuaRegisterScript = module['_riveLuaRegisterScript'] as js.JSFunction;
    _riveLuaSetField = module['_lua_setfield'] as js.JSFunction;
    _riveLuaGetField = module['_lua_getfield'] as js.JSFunction;
    _riveLuaToNumber = module['_lua_tonumberx'] as js.JSFunction;
    _riveLuaToInteger = module['_lua_tointegerx'] as js.JSFunction;
    _riveLuaToBoolean = module['_lua_toboolean'] as js.JSFunction;
    _riveLuaType = module['_lua_type'] as js.JSFunction;
    _riveLuaToUnsigned = module['_lua_tounsignedx'] as js.JSFunction;
    _riveLuaToString = module['_lua_tolstring'] as js.JSFunction;
    _riveLuaPushNumber = module['_lua_pushnumber'] as js.JSFunction;
    _riveLuaPushValue = module['_lua_pushvalue'] as js.JSFunction;
    _riveLuaPushRenderer = module['_riveLuaPushRenderer'] as js.JSFunction;
    _riveLuaPushArtboard = module['_riveLuaPushArtboard'] as js.JSFunction;
    _riveLuaPushViewModelInstanceValue =
        module['_riveLuaPushViewModelInstanceValue'] as js.JSFunction;
    _riveLuaScriptedRendererEnd =
        module['_riveLuaScriptedRendererEnd'] as js.JSFunction;
    _riveLuaSetTop = module['_lua_settop'] as js.JSFunction;
    _riveLuaReplace = module['_lua_replace'] as js.JSFunction;
    _riveLuaGetTop = module['_lua_gettop'] as js.JSFunction;
    _riveLuaInsert = module['_lua_insert'] as js.JSFunction;
    _riveLuaPushNil = module['_lua_pushnil'] as js.JSFunction;
    _riveLuaPushUnsigned = module['_lua_pushunsigned'] as js.JSFunction;
    _riveLuaPushInteger = module['_lua_pushinteger'] as js.JSFunction;
    _riveLuaPushString = module['_lua_pushstring'] as js.JSFunction;
    _riveLuaPushBoolean = module['_lua_pushboolean'] as js.JSFunction;
    _riveLuaPushClosure = module['riveLuaPushClosure'] as js.JSFunction;
    _riveLuaCall = module['_riveLuaCall'] as js.JSFunction;
    _riveLuaPCall = module['_riveLuaPCall'] as js.JSFunction;
    _riveStackDump = module['_riveStackDump'] as js.JSFunction;
    _riveLuaRef = module['_lua_ref'] as js.JSFunction;
    _riveLuaUnref = module['_lua_unref'] as js.JSFunction;
    _riveLuaRawGeti = module['_lua_rawgeti'] as js.JSFunction;
    _riveLuaConsole = module['riveLuaConsole'] as js.JSFunction;
    _riveLuaConsoleClear = module['_riveLuaConsoleClear'] as js.JSFunction;
    _riveLuaGC = module['_lua_gc'] as js.JSFunction;
    _riveLuaScriptedDataValueType =
        module['_riveLuaScriptedDataValueType'] as js.JSFunction;
    _riveLuaScriptedDataValueNumberValue =
        module['_riveLuaScriptedDataValueNumberValue'] as js.JSFunction;
    _riveLuaScriptedDataValueStringValue =
        module['_riveLuaScriptedDataValueStringValue'] as js.JSFunction;
    _riveLuaScriptedDataValueBooleanValue =
        module['_riveLuaScriptedDataValueBooleanValue'] as js.JSFunction;
    _riveLuaScriptedDataValueColorValue =
        module['_riveLuaScriptedDataValueColorValue'] as js.JSFunction;
    _riveLuaPushDataValueNumber =
        module['_riveLuaPushDataValueNumber'] as js.JSFunction;
    _riveLuaPushDataValueString =
        module['_riveLuaPushDataValueString'] as js.JSFunction;
    _riveLuaPushDataValueBoolean =
        module['_riveLuaPushDataValueBoolean'] as js.JSFunction;
    _riveLuaPushDataValueColor =
        module['_riveLuaPushDataValueColor'] as js.JSFunction;
    _riveLuaToDataValue = module['_riveLuaDataValue'] as js.JSFunction;
    _riveLuaToPath = module['_riveLuaPath'] as js.JSFunction;
    _riveLuaPushPath = module['_riveLuaPushPath'] as js.JSFunction;
    _riveLuaRenderPath = module['_riveLuaRenderPath'] as js.JSFunction;
    _riveLuaRegisterStateWithFile = module['_setScriptingVM'] as js.JSFunction;
    _riveLuaPushVector = module['_lua_pushvector2'] as js.JSFunction;
    _riveLuaToVector = module['_lua_tovector'] as js.JSFunction;
    _riveLuaPushPointerEvent =
        module['_riveLuaPushPointerEvent'] as js.JSFunction;
    _riveLuaPointerEventHitResult =
        module['_riveLuaPointerEventHitResult'] as js.JSFunction;
    _riveLuaCreateTable = module['_lua_createtable'] as js.JSFunction;
    _riveLuaRemove = module['_lua_remove'] as js.JSFunction;
    _riveLuaSetMetaTable = module['_lua_setmetatable'] as js.JSFunction;
    _riveLuaEqual = module['_lua_equal'] as js.JSFunction;
    _riveLuaLessThan = module['_lua_lessthan'] as js.JSFunction;
    _riveLuaWhere = module['_luaL_where'] as js.JSFunction;
  }

  js.JSAny _nativePtr = 0.toJS;
  int get _nativeIntegerPointer => (_nativePtr as js.JSNumber).toDartInt;

  @js.JSExport()
  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  void notifyConsoleHasData() => consoleHasData.notifyListeners();

  LuauStateWasm(WebFactory riveFactory) {
    _nativePtr = _riveLuaNewState.callAsFunction(
      null,
      riveFactory.pointer,
      notifyConsoleHasData.toJS,
    ) as js.JSAny;
    _states[_nativeIntegerPointer] = this;
  }

  int get pointer => _nativeIntegerPointer;

  @override
  void dispose() {
    _states.remove(_nativeIntegerPointer);
    _riveLuaClose.callAsFunction(null, _nativePtr);
    _nativePtr = 0.toJS;
  }

  final List<ConsoleEntry> _bufferedEntries = [];

  bool _readConsole(List<ConsoleEntry> entries) {
    final result = _riveLuaConsole.callAsFunction(null, _nativePtr);
    if (result == null) {
      return false;
    }

    final byteData = (result as js.JSDataView).toDart;

    final added = readConsoleEntries(BinaryReader(byteData), entries);
    _riveLuaConsoleClear.callAsFunction(null, _nativePtr);
    return added;
  }

  @override
  bool readConsole(List<ConsoleEntry> entries) {
    bool read = _bufferedEntries.isNotEmpty;
    if (read) {
      entries.addAll(_bufferedEntries);
      _bufferedEntries.clear();
    }
    return _readConsole(entries) || read;
  }

  @override
  void writeConsole(ConsoleEntry entry) {
    _readConsole(_bufferedEntries);
    _bufferedEntries.add(entry);
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    consoleHasData.notifyListeners();
  }

  @override
  bool booleanAt(int index) =>
      _wasmBool(_riveLuaToBoolean.callAsFunction(null, _nativePtr, index.toJS));

  @override
  void call(int numArgs, int numResults) => _riveLuaCall.callAsFunction(
      null, _nativePtr, numArgs.toJS, numResults.toJS);

  @override
  void dumpStack() => _riveStackDump.callAsFunction(null, _nativePtr);

  @override
  LuauType getField(int index, String name) => RiveWasm.toNativeString(
        name,
        (namePointer) {
          final type = (_riveLuaGetField.callAsFunction(
                  null, _nativePtr, index.toJS, namePointer) as js.JSNumber)
              .toDartInt;
          return LuauType.values[type];
        },
      );

  @override
  int getTop() =>
      (_riveLuaGetTop.callAsFunction(null, _nativePtr) as js.JSNumber)
          .toDartInt;

  @override
  void insert(int index) =>
      _riveLuaInsert.callAsFunction(null, _nativePtr, index.toJS);

  @override
  int integerAt(int index) =>
      (_riveLuaToInteger.callAsFunction(null, _nativePtr, index.toJS, 0.toJS)
              as js.JSNumber)
          .toDartInt;

  @override
  void load(String name, Uint8List bytecode, {int env = 0}) =>
      RiveWasm.toNativeString(
        name,
        (namePointer) {
          final bytecodeBuffer = WasmBuffer.fromBytes(bytecode);
          _riveLuaLoad.callAsFunctionEx(null, _nativePtr, namePointer,
              bytecodeBuffer.pointer, bytecode.length.toJS, env.toJS);
          bytecodeBuffer.dispose();
        },
      );

  @override
  bool registerModule(
    String name,
    Uint8List bytecode,
  ) =>
      RiveWasm.toNativeString(
        name,
        (namePointer) {
          final bytecodeBuffer = WasmBuffer.fromBytes(bytecode);
          final result = _wasmBool(_riveLuaRegisterModule.callAsFunctionEx(
              null,
              _nativePtr,
              namePointer,
              bytecodeBuffer.pointer,
              bytecode.length.toJS));
          bytecodeBuffer.dispose();
          return result;
        },
      );

  @override
  void unregisterModule(
    String name,
  ) =>
      RiveWasm.toNativeString(
        name,
        (namePointer) {
          _riveLuaUnregisterModule.callAsFunction(
            null,
            _nativePtr,
            namePointer,
          );
        },
      );

  @override
  bool registerScript(
    String name,
    Uint8List bytecode,
  ) =>
      RiveWasm.toNativeString(
        name,
        (namePointer) {
          final bytecodeBuffer = WasmBuffer.fromBytes(bytecode);
          final result = _wasmBool(_riveLuaRegisterScript.callAsFunction(
              null,
              _nativePtr,
              namePointer,
              bytecodeBuffer.pointer,
              bytecode.length.toJS));
          bytecodeBuffer.dispose();
          return result;
        },
      );

  @override
  void registerStateWithFile(covariant WebRiveFile file) =>
      _riveLuaRegisterStateWithFile.callAsFunction(
          null, _nativePtr, file.pointer.toJS);

  @override
  double numberAt(int index) =>
      (_riveLuaToNumber.callAsFunction(null, _nativePtr, index.toJS, 0.toJS)
              as js.JSNumber)
          .toDartDouble;

  @override
  LuauStatus pcall(int numArgs, int numResults) {
    int code = (_riveLuaPCall.callAsFunction(
            null, _nativePtr, numArgs.toJS, numResults.toJS) as js.JSNumber)
        .toDartInt;
    if (code < LuauStatus.values.length) {
      return LuauStatus.values[code];
    }
    return LuauStatus.unknown;
  }

  static js.JSNumber _callback(int luaState, int index) {
    final state = _states[luaState];
    if (state == null) {
      return 0.toJS;
    }
    final callback = state._registeredFunctions[index];
    return callback(state).toJS;
  }

  final List<LuauFunction> _registeredFunctions = [];
  static final HashMap<int, LuauStateWasm> _states =
      HashMap<int, LuauStateWasm>();

  @override
  void pushFunction(LuauFunction t, {String debugName = 'unknown'}) =>
      RiveWasm.toNativeString(
        debugName,
        (debugNamePointer) {
          _registeredFunctions.add(t);
          _riveLuaPushClosure.callAsFunctionEx(
            null,
            _nativePtr,
            _callback.toJS,
            debugNamePointer,
          );
        },
      );

  @override
  void pushInteger(int value) =>
      _riveLuaPushInteger.callAsFunction(null, _nativePtr, value.toJS);

  @override
  void pushNil() => _riveLuaPushNil.callAsFunction(null, _nativePtr);

  @override
  void pushNumber(double value) =>
      _riveLuaPushNumber.callAsFunction(null, _nativePtr, value.toJS);

  @override
  ScriptedRenderer pushRenderer(covariant WebRiveRenderer renderer) =>
      ScriptedRendererWasm(_riveLuaPushRenderer.callAsFunction(
          null, _nativePtr, renderer.jsRendererPtr) as js.JSAny);

  @override
  void pushArtboard(covariant WebRiveArtboard artboard) => _riveLuaPushArtboard
      .callAsFunction(null, _nativePtr, artboard.pointer.toJS);

  @override
  void pushViewModelInstanceValue(
      covariant WebInternalViewModelInstanceValue value) {
    _riveLuaPushViewModelInstanceValue.callAsFunction(
        null, _nativePtr, value.pointer.toJS);
  }

  @override
  void pushString(String value) => RiveWasm.toNativeString(
        value,
        (valuePointer) => _riveLuaPushString.callAsFunction(
          null,
          _nativePtr,
          valuePointer,
        ),
      );

  @override
  void pushUnsigned(int value) {
    assert(value > 0);
    _riveLuaPushUnsigned.callAsFunction(null, _nativePtr, value.toJS);
  }

  @override
  void pushBoolean(bool value) =>
      _riveLuaPushBoolean.callAsFunction(null, _nativePtr, value.toJS);

  @override
  void pushValue(int index) =>
      _riveLuaPushValue.callAsFunction(null, _nativePtr, index.toJS);

  @override
  void setField(int index, String name) => RiveWasm.toNativeString(
        name,
        (namePointer) => _riveLuaSetField.callAsFunction(
          null,
          _nativePtr,
          index.toJS,
          namePointer,
        ),
      );

  @override
  void setTop(int index) =>
      _riveLuaSetTop.callAsFunction(null, _nativePtr, index.toJS);

  @override
  void replace(int index) =>
      _riveLuaReplace.callAsFunction(null, _nativePtr, index.toJS);

  @override
  String stringAt(int index) => RiveWasm.toDartString((_riveLuaToString
          .callAsFunction(null, _nativePtr, index.toJS, 0.toJS) as js.JSNumber)
      .toDartInt);

  @override
  LuauType typeAt(int index) => LuauType.values[
      (_riveLuaType.callAsFunction(null, _nativePtr, index.toJS) as js.JSNumber)
          .toDartInt];

  @override
  int unsignedAt(int index) =>
      (_riveLuaToUnsigned.callAsFunction(null, _nativePtr, index.toJS, 0.toJS)
              as js.JSNumber)
          .toDartInt;

  @override
  LuauType rawGeti(int idx, int n) {
    final type = (_riveLuaRawGeti.callAsFunction(
            null, _nativePtr, idx.toJS, n.toJS) as js.JSNumber)
        .toDartInt;
    return LuauType.values[type];
  }

  @override
  int ref(int idx) =>
      (_riveLuaRef.callAsFunction(null, _nativePtr, idx.toJS) as js.JSNumber)
          .toDartInt;

  @override
  void unref(int id) => _riveLuaUnref.callAsFunction(null, _nativePtr, id.toJS);

  @override
  int gc(GarbageCollection what, [int data = 0]) =>
      (_riveLuaGC.callAsFunction(null, _nativePtr, what.index.toJS, data.toJS)
              as js.JSNumber)
          .toDartInt;

  @override
  ScriptedDataValue pushDataValueNumber(double value) {
    final nativeDataValueNumber = _riveLuaPushDataValueNumber.callAsFunction(
        null, _nativePtr, value.toJS) as js.JSAny;
    return ScriptedDataValueWasm(nativeDataValueNumber);
  }

  @override
  ScriptedDataValue pushDataValueString(String value) {
    final nativeDataValueString = _riveLuaPushDataValueString.callAsFunction(
        null, _nativePtr, value.toJS) as js.JSAny;
    return ScriptedDataValueWasm(nativeDataValueString);
  }

  @override
  ScriptedDataValue pushDataValueBoolean(bool value) {
    final nativeDataValueNumber = _riveLuaPushDataValueBoolean.callAsFunction(
        null, _nativePtr, value.toJS) as js.JSAny;
    return ScriptedDataValueWasm(nativeDataValueNumber);
  }

  @override
  ScriptedDataValue pushDataValueColor(int value) {
    final nativeDataValueColor = _riveLuaPushDataValueColor.callAsFunction(
        null, _nativePtr, value.toJS) as js.JSAny;
    return ScriptedDataValueWasm(nativeDataValueColor);
  }

  @override
  ScriptedDataValue dataValueAt(int index) => ScriptedDataValueWasm(
      _riveLuaToDataValue.callAsFunction(null, _nativePtr, index.toJS)
          as js.JSAny);

  @override
  ScriptedPath pathAt(int index) => ScriptedPathWasm(_nativePtr,
      _riveLuaToPath.callAsFunction(null, _nativePtr, index.toJS) as js.JSAny);

  @override
  void pushVector(Vec2D value) => _riveLuaPushVector.callAsFunction(
      null, _nativePtr, value.x.toJS, value.y.toJS);

  @override
  Vec2D vectorAt(int index) {
    final pointer = (_riveLuaToVector.callAsFunction(
            null, _nativePtr, index.toJS) as js.JSNumber)
        .toDartInt;
    final content = RiveWasm.heapViewF32(pointer, 2);
    return Vec2D.fromValues(content[0], content[1]);
  }

  @override
  PointerEvent pushPointerEvent(int id, Vec2D position) => PointerEventWeb(
        _riveLuaPushPointerEvent.callAsFunction(
                null, _nativePtr, id.toJS, position.x.toJS, position.y.toJS)
            as js.JSNumber,
      );

  @override
  void createTable({int arraySize = 0, int recordCount = 0}) =>
      _riveLuaCreateTable.callAsFunction(
          null, _nativePtr, arraySize.toJS, recordCount.toJS);

  @override
  void remove(int index) =>
      _riveLuaRemove.callAsFunction(null, _nativePtr, index.toJS);

  @override
  void setMetaTable(int index) =>
      _riveLuaSetMetaTable.callAsFunction(null, _nativePtr, index.toJS);

  @override
  bool equal(int index1, int index2) => _wasmBool(
      _riveLuaEqual.callAsFunction(null, _nativePtr, index1.toJS, index2.toJS));

  @override
  bool lessThan(int index1, int index2) => _wasmBool(_riveLuaLessThan
      .callAsFunction(null, _nativePtr, index1.toJS, index2.toJS));

  @override
  void where(int level) =>
      _riveLuaWhere.callAsFunction(null, _nativePtr, level.toJS);

  @override
  void pushPath(RenderPath path) {
    final webRenderPath = path as WebRenderPath;
    _riveLuaPushPath.callAsFunction(null, _nativePtr,
        webRenderPath.riveFactory.pointer, webRenderPath.pointer);
  }
}

class ScriptedRendererWasm extends ScriptedRenderer {
  js.JSAny pointer;
  ScriptedRendererWasm(this.pointer);
  @override
  void end() {
    _riveLuaScriptedRendererEnd.callAsFunction(null, pointer);
    pointer = 0.toJS;
  }
}

LuauState makeLuauState(Factory riveFactory) =>
    LuauStateWasm(riveFactory as WebFactory);

class PointerEventWeb extends PointerEvent {
  final js.JSAny pointer;
  PointerEventWeb(this.pointer);
  @override
  HitResult get hitResult => HitResult.values[(_riveLuaPointerEventHitResult
          .callAsFunction(null, pointer) as js.JSNumber)
      .toDartInt];
}

class ScriptedPathWasm extends ScriptedPath {
  final js.JSAny statePtr;
  final js.JSAny pointer;
  ScriptedPathWasm(this.statePtr, this.pointer);

  @override
  RenderPath? renderPath(
    RenderPath path,
  ) {
    final riveFactory = (path as WebRenderPath).riveFactory;
    final renderPathPointer = (_riveLuaRenderPath.callAsFunction(
        null, statePtr, pointer) as js.JSNumber);
    final webRenderPath =
        WebRenderPath.fromPointer(riveFactory, renderPathPointer);
    return webRenderPath;
  }
}

class ScriptedDataValueWasm extends ScriptedDataValue {
  final js.JSAny pointer;
  ScriptedDataValueWasm(this.pointer);

  @override
  String get type {
    return RiveWasm.toDartString(
        (_riveLuaScriptedDataValueType.callAsFunction(null, pointer)
                as js.JSNumber)
            .toDartInt,
        deleteNative: true);
  }

  @override
  double numberValue() {
    final val = (_riveLuaScriptedDataValueNumberValue.callAsFunction(
            null, pointer) as js.JSNumber)
        .toDartDouble;
    return val;
  }

  @override
  String stringValue() {
    return RiveWasm.toDartString(
        (_riveLuaScriptedDataValueStringValue.callAsFunction(null, pointer)
                as js.JSNumber)
            .toDartInt,
        deleteNative: true);
  }

  @override
  bool booleanValue() {
    return _wasmBool(_riveLuaScriptedDataValueBooleanValue.callAsFunction(
      null,
      pointer,
    ));
  }

  @override
  int colorValue() {
    return (_riveLuaScriptedDataValueColorValue.callAsFunction(
      null,
      pointer,
    ) as js.JSNumber)
        .toDartInt;
  }
}
