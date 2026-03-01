import "package:concordia_campus_guide/data/repositories/google_calendar.dart";
import "package:concordia_campus_guide/domain/exceptions/invalid_location_format_exception.dart";
import "package:concordia_campus_guide/domain/interactors/calendar_interactor.dart";
import "package:flutter_test/flutter_test.dart";
import "package:googleapis/calendar/v3.dart";
import "package:mockito/annotations.dart";
import "package:mockito/mockito.dart";

import "calendar_interactor_test.mocks.dart";

@GenerateMocks([GoogleCalendarRepository])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const buildingDataPath = "assets/maps/building_data.json";

  group("CalendarInteractor unauthenticated", () {
    test("getUpcomingClasses returns empty list when no events returned", () async {
      final mockRepo = MockGoogleCalendarRepository();

      when(
        mockRepo.getUpcomingEvents(
          maxResults: anyNamed("maxResults"),
          timeMin: anyNamed("timeMin"),
          timeMax: anyNamed("timeMax"),
        ),
      ).thenAnswer((_) async => []);

      final interactor = CalendarInteractor(calendarRepo: mockRepo);

      final result = await interactor.getUpcomingClasses();

      expect(result, isEmpty);
    });

    test("getUpcomingClasses maps valid events and forwards time filters", () async {
      final mockRepo = MockGoogleCalendarRepository();
      final timeMin = DateTime.parse("2025-01-01T00:00:00Z");
      final timeMax = DateTime.parse("2025-01-08T00:00:00Z");

      final events = [
        Event(
          summary: "ENGR 201 LEC",
          location: "Sir George Williams Campus - Henry F. Hall Building (H) Rm 820",
          start: EventDateTime(dateTime: DateTime.parse("2025-01-02T14:00:00Z")),
          end: EventDateTime(dateTime: DateTime.parse("2025-01-02T16:00:00Z")),
        ),
      ];

      when(
        mockRepo.getUpcomingEvents(
          maxResults: anyNamed("maxResults"),
          timeMin: anyNamed("timeMin"),
          timeMax: anyNamed("timeMax"),
        ),
      ).thenAnswer((_) async => events);

      final interactor = CalendarInteractor(calendarRepo: mockRepo);

      final result = await interactor.getUpcomingClasses(
        maxResults: 5,
        timeMin: timeMin,
        timeMax: timeMax,
        buildingDataPath: buildingDataPath,
      );

      expect(result, hasLength(1));
      expect(result.first.name, "ENGR 201 LEC");
      expect(result.first.room.buildingId, "h");
      expect(result.first.room.roomNumber, "820");
      verify(
        mockRepo.getUpcomingEvents(maxResults: 5, timeMin: timeMin, timeMax: timeMax),
      ).called(1);
    });

    test("getUpcomingClasses skips invalid non-class events", () async {
      final mockRepo = MockGoogleCalendarRepository();

      final events = [
        Event(
          summary: "Team Meeting",
          location: "Sir George Williams Campus - Henry F. Hall Building (H) Rm 235",
          start: EventDateTime(dateTime: DateTime.parse("2025-01-01T10:00:00Z")),
          end: EventDateTime(dateTime: DateTime.parse("2025-01-01T11:00:00Z")),
        ),
        Event(
          summary: "ENGR 201 LEC",
          location: "Sir George Williams Campus - Henry F. Hall Building (H) Rm 820",
          start: EventDateTime(dateTime: DateTime.parse("2025-01-01T12:00:00Z")),
          end: EventDateTime(dateTime: DateTime.parse("2025-01-01T13:00:00Z")),
        ),
      ];

      when(
        mockRepo.getUpcomingEvents(
          maxResults: anyNamed("maxResults"),
          timeMin: anyNamed("timeMin"),
          timeMax: anyNamed("timeMax"),
        ),
      ).thenAnswer((_) async => events);

      final interactor = CalendarInteractor(calendarRepo: mockRepo);

      final result = await interactor.getUpcomingClasses(buildingDataPath: buildingDataPath);

      expect(result, hasLength(1));
      expect(result.first.name, "ENGR 201 LEC");
      expect(result.first.room.buildingId, "h");
    });

    test("getUpcomingClasses throws when class has unknown building name", () async {
      final mockRepo = MockGoogleCalendarRepository();

      final events = [
        Event(
          summary: "ENGR 201 LEC D",
          location: "Sir George Williams Campus - Unknown Building Rm 820",
          start: EventDateTime(dateTime: DateTime.parse("2025-01-01T12:00:00Z")),
          end: EventDateTime(dateTime: DateTime.parse("2025-01-01T13:00:00Z")),
        ),
      ];

      when(
        mockRepo.getUpcomingEvents(
          maxResults: anyNamed("maxResults"),
          timeMin: anyNamed("timeMin"),
          timeMax: anyNamed("timeMax"),
        ),
      ).thenAnswer((_) async => events);

      final interactor = CalendarInteractor(calendarRepo: mockRepo);

      await expectLater(
        interactor.getUpcomingClasses(buildingDataPath: buildingDataPath),
        throwsA(isA<InvalidLocationFormatException>()),
      );
    });
  });
}
