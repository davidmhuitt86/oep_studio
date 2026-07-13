import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/app/studio_app.dart';

/// A bounded stand-in for `pumpAndSettle()`. The Settings Workspace
/// (Work Package 017/018) shows an indeterminate `CircularProgressIndicator`
/// while its configuration loads from disk — indeterminate progress
/// indicators animate forever by design, so `pumpAndSettle()` (which
/// waits for *no* frame to be scheduled) never converges once one is
/// on screen and reliably times out. A fixed number of bounded pumps
/// gives every real async operation (Settings load, dialog transitions,
/// route animations) ample time to finish without waiting on an
/// animation that never stops on its own.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('StudioApp launches on the Dashboard and navigates via the rail', (
    WidgetTester tester,
  ) async {
    // Flutter's default 800x600 test surface is narrower than this app's
    // actual minimum window size (windows/runner/win32_window.cpp,
    // kMinWindowWidth/kMinWindowHeight) — testing below that size isn't
    // representative of anything a real user can produce.
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: StudioApp()));
    await settle(tester);

    expect(find.text('Welcome to OEP Studio'), findsOneWidget);
    expect(find.text('Open Repository'), findsWidgets);

    await tester.tap(find.text('Settings').first);
    await settle(tester);

    // Work Package 017: Settings is now a real Workspace (General page by
    // default), not a placeholder.
    expect(find.text('Localization'), findsOneWidget);

    // Property Inspector (Work Package 003) is a persistent panel —
    // "No Object Selected" regardless of which page is active.
    expect(find.text('No Object Selected'), findsOneWidget);
    // Status Bar's new Selected Object field.
    expect(find.text('Selected Object: None'), findsOneWidget);
  });

  testWidgets('Repository Explorer shows No Repository Open and returns to the Dashboard', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: StudioApp()));
    await settle(tester);

    await tester.tap(find.text('Repository').first);
    await settle(tester);

    expect(find.text('No Repository Open'), findsOneWidget);

    await tester.tap(find.text('Open Repository').first);
    await settle(tester);

    expect(find.text('Welcome to OEP Studio'), findsOneWidget);
  });

  testWidgets('Object Explorer prompts for a category when none is selected', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: StudioApp()));
    await settle(tester);

    await tester.tap(find.text('Objects').first);
    await settle(tester);

    expect(find.text('No Category Selected'), findsOneWidget);

    await tester.tap(find.text('Go to Repository Explorer').first);
    await settle(tester);

    expect(find.text('No Repository Open'), findsOneWidget);
  });

  testWidgets('Relationship Explorer shows No Repository Open when disconnected', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: StudioApp()));
    await settle(tester);

    await tester.tap(find.text('Relationships').first);
    await settle(tester);

    expect(find.text('No Repository Open'), findsOneWidget);
  });

  testWidgets('Search Workspace shows No Repository Open when disconnected', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: StudioApp()));
    await settle(tester);

    await tester.tap(find.text('Search').first);
    await settle(tester);

    expect(find.text('No Repository Open'), findsOneWidget);
  });

  testWidgets('Knowledge Studio opens with placeholder panels and no active session', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: StudioApp()));
    await settle(tester);

    await tester.tap(find.text('Knowledge Studio').first);
    await settle(tester);

    expect(find.text('No Knowledge Curation Session'), findsOneWidget);
    expect(find.text('Import Queue'), findsOneWidget);
    expect(find.text('Source Viewer'), findsOneWidget);
    expect(find.text('AI Suggestions'), findsOneWidget);
    expect(find.text('Repository Matches'), findsOneWidget);
    expect(find.text('Engineering Review'), findsOneWidget);
    expect(find.text('Commit Summary'), findsOneWidget);
    // Knowledge Studio is Studio-only — it never requires a live
    // Foundation repository to be open (Work Package 007).
    expect(find.text('No Repository Open'), findsNothing);
  });

  testWidgets('Knowledge Curation Session: create a session, add a candidate, accept it', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: StudioApp()));
    await settle(tester);

    await tester.tap(find.text('Knowledge Studio').first);
    await settle(tester);

    // Create a session.
    await tester.tap(find.widgetWithText(OutlinedButton, 'New Session'));
    await settle(tester);

    await tester.enterText(findFieldLabeled('Session Name'), 'Timing Chain Manual Import');
    await tester.pump();
    await tester.enterText(findFieldLabeled('Repository'), 'demo-repo');
    await tester.pump();
    await tester.enterText(findFieldLabeled('Author'), 'jsmith');
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Session'));
    await settle(tester);

    expect(
      find.byType(AlertDialog),
      findsNothing,
      reason: 'the New Session dialog should have closed after a valid submission',
    );
    // Appears in both the session header and the Property Inspector's
    // Session mode (no proposal/object/relationship selected yet).
    expect(find.text('Timing Chain Manual Import'), findsNWidgets(2));
    expect(find.text('Created'), findsWidgets);
    expect(find.text('No Knowledge Curation Session'), findsNothing);

    // Add a manual Knowledge Candidate.
    await tester.tap(find.widgetWithText(OutlinedButton, 'New Candidate'));
    await settle(tester);

    await tester.enterText(findFieldLabeled('Name'), 'Timing Chain Cover');
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add Candidate'));
    await settle(tester);

    expect(find.text('Timing Chain Cover'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);

    // Selecting the candidate updates the Property Inspector.
    await tester.tap(find.text('Timing Chain Cover'));
    await settle(tester);
    expect(find.text('Knowledge Candidate ID'), findsOneWidget);

    // Accept it — the status badge (Engineering Review) and the
    // Property Inspector's Knowledge Candidate mode (still showing this
    // same, now-updated candidate) both read "Accepted".
    await tester.tap(find.widgetWithTooltip('Accept'));
    await settle(tester);
    expect(find.text('Accepted'), findsNWidgets(2));
    expect(find.text('Pending'), findsNothing);
  });
}

extension on CommonFinders {
  Finder widgetWithTooltip(String tooltip) =>
      find.byWidgetPredicate((widget) => widget is IconButton && widget.tooltip == tooltip);
}

/// Finds a `TextField` by its `InputDecoration.labelText`, avoiding
/// positional-index ambiguity across a dialog's several fields.
Finder findFieldLabeled(String label) {
  return find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.labelText == label);
}
