import 'dart:async';
import 'dart:js_interop' as js;
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:rive_native/scripting_workspace.dart';
import 'package:rive_native/src/rive_native_web.dart';
import 'package:rive_native/utilities.dart';

late js.JSFunction _makeScriptingWorkspace;
late js.JSFunction _deleteScriptingWorkspace;
late js.JSFunction _requestProblemReport;
late js.JSFunction _requestFullProblemReport;
late js.JSFunction _requestImplementedType;
late js.JSFunction _scriptingWorkspaceCompleteInsertion;
// ignore: unused_element
late js.JSFunction _scriptingWorkspaceRequestAutocomplete;
late js.JSFunction _scriptingWorkspaceHighlightRow;
late js.JSFunction _scriptingWorkspaceResponse;
late js.JSFunction _setScriptSource;
late js.JSFunction _removeScriptSource;
late js.JSFunction _checkScriptsWithRequires;
late js.JSFunction _setSystemGeneratedSource;
late js.JSFunction _scriptingWorkspaceFormat;
late js.JSFunction _scriptingWorkspaceCompile;
late js.JSFunction _nativeFontBytes;
late js.JSFunction _freeNativeFont;

class ScriptingWorkspaceResponseResultWasm
    implements ScriptingWorkspaceResponseResult {
  @override
  final bool available;
  late final ByteData? data;
  ScriptingWorkspaceResponseResultWasm(js.JSObject object)
      : available = (object['available'] as js.JSBoolean).toDart {
    data = available ? (object['data'] as js.JSDataView).toDart : null;
  }

  @override
  BinaryReader? get reader {
    final data = this.data;
    if (data == null) {
      return null;
    }

    return BinaryReader(data);
  }
}

// bool _wasmBool(js.JSAny? value) => (value as js.JSNumber).toDartInt == 1;
js.JSNumber _boolWasm(bool value) => (value ? 1 : 0).toJS;

class ScriptingWorkspaceWasm extends ScriptingWorkspace {
  static void link(js.JSObject module) {
    _makeScriptingWorkspace = module['makeScriptingWorkspace'] as js.JSFunction;
    _deleteScriptingWorkspace =
        module['_deleteScriptingWorkspace'] as js.JSFunction;
    _requestProblemReport =
        module['scriptingWorkspaceRequestProblemReport'] as js.JSFunction;
    _requestFullProblemReport =
        module['_scriptingWorkspaceRequestFullProblemReport'] as js.JSFunction;
    _requestImplementedType =
        module['scriptingWorkspaceImplementedType'] as js.JSFunction;
    _scriptingWorkspaceCompleteInsertion =
        module['scriptingWorkspaceCompleteInsertion'] as js.JSFunction;
    _scriptingWorkspaceRequestAutocomplete =
        module['scriptingWorkspaceRequestAutocomplete'] as js.JSFunction;
    _scriptingWorkspaceHighlightRow =
        module['scriptingWorkspaceHighlightRow'] as js.JSFunction;
    _scriptingWorkspaceResponse =
        module['scriptingWorkspaceResponse'] as js.JSFunction;
    _setScriptSource =
        module['scriptingWorkspaceSetScriptSource'] as js.JSFunction;
    _removeScriptSource =
        module['scriptingWorkspaceRemoveScriptSource'] as js.JSFunction;
    _checkScriptsWithRequires =
        module['_scriptingWorkspaceCheckScriptsWithRequires'] as js.JSFunction;
    _setSystemGeneratedSource =
        module['scriptingWorkspaceSetSystemGeneratedSource'] as js.JSFunction;
    _scriptingWorkspaceFormat =
        module['scriptingWorkspaceFormat'] as js.JSFunction;
    _scriptingWorkspaceCompile =
        module['scriptingWorkspaceCompile'] as js.JSFunction;
    _nativeFontBytes = module['nativeFontBytes'] as js.JSFunction;
    _freeNativeFont = module['_freeNativeFont'] as js.JSFunction;
  }

  static final Finalizer<int> _finalizer = Finalizer(
    (nativePtr) => _deleteScriptingWorkspace.callAsFunction(
      null,
      nativePtr.toJS,
    ),
  );
  int _nativePtr = 0;

  ScriptingWorkspaceWasm() {
    _nativePtr = (_makeScriptingWorkspace.callAsFunction(
      null,
      workReadyCallback.toJS,
    ) as js.JSNumber)
        .toDartInt;
    _finalizer.attach(this, _nativePtr, detach: this);
  }

  @override
  void dispose() {
    super.dispose();
    _deleteScriptingWorkspace.callAsFunction(null, _nativePtr.toJS);
    _nativePtr = 0;
    _finalizer.detach(this);
  }

