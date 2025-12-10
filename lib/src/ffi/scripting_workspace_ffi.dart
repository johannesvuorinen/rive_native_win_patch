// ignore_for_file: collection_methods_unrelated_type

import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:rive_native/scripting_workspace.dart';
import 'package:rive_native/src/ffi/dynamic_library_helper.dart';
import 'package:rive_native/src/ffi/rive_ffi.dart';
import 'package:rive_native/utilities.dart';

final DynamicLibrary _nativeLib = DynamicLibraryHelper.nativeLib;

Pointer<Void> Function(Pointer<NativeFunction<Void Function(Uint64)>>)
    _makeScriptingWorkspace = _nativeLib
        .lookup<
            NativeFunction<
                Pointer<Void> Function(
                  Pointer<NativeFunction<Void Function(Uint64)>>,
                )>>('makeScriptingWorkspace')
        .asFunction();
void Function(Pointer<Void> workspace) _deleteScriptingWorkspace = _nativeLib
    .lookup<NativeFunction<Void Function(Pointer<Void>)>>(
      'deleteScriptingWorkspace',
    )
    .asFunction();
int Function(
  Pointer<Void> workspace,
  Pointer<Utf8> scriptId,
  Pointer<Utf8> scriptName,
  Pointer<Utf8> source,
  bool highlight,
) _setScriptSource = _nativeLib
    .lookup<
        NativeFunction<
            Uint64 Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>,
                Pointer<Utf8>, Bool)>>('scriptingWorkspaceSetScriptSource')
    .asFunction();

void Function(Pointer<Void> workspace) _checkScriptsWithRequires = _nativeLib
    .lookup<NativeFunction<Void Function(Pointer<Void>)>>(
        'scriptingWorkspaceCheckScriptsWithRequires')
    .asFunction();

void Function(
  Pointer<Void> workspace,
  Pointer<Utf8> scriptId,
) _removeScriptSource = _nativeLib
    .lookup<NativeFunction<Void Function(Pointer<Void>, Pointer<Utf8>)>>(
        'scriptingWorkspaceRemoveScriptSource')
    .asFunction();

int Function(
  Pointer<Void> workspace,
  Pointer<Utf8> scriptName,
  Pointer<Utf8> prefix,
  Pointer<Utf8> source,
) _setSystemGeneratedSource = _nativeLib
    .lookup<
        NativeFunction<
            Uint64 Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>,
                Pointer<Utf8>)>>('scriptingWorkspaceSetSystemGeneratedSource')
    .asFunction();

int Function(Pointer<Void> workspace, Pointer<Utf8> source) _format = _nativeLib
    .lookup<NativeFunction<Uint64 Function(Pointer<Void>, Pointer<Utf8>)>>(
        'scriptingWorkspaceFormat')
    .asFunction();

int Function(Pointer<Void> workspace, Pointer<Utf8> source, bool failOnErrors,
        bool compileDependencies, int, int) _compile =
    _nativeLib
        .lookup<
            NativeFunction<
                Uint64 Function(Pointer<Void>, Pointer<Utf8>, Bool, Bool, Uint8,
                    Uint8)>>('scriptingWorkspaceCompile')
        .asFunction();

int Function(Pointer<Void> workspace, Pointer<Uint8> sourcesAndKey,
        int sourcesAndKeySize, bool failOnErrors, int, int) _compileAndSign =
    _nativeLib
        .lookup<
            NativeFunction<
                Uint64 Function(Pointer<Void>, Pointer<Uint8>, Size, Bool,
                    Uint8, Uint8)>>('scriptingWorkspaceCompileAndSign')
        .asFunction();

int Function(
        Pointer<Void> workspace,
        Pointer<Uint8> inclusionSetAndQuery,
        int inclusionSetAndQuerySize,
        bool caseSensitive,
        bool matchWholeWord,
        bool regularExpression,
        bool trim) _findInFiles =
    _nativeLib
        .lookup<
            NativeFunction<
                Uint64 Function(Pointer<Void>, Pointer<Uint8>, Size, Bool, Bool,
                    Bool, Bool)>>('scriptingWorkspaceFindInFiles')
        .asFunction();

