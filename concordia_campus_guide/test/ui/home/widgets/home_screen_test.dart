import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:provider/provider.dart";
import "package:concordia_campus_guide/ui/home/widgets/home_screen.dart";
import "package:concordia_campus_guide/ui/home/view_models/home_view_model.dart";
import "package:concordia_campus_guide/data/repositories/building_repository.dart";
import "package:concordia_campus_guide/domain/interactors/map_data_interactor.dart";

class TestHomeViewModel extends HomeViewModel {
  bool initCalled = false;
  String? initPath;
  bool goToCalled = false;
  bool clearCalled = false;

  TestHomeViewModel()
      : super(
          mapInteractor: MapDataInteractor(
            buildingRepo: BuildingRepository(
              buildingLoader: (_) async => "{}",
            ),
          ),
        );

  @override
  Future<void> initializeBuildingsData(final String path) async {
    initCalled = true;
    initPath = path;
    notifyListeners();
  }

  @override
  Future<void> goToCurrentLocation() async {
    goToCalled = true;
    notifyListeners();
  }

  @override
  void toggleCampus() {
    selectedCampusIndex = (selectedCampusIndex + 1) % 2;
    notifyListeners();
  }

  @override
  void clearCameraTarget() {
    clearCalled = true;
    cameraTarget = null;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("HomeScreen Widget Tests", () {
    late TestHomeViewModel vm;

    setUp(() {
      vm = TestHomeViewModel();
    });

    Future<void> pumpHomeScreen(final WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<HomeViewModel>.value(
            value: vm,
            child: const HomeScreen(),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets("calls initializeBuildingsData on mount", (final tester) async {
      await pumpHomeScreen(tester);
      expect(vm.initCalled, isTrue);
    });

    testWidgets("pressing my location FAB calls goToCurrentLocation", (final tester) async {
      await pumpHomeScreen(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      expect(vm.goToCalled, isTrue);
    });

    testWidgets("pressing campus toggle toggles campus label", (final tester) async {
      await pumpHomeScreen(tester);
      expect(find.text("SGW"), findsOneWidget);
      await tester.tap(find.byKey(const Key("campus_toggle_button")));
      await tester.pump();
      expect(find.text("LOY"), findsOneWidget);
    });

    testWidgets("shows SnackBar when view model has errorMessage", (final tester) async {
      await pumpHomeScreen(tester);
      vm.errorMessage = "test-error";
      vm.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text("test-error"), findsOneWidget);
    });

    testWidgets("when cameraTarget set, view model clearCameraTarget is called", (final tester) async {
      await pumpHomeScreen(tester);
      vm.cameraTarget = HomeViewModel.sgw;
      vm.notifyListeners();
      await tester.pump();
      expect(vm.clearCalled, isTrue);
      await tester.pumpAndSettle();
    });
  });
}
