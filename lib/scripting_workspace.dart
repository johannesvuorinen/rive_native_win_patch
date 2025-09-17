import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:rive_native/src/utilities/utilities.dart';

import 'package:rive_native/src/ffi/scripting_workspace_ffi.dart'
    if (dart.library.js_interop) 'package:rive_native/src/web/scripting_workspace_web.dart';
import 'package:rive_native/utilities.dart';

enum HighlightScope {
  none,
  keyword,
  type,
  literal,
  number,
  operator,
  punctuation,
  property,
  string,
  comment,
  boolean,
  nil,
  interpString,
  function
}

class FormatOp {
  final ScriptPosition position;
  Object? userdata;
  FormatOp({required this.position});
}

class FormatOpInsert extends FormatOp {
  final String text;

  FormatOpInsert({
    required super.position,
    required this.text,
  });
}

class FormatOpErase extends FormatOp {
  final ScriptPosition positionEnd;

  FormatOpErase({required super.position, required this.positionEnd});
}

class FormatResult {
  final List<FormatOp> operations;

  FormatResult({required this.operations});

  static FormatResult read(BinaryReader reader) {
    final List<FormatOp> operations = [];
    while (!reader.isEOF) {
      switch (reader.readUint8()) {
        case 1:
          final line = reader.readVarUint();
          final column = reader.readVarUint();
          final text = reader.readString();
          operations.add(
            FormatOpInsert(
              position: ScriptPosition(line: line, column: column),
              text: text,
            ),
          );
          break;
        case 0:
          final lineFrom = reader.readVarUint();
          final columnFrom = reader.readVarUint();
          final lineTo = reader.readVarUint();
          final columnTo = reader.readVarUint();
          operations.add(
            FormatOpErase(
              position: ScriptPosition(line: lineFrom, column: columnFrom),
              positionEnd: ScriptPosition(line: lineTo, column: columnTo),
            ),
          );
          break;
      }
    }
    return FormatResult(operations: operations);
  }
}

class ScriptPosition implements Comparable<ScriptPosition> {
  final int line;
  final int column;

  const ScriptPosition({required this.line, required this.column});
  static ScriptPosition read(BinaryReader reader) {
    var line = reader.readVarUint();
    var column = reader.readVarUint();
    return ScriptPosition(line: line, column: column);
  }

  @override
  int get hashCode => szudzik(line, column);

  @override
  bool operator ==(Object other) =>
      other is ScriptPosition && other.line == line && other.column == column;

  @override
  String toString() => 'Ln $line, Col $column';

  @override
  int compareTo(ScriptPosition other) {
    if (line < other.line) {
      return -1;
    }
    if (line > other.line) {
      return 1;
    }
    if (column < other.column) {
      return -1;
    }
    if (column > other.column) {
      return 1;
    }
    return 0;
  }
}

class ScriptRange {
  final ScriptPosition begin;
  final ScriptPosition end;

  const ScriptRange({required this.begin, required this.end});
  static ScriptRange read(BinaryReader reader) {
    final begin = ScriptPosition.read(reader);
    final end = ScriptPosition.read(reader);

    return ScriptRange(begin: begin, end: end);
  }

  bool get isCollapsed => begin == end;

  @override
  String toString() => '$begin -> $end';

  @override
  int get hashCode =>
      Object.hash(begin.line, begin.column, end.line, end.column);

  @override
  bool operator ==(Object other) =>
      other is ScriptRange && other.begin == begin && other.end == end;
}

enum ScriptProblemType {
  unknown,

  linterUnknownGlobal,
  linterDeprecatedGlobal,
  linterGlobalUsedAsLocal,
  linterLocalShadow,
  linterSameLineStatement,
  linterMultiLineStatement,
  linterLocalUnused,
  linterFunctionUnused,
  linterImportUnused,
  linterBuiltinGlobalWrite,
  linterPlaceholderRead,
  linterUnreachableCode,
  linterUnknownType,
  linterForRange,
  linterUnbalancedAssignment,
  linterImplicitReturn,
  linterDuplicateLocal,
  linterFormatString,
  linterTableLiteral,
  linterUninitializedLocal,
  linterDuplicateFunction,
  linterDeprecatedApi,
  linterTableOperations,
  linterDuplicateCondition,
  linterMisleadingAndOr,
  linterCommentDirective,
  linterIntegerParsing,
  linterComparisonPrecedence,

