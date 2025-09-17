import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:rive_native/rive_luau.dart';
import 'package:rive_native/rive_native.dart';
import 'package:rive_native/src/console_reader.dart';
import 'package:rive_native/src/ffi/dynamic_library_helper.dart';
import 'package:rive_native/src/ffi/rive_ffi.dart';
import 'package:rive_native/src/ffi/rive_ffi_reference.dart';
import 'package:rive_native/utilities.dart';

final DynamicLibrary _nativeLib = DynamicLibraryHelper.nativeLib;

typedef LuaCFunction = Int32 Function(Pointer<Void>);
typedef LuaContinuation = Int32 Function(Pointer<Void>, Int32);

final Pointer<Void> Function(
  Pointer<Void>,
  Pointer<NativeFunction<Void Function()>>,
) _riveLuaNewState = _nativeLib
    .lookup<
        NativeFunction<
            Pointer<Void> Function(
              Pointer<Void>,
              Pointer<NativeFunction<Void Function()>>,
            )>>(
      'riveLuaNewState',
    )
    .asFunction();

final void Function(Pointer<Void> state) _riveLuaClose = _nativeLib
    .lookup<NativeFunction<Void Function(Pointer<Void>)>>('riveLuaCloseState')
    .asFunction();
final void Function(
  Pointer<Void> state,
  Pointer<Utf8> scriptName,
  Pointer<Uint8> data,
  int size,
  int env,
) _riveLuaLoad = _nativeLib
    .lookup<
        NativeFunction<
            Void Function(
              Pointer<Void>,
              Pointer<Utf8>,
              Pointer<Uint8>,
              Size,
              Int32,
            )>>('luau_load')
    .asFunction();
final bool Function(
  Pointer<Void> state,
  Pointer<Utf8> scriptName,
  Pointer<Uint8> data,
  int size,
) _riveLuaRegisterModule = _nativeLib
    .lookup<
        NativeFunction<
            Bool Function(
              Pointer<Void>,
              Pointer<Utf8>,
              Pointer<Uint8>,
              Size,
            )>>('riveLuaRegisterModule')
    .asFunction();

final bool Function(
  Pointer<Void> state,
  Pointer<Utf8> scriptName,
) _riveLuaUnregisterModule = _nativeLib
    .lookup<
        NativeFunction<
            Bool Function(
              Pointer<Void>,
              Pointer<Utf8>,
            )>>('riveLuaUnregisterModule')
    .asFunction();

final bool Function(
  Pointer<Void> state,
  Pointer<Utf8> scriptName,
  Pointer<Uint8> data,
  int size,
) _riveLuaRegisterScript = _nativeLib
    .lookup<
        NativeFunction<
            Bool Function(
              Pointer<Void>,
              Pointer<Utf8>,
              Pointer<Uint8>,
              Size,
            )>>('riveLuaRegisterScript')
    .asFunction();

final void Function(
    Pointer<Void> state,
    int idx,
    Pointer<Utf8>
        name) _riveLuaSetField = _nativeLib
    .lookup<NativeFunction<Void Function(Pointer<Void>, Int32, Pointer<Utf8>)>>(
        'lua_setfield')
    .asFunction();

final int Function(Pointer<Void> state, int idx, int name) _riveLuaGC =
    _nativeLib
        .lookup<NativeFunction<Int32 Function(Pointer<Void>, Int32, Int32)>>(
            'lua_gc')
        .asFunction();

final int Function(Pointer<Void> state, int idx, Pointer<Utf8> name)
    _riveLuaGetField = _nativeLib
        .lookup<
            NativeFunction<
                Int32 Function(
                    Pointer<Void>, Int32, Pointer<Utf8>)>>('lua_getfield')
        .asFunction();

final double Function(Pointer<Void> state, int idx, Pointer<Int32> isnum)
    _riveLuaToNumber = _nativeLib
        .lookup<
            NativeFunction<
                Double Function(
                    Pointer<Void>, Int32, Pointer<Int32>)>>('lua_tonumberx')
        .asFunction();

final int Function(Pointer<Void> state, int idx, Pointer<Int32> isnum)
    _riveLuaToInteger = _nativeLib
        .lookup<
            NativeFunction<
                Int32 Function(
                    Pointer<Void>, Int32, Pointer<Int32>)>>('lua_tointegerx')
        .asFunction();

final int Function(Pointer<Void> state, int idx) _riveLuaToBoolean = _nativeLib
    .lookup<NativeFunction<Int32 Function(Pointer<Void>, Int32)>>(
      'lua_toboolean',
    )
    .asFunction();

final int Function(Pointer<Void> state, int idx) _riveLuaType = _nativeLib
    .lookup<NativeFunction<Int32 Function(Pointer<Void>, Int32)>>(
      'lua_type',
    )
    .asFunction();

