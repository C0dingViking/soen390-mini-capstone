import "package:concordia_campus_guide/data/repositories/google_calendar.dart";
import "package:concordia_campus_guide/domain/interactors/calendar_interactor.dart";
import "package:flutter_test/flutter_test.dart";
import "package:googleapis/calendar/v3.dart";
import "package:mockito/annotations.dart";
import "package:mockito/mockito.dart";

import "calendar_interactor_test.mocks.dart";

@GenerateMocks([GoogleCalendarRepository])
void main() {
  group("CalendarInteractor unauthenticated", () {
    test("getClassInRange throws when no events returned", () async {
      final mockRepo = MockGoogleCalendarRepository();
      final startDate = DateTime.parse("2025-01-01T00:00:00Z");
      final endDate = DateTime.parse("2025-01-02T00:00:00Z");

      when(
        mockRepo.getEventsInRange(startDate: anyNamed("startDate"), endDate: anyNamed("endDate")),
      ).thenAnswer((_) async => []);

      final interactor = CalendarInteractor(calendarRepo: mockRepo);

      await expectLater(
        interactor.getClassInRange(startDate: startDate, endDate: endDate),
        throwsA(isA<Exception>()),
      );
    });

    test("getClassInRange returns parsed classes when events are valid", () async {
      final mockRepo = MockGoogleCalendarRepository();
      final startDate = DateTime.parse("2025-01-01T00:00:00Z");
      final endDate = DateTime.parse("2025-01-02T00:00:00Z");

      final events = [
        Event(
          summary: "SOEN 390 LEC A",
          location: "Sir George Williams Campus - CL Building Rm 235",
          start: EventDateTime(dateTime: DateTime.parse("2025-01-01T10:00:00Z")),
          end: EventDateTime(dateTime: DateTime.parse("2025-01-01T11:00:00Z")),
        ),
      ];

      when(
        mockRepo.getEventsInRange(startDate: anyNamed("startDate"), endDate: anyNamed("endDate")),
      ).thenAnswer((_) async => events);

      final interactor = CalendarInteractor(calendarRepo: mockRepo);

      final result = await interactor.getClassInRange(startDate: startDate, endDate: endDate);

      expect(result, hasLength(1));
      expect(result.first.name, "SOEN 390 LEC A");
      expect(result.first.room.roomNumber, "235");
      verify(mockRepo.getEventsInRange(startDate: startDate, endDate: endDate)).called(1);
    });

    test("getClassInRange skips invalid events and returns valid ones", () async {
      final mockRepo = MockGoogleCalendarRepository();
      final startDate = DateTime.parse("2025-01-01T00:00:00Z");
      final endDate = DateTime.parse("2025-01-02T00:00:00Z");

      final events = [
        Event(
          summary: "",
          location: "Sir George Williams Campus - CL Building Rm 235",
          start: EventDateTime(dateTime: DateTime.parse("2025-01-01T08:00:00Z")),
          end: EventDateTime(dateTime: DateTime.parse("2025-01-01T09:00:00Z")),
        ),
        Event(
          summary: "COMP 248 TUT B",
          location: "Loyola Campus - SP Building Rm 101",
          start: EventDateTime(dateTime: DateTime.parse("2025-01-01T10:00:00Z")),
          end: EventDateTime(dateTime: DateTime.parse("2025-01-01T11:00:00Z")),
        ),
      ];

      when(
        mockRepo.getEventsInRange(startDate: anyNamed("startDate"), endDate: anyNamed("endDate")),
      ).thenAnswer((_) async => events);

      final interactor = CalendarInteractor(calendarRepo: mockRepo);

      final result = await interactor.getClassInRange(startDate: startDate, endDate: endDate);

      expect(result, hasLength(1));
      expect(result.first.name, "COMP 248 TUT B");
      expect(result.first.room.buildingId, "sp");
    });

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
          summary: "SOEN 390 LAB C",
          location: "Sir George Williams Campus - CL Building Rm S2.330",
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
      );

      expect(result, hasLength(1));
      expect(result.first.name, "SOEN 390 LAB C");
      expect(result.first.room.floor, "S2");
      verify(
        mockRepo.getUpcomingEvents(maxResults: 5, timeMin: timeMin, timeMax: timeMax),
      ).called(1);
    });

    test("getUpcomingClasses skips invalid events", () async {
      final mockRepo = MockGoogleCalendarRepository();

      final events = [
        Event(
          summary: "",
          location: "Sir George Williams Campus - CL Building Rm 235",
          start: EventDateTime(dateTime: DateTime.parse("2025-01-01T10:00:00Z")),
          end: EventDateTime(dateTime: DateTime.parse("2025-01-01T11:00:00Z")),
        ),
        Event(
          summary: "ENGR 201 LEC D",
          location: "Sir George Williams Campus - H Building Rm 820",
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

      final result = await interactor.getUpcomingClasses();

      expect(result, hasLength(1));
      expect(result.first.name, "ENGR 201 LEC D");
      expect(result.first.room.buildingId, "h");
    });
  });
}