int Function(Pointer<Void> workspace, Pointer<Utf8> source) _implementedType =
    _nativeLib
        .lookup<NativeFunction<Uint64 Function(Pointer<Void>, Pointer<Utf8>)>>(
            'scriptingWorkspaceImplementedType')
        .asFunction();

int Function(Pointer<Void>, Pointer<Utf8> scriptName) _requestProblemReport =
    _nativeLib
        .lookup<
                NativeFunction<
                    Uint64 Function(Pointer<Void>, Pointer<Utf8> scriptName)>>(
            'scriptingWorkspaceRequestProblemReport')
        .asFunction();

int Function(Pointer<Void>) _requestFullProblemReport = _nativeLib
    .lookup<NativeFunction<Uint64 Function(Pointer<Void>)>>(
        'scriptingWorkspaceRequestFullProblemReport')
    .asFunction();

int Function(Pointer<Void>, Pointer<Utf8> scriptName, int line, int column)
    _scriptingWorkspaceCompleteInsertion = _nativeLib
        .lookup<
            NativeFunction<
                Uint8 Function(
                  Pointer<Void>,
                  Pointer<Utf8> scriptName,
                  Uint32 line,
                  Uint32 column,
                )>>('scriptingWorkspaceCompleteInsertion')
        .asFunction();

int Function(
  Pointer<Void>,
  Pointer<Utf8> scriptName,
  int line,
  int column,
) _scriptingWorkspaceRequestAutocomplete = _nativeLib
    .lookup<
        NativeFunction<
            Uint64 Function(
              Pointer<Void>,
              Pointer<Utf8> scriptName,
              Uint32 line,
              Uint32 column,
            )>>('scriptingWorkspaceRequestAutocomplete')
    .asFunction();

int Function(
  Pointer<Void>,
  Pointer<Utf8> scriptName,
  int line,
  int column,
) _scriptingWorkspaceRequestGetDefinition = _nativeLib
    .lookup<
        NativeFunction<
            Uint64 Function(
              Pointer<Void>,
              Pointer<Utf8> scriptName,
              Uint32 line,
              Uint32 column,
            )>>('scriptingWorkspaceRequestGetDefinition')
    .asFunction();

HighlightBuffer Function(Pointer<Void>, Pointer<Utf8> scriptName, int row)
    _scriptingWorkspaceHighlightRow = _nativeLib
        .lookup<
            NativeFunction<
                HighlightBuffer Function(
                  Pointer<Void>,
                  Pointer<Utf8> scriptName,
                  Uint32 row,
                )>>('scriptingWorkspaceHighlightRow')
        .asFunction();

Pointer<Uint8> Function() _nativeFontBytes = _nativeLib
    .lookup<NativeFunction<Pointer<Uint8> Function()>>('nativeFontBytes')
    .asFunction();

int Function() _nativeFontSize = _nativeLib
    .lookup<NativeFunction<Size Function()>>('nativeFontSize')
    .asFunction();

void Function() _freeNativeFont = _nativeLib
    .lookup<NativeFunction<Void Function()>>('freeNativeFont')
    .asFunction();

final Pointer<Utf8> Function(Pointer<Void>)
    _scriptingWorkspaceBuiltinDefinitions = nativeLib
        .lookup<NativeFunction<Pointer<Utf8> Function(Pointer<Void>)>>(
            'scriptingWorkspaceBuiltinDefinitions')
        .asFunction();

final class HighlightBuffer extends Struct {
  @Uint32()
  external int count;

  external Pointer<Uint32> data;
}

final class ScriptingWorkspaceResponseResultFFI extends Struct
    implements ScriptingWorkspaceResponseResult {
  @override
  @Bool()
  external bool available;

  external Pointer<Uint8> data;

  @Size()
  external int size;

  @override
  BinaryReader? get reader => BinaryReader.fromList(data.asTypedList(size));
}