final int Function(Pointer<Void> state, int idx, Pointer<Int32> isnum)
    _riveLuaToUnsigned = _nativeLib
        .lookup<
            NativeFunction<
                Uint32 Function(
                    Pointer<Void>, Int32, Pointer<Int32>)>>('lua_tounsignedx')
        .asFunction();

final Pointer<Utf8> Function(
    Pointer<Void> state,
    int idx,
    int
        length) _riveLuaToString = _nativeLib
    .lookup<NativeFunction<Pointer<Utf8> Function(Pointer<Void>, Int32, Size)>>(
        'lua_tolstring')
    .asFunction();

final void Function(Pointer<Void> state, double value) _riveLuaPushNumber =
    _nativeLib
        .lookup<NativeFunction<Void Function(Pointer<Void>, Double)>>(
          'lua_pushnumber',
        )
        .asFunction();

final void Function(Pointer<Void> state, int index) _riveLuaPushValue =
    _nativeLib
        .lookup<NativeFunction<Void Function(Pointer<Void>, Int32)>>(
          'lua_pushvalue',
        )
        .asFunction();

final Pointer<Void> Function(Pointer<Void> state, Pointer<Void> renderer)
    _riveLuaPushRenderer = _nativeLib
        .lookup<
            NativeFunction<
                Pointer<Void> Function(Pointer<Void>, Pointer<Void>)>>(
          'riveLuaPushRenderer',
        )
        .asFunction();
final void Function(Pointer<Void> state, Pointer<Void> renderer)
    _riveLuaPushArtboard = _nativeLib
        .lookup<NativeFunction<Void Function(Pointer<Void>, Pointer<Void>)>>(
          'riveLuaPushArtboard',
        )
        .asFunction();

final Pointer<Void> Function(
    Pointer<Void> state,
    Pointer<Void>
        viewModelInstanceValue) _riveLuaPushViewModelInstanceValue = _nativeLib
    .lookup<
        NativeFunction<Pointer<Void> Function(Pointer<Void>, Pointer<Void>)>>(
      'riveLuaPushViewModelInstanceValue',
    )
    .asFunction();

final void Function(Pointer<Void> scriptedRenderer)
    _riveLuaScriptedRendererEnd = _nativeLib
        .lookup<NativeFunction<Void Function(Pointer<Void>)>>(
          'riveLuaScriptedRendererEnd',
        )
        .asFunction();

final void Function(Pointer<Void> state, int value) _riveLuaSetTop = _nativeLib
    .lookup<NativeFunction<Void Function(Pointer<Void>, Int32)>>(
      'lua_settop',
    )
    .asFunction();

final void Function(Pointer<Void> state, int value) _riveLuaReplace = _nativeLib
    .lookup<NativeFunction<Void Function(Pointer<Void>, Int32)>>(
      'lua_replace',
    )
    .asFunction();

final int Function(Pointer<Void> state) _riveLuaGetTop = _nativeLib
    .lookup<NativeFunction<Int32 Function(Pointer<Void>)>>(
      'lua_gettop',
    )
    .asFunction();

final void Function(Pointer<Void> state, int value) _riveLuaInsert = _nativeLib
    .lookup<NativeFunction<Void Function(Pointer<Void>, Int32)>>(
      'lua_insert',
    )
    .asFunction();

final void Function(Pointer<Void> state) _riveLuaPushNil = _nativeLib
    .lookup<NativeFunction<Void Function(Pointer<Void>)>>('lua_pushnil')
    .asFunction();

final void Function(Pointer<Void> state, int value) _riveLuaPushUnsigned =
    _nativeLib
        .lookup<NativeFunction<Void Function(Pointer<Void>, Uint32)>>(
          'lua_pushunsigned',
        )
        .asFunction();

final void Function(Pointer<Void> state, int value) _riveLuaPushInteger =
    _nativeLib
        .lookup<NativeFunction<Void Function(Pointer<Void>, Int32)>>(
          'lua_pushinteger',
        )
        .asFunction();

final void Function(Pointer<Void> state, Pointer<Utf8>) _riveLuaPushString =
    _nativeLib
        .lookup<NativeFunction<Void Function(Pointer<Void>, Pointer<Utf8>)>>(
          'lua_pushstring',
        )
        .asFunction();

final void Function(
  Pointer<Void> state,
  Pointer<NativeFunction<LuaCFunction>>,
  Pointer<Utf8>,
  int,
  Pointer<NativeFunction<LuaContinuation>>,
) _riveLuaPushClosure = _nativeLib
    .lookup<
        NativeFunction<
            Void Function(
              Pointer<Void>,
              Pointer<NativeFunction<LuaCFunction>>,
              Pointer<Utf8>,
              Int32,
              Pointer<NativeFunction<LuaContinuation>>,
            )>>('lua_pushcclosurek')
    .asFunction();

