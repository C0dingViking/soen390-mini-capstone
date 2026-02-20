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
    final events = await _calendarRepo.getEventsInRange(
      startDate: startDate,
      endDate: endDate,
    );

    final academicClasses = <AcademicClass>[];
    for (final event in events) {
      try {
        final academicClass = AcademicClass.fromCalendar(event);
        academicClasses.add(academicClass);
      } catch (e) {
        continue;
      }
    }

    if (academicClasses.isEmpty) {
      throw Exception("No academic classes found in the specified date range");
    }

    return academicClasses;
  }
}
