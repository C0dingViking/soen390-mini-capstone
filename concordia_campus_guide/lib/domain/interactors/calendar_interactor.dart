import "package:concordia_campus_guide/data/repositories/google_calendar.dart";
import "package:concordia_campus_guide/domain/models/academic_class.dart";

class CalendarInteractor {
  final GoogleCalendarRepository _calendarRepo;

  CalendarInteractor({final GoogleCalendarRepository? calendarRepo})
    : _calendarRepo = calendarRepo ?? GoogleCalendarRepository();

  Future<List<AcademicClass>> getClassInRange({
    required final DateTime startDate,
    required final DateTime endDate,
  }) async {
    final events = await _calendarRepo.getEventsInRange(startDate: startDate, endDate: endDate);

    final academicClasses = <AcademicClass>[];
    for (final event in events) {
      try {
        final academicClass = AcademicClass.fromCalendar(event);
        academicClasses.add(academicClass);
      } catch (ignored) {
        continue;
      }
    }

    if (academicClasses.isEmpty) {
      throw Exception("No academic classes found in the specified date range");
    }

    return academicClasses;
  }

  Future<List<AcademicClass>> getUpcomingClasses({
    final int maxResults = 10,
    final DateTime? timeMin,
    final DateTime? timeMax,
  }) async {
    final events = await _calendarRepo.getUpcomingEvents(
      maxResults: maxResults,
      timeMin: timeMin,
      timeMax: timeMax,
    );

    final academicClasses = <AcademicClass>[];
    for (final event in events) {
      try {
        final academicClass = AcademicClass.fromCalendar(event);
        academicClasses.add(academicClass);
      } catch (ignored) {
        continue;
      }
    }
    // It's possible that there are no upcoming classes, but we don't want to throw an error in that case since it's a valid state

    return academicClasses;
  }
}
