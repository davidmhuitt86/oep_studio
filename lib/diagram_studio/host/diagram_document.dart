import 'dart:convert';
import 'dart:io';

import 'package:engineering_engine/engineering_engine.dart';

/// A Diagram Studio document — an Engineering Graph plus its Diagram
/// Layout, persisted together as one file (WORK_PACKAGE_024,
/// ENGINE-TASK-000111: Open/Save/Save As/Close/Dirty State).
///
/// Foundation's actual repository API has no schema for Diagram Layout/
/// ViewState/Annotations/Layers/wire overrides, no "Save"/"Save As", and
/// no dirty-state concept at all — it only knows `EngineeringObject`/
/// `Relationship` plus an append-only audit log (see
/// `docs/REPOSITORY_INTEGRATION.md` for the full account). Building
/// genuine Foundation-backed diagram persistence would require a
/// Foundation-side schema change, which is out of scope — `oep_foundation`
/// may not be modified. A Diagram Studio document therefore uses the
/// Engineering Engine's own existing, already-serializable
/// `EngineeringGraph.toJson()`/`DiagramLayoutState.toJson()` — the same
/// SDD-025-sanctioned path Foundation-less verification already used in
/// WORK_PACKAGE_019–023 ("Engineering Engine shall operate without an
/// open Repository where practical"). This class composes those two
/// already-serializable pieces into one file; it does not reimplement
/// graph or layout serialization itself. The *ambient* Foundation
/// repository (opened separately, via the existing
/// `FoundationRuntimeNotifier`) is tracked for display only — see
/// `DiagramStudioPage`.
class DiagramDocument {
  static const int schemaVersion = 1;

  String? path;
  bool isDirty = false;

  /// Reads a document file, returning its Graph and Layout together.
  Future<({EngineeringGraph graph, DiagramLayoutState layout})> open(String filePath) async {
    final file = File(filePath);
    final raw = await file.readAsString();
    final decoded = jsonDecode(raw) as Map<String, Object?>;
    final graph = EngineeringGraph.fromJson(decoded['graph'] as Map<String, Object?>);
    final layoutJson = decoded['layout'] as Map<String, Object?>?;
    final layout =
        layoutJson == null ? DiagramLayoutState.empty : DiagramLayoutState.fromJson(layoutJson);
    path = filePath;
    isDirty = false;
    return (graph: graph, layout: layout);
  }

  /// Writes [graph]/[layout] to [filePath] — "Save As," which also
  /// becomes this document's new [path] going forward.
  Future<void> saveAs(String filePath, EngineeringGraph graph, DiagramLayoutState layout) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    final envelope = {
      'schemaVersion': schemaVersion,
      'graph': graph.toJson(),
      'layout': layout.toJson(),
    };
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(envelope));
    path = filePath;
    isDirty = false;
  }

  /// Writes to the document's current [path]. Throws [StateError] if the
  /// document has never been saved — the caller should prompt for a
  /// location via [saveAs] instead ("Save" requires an existing path;
  /// "Save As" always works and establishes one).
  Future<void> save(EngineeringGraph graph, DiagramLayoutState layout) async {
    final currentPath = path;
    if (currentPath == null) {
      throw StateError('This document has no file path yet — use saveAs() instead.');
    }
    await saveAs(currentPath, graph, layout);
  }

  /// Marks the document dirty — Diagram Studio calls this on every
  /// `EditingService.sessionChanges` emission once a document is open.
  void markDirty() => isDirty = true;

  /// Resets to a brand-new, unsaved, clean document (Close).
  void close() {
    path = null;
    isDirty = false;
  }
}