  typeError,
  syntaxError,
}

class ScriptProblemResult {
  final String scriptName;
  final List<ScriptProblem> errors;
  final List<ScriptProblem> lintErrors;
  final List<ScriptProblem> lintWarnings;

  ScriptProblemResult({
    required this.scriptName,
    required this.errors,
    required this.lintErrors,
    required this.lintWarnings,
  });

  bool get isEmpty =>
      errors.isEmpty && lintErrors.isEmpty && lintWarnings.isEmpty;

  static ScriptProblemResult read(BinaryReader reader) {
    final scriptName = reader.readString();
    final errorCount = reader.readVarUint();
    final lintErrorCount = reader.readVarUint();
    final lintWarningCount = reader.readVarUint();

    var errors = <ScriptProblem>[];
    for (int i = 0; i < errorCount; i++) {
      errors.add(ScriptProblem.read(reader));
    }

    var lintErrors = <ScriptProblem>[];
    for (int i = 0; i < lintErrorCount; i++) {
      lintErrors.add(ScriptProblem.read(reader));
    }

    var lintWarnings = <ScriptProblem>[];
    for (int i = 0; i < lintWarningCount; i++) {
      lintWarnings.add(ScriptProblem.read(reader));
    }

    return ScriptProblemResult(
      scriptName: scriptName,
      errors: errors,
      lintErrors: lintErrors,
      lintWarnings: lintWarnings,
    );
  }
}

class ScriptProblem {
  final ScriptRange range;
  final String message;
  final ScriptProblemType type;

  ScriptProblem({
    required this.range,
    required this.message,
    required this.type,
  });

  @override
  String toString() => 'ScriptProblem($type:$range) - $message';

  @override
  int get hashCode => Object.hash(range, message, type);

  @override
  bool operator ==(Object other) =>
      other is ScriptProblem &&
      other.type == type &&
      other.range == range &&
      other.message == message;

  static ScriptProblem read(BinaryReader reader) {
    return ScriptProblem(
      type: ScriptProblemType.values[reader.readUint8()],
      range: ScriptRange.read(reader),
      message: reader.readString(),
    );
  }
}

class AutocompleteResult {
  final List<AutocompleteEntry> entries;

  AutocompleteResult({required this.entries});

  static AutocompleteResult read(BinaryReader reader) {
    final entries = <AutocompleteEntry>[];
    while (!reader.isEOF) {
      entries.add(AutocompleteEntry.read(reader));
    }
    return AutocompleteResult(entries: entries);
  }
}

class AutocompleteEntry {
  final ScriptRange range;
  final String text;
  final Uint32List matchedIndices;
  AutocompleteEntry({
    required this.range,
    required this.text,
    required this.matchedIndices,
  });

  static AutocompleteEntry read(BinaryReader reader) {
    final range = ScriptRange.read(reader);
    final text = reader.readString();
    final matchedIndices = Uint32List(reader.readVarUint());
    for (int i = 0; i < matchedIndices.length; i++) {
      matchedIndices[i] = reader.readVarUint();
    }
    return AutocompleteEntry(
        range: range, text: text, matchedIndices: matchedIndices);
  }
}

enum HighlightResult { unknown, computed }

enum InsertionCompletion { none, end, doEnd, until, thenEnd }

enum PropertyType {
  number,
  string,
  boolean,
  color,
  trigger,
  artboard,
  other,
}

class ImplementedTypeProperty {
  final PropertyType type;
  final String name;

  /// Only applies when [type] == [PropertyType.other] or [type] ==
  /// [PropertyType.artboard] and the typeName is the viewmodel bound to the
  /// artboard.
  final String typeName;

  ImplementedTypeProperty({
    required this.type,
    required this.typeName,
    required this.name,
  });

  static ImplementedTypeProperty? read(BinaryReader reader) {
    if (reader.isEOF) {
      return null;
    }
    final typeValue = reader.readUint8();
    if (reader.isEOF) {
      return null;
    }
    final typeName = reader.readString();
    if (reader.isEOF) {
      return null;
    }
    final name = reader.readString();

    if (typeValue >= PropertyType.values.length) {
      return null;
    }
    return ImplementedTypeProperty(
      type: PropertyType.values[typeValue],
      typeName: typeName,
      name: name,
    );
  }
}

