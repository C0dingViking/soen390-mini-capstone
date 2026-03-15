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
    test(
      "getUpcomingClasses returns empty list when no events returned",
      () async {
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
      },
    );

    test(
      "getUpcomingClasses maps valid events and forwards time filters",
      () async {
        final mockRepo = MockGoogleCalendarRepository();
        final timeMin = DateTime.parse("2025-01-01T00:00:00Z");
        final timeMax = DateTime.parse("2025-01-08T00:00:00Z");

        final events = [
          Event(
            summary: "ENGR 201 LEC",
            location:
                "Sir George Williams Campus - Henry F. Hall Building (H) Rm 820",
            start: EventDateTime(
              dateTime: DateTime.parse("2025-01-02T14:00:00Z"),
            ),
            end: EventDateTime(
              dateTime: DateTime.parse("2025-01-02T16:00:00Z"),
            ),
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
          mockRepo.getUpcomingEvents(
            maxResults: 5,
            timeMin: timeMin,
            timeMax: timeMax,
          ),
        ).called(1);
      },
    );

    test("getUpcomingClasses skips invalid non-class events", () async {
      final mockRepo = MockGoogleCalendarRepository();

      final events = [
        Event(
          summary: "Team Meeting",
          location:
              "Sir George Williams Campus - Henry F. Hall Building (H) Rm 235",
          start: EventDateTime(
            dateTime: DateTime.parse("2025-01-01T10:00:00Z"),
          ),
          end: EventDateTime(dateTime: DateTime.parse("2025-01-01T11:00:00Z")),
        ),
        Event(
          summary: "ENGR 201 LEC",
          location:
              "Sir George Williams Campus - Henry F. Hall Building (H) Rm 820",
          start: EventDateTime(
            dateTime: DateTime.parse("2025-01-01T12:00:00Z"),
          ),
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

      final result = await interactor.getUpcomingClasses(
        buildingDataPath: buildingDataPath,
      );

      expect(result, hasLength(1));
      expect(result.first.name, "ENGR 201 LEC");
      expect(result.first.room.buildingId, "h");
    });

    test("maps Faubourg Building (FG) to fg building id", () async {
      final mockRepo = MockGoogleCalendarRepository();

      final events = [
        Event(
          summary: "SOEN 390 LEC",
          location:
              "Sir George Williams Campus - Faubourg Building (FG) Rm B123",
          start: EventDateTime(
            dateTime: DateTime.parse("2025-01-01T10:00:00Z"),
          ),
          end: EventDateTime(dateTime: DateTime.parse("2025-01-01T11:00:00Z")),
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
        buildingDataPath: "test/assets/building_testdata.json",
      );

      expect(result, hasLength(1));
      expect(result.first.room.buildingId, "fg");
      expect(result.first.room.roomNumber, "B123");
    });

    test("maps Faubourg Tower (FB) to fb building id", () async {
      final mockRepo = MockGoogleCalendarRepository();

      final events = [
        Event(
          summary: "SOEN 390 LEC",
          location: "Sir George Williams Campus - Faubourg Tower (FB) Rm S123",
          start: EventDateTime(
            dateTime: DateTime.parse("2025-01-01T10:00:00Z"),
          ),
          end: EventDateTime(dateTime: DateTime.parse("2025-01-01T11:00:00Z")),
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
        buildingDataPath: "test/assets/building_testdata.json",
      );

      expect(result, hasLength(1));
      expect(result.first.room.buildingId, "fb");
      expect(result.first.room.roomNumber, "S123");
    });

    test("maps CL Building to cl building id", () async {
      final mockRepo = MockGoogleCalendarRepository();

      final events = [
        Event(
          summary: "SOEN 390 LEC",
          location: "Sir George Williams Campus - CL Building Rm 123",
          start: EventDateTime(
            dateTime: DateTime.parse("2025-01-01T10:00:00Z"),
          ),
          end: EventDateTime(dateTime: DateTime.parse("2025-01-01T11:00:00Z")),
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
        buildingDataPath: "test/assets/building_testdata.json",
      );

      expect(result, hasLength(1));
      expect(result.first.room.buildingId, "cl");
      expect(result.first.room.roomNumber, "123");
    });

    test("uses unsupported building name as building id fallback", () async {
      final mockRepo = MockGoogleCalendarRepository();

      final events = [
        Event(
          summary: "SOEN 390 LEC",
          location: "Loyola Campus - Mystery Annex Rm A101",
          start: EventDateTime(
            dateTime: DateTime.parse("2025-01-01T10:00:00Z"),
          ),
          end: EventDateTime(dateTime: DateTime.parse("2025-01-01T11:00:00Z")),
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
        buildingDataPath: "test/assets/building_testdata.json",
      );

      expect(result, hasLength(1));
      expect(result.first.room.buildingId, "Mystery Annex");
      expect(result.first.room.roomNumber, "A101");
    });

    test(
      "throws when building name cannot be extracted from location",
      () async {
        final mockRepo = MockGoogleCalendarRepository();

        final events = [
          Event(
            summary: "SOEN 390 LEC",
            location: "Sir George Williams Campus Rm 820",
            start: EventDateTime(
              dateTime: DateTime.parse("2025-01-01T10:00:00Z"),
            ),
            end: EventDateTime(
              dateTime: DateTime.parse("2025-01-01T11:00:00Z"),
            ),
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

        expect(
          () => interactor.getUpcomingClasses(
            buildingDataPath: "test/assets/building_testdata.json",
          ),
          throwsA(isA<InvalidLocationFormatException>()),
        );
      },
    );
  });
}