  @override
  Future<AutocompleteResult> autocomplete(
      String scriptName, ScriptPosition position) {
    final workId = (_scriptingWorkspaceRequestAutocomplete.callAsFunction(
            null,
            _nativePtr.toJS,
            scriptName.toJS,
            position.line.toJS,
            position.column.toJS) as js.JSNumber)
        .toDartInt;

    return registerCompleter(workId);
  }

  @override
  InsertionCompletion completeInsertion(
      String scriptName, ScriptPosition position) {
    final completionType = (_scriptingWorkspaceCompleteInsertion.callAsFunction(
            null,
            _nativePtr.toJS,
            scriptName.toJS,
            position.line.toJS,
            position.column.toJS) as js.JSNumber)
        .toDartInt;
    return InsertionCompletion.values[completionType];
  }

  @override
  Future<FormatResult> format(String scriptName) {
    final workId = (_scriptingWorkspaceFormat.callAsFunction(
            null, _nativePtr.toJS, scriptName.toJS) as js.JSNumber)
        .toDartInt;

    return registerCompleter(workId);
  }

  @override
  Future<List<ScriptProblemResult>> fullProblemReport() {
    final workId = (_requestFullProblemReport.callAsFunction(
            null, _nativePtr.toJS) as js.JSNumber)
        .toDartInt;
    return registerCompleter(workId);
  }

  @override
  Future<ScriptProblemResult> problemReport(String scriptName) async {
    final workId = (_requestProblemReport.callAsFunction(
            null, _nativePtr.toJS, scriptName.toJS) as js.JSNumber)
        .toDartInt;
    return registerCompleter(workId);
  }

  @override
  Future<ImplementedType?> implementedType(String scriptName) async {
    final workId = (_requestImplementedType.callAsFunction(
            null, _nativePtr.toJS, scriptName.toJS) as js.JSNumber)
        .toDartInt;
    return registerCompleter(workId);
  }

  @override
  Uint32List rowHighlight(String scriptName, int row) {
    var result = _scriptingWorkspaceHighlightRow.callAsFunction(
        null, _nativePtr.toJS, scriptName.toJS, row.toJS) as js.JSUint32Array;
    return result.toDart;
  }

  @override
  Future<HighlightResult> setSystemGeneratedSource(
      String scriptName, String prefix, String source) async {
    final workId = (_setSystemGeneratedSource.callAsFunctionEx(
      null,
      _nativePtr.toJS,
      scriptName.toJS,
      prefix.toJS,
      source.toJS,
    ) as js.JSNumber)
        .toDartInt;

    return registerCompleter(workId);
  }

  @override
  Future<HighlightResult> setScriptSource(
      String scriptId, String scriptName, String source,
      {bool highlight = false}) async {
    final workId = (_setScriptSource.callAsFunctionEx(
            null,
            _nativePtr.toJS,
            scriptId.toJS,
            scriptName.toJS,
            source.toJS,
            highlight.toJS) as js.JSNumber)
        .toDartInt;
    if (!highlight) {
      return HighlightResult.unknown;
    }

    return registerCompleter(workId);
  }

  @override
  void removeScriptSource(String scriptId) => _removeScriptSource
      .callAsFunctionEx(null, _nativePtr.toJS, scriptId.toJS);

  @override
  Future<CompileResult?> compile(String scriptName,
      {bool failOnErrors = false, bool compileDependencies = false}) {
    final workId = (_scriptingWorkspaceCompile.callAsFunction(
            null,
            _nativePtr.toJS,
            scriptName.toJS,
            _boolWasm(failOnErrors),
            _boolWasm(compileDependencies)) as js.JSNumber)
        .toDartInt;
    return registerCompleter(workId);
  }

  @override
  ScriptingWorkspaceResponseResult responseForWork(int workId) =>
      ScriptingWorkspaceResponseResultWasm(
        _scriptingWorkspaceResponse.callAsFunction(
          null,
          _nativePtr.toJS,
          workId.toJS,
        ) as js.JSObject,
      );

  @override
  void checkScriptsWithRequires() => _checkScriptsWithRequires.callAsFunction(
        null,
        _nativePtr.toJS,
      );
}

ScriptingWorkspace makeScriptingWorkspace() => ScriptingWorkspaceWasm();

Uint8List getNativeFontBytes() {
  final data =
      (_nativeFontBytes.callAsFunction(null) as js.JSUint8Array).toDart;
  final result = Uint8List.fromList(data);
  _freeNativeFont.callAsFunction(null);
  return result;
}
