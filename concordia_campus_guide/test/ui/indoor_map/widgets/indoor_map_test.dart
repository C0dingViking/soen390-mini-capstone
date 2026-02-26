import "package:concordia_campus_guide/domain/interactors/floorplan_interactor.dart";
import "package:concordia_campus_guide/ui/indoor_map/view_models/indoor_view_model.dart";
import "package:flutter_test/flutter_test.dart";

class TestIndoorViewModel extends IndoorViewModel {
  bool initCalled = false;
  String? initPath;

  TestIndoorViewModel() : super(floorplanInteractor: FloorplanInteractor()) {}

  @override
  Future<void> initializeBuildingFloorplans(final String path) async {
    initCalled = true;
    initPath = path;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("IndoorMap Widget Tests", () {});
}
