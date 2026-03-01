import "package:concordia_campus_guide/ui/indoor_map/widgets/indoor_search_bar.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  testWidgets("shows expanded fields with Current location hint", (final tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: IndoorSearchBar())));

    expect(find.widgetWithText(TextField, "Current location"), findsOneWidget);
    expect(find.widgetWithText(TextField, "Choose destination"), findsOneWidget);
  });

  testWidgets("clear button appears when destination has text", (final tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: IndoorSearchBar())));

    expect(find.byIcon(Icons.close), findsNothing);

    await tester.enterText(find.byType(TextField).last, "H-110");
    await tester.pump();

    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets("clear button appears when start has text", (final tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: IndoorSearchBar())));

    expect(find.byIcon(Icons.close), findsNothing);

    await tester.enterText(find.byType(TextField).first, "Hall Building");
    await tester.pump();

    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets("clear button clears destination field", (final tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: IndoorSearchBar())));

    await tester.enterText(find.byType(TextField).last, "H-110");
    await tester.pump();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets("clear button clears start field", (final tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: IndoorSearchBar())));

    await tester.enterText(find.byType(TextField).first, "Hall Building");
    await tester.pump();

    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(find.byIcon(Icons.close), findsNothing);
  });
}
