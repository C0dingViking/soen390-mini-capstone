import "package:concordia_campus_guide/data/repositories/building_repository.dart";
import "package:concordia_campus_guide/data/repositories/google_calendar.dart";
import "package:concordia_campus_guide/domain/interactors/calendar_interactor.dart";
import "package:concordia_campus_guide/domain/interactors/directions_interactor.dart";
import "package:concordia_campus_guide/domain/interactors/map_data_interactor.dart";
import "package:concordia_campus_guide/domain/interactors/places_interactor.dart";
import "package:concordia_campus_guide/domain/models/calendar_option.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/models/place_suggestion.dart";
import "package:concordia_campus_guide/domain/models/route_option.dart";
import "package:concordia_campus_guide/ui/home/view_models/home_view_model.dart";
import "package:concordia_campus_guide/ui/home/widgets/calendar_picker.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:googleapis/calendar/v3.dart" as calendar;
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

class _FakeGoogleCalendarRepository implements GoogleCalendarRepository {
  @override
  Future<List<calendar.Event>> getUpcomingEvents({
    final int maxResults = 10,
    final DateTime? timeMin,
    final DateTime? timeMax,
    final String calendarId = "primary",
  }) async => [];

  @override
  Future<List<calendar.Event>> getEventsInRange({
    required final DateTime startDate,
    required final DateTime endDate,
    final String calendarId = "primary",
  }) async => [];

  @override
  Future<List<calendar.CalendarListEntry>> getUserCalendars() async => [];
}

class _FakeCalendarInteractor extends CalendarInteractor {
  _FakeCalendarInteractor() : super(calendarRepo: _FakeGoogleCalendarRepository());
}

class _TestHomeViewModel extends HomeViewModel {
  _TestHomeViewModel()
    : super(
        mapInteractor: MapDataInteractor(
          buildingRepo: BuildingRepository(buildingLoader: (_) async => "{}"),
        ),
        placesInteractor: _FakePlacesInteractor(),
        directionsInteractor: _FakeDirectionsInteractor(),
        calendarInteractor: _FakeCalendarInteractor(),
      );

  List<CalendarOption> options = [];
  bool? lastToggleFabValue;
  int clearUpcomingClassCount = 0;

  @override
  List<CalendarOption> get getCalendarTitles => options;

  @override
  void toggleNextClassFabVisibility(final bool isVisible) {
    lastToggleFabValue = isVisible;
  }

  @override
  void clearUpcomingClass() {
    clearUpcomingClassCount++;
  }
}

class _DialogHost extends StatefulWidget {
  const _DialogHost();

  @override
  State<_DialogHost> createState() => _DialogHostState();
}

class _DialogHostState extends State<_DialogHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const CalendarPicker(),
      );
    });
  }

  @override
  Widget build(final BuildContext context) {
    return const Scaffold(body: SizedBox());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("CalendarPicker", () {
    late _TestHomeViewModel vm;

    setUp(() {
      vm = _TestHomeViewModel();
      vm.options = [
        CalendarOption(title: "Primary", id: "primary"),
        CalendarOption(title: "Work", id: "work"),
      ];
    });

    Future<void> pumpPicker(final WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<HomeViewModel>.value(
          value: vm,
          child: const MaterialApp(home: _DialogHost()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets("renders title, hint, and calendars in dropdown", (final tester) async {
      await pumpPicker(tester);

      expect(find.text("Select a Calendar"), findsOneWidget);
      expect(find.text("Choose a calendar"), findsOneWidget);

      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();

      expect(find.text("Primary"), findsWidgets);
      expect(find.text("Work"), findsOneWidget);
    });

    testWidgets("shows validation error when confirming without selection", (final tester) async {
      await pumpPicker(tester);

      await tester.tap(find.text("Confirm"));
      await tester.pumpAndSettle();

      expect(find.text("Selection cannot be empty"), findsOneWidget);
      expect(find.text("Select a Calendar"), findsOneWidget);
      expect(vm.lastToggleFabValue, isNull);
      expect(vm.clearUpcomingClassCount, equals(0));
    });

    testWidgets("selecting a calendar updates state but does not trigger confirm side effects", (
      final tester,
    ) async {
      await pumpPicker(tester);

      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Primary").last);
      await tester.pumpAndSettle();

      expect(vm.selectedCalendarId, equals("primary"));
      expect(vm.lastToggleFabValue, isNull);
      expect(vm.clearUpcomingClassCount, equals(0));
      expect(find.text("Select a Calendar"), findsOneWidget);
    });

    testWidgets("preselected calendar allows immediate confirm", (final tester) async {
      vm.selectedCalendarId = "primary";
      await pumpPicker(tester);

      expect(find.text("Choose a calendar"), findsNothing);

      await tester.tap(find.text("Confirm"));
      await tester.pumpAndSettle();

      expect(vm.lastToggleFabValue, isTrue);
      expect(vm.clearUpcomingClassCount, equals(1));
      expect(find.text("Google Calendar imported successfully!"), findsOneWidget);
      expect(find.text("Select a Calendar"), findsNothing);
    });

    testWidgets("confirming with selected calendar triggers actions and closes dialog", (
      final tester,
    ) async {
      await pumpPicker(tester);

      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Work").last);
      await tester.pumpAndSettle();

      expect(vm.selectedCalendarId, equals("work"));

      await tester.tap(find.text("Confirm"));
      await tester.pumpAndSettle();

      expect(vm.lastToggleFabValue, isTrue);
      expect(vm.clearUpcomingClassCount, equals(1));
      expect(find.text("Google Calendar imported successfully!"), findsOneWidget);
      expect(find.text("Select a Calendar"), findsNothing);
    });
  });
}
