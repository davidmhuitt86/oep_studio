import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:engineering_engine/engineering_engine.dart';
import 'package:oep_studio/diagram_studio/host/diagram_document.dart';

/// Exercises `DiagramDocument` against a real temp directory
/// (WORK_PACKAGE_024, ENGINE-TASK-000111) — Open/Save/Save As/Close/
/// Dirty State, and that Graph + Layout round-trip together as one
/// file (the Repository Integration resolution documented in
/// `docs/REPOSITORY_INTEGRATION.md`).
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('diagram_document_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  EngineeringGraph buildGraph() {
    final graph = EngineeringGraph.empty('g1');
    return graph.withNode(const EngineeringNode(
      id: 'battery',
      category: NodeCategory.component,
      displayName: 'Battery',
      symbolId: 'battery',
    ));
  }

  DiagramLayoutState buildLayout() {
    return DiagramLayoutState.empty.withPositions({'battery': const Point2D(10, 20)});
  }

  test('saveAs writes graph and layout together, sets path, clears dirty', () async {
    final document = DiagramDocument();
    document.markDirty();
    final filePath = '${tempDir.path}/diagram.json';

    await document.saveAs(filePath, buildGraph(), buildLayout());

    expect(document.path, filePath);
    expect(document.isDirty, isFalse);
    expect(File(filePath).existsSync(), isTrue);
  });

  test('open reads back an equivalent graph and layout', () async {
    final document = DiagramDocument();
    final filePath = '${tempDir.path}/diagram.json';
    await document.saveAs(filePath, buildGraph(), buildLayout());

    final reopened = DiagramDocument();
    final result = await reopened.open(filePath);

    expect(result.graph.nodes['battery']?.displayName, 'Battery');
    expect(result.layout.positionOf('battery'), const Point2D(10, 20));
    expect(reopened.path, filePath);
    expect(reopened.isDirty, isFalse);
  });

  test('save() without a prior path throws StateError', () async {
    final document = DiagramDocument();
    expect(
      () => document.save(buildGraph(), buildLayout()),
      throwsA(isA<StateError>()),
    );
  });

  test('save() writes to the existing path after saveAs', () async {
    final document = DiagramDocument();
    final filePath = '${tempDir.path}/diagram.json';
    await document.saveAs(filePath, buildGraph(), buildLayout());

    final updatedGraph = buildGraph().withNode(const EngineeringNode(
      id: 'ground',
      category: NodeCategory.ground,
      displayName: 'Ground',
    ));
    await document.save(updatedGraph, buildLayout());

    final reopened = DiagramDocument();
    final result = await reopened.open(filePath);
    expect(result.graph.nodes.containsKey('ground'), isTrue);
  });

  test('close() resets path and dirty state', () async {
    final document = DiagramDocument();
    final filePath = '${tempDir.path}/diagram.json';
    await document.saveAs(filePath, buildGraph(), buildLayout());

    document.close();

    expect(document.path, isNull);
    expect(document.isDirty, isFalse);
  });

  test('markDirty() sets isDirty until the next save', () async {
    final document = DiagramDocument();
    expect(document.isDirty, isFalse);
    document.markDirty();
    expect(document.isDirty, isTrue);

    await document.saveAs('${tempDir.path}/diagram.json', buildGraph(), buildLayout());
    expect(document.isDirty, isFalse);
  });
}
