import "package:concordia_campus_guide/main.dart" as app;
import "package:firebase_core/firebase_core.dart";
import "package:flutter_test/flutter_test.dart";
import "package:patrol/patrol.dart";

void main() {
  patrolTest("App boots", (final $) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();
    app.main();
    await $.pumpAndSettle();
  });
}
