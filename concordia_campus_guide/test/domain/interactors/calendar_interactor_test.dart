import "package:concordia_campus_guide/data/repositories/google_calendar.dart";
import "package:concordia_campus_guide/domain/interactors/calendar_interactor.dart";
import "package:flutter_test/flutter_test.dart";
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
  });
}
