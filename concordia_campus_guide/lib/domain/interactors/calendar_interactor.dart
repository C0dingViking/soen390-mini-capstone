import "package:concordia_campus_guide/data/repositories/google_calendar.dart";
import "package:googleapis/calendar/v3.dart" as calendar;

class CalendarInteractor {
  final GoogleCalendarRepository _calendarRepo;

  CalendarInteractor({final GoogleCalendarRepository? calendarRepo})
    : _calendarRepo = calendarRepo ?? GoogleCalendarRepository();

  Future<List<calendar.Event>> getTodaysEvents() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return _calendarRepo.getEventsInRange(
      startDate: startOfDay,
      endDate: endOfDay,
    );
  }

  Future<List<calendar.Event>> getWeekEvents() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    return _calendarRepo.getEventsInRange(
      startDate: startOfWeek,
      endDate: endOfWeek,
    );
  }

  Future<List<calendar.Event>> getUpcomingEvents({final int count = 10}) async {
    return _calendarRepo.getUpcomingEvents(maxResults: count);
  }

  Future<List<calendar.Event>> getNextWeekEvents() async {
    final now = DateTime.now();
    final startOfNextWeek = now.add(const Duration(days: 1));
    final endOfNextWeek = now.add(const Duration(days: 7));

    return _calendarRepo.getEventsInRange(
      startDate: startOfNextWeek,
      endDate: endOfNextWeek,
    );
  }

  Future<bool> ensureCalendarAccess() async {
    final hasAccess = await _calendarRepo.hasCalendarAccess();
    if (hasAccess) return true;

    return _calendarRepo.requestCalendarAccess();
  }
}
