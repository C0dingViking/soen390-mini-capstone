import "package:concordia_campus_guide/data/repositories/google_calendar.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mockito/mockito.dart";

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

void main() {
  group("GoogleCalendarRepository unauthenticated", () {
    test("getUpcomingEvents returns empty list when no user", () async {
      final mockAuth = MockFirebaseAuth();
      when(mockAuth.currentUser).thenReturn(null);
      final repository = GoogleCalendarRepository(firebaseAuth: mockAuth);

      final events = await repository.getUpcomingEvents();

      expect(events, isEmpty);
    });

    test("getEventsInRange returns empty list when no user", () async {
      final mockAuth = MockFirebaseAuth();
      when(mockAuth.currentUser).thenReturn(null);
      final repository = GoogleCalendarRepository(firebaseAuth: mockAuth);

      final events = await repository.getEventsInRange(
        startDate: DateTime.parse("2025-01-01T00:00:00Z"),
        endDate: DateTime.parse("2025-01-02T00:00:00Z"),
      );

      expect(events, isEmpty);
    });

    test("getUserCalendars returns empty list when no user", () async {
      final mockAuth = MockFirebaseAuth();
      when(mockAuth.currentUser).thenReturn(null);
      final repository = GoogleCalendarRepository(firebaseAuth: mockAuth);

      final calendars = await repository.getUserCalendars();

      expect(calendars, isEmpty);
    });
  });
}
