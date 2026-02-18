import "package:googleapis/calendar/v3.dart" as calendar;
import "package:firebase_auth/firebase_auth.dart";
import "package:google_sign_in/google_sign_in.dart";
import "package:http/http.dart" as http;
import "package:concordia_campus_guide/utils/app_logger.dart";

class GoogleCalendarRepository {
  final FirebaseAuth _firebaseAuth;

  GoogleCalendarRepository({final FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  Future<calendar.CalendarApi?> _getCalendarApi() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        logger.w("GoogleCalendarRepository: No signed-in user");
        return null;
      }

      final googleSignIn = GoogleSignIn(
        scopes: [calendar.CalendarApi.calendarScope],
      );

      // use cached user to sign in and get the headers (kind of a hack)
      final googleAccount = await googleSignIn.signInSilently();
      if (googleAccount == null) {
        logger.w("GoogleCalendarRepository: No Google account");
        return null;
      }

      final authHeaders = await googleAccount.authHeaders;
      final authenticateClient = _GoogleAuthClient(authHeaders);

      return calendar.CalendarApi(authenticateClient);
    } catch (e, stackTrace) {
      logger.e(
        "GoogleCalendarRepository: Failed to get calendar API",
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<List<calendar.Event>> getUpcomingEvents({
    final int maxResults = 10,
    final DateTime? timeMin,
    final DateTime? timeMax,
  }) async {
    try {
      final api = await _getCalendarApi();
      if (api == null) return [];

      final now = timeMin ?? DateTime.now();
      final events = await api.events.list(
        "primary",
        timeMin: now.toUtc(),
        timeMax: timeMax?.toUtc(),
        maxResults: maxResults,
        singleEvents: true,
        orderBy: "startTime",
      );

      return events.items ?? [];
    } catch (e, stackTrace) {
      logger.e(
        "GoogleCalendarRepository: Failed to fetch events",
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  Future<List<calendar.Event>> getEventsInRange({
    required final DateTime startDate,
    required final DateTime endDate,
  }) async {
    return getUpcomingEvents(
      timeMin: startDate,
      timeMax: endDate,
      maxResults: 100,
    );
  }

  Future<bool> hasCalendarAccess() async {
    return _firebaseAuth.currentUser != null;
  }

  Future<bool> requestCalendarAccess() async {
    return _firebaseAuth.currentUser != null;
  }
}

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(final http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}