final void Function(Pointer<Void>, int, int) _riveLuaCall = _nativeLib
    .lookup<NativeFunction<Void Function(Pointer<Void>, Int32, Int32)>>(
      'riveLuaCall',
    )
    .asFunction();

final int Function(Pointer<Void>, int, int) _riveLuaPCall = _nativeLib
    .lookup<NativeFunction<Int32 Function(Pointer<Void>, Int32, Int32)>>(
        'riveLuaPCall')
    .asFunction();

final int Function(Pointer<Void> state) _riveStackDump = _nativeLib
    .lookup<NativeFunction<Uint32 Function(Pointer<Void>)>>('riveStackDump')
    .asFunction();

final int Function(Pointer<Void> state, int idx) _riveLuaRef = _nativeLib
    .lookup<NativeFunction<Int32 Function(Pointer<Void>, Int32)>>('lua_ref')
    .asFunction();

final void Function(Pointer<Void> state, int idx) _riveLuaUnref = _nativeLib
    .lookup<NativeFunction<Void Function(Pointer<Void>, Int32)>>('lua_unref')
    .asFunction();

final int Function(Pointer<Void> state, int idx, int n) _riveLuaRawGeti =
    _nativeLib
        .lookup<NativeFunction<Int32 Function(Pointer<Void>, Int32, Int32)>>(
            'lua_rawgeti')
        .asFunction();

class LuauStateFFI extends LuauState {
  Pointer<Void> nativePtr;
  final List<NativeCallable> _nativeCallables = [];

  LuauStateFFI(this.nativePtr);

  LuauStateFFI.fromFactory(Factory riveFactory) : nativePtr = nullptr {
    final consoleHasDataCallback = NativeCallable<Void Function()>.isolateLocal(
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      consoleHasData.notifyListeners,
    );
    _nativeCallables.add(
      consoleHasDataCallback,
    );

    nativePtr = _riveLuaNewState(
      (riveFactory as FFIFactory).pointer,
      consoleHasDataCallback.nativeFunction,
    );
  }

  @override
  void dispose() {
    _riveLuaClose(nativePtr);
    nativePtr = nullptr;
    for (final callable in _nativeCallables) {
      callable.close();
    }
    _nativeCallables.clear();
    calloc.free(_bytecodeBytes);
    _bytecodeBytes = nullptr;
  }

  @override
  void call(int numArgs, int numResults) =>
      _riveLuaCall(nativePtr, numArgs, numResults);

  Pointer<Uint8> _bytecodeBytes = calloc.allocate(4096);
  int _bytecodeBytesSize = 4096;

  @override
  void load(String name, Uint8List bytecode, {int env = 0}) {
    if (_bytecodeBytesSize < bytecode.length) {
      calloc.free(_bytecodeBytes);
      _bytecodeBytes = calloc.allocate(bytecode.length);
      _bytecodeBytesSize = bytecode.length;
    }
    _bytecodeBytes
        .asTypedList(bytecode.length)
        .setRange(0, bytecode.length, bytecode);

    _riveLuaLoad(
      nativePtr,
      toNativeString(name),
      _bytecodeBytes,
      bytecode.length,
      env,
    );
  }

  @override
  void unregisterModule(String name) => _riveLuaUnregisterModule(
        nativePtr,
        toNativeString(name),
      );

  @override
  bool registerModule(String name, Uint8List bytecode) {
    if (_bytecodeBytesSize < bytecode.length) {
      calloc.free(_bytecodeBytes);
      _bytecodeBytes = calloc.allocate(bytecode.length);
      _bytecodeBytesSize = bytecode.length;
    }
    _bytecodeBytes
        .asTypedList(bytecode.length)
        .setRange(0, bytecode.length, bytecode);

    return _riveLuaRegisterModule(
      nativePtr,
      toNativeString(name),
      _bytecodeBytes,
      bytecode.length,
    );
  }

  @override
  bool registerScript(String name, Uint8List bytecode) {
    if (_bytecodeBytesSize < bytecode.length) {
      calloc.free(_bytecodeBytes);
      _bytecodeBytes = calloc.allocate(bytecode.length);
      _bytecodeBytesSize = bytecode.length;
    }
    _bytecodeBytes
        .asTypedList(bytecode.length)
        .setRange(0, bytecode.length, bytecode);

    return _riveLuaRegisterScript(
      nativePtr,
      toNativeString(name),
      _bytecodeBytes,
      bytecode.length,
    );
  }

  @override
  LuauStatus pcall(int numArgs, int numResults) {
    int code = _riveLuaPCall(nativePtr, numArgs, numResults);
    if (code < LuauStatus.values.length) {
      return LuauStatus.values[code];
    }
    return LuauStatus.unknown;
  }

