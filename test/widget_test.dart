import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oep_studio/app/studio_app.dart';

void main() {
  testWidgets('StudioApp launches on the Dashboard and navigates via the rail', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: StudioApp()));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to OEP Studio'), findsOneWidget);
    expect(find.text('Open Repository'), findsWidgets);

    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();

    expect(find.text('Studio Settings will appear here.'), findsOneWidget);
  });
}