class ImplementedType {
  final String scriptName;
  final String interfaceTypeName;
  final String userTypeName;
  final List<ImplementedTypeProperty> inputs;
  final List<ImplementedTypeProperty> outputs;
  ImplementedType({
    required this.scriptName,
    required this.interfaceTypeName,
    required this.userTypeName,
    required this.inputs,
    required this.outputs,
  });

  static ImplementedType? read(BinaryReader reader) {
    if (reader.isEOF) {
      return null;
    }
    final scriptName = reader.readString();
    if (reader.isEOF) {
      return null;
    }
    final interfaceName = reader.readString();
    if (reader.isEOF) {
      return null;
    }
    final userTypeName = reader.readString();
    if (reader.isEOF) {
      return null;
    }

    final inputCount = reader.readVarUint();
    final inputs = <ImplementedTypeProperty>[];
    for (int i = 0; i < inputCount; i++) {
      final argument = ImplementedTypeProperty.read(reader);
      if (argument == null) {
        return null;
      }
      inputs.add(argument);
    }

    final outputCount = reader.readVarUint();
    final outputs = <ImplementedTypeProperty>[];
    for (int i = 0; i < outputCount; i++) {
      final argument = ImplementedTypeProperty.read(reader);
      if (argument == null) {
        return null;
      }
      outputs.add(argument);
    }

    return ImplementedType(
      scriptName: scriptName,
      interfaceTypeName: interfaceName,
      userTypeName: userTypeName,
      inputs: inputs,
      outputs: outputs,
    );
  }
}

abstract class ScriptingWorkspaceResponseResult {
  bool get available;
  BinaryReader? get reader;
}

class CompiledDependency {
  final String name;
  final Uint8List bytecode;
  CompiledDependency({required this.bytecode, required this.name});
}

class CompileResult {
  final Uint8List bytecode;
  final Iterable<CompiledDependency> dependencies;
  final Iterable<String> dependents;

  CompileResult(
      {required this.bytecode,
      this.dependencies = const Iterable.empty(),
      this.dependents = const Iterable.empty()});

  static CompileResult? read(BinaryReader reader) {
    if (reader.isEOF) {
      return null;
    }
    final length = reader.readVarUint();
    final bytecode = reader.read(length);
    if (reader.isEOF) {
      return CompileResult(bytecode: bytecode);
    }
    final dependencies = <CompiledDependency>[];
    final count = reader.readVarUint();
    for (int i = 0; i < count; i++) {
      final name = reader.readString();
      final length = reader.readVarUint();
      final bytecode = reader.read(length);
      dependencies.add(CompiledDependency(bytecode: bytecode, name: name));
    }
    final dependents = <String>[];
    while (!reader.isEOF) {
      dependents.add(reader.readString());
    }
    return CompileResult(
      bytecode: bytecode,
      dependencies: dependencies,
      dependents: dependents,
    );
  }
}

/// A workspace represents a collection of files that are likely related
/// (usually part of a single Rive file).
abstract class ScriptingWorkspace {
  Future<HighlightResult> setSystemGeneratedSource(
      String scriptName, String prefix, String source);

  /// Set the [source] code for the script with [scriptId]. Calling this again
  /// with the same [scriptId] will overwrite the script. Set [highlight] to
  /// true if you'd like to have highlighting data computed. [scriptName] is the
  /// name used to require this script.
  Future<HighlightResult> setScriptSource(
      String scriptId, String scriptName, String source,
      {bool highlight = false});

  void checkScriptsWithRequires();
  void removeScriptSource(String scriptId);

  /// Formats module named [scriptName].
  Future<FormatResult> format(String scriptName);

  /// Retrieves the bytecode for module named [scriptName].
  Future<CompileResult?> compile(String scriptName,
      {bool failOnErrors = false, bool compileDependencies = false});

  /// Retrieves the implemented type for module named [scriptName].
  Future<ImplementedType?> implementedType(String scriptName);

  /// Get the highlight data for a single row of [scriptName].
  Uint32List rowHighlight(String scriptName, int row);

  /// Get an error report for all the script files in this workspace.
  Future<List<ScriptProblemResult>> fullProblemReport();

