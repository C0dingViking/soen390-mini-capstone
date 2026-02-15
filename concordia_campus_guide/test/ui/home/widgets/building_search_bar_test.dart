import "dart:convert";

import "package:concordia_campus_guide/data/repositories/building_repository.dart";
import "package:concordia_campus_guide/domain/interactors/directions_interactor.dart";
import "package:concordia_campus_guide/domain/interactors/map_data_interactor.dart";
import "package:concordia_campus_guide/domain/interactors/places_interactor.dart";
import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/models/place_suggestion.dart";
import "package:concordia_campus_guide/domain/models/route_option.dart";
import "package:concordia_campus_guide/domain/models/search_suggestion.dart";
import "package:concordia_campus_guide/ui/home/view_models/home_view_model.dart";
import "package:concordia_campus_guide/ui/home/widgets/building_detail_screen.dart";
import "package:concordia_campus_guide/ui/home/widgets/building_search_bar.dart";
import "package:concordia_campus_guide/utils/campus.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:flutter_google_maps_webservices/places.dart";
import "package:provider/provider.dart";

class _FakePlacesInteractor extends PlacesInteractor {
  @override
  Future<List<PlaceSuggestion>> searchPlaces(final String query) async => [];

  @override
  Future<Coordinate?> resolvePlace(final String placeId) async => null;

  @override
  Future<Coordinate?> resolvePlaceSuggestion(final PlaceSuggestion suggestion) async => null;
}

class _FakeDirectionsInteractor extends DirectionsInteractor {
  @override
  Future<List<RouteOption>> getRouteOptions(
    final Coordinate start,
    final Coordinate destination, {
    final DateTime? departureTime,
    final DateTime? arrivalTime,
  }) async {
    return [];
  }
}

class _FakeAssetBundle extends CachingAssetBundle {
  static const String _svg =
      "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\"></svg>";

  @override
  Future<String> loadString(final String key, {final bool cache = true}) async {
    if (key == "assets/images/app_logo.svg") {
      return _svg;
    }
    throw FlutterError("Asset not found: $key");
  }

  @override
  Future<ByteData> load(final String key) async {
    final data = utf8.encode(await loadString(key));
    return ByteData.view(Uint8List.fromList(data).buffer);
  }
}

class _TestHomeViewModel extends HomeViewModel {
  _TestHomeViewModel()
      : super(
          mapInteractor: MapDataInteractor(
            buildingRepo: BuildingRepository(buildingLoader: (_) async => "{}"),
          ),
          placesInteractor: _FakePlacesInteractor(),
          directionsInteractor: _FakeDirectionsInteractor(),
        );

  String? lastQuery;
  bool clearSearchResultsCalled = false;
  bool clearRouteSelectionCalled = false;
  bool setStartToCurrentLocationCalled = false;
  bool? lastSearchBarExpanded;
  SearchField? lastSelectedField;
  SearchSuggestion? lastSelectedSuggestion;

  @override
  void updateSearchQuery(final String query) {
    lastQuery = query;
  }

  @override
  void clearSearchResults() {
    clearSearchResultsCalled = true;
    searchResults = [];
    isSearchingPlaces = false;
    notifyListeners();
  }

  @override
  void clearRouteSelection() {
    clearRouteSelectionCalled = true;
    startCoordinate = null;
    destinationCoordinate = null;
    selectedStartLabel = null;
    selectedDestinationLabel = null;
    searchStartMarker = null;
    searchDestinationMarker = null;
    routeOptions = {};
    routePolylines = {};
    transitChangeCircles = {};
    routeBounds = null;
    routeErrorMessage = null;
    isLoadingRoutes = false;
    notifyListeners();
  }

  @override
  void setSearchBarExpanded(final bool value) {
    lastSearchBarExpanded = value;
    super.setSearchBarExpanded(value);
  }

  @override
  Future<void> selectSearchSuggestion(
    final SearchSuggestion suggestion,
    final SearchField field,
  ) async {
    lastSelectedField = field;
    lastSelectedSuggestion = suggestion;
    if (field == SearchField.start) {
      selectedStartLabel = suggestion.title;
    } else {
      selectedDestinationLabel = suggestion.title;
    }
    searchResults = [];
    notifyListeners();
  }