ScriptingWorkspaceResponseResultFFI Function(
  Pointer<Void> workspace,
  int workId,
) _scriptingWorkspaceResponse = _nativeLib
    .lookup<
        NativeFunction<
            ScriptingWorkspaceResponseResultFFI Function(
              Pointer<Void> workspace,
              Uint64 workId,
            )>>('scriptingWorkspaceResponse')
    .asFunction();

class ScriptingWorkspaceFFI extends ScriptingWorkspace {
  late Pointer<Void> _nativeWorkspace;
  NativeCallable<Void Function(Uint64)>? _callable;
  ScriptingWorkspaceFFI() {
    _callable = NativeCallable<Void Function(Uint64)>.listener(
      workReadyCallback,
    );

    final callback = _callable;
    _nativeWorkspace = callback == null
        ? nullptr
        : _makeScriptingWorkspace(callback.nativeFunction);
  }

  @override
  void dispose() {
    super.dispose();
    _deleteScriptingWorkspace(_nativeWorkspace);
    _nativeWorkspace = nullptr;
    _callable?.close();
    _callable = null;
    _completers.clear();
  }

  @override
  Future<AutocompleteResult> autocomplete(
    String scriptName,
    ScriptPosition position,
  ) {
    final scriptNameNative = scriptName.toNativeUtf8(allocator: calloc);
    final workId = _scriptingWorkspaceRequestAutocomplete(
      _nativeWorkspace,
      scriptNameNative,
      position.line,
      position.column,
    );
    calloc.free(scriptNameNative);
    return registerCompleter(workId);
  }

  @override
  Future<DefinitionResult> getDefinition(
    String scriptName,
    ScriptPosition position,
  ) {
    final scriptNameNative = scriptName.toNativeUtf8(allocator: calloc);
    final workId = _scriptingWorkspaceRequestGetDefinition(
      _nativeWorkspace,
      scriptNameNative,
      position.line,
      position.column,
    );
    calloc.free(scriptNameNative);
    return registerCompleter(workId);
  }

  @override
  Future<ImplementedType?> implementedType(String scriptName) {
    final scriptNameNative = scriptName.toNativeUtf8(allocator: calloc);
    final workId = _implementedType(_nativeWorkspace, scriptNameNative);

    return registerCompleter(workId);
  }

  @override
  Future<ScriptProblemResult> problemReport(String scriptName) {
    final scriptNameNative = toNativeString(scriptName);
    final workId = _requestProblemReport(_nativeWorkspace, scriptNameNative);
    return registerCompleter(workId);
  }

  @override
  Future<List<ScriptProblemResult>> fullProblemReport() {
    final workId = _requestFullProblemReport(_nativeWorkspace);
    return registerCompleter(workId);
  }

  final HashMap<int, Completer> _completers = HashMap<int, Completer>();

  @override
  Future<HighlightResult> setSystemGeneratedSource(
      String scriptName, String prefix, String source) async {
    final scriptNameNative = scriptName.toNativeUtf8(allocator: calloc);
    final prefixNative = prefix.toNativeUtf8(allocator: calloc);
    final sourceNative = toNativeString(source);
    final workId = _setSystemGeneratedSource(
        _nativeWorkspace, scriptNameNative, prefixNative, sourceNative);
    calloc.free(scriptNameNative);
    calloc.free(prefixNative);
    return registerCompleter(workId);
  }

  @override
  Future<HighlightResult> setScriptSource(
    String scriptId,
    String scriptName,
    String source, {
    bool highlight = false,
  }) async {
    final scriptIdNative = scriptId.toNativeUtf8(allocator: calloc);
    final scriptNameNative = scriptName.toNativeUtf8(allocator: calloc);
    final sourceNative = toNativeString(source);
    final workId = _setScriptSource(_nativeWorkspace, scriptIdNative,
        scriptNameNative, sourceNative, highlight);
    calloc.free(scriptNameNative);
    calloc.free(scriptIdNative);
    if (!highlight) {
      return HighlightResult.unknown;
    }
    return registerCompleter(workId);
  }

  @override
  void removeScriptSource(String scriptId) =>
      _removeScriptSource(_nativeWorkspace, toNativeString(scriptId));

