import "package:concordia_campus_guide/ui/indoor_map/widgets/indoor_search_bar.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

class _ControllerSwapHost extends StatefulWidget {
  final TextEditingController startA;
  final TextEditingController startB;
  final TextEditingController destinationA;
  final TextEditingController destinationB;

  const _ControllerSwapHost({
    super.key,
    required this.startA,
    required this.startB,
    required this.destinationA,
    required this.destinationB,
  });

  @override
  State<_ControllerSwapHost> createState() => _ControllerSwapHostState();
}

class _ControllerSwapHostState extends State<_ControllerSwapHost> {
  bool useSecondControllers = false;

  void swapControllers() {
    setState(() {
      useSecondControllers = !useSecondControllers;
    });
  }

  @override
  Widget build(final BuildContext context) {
    return IndoorSearchBar(
      startController: useSecondControllers ? widget.startB : widget.startA,
      destinationController: useSecondControllers ? widget.destinationB : widget.destinationA,
    );
  }
}

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

  testWidgets("programmatic external controller updates are reflected in UI", (final tester) async {
    final destinationController = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: IndoorSearchBar(destinationController: destinationController)),
      ),
    );

    expect(find.byIcon(Icons.close), findsNothing);

    destinationController.text = "MB 1-310";
    await tester.pump();

    expect(find.byIcon(Icons.close), findsOneWidget);

    destinationController.dispose();
  });

  testWidgets("controller swap updates attached text field controllers", (final tester) async {
    final startA = TextEditingController(text: "A");
    final startB = TextEditingController(text: "B");
    final destinationA = TextEditingController(text: "C");
    final destinationB = TextEditingController(text: "D");
    final hostKey = GlobalKey<_ControllerSwapHostState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _ControllerSwapHost(
            key: hostKey,
            startA: startA,
            startB: startB,
            destinationA: destinationA,
            destinationB: destinationB,
          ),
        ),
      ),
    );

    var fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields.first.controller, same(startA));
    expect(fields.last.controller, same(destinationA));

    hostKey.currentState!.swapControllers();
    await tester.pump();

    fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields.first.controller, same(startB));
    expect(fields.last.controller, same(destinationB));

    startA.dispose();
    startB.dispose();
    destinationA.dispose();
    destinationB.dispose();
  });

  testWidgets("externally owned controllers are not disposed by widget", (final tester) async {
    final startController = TextEditingController();
    final destinationController = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IndoorSearchBar(
            startController: startController,
            destinationController: destinationController,
          ),
        ),
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox.shrink())));

    expect(() => startController.text = "Still usable", returnsNormally);
    expect(() => destinationController.text = "Still usable", returnsNormally);

    startController.dispose();
    destinationController.dispose();
  });
}