  /// Get an error report for a script file with identified by [scriptName].
  Future<ScriptProblemResult> problemReport(String scriptName);

  /// Get possible autocompletion results at [position] in script with name
  /// [scriptName].
  Future<AutocompleteResult> autocomplete(
      String scriptName, ScriptPosition position);

  /// Dispose of the workspace, any further calls will not work.
  @mustCallSuper
  void dispose() {
    _closing = true;
  }

  /// Get extra text insertion to be auto-completed at the given position.
  InsertionCompletion completeInsertion(
      String scriptName, ScriptPosition position);

  static ScriptingWorkspace make() => makeScriptingWorkspace();

  static Uint8List nativeFontBytes() => getNativeFontBytes();

  final HashMap<int, Completer> _completers = HashMap<int, Completer>();

  ScriptingWorkspaceResponseResult responseForWork(int workId);

  @protected
  Future<T> registerCompleter<T>(int workId) {
    final completer = Completer<T>();
    assert(!_completers.containsKey(workId));
    final response = responseForWork(workId);
    if (response.available) {
      completeWork(completer, response);
    } else {
      assert(!_completers.containsKey(workId));
      _completers[workId] = completer;
    }
    return completer.future;
  }

  @protected
  void completeWork(
      Completer completer, ScriptingWorkspaceResponseResult response) {
    assert(response.available);
    if (completer is Completer<List<ScriptProblemResult>>) {
      _completeFullProblemReport(completer, response);
    } else if (completer is Completer<ScriptProblemResult>) {
      _completeProblemReport(completer, response);
    } else if (completer is Completer<HighlightResult>) {
      _completeHighlight(completer, response);
    } else if (completer is Completer<FormatResult>) {
      _completeFormat(completer, response);
    } else if (completer is Completer<AutocompleteResult>) {
      _completeAutocomplete(completer, response);
    } else if (completer is Completer<ImplementedType?>) {
      _completeImplementedType(completer, response);
    } else if (completer is Completer<CompileResult?>) {
      _completeCompile(completer, response);
    }
  }

  bool _closing = false;

  @protected
  void workReadyCallback(int workId) {
    if (_closing) {
      return;
    }
    final completer = _completers.remove(workId);
    if (completer == null) {
      return;
    }
    final response = responseForWork(workId);
    completeWork(completer, response);
  }

  void _completeFullProblemReport(
    Completer<List<ScriptProblemResult>> completer,
    ScriptingWorkspaceResponseResult result,
  ) {
    final reader = result.reader;
    if (reader == null) {
      return;
    }
    final results = <ScriptProblemResult>[];
    while (!reader.isEOF) {
      results.add(ScriptProblemResult.read(reader));
    }
    completer.complete(results);
  }

  void _completeProblemReport(Completer<ScriptProblemResult> completer,
      ScriptingWorkspaceResponseResult result) {
    final reader = result.reader;
    if (reader == null) {
      return;
    }

    completer.complete(ScriptProblemResult.read(reader));
  }

  void _completeAutocomplete(
    Completer<AutocompleteResult> completer,
    ScriptingWorkspaceResponseResult result,
  ) {
    final reader = result.reader;
    if (reader == null) {
      return;
    }

    completer.complete(AutocompleteResult.read(reader));
  }

  void _completeHighlight(
    Completer<HighlightResult> completer,
    ScriptingWorkspaceResponseResult result,
  ) {
    completer.complete(HighlightResult.computed);
  }

  void _completeFormat(
    Completer<FormatResult> completer,
    ScriptingWorkspaceResponseResult result,
  ) {
    final reader = result.reader;
    if (reader == null) {
      return;
    }

    completer.complete(FormatResult.read(reader));
  }

  void _completeImplementedType(
    Completer<ImplementedType?> completer,
    ScriptingWorkspaceResponseResult result,
  ) {
    final reader = result.reader;
    if (reader == null) {
      return;
    }
    return completer.complete(ImplementedType.read(reader));
  }

  void _completeCompile(
    Completer<CompileResult?> completer,
    ScriptingWorkspaceResponseResult result,
  ) {
    final reader = result.reader;
    if (reader == null) {
      return;
    }
    completer.complete(CompileResult.read(reader));
  }
}