  @override
  void checkScriptsWithRequires() =>
      _checkScriptsWithRequires(_nativeWorkspace);

  @override
  Future<FormatResult> format(String scriptName) async {
    final sourceNative = toNativeString(scriptName);
    final workId = _format(_nativeWorkspace, sourceNative);

    return registerCompleter(workId);
  }

  @override
  Future<CompileResult?> compile(
    String scriptName, {
    bool failOnErrors = false,
    bool compileDependencies = false,
    OptimizationLevel optimizationLevel = OptimizationLevel.medium,
    DebugLevel debugLevel = DebugLevel.medium,
  }) async {
    final sourceNative = toNativeString(scriptName);
    final workId = _compile(_nativeWorkspace, sourceNative, failOnErrors,
        compileDependencies, optimizationLevel.index, debugLevel.index);

    return registerCompleter(workId);
  }

  @override
  Future<CompileAndSignResult?> compileAndSign(
    Iterable<String> scriptNames,
    Uint8List privateKey, {
    bool failOnErrors = false,
    OptimizationLevel optimizationLevel = OptimizationLevel.medium,
    DebugLevel debugLevel = DebugLevel.medium,
  }) {
    assert(privateKey.length == 64, "private key must be 64 bytes long");
    final writer = BinaryWriter();
    writer.writeVarUint(scriptNames.length);
    for (final name in scriptNames) {
      writer.writeString(name);
    }
    writer.writeVarUint(privateKey.length);
    writer.write(privateKey);
    final buffer = writer.uint8Buffer;
    final memory = calloc.allocate<Uint8>(buffer.length);
    memory.asTypedList(buffer.length).setAll(0, buffer);

    final workId = _compileAndSign(_nativeWorkspace, memory, buffer.length,
        failOnErrors, optimizationLevel.index, debugLevel.index);
    calloc.free(memory);
    return registerCompleter(workId);
  }

  @override
  Future<FindInFilesResult> findInFiles(
    Iterable<String>? inclusionSet,
    String query, {
    bool caseSensitive = false,
    bool matchWholeWord = false,
    bool regularExpression = false,
    bool trim = false,
  }) {
    final writer = BinaryWriter();
    final inclusionList = inclusionSet?.toList() ?? [];
    writer.writeVarUint(inclusionList.length);
    for (final name in inclusionList) {
      writer.writeString(name);
    }
    writer.writeString(query);
    final buffer = writer.uint8Buffer;
    final memory = calloc.allocate<Uint8>(buffer.length);
    memory.asTypedList(buffer.length).setAll(0, buffer);

    final workId = _findInFiles(_nativeWorkspace, memory, buffer.length,
        caseSensitive, matchWholeWord, regularExpression, trim);
    calloc.free(memory);
    return registerCompleter(workId);
  }

  @override
  Uint32List rowHighlight(String scriptName, int row) {
    final scriptNameNative = toNativeString(scriptName);
    final result = _scriptingWorkspaceHighlightRow(
      _nativeWorkspace,
      scriptNameNative,
      row,
    );
    return result.data.asTypedList(result.count);
  }

  @override
  InsertionCompletion completeInsertion(
    String scriptName,
    ScriptPosition position,
  ) {
    var scriptNameNative = toNativeString(scriptName);
    var completionType = _scriptingWorkspaceCompleteInsertion(
      _nativeWorkspace,
      scriptNameNative,
      position.line,
      position.column,
    );
    return InsertionCompletion.values[completionType];
  }

  @override
  ScriptingWorkspaceResponseResult responseForWork(int workId) =>
      _scriptingWorkspaceResponse(_nativeWorkspace, workId);

  @override
  String get builtinDefinitions =>
      _scriptingWorkspaceBuiltinDefinitions(_nativeWorkspace).toDartString();
}

ScriptingWorkspace makeScriptingWorkspace() => ScriptingWorkspaceFFI();
Uint8List getNativeFontBytes() {
  final bytes = _nativeFontBytes();
  final size = _nativeFontSize();

  final result = Uint8List.fromList(bytes.asTypedList(size));
  _freeNativeFont();
  return result;
}