  @override
  Future<void> setStartToCurrentLocation() async {
    setStartToCurrentLocationCalled = true;
    selectedStartLabel = "Current location";
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("BuildingSearchBar", () {
    late _TestHomeViewModel vm;

    setUp(() {
      vm = _TestHomeViewModel();
    });

    Future<void> pumpSearchBar(final WidgetTester tester) async {
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: _FakeAssetBundle(),
          child: MaterialApp(
            home: ChangeNotifierProvider<HomeViewModel>.value(
              value: vm,
              child: const Scaffold(body: BuildingSearchBar()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder findStartField() => find.byWidgetPredicate(
          (final widget) =>
              widget is TextField &&
              widget.decoration?.hintText == "Choose starting point",
        );

    Finder findDestinationFieldCollapsed() => find.byWidgetPredicate(
          (final widget) =>
              widget is TextField &&
              widget.decoration?.hintText == "Search for a place or address",
        );

    Finder findDestinationFieldExpanded() => find.byWidgetPredicate(
          (final widget) =>
              widget is TextField &&
              widget.decoration?.hintText == "Choose destination",
        );

    TextField getField(final WidgetTester tester, final Finder finder) {
      return tester.widget<TextField>(finder);
    }

    testWidgets("starts collapsed with destination field only", (
      final tester,
    ) async {
      await pumpSearchBar(tester);
      expect(findDestinationFieldCollapsed(), findsOneWidget);
      expect(findStartField(), findsNothing);
    });

    testWidgets("expands when selection labels are set", (
      final tester,
    ) async {
      await pumpSearchBar(tester);
      vm.setSearchBarExpanded(true);
      vm.selectedDestinationLabel = "Hall Building";
      vm.notifyListeners();
      await tester.pumpAndSettle();
      expect(findStartField(), findsOneWidget);
      expect(findDestinationFieldExpanded(), findsOneWidget);
    });

    testWidgets("collapses when view model requests collapse", (
      final tester,
    ) async {
      await pumpSearchBar(tester);
      vm.setSearchBarExpanded(true);
      vm.selectedDestinationLabel = "Hall Building";
      vm.notifyListeners();
      await tester.pumpAndSettle();
      expect(findStartField(), findsOneWidget);

      vm.selectedDestinationLabel = null;
      vm.setSearchBarExpanded(false);
      vm.notifyListeners();
      await tester.pumpAndSettle();

      expect(findStartField(), findsNothing);
      expect(findDestinationFieldCollapsed(), findsOneWidget);
    });

    testWidgets("typing in destination updates query", (
      final tester,
    ) async {
      await pumpSearchBar(tester);
      await tester.enterText(
        findDestinationFieldCollapsed(),
        "Dest query",
      );
      await tester.pumpAndSettle();
      expect(vm.lastQuery, equals("Dest query"));
    });

    testWidgets("clear destination query clears text and results", (
      final tester,
    ) async {
      await pumpSearchBar(tester);
      await tester.enterText(
        findDestinationFieldCollapsed(),
        "Clear me",
      );
      await tester.pumpAndSettle();

      final closeButton = find.byIcon(Icons.close);
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      final destField = getField(tester, findDestinationFieldCollapsed());
      expect(destField.controller?.text, isEmpty);
      expect(vm.clearSearchResultsCalled, isTrue);
    });

    testWidgets("cancel search clears selection and collapses", (
      final tester,
    ) async {
      await pumpSearchBar(tester);
      vm.selectedDestinationLabel = "Hall Building";
      vm.notifyListeners();
      await tester.pumpAndSettle();

      final cancelButton = find.byIcon(Icons.close);
      expect(cancelButton, findsOneWidget);
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      expect(vm.clearRouteSelectionCalled, isTrue);
      expect(findStartField(), findsNothing);
      expect(findDestinationFieldCollapsed(), findsOneWidget);
      expect(vm.isSearchBarExpanded, isFalse);
    });

    testWidgets("destination selection auto-sets start only when collapsed", (
      final tester,
    ) async {
      await pumpSearchBar(tester);
      vm.searchResults = [
        SearchSuggestion.place(
          const PlaceSuggestion(
            placeId: "place-1",
            description: "Place 1",
            mainText: "Place 1",
            secondaryText: "",
          ),
        ),
      ];
      vm.notifyListeners();
      await tester.pumpAndSettle();

      await tester.tap(find.text("Place 1"));
      await tester.pumpAndSettle();

      expect(vm.lastSelectedField, equals(SearchField.destination));
      expect(vm.setStartToCurrentLocationCalled, isTrue);
      final startField = getField(tester, findStartField());
      expect(startField.controller?.text, equals("Current location"));
      expect(vm.isSearchBarExpanded, isTrue);
    });

    testWidgets("destination selection does not auto-set when expanded", (
      final tester,
    ) async {
      await pumpSearchBar(tester);
      vm.selectedStartLabel = "Start A";
      vm.selectedDestinationLabel = "Dest A";
      vm.notifyListeners();
      await tester.pumpAndSettle();

      vm.setStartToCurrentLocationCalled = false;
      vm.searchResults = [
        SearchSuggestion.place(
          const PlaceSuggestion(
            placeId: "place-2",
            description: "Place 2",
            mainText: "Place 2",
            secondaryText: "",
          ),
        ),
      ];
      vm.notifyListeners();
      await tester.pumpAndSettle();

      await tester.tap(find.text("Place 2"));
      await tester.pumpAndSettle();

      expect(vm.setStartToCurrentLocationCalled, isFalse);
      final startField = getField(tester, findStartField());
      expect(startField.controller?.text, equals("Start A"));
    });

    testWidgets("start selection does not auto-set current location", (
      final tester,
    ) async {
      await pumpSearchBar(tester);
      vm.selectedDestinationLabel = "Hall Building";
      vm.notifyListeners();
      await tester.pumpAndSettle();

      await tester.tap(findStartField());
      await tester.pumpAndSettle();

      vm.searchResults = [
        SearchSuggestion.place(
          const PlaceSuggestion(
            placeId: "place-3",
            description: "Place 3",
            mainText: "Place 3",
            secondaryText: "",
          ),
        ),
      ];
      vm.notifyListeners();
      await tester.pumpAndSettle();

      await tester.tap(find.text("Place 3"));
      await tester.pumpAndSettle();

      expect(vm.lastSelectedField, equals(SearchField.start));
      expect(vm.setStartToCurrentLocationCalled, isFalse);
    });

    testWidgets("current location button updates start field", (
      final tester,
    ) async {
      await pumpSearchBar(tester);
      vm.selectedDestinationLabel = "Hall Building";
      vm.notifyListeners();
      await tester.pumpAndSettle();

      final locationButton = find.descendant(
        of: findStartField(),
        matching: find.byIcon(Icons.my_location),
      );

      await tester.tap(locationButton);
      await tester.pumpAndSettle();

      expect(vm.setStartToCurrentLocationCalled, isTrue);
      final startField = getField(tester, findStartField());
      expect(startField.controller?.text, equals("Current location"));
    });

    testWidgets("shows resolving start spinner", (
      final tester,
    ) async {
      await pumpSearchBar(tester);
      // First expand the search bar by setting a destination
      vm.selectedDestinationLabel = "Hall Building";
      vm.notifyListeners();
      await tester.pump();

      // Now set the resolving flag
      vm.isResolvingStartLocation = true;
      vm.notifyListeners();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets("syncs labels when not focused", (
      final tester,
    ) async {
      await pumpSearchBar(tester);
      vm.selectedStartLabel = "Start A";
      vm.selectedDestinationLabel = "Dest A";
      vm.notifyListeners();
      await tester.pumpAndSettle();

      final startField = getField(tester, findStartField());
      expect(startField.controller?.text, equals("Start A"));
    });

    testWidgets("does not override text while focused", (
      final tester,
    ) async {
      await pumpSearchBar(tester);
      vm.selectedDestinationLabel = "Hall Building";
      vm.notifyListeners();
      await tester.pumpAndSettle();

      await tester.tap(findStartField());
      await tester.pumpAndSettle();
      await tester.enterText(findStartField(), "User start");
      await tester.pumpAndSettle();

      vm.selectedStartLabel = "External change";
      vm.notifyListeners();
      await tester.pumpAndSettle();

      final startField = getField(tester, findStartField());
      expect(startField.controller?.text, equals("User start"));
    });

    testWidgets("unfocus signal clears focus", (
      final tester,
    ) async {
      await pumpSearchBar(tester);
      vm.selectedDestinationLabel = "Hall Building";
      vm.notifyListeners();
      await tester.pumpAndSettle();

      await tester.tap(findStartField());
      await tester.pumpAndSettle();

      final focusedField = getField(tester, findStartField());
      expect(focusedField.focusNode?.hasFocus, isTrue);

      vm.requestUnfocusSearchBar();
      await tester.pumpAndSettle();

      final updatedField = getField(tester, findStartField());
      expect(updatedField.focusNode?.hasFocus, isFalse);
    });

    testWidgets("shows building info button and opens detail screen", (
      final tester,
    ) async {
      final building = Building(
        id: "H",
        googlePlacesId: null,
        name: "Science Hall",
        description: "Test building",
        street: "7141 Rue Sherbrooke O",
        postalCode: "H4B 1R6",
        location: const Coordinate(latitude: 45.4572, longitude: -73.6404),
        hours: OpeningHoursDetail(),
        campus: Campus.loyola,
        outlinePoints: const [],
        images: const [],
        buildingFeatures: null,
      );
      vm.searchResults = [SearchSuggestion.building(building)];

      await pumpSearchBar(tester);
      vm.notifyListeners();
      await tester.pumpAndSettle();

      final infoButton = find.byIcon(Icons.info_outline);
      expect(infoButton, findsOneWidget);
      await tester.tap(infoButton);
      await tester.pumpAndSettle();

      expect(find.byType(BuildingDetailScreen), findsOneWidget);
    });
  });
}
