import "package:concordia_campus_guide/utils/dialog_helper.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("showErrorPopup", () {
    testWidgets("shows dialog with default title and message", (final tester) async {
      late BuildContext context;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (final ctx) {
              context = ctx;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      );

      showErrorPopup(context, "Something went wrong");
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text("Error"), findsOneWidget);
      expect(find.text("Something went wrong"), findsOneWidget);
      expect(find.text("Dismiss"), findsOneWidget);
    });

    testWidgets("shows dialog with custom title", (final tester) async {
      late BuildContext context;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (final ctx) {
              context = ctx;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      );

      showErrorPopup(context, "Cannot compute route", title: "Navigation Error");
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text("Navigation Error"), findsOneWidget);
      expect(find.text("Cannot compute route"), findsOneWidget);
    });

    testWidgets("dismiss button closes dialog and completes future", (final tester) async {
      late BuildContext context;
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (final ctx) {
              context = ctx;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      );

      showErrorPopup(context, "Dismiss me").then((_) {
        completed = true;
      });
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text("Dismiss"));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(completed, isTrue);
    });
  });
}
