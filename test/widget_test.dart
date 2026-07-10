import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/app/studio_app.dart';

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
    await tester.pumpAndSettle();

    expect(find.text('Welcome to OEP Studio'), findsOneWidget);
    expect(find.text('Open Repository'), findsWidgets);

    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();

    expect(find.text('Studio Settings will appear here.'), findsOneWidget);

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
    await tester.pumpAndSettle();

    await tester.tap(find.text('Repository').first);
    await tester.pumpAndSettle();

    expect(find.text('No Repository Open'), findsOneWidget);

    await tester.tap(find.text('Open Repository').first);
    await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();

    await tester.tap(find.text('Objects').first);
    await tester.pumpAndSettle();

    expect(find.text('No Category Selected'), findsOneWidget);

    await tester.tap(find.text('Go to Repository Explorer').first);
    await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();

    await tester.tap(find.text('Relationships').first);
    await tester.pumpAndSettle();

    expect(find.text('No Repository Open'), findsOneWidget);
  });

  testWidgets('Search Workspace runs a search and reports it as unavailable', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: StudioApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search').first);
    await tester.pumpAndSettle();

    expect(find.text('Search this repository'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'generator');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Search'));
    await tester.pumpAndSettle();

    expect(find.text('Couldn\'t search for "generator"'), findsOneWidget);
    expect(find.text('generator'), findsWidgets); // appears in the Previous Searches panel too

    // Disambiguate from the "Clear" text link in the Previous Searches panel.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Clear'));
    await tester.pumpAndSettle();

    expect(find.text('Search this repository'), findsOneWidget);
  });
}
