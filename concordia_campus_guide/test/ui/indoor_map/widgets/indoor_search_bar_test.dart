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
      destinationController: useSecondControllers
          ? widget.destinationB
          : widget.destinationA,
      queryableRooms: [],
    );
  }
}

void main() {
  testWidgets("shows expanded fields with Current location hint", (
    final tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: IndoorSearchBar(queryableRooms: [])),
      ),
    );

    expect(find.widgetWithText(TextField, "Current location"), findsOneWidget);
    expect(
      find.widgetWithText(TextField, "Choose destination"),
      findsOneWidget,
    );
  });

  testWidgets("clear button appears when destination has text", (
    final tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: IndoorSearchBar(queryableRooms: [])),
      ),
    );

    expect(find.byIcon(Icons.close), findsNothing);

    await tester.enterText(find.byType(TextField).last, "H-110");
    await tester.pump();

    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets("clear button appears when start has text", (final tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: IndoorSearchBar(queryableRooms: [])),
      ),
    );

    expect(find.byIcon(Icons.close), findsNothing);

    await tester.enterText(find.byType(TextField).first, "Hall Building");
    await tester.pump();

    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets("clear button clears destination field", (final tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: IndoorSearchBar(queryableRooms: [])),
      ),
    );

    await tester.enterText(find.byType(TextField).last, "H-110");
    await tester.pump();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets("clear button clears start field", (final tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: IndoorSearchBar(queryableRooms: [])),
      ),
    );

    await tester.enterText(find.byType(TextField).first, "Hall Building");
    await tester.pump();

    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets("programmatic external controller updates are reflected in UI", (
    final tester,
  ) async {
    final destinationController = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IndoorSearchBar(
            destinationController: destinationController,
            queryableRooms: [],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField).last);
    await tester.pump();
    expect(find.byIcon(Icons.close), findsNothing);

    destinationController.text = "MB 1-310";
    await tester.pump();

    expect(find.byIcon(Icons.close), findsOneWidget);

    destinationController.dispose();
  });

  testWidgets("controller swap updates attached text field controllers", (
    final tester,
  ) async {
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

  testWidgets("externally owned controllers are not disposed by widget", (
    final tester,
  ) async {
    final startController = TextEditingController();
    final destinationController = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IndoorSearchBar(
            startController: startController,
            destinationController: destinationController,
            queryableRooms: [],
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
    );

    expect(() => startController.text = "Still usable", returnsNormally);
    expect(() => destinationController.text = "Still usable", returnsNormally);

    startController.dispose();
    destinationController.dispose();
  });

  testWidgets("typing filters rooms and shows matching suggestions", (
    final tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IndoorSearchBar(queryableRooms: ["H 849", "H 101", "MB 1-310"]),
        ),
      ),
    );

    final startField = find.byType(TextField).first;

    await tester.tap(startField);
    await tester.enterText(startField, "H 8");
    await tester.pump();

    expect(find.text("H 849"), findsOneWidget);
    expect(find.text("H 101"), findsNothing);
    expect(find.text("MB 1-310"), findsNothing);
  });

  testWidgets("switching focus clears suggestions", (final tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: IndoorSearchBar(queryableRooms: ["H 849"])),
      ),
    );

    final startField = find.byType(TextField).first;
    final destField = find.byType(TextField).last;

    await tester.tap(startField);
    await tester.enterText(startField, "H");
    await tester.pump();

    expect(find.text("H 849"), findsOneWidget);

    await tester.tap(destField);
    await tester.pump();

    expect(find.text("H 849"), findsNothing);
  });

  testWidgets("selecting a suggestion fills the field and hides the list", (
    final tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: IndoorSearchBar(queryableRooms: ["H 849"])),
      ),
    );

    final startField = find.byType(TextField).first;

    await tester.tap(startField);
    await tester.enterText(startField, "H");
    await tester.pump();

    await tester.tap(find.text("H 849"));
    await tester.pump();

    expect(find.text("H 849"), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets("refocusing a field with existing text does not show suggestions", (
    final tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IndoorSearchBar(queryableRooms: ["H 849", "H 101"]),
        ),
      ),
    );

    final startField = find.byType(TextField).first;
    final destField = find.byType(TextField).last;

    await tester.tap(startField);
    await tester.enterText(startField, "H");
    await tester.pump();

    expect(find.text("H 849"), findsOneWidget);

    // tapping elsewhere to remove focus from the searchbar
    await tester.tap(destField);
    await tester.pump();

    expect(find.text("H 849"), findsNothing);

    // focusing the searchbar again shouldn"t show the suggestions unless typing occurrs
    await tester.tap(startField);
    await tester.pump();

    expect(find.text("H 849"), findsNothing);
  });

  testWidgets("typing in one field does not affect the other field", (
    final tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IndoorSearchBar(queryableRooms: ["H 849", "MB 1-310"]),
        ),
      ),
    );

    final startField = find.byType(TextField).first;
    final destField = find.byType(TextField).last;

    await tester.tap(startField);
    await tester.enterText(startField, "H");
    await tester.pump();

    expect(find.text("H 849"), findsOneWidget);

    await tester.tap(destField);
    await tester.enterText(destField, "MB");
    await tester.pump();

    expect(find.text("MB 1-310"), findsOneWidget);
    expect(find.text("H 849"), findsNothing);
  });

  testWidgets("clearing a field hides suggestions even while focused", (
    final tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: IndoorSearchBar(queryableRooms: ["H 849"])),
      ),
    );

    final startField = find.byType(TextField).first;

    await tester.tap(startField);
    await tester.enterText(startField, "H");
    await tester.pump();

    expect(find.text("H 849"), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(find.text("H 849"), findsNothing);
  });

  testWidgets(
    "Start Navigation button appears only when both rooms are valid",
    (final tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IndoorSearchBar(queryableRooms: ["H 849", "MB 1-310"]),
          ),
        ),
      );

      final startField = find.byType(TextField).first;
      final destField = find.byType(TextField).last;

      expect(find.text("Start Navigation"), findsNothing);

      await tester.enterText(startField, "H 849");
      await tester.pump();

      expect(find.text("Start Navigation"), findsNothing);

      await tester.enterText(destField, "MB 1-310");
      await tester.pump();

      expect(find.text("Start Navigation"), findsOneWidget);

      await tester.enterText(destField, "NOT A ROOM");
      await tester.pump();

      expect(find.text("Start Navigation"), findsNothing);
    },
  );

  testWidgets("Start Navigation button triggers callback with selected rooms", (
    final tester,
  ) async {
    String? selectedStartRoom;
    String? selectedDestinationRoom;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IndoorSearchBar(
            queryableRooms: ["H 849", "MB 1-310"],
            onStartNavigation: (final startRoom, final destinationRoom) {
              selectedStartRoom = startRoom;
              selectedDestinationRoom = destinationRoom;
            },
          ),
        ),
      ),
    );

    final startField = find.byType(TextField).first;
    final destField = find.byType(TextField).last;

    await tester.enterText(startField, "H 849");
    await tester.enterText(destField, "MB 1-310");
    await tester.pump();

    await tester.tap(find.text("Start Navigation"));
    await tester.pump();

    expect(selectedStartRoom, "H 849");
    expect(selectedDestinationRoom, "MB 1-310");
  });
}