  @override
  void pushFunction(LuauFunction t, {String debugName = 'unknown'}) {
    final ff = NativeCallable<LuaCFunction>.isolateLocal(
      (Pointer<Void> pointer) => t.call(LuauStateFFI(pointer)),
      exceptionalReturn: 0,
    );
    _nativeCallables.add(ff);
    _riveLuaPushClosure(
      nativePtr,
      ff.nativeFunction,
      toNativeString(debugName),
      0,
      nullptr,
    );
  }

  @override
  void pushInteger(int value) => _riveLuaPushInteger(nativePtr, value);

  @override
  void pushNil() => _riveLuaPushNil(nativePtr);

  @override
  void pushNumber(double value) => _riveLuaPushNumber(nativePtr, value);

  @override
  void pushString(String value) =>
      _riveLuaPushString(nativePtr, toNativeString(value));

  @override
  void pushUnsigned(int value) {
    assert(value > 0);
    _riveLuaPushUnsigned(nativePtr, value);
  }

  @override
  void setField(int index, String name) =>
      _riveLuaSetField(nativePtr, index, toNativeString(name));

  @override
  LuauType getField(int index, String name) {
    final type = _riveLuaGetField(nativePtr, index, toNativeString(name));
    return LuauType.values[type];
  }

  @override
  void setTop(int index) => _riveLuaSetTop(nativePtr, index);

  @override
  void replace(int index) => _riveLuaReplace(nativePtr, index);

  @override
  int getTop() => _riveLuaGetTop(nativePtr);

  @override
  void insert(int index) => _riveLuaInsert(nativePtr, index);

  @override
  int integerAt(int index) => _riveLuaToInteger(nativePtr, index, nullptr);

  @override
  bool booleanAt(int index) => _riveLuaToBoolean(nativePtr, index) != 0;

  @override
  LuauType typeAt(int index) => LuauType.values[_riveLuaType(nativePtr, index)];

  @override
  String stringAt(int index) =>
      _riveLuaToString(nativePtr, index, 0).toDartString();

  @override
  double numberAt(int index) => _riveLuaToNumber(nativePtr, index, nullptr);

  @override
  int unsignedAt(int index) => _riveLuaToUnsigned(nativePtr, index, nullptr);

  @override
  void dumpStack() {
    _riveStackDump(nativePtr);
  }

  @override
  void pushValue(int index) => _riveLuaPushValue(nativePtr, index);

  @override
  ScriptedRenderer pushRenderer(Renderer renderer) {
    return FFIScriptedRenderer(_riveLuaPushRenderer(
        nativePtr, (renderer as RiveFFIReference).pointer));
  }

  @override
  void pushArtboard(Artboard artboard) =>
      _riveLuaPushArtboard(nativePtr, (artboard as RiveFFIReference).pointer);

  @override
  void pushViewModelInstanceValue(InternalViewModelInstanceValue value) {
    _riveLuaPushViewModelInstanceValue(
        nativePtr, (value as RiveFFIReference).pointer);
  }

  final List<ConsoleEntry> _bufferedEntries = [];

  bool _readConsole(List<ConsoleEntry> entries) {
    final result = _riveLuaConsole(nativePtr);
    final added = readConsoleEntries(result.reader, entries);
    _riveLuaConsoleClear(nativePtr);
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
  int gc(GarbageCollection what, [int data = 0]) =>
      _riveLuaGC(nativePtr, what.index, data);

  @override
  LuauType rawGeti(int idx, int n) {
    final type = _riveLuaRawGeti(nativePtr, idx, n);
    return LuauType.values[type];
  }

  @override
  int ref(int idx) => _riveLuaRef(nativePtr, idx);

  @override
  void unref(int id) => _riveLuaUnref(nativePtr, id);
}

final class BufferResponse extends Struct {
  external Pointer<Uint8> data;

  @Size()
  external int size;

  BinaryReader get reader => BinaryReader.fromList(data.asTypedList(size));
}

BufferResponse Function(
  Pointer<Void> state,
) _riveLuaConsole = _nativeLib
    .lookup<
        NativeFunction<
            BufferResponse Function(
              Pointer<Void> state,
            )>>('riveLuaConsole')
    .asFunction();

void Function(
  Pointer<Void> state,
) _riveLuaConsoleClear = _nativeLib
    .lookup<
        NativeFunction<
            Void Function(
              Pointer<Void> state,
            )>>('riveLuaConsoleClear')
    .asFunction();

class FFIScriptedRenderer extends ScriptedRenderer {
  Pointer<Void> pointer;
  FFIScriptedRenderer(this.pointer);
  @override
  void end() {
    _riveLuaScriptedRendererEnd(pointer);
    pointer = nullptr;
  }
}

LuauState makeLuauState(Factory riveFactory) =>
    LuauStateFFI.fromFactory(riveFactory);
