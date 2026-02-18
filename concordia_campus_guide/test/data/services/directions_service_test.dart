import "dart:convert";
import "package:concordia_campus_guide/data/services/api_key_service.dart";
import "package:concordia_campus_guide/data/services/directions_service.dart";
import "package:concordia_campus_guide/domain/models/coordinate.dart";
import "package:concordia_campus_guide/domain/models/route_option.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;

class _FakeApiKeyService extends ApiKeyService {
  _FakeApiKeyService(this.value);

  final String? value;

  @override
  Future<String?> getGoogleMapsApiKey() async => value;
}

class _FakeHttpClient extends http.BaseClient {
  http.Response? _response;
  Exception? _error;
  final List<Uri> capturedUris = <Uri>[];

  void setResponse(final http.Response response) {
    _response = response;
    _error = null;
  }

  void setError(final Exception error) {
    _error = error;
    _response = null;
  }

  @override
  Future<http.StreamedResponse> send(final http.BaseRequest request) async {
    capturedUris.add(request.url);

    if (_error != null) {
      throw _error!;
    }

    if (_response != null) {
      return http.StreamedResponse(
        Stream.value(utf8.encode(_response!.body)),
        _response!.statusCode,
        headers: _response!.headers,
      );
    }

    return http.StreamedResponse(
      Stream.value(utf8.encode("{}")),
      200,
    );
  }
}

void main() {
  group("DirectionsService", () {
    const Coordinate defaultOrigin = Coordinate(
      latitude: 45.5,
      longitude: -73.5,
    );
    const Coordinate defaultDestination = Coordinate(
      latitude: 45.6,
      longitude: -73.6,
    );

    late _FakeHttpClient fakeClient;
    late _FakeApiKeyService fakeApiKeyService;
    late DirectionsService service;

    Future<RouteOption?> fetchRoute({
      final DirectionsService? serviceOverride,
      final RouteMode mode = RouteMode.walking,
      final DateTime? departureTime,
      final DateTime? arrivalTime,
    }) {
      final routeService = serviceOverride ?? service;
      return routeService.fetchRoute(
        defaultOrigin,
        defaultDestination,
        mode,
        departureTime: departureTime,
        arrivalTime: arrivalTime,
      );
    }

    setUp(() {
      fakeClient = _FakeHttpClient();
      fakeApiKeyService = _FakeApiKeyService("test-api-key");
      service = DirectionsService(
        httpClient: fakeClient,
        apiKeyService: fakeApiKeyService,
      );
    });

    group("constructor", () {
      test("initializes with default client and api key service when none provided", () {
        final service = DirectionsService();
        expect(service, isNotNull);
      });

      test("initializes with provided client and api key service", () {
        final service = DirectionsService(
          httpClient: fakeClient,
          apiKeyService: fakeApiKeyService,
        );
        expect(service, isNotNull);
      });
    });

    group("fetchRoute", () {
      test("returns null when API key is not available", () async {
        final service = DirectionsService(
          httpClient: fakeClient,
          apiKeyService: _FakeApiKeyService(null),
        );

        final result = await fetchRoute(serviceOverride: service);

        expect(result, isNull);
        expect(fakeClient.capturedUris, isEmpty);
      });

      test("returns null when API key is empty string", () async {
        final service = DirectionsService(
          httpClient: fakeClient,
          apiKeyService: _FakeApiKeyService("  "),
        );

        final result = await fetchRoute(serviceOverride: service);

        expect(result, isNull);
        expect(fakeClient.capturedUris, isEmpty);
      });

      test("successfully fetches and parses walking route", () async {
        fakeClient.setResponse(http.Response(
          json.encode({
            "status": "OK",
            "routes": [
              {
                "summary": "Main St",
                "overview_polyline": {"points": "_p~iF~ps|U"},
                "legs": [
                  {
                    "distance": {"value": 1000, "text": "1.0 km"},
                    "duration": {"value": 600, "text": "10 mins"},
                    "steps": [
                      {
                        "distance": {"value": 500},
                        "duration": {"value": 300},
                        "travel_mode": "WALKING",
                        "html_instructions": "Walk to <b>Main St</b>",
                        "polyline": {"points": "gfo}EtbdwG"},
                      }
                    ],
                  }
                ],
              }
            ],
          }),
          200,
        ));

        final result = await fetchRoute();

        expect(result, isNotNull);
        expect(result?.mode, RouteMode.walking);
        expect(result?.distanceMeters, 1000);
        expect(result?.durationSeconds, 600);
        expect(result?.summary, "Main St");
        expect(result?.steps.length, 1);
        expect(result?.steps[0].instruction, "Walk to Main St");
      });

      test("successfully fetches transit route with departure time", () async {
        fakeClient.setResponse(http.Response(
          json.encode({
            "status": "OK",
            "routes": [
              {
                "overview_polyline": {"points": "_p~iF~ps|U"},
                "legs": [
                  {
                    "distance": {"value": 5000},
                    "duration": {"value": 1200},
                    "departure_time": {"value": 1234567890},
                    "arrival_time": {"value": 1234569090},
                    "steps": [
                      {
                        "distance": {"value": 5000},
                        "duration": {"value": 1200},
                        "travel_mode": "TRANSIT",
                        "html_instructions": "Take subway",
                        "polyline": {"points": ""},
                        "transit_details": {
                          "line": {
                            "name": "Green Line",
                            "short_name": "G",
                            "vehicle": {"type": "SUBWAY"},
                          },
                          "departure_stop": {"name": "Station A"},
                          "arrival_stop": {"name": "Station B"},
                          "num_stops": 5,
                        },
                      }
                    ],
                  }
                ],
              }
            ],
          }),
          200,
        ));

        final departureTime = DateTime(2026, 2, 14, 10, 0);
        final result = await fetchRoute(
          mode: RouteMode.transit,
          departureTime: departureTime,
        );

        expect(result, isNotNull);
        expect(result?.mode, RouteMode.transit);
        expect(result?.departureTime, isNotNull);
        expect(result?.arrivalTime, isNotNull);
        expect(result?.steps[0].transitDetails?.mode, TransitMode.subway);
        expect(result?.steps[0].transitDetails?.lineName, "Green Line");

        // Verify URI contains departure time
        final uri = fakeClient.capturedUris[0];
        expect(uri.queryParameters.containsKey("departure_time"), isTrue);
      });

      test("includes arrival time parameter when provided", () async {
        fakeClient.setResponse(http.Response(
          json.encode({
            "status": "OK",
            "routes": [
              {
                "overview_polyline": {"points": ""},
                "legs": [
                  {"distance": {"value": 1000}, "duration": {"value": 300}}
                ],
              }
            ],
          }),
          200,
        ));

        final arrivalTime = DateTime(2026, 2, 14, 16, 0);
        await fetchRoute(
          mode: RouteMode.transit,
          arrivalTime: arrivalTime,
        );

        final uri = fakeClient.capturedUris[0];
        expect(uri.queryParameters.containsKey("arrival_time"), isTrue);
      });

      test("returns null when HTTP status is not 200", () async {
        fakeClient.setResponse(http.Response("Forbidden", 403));

        final result = await fetchRoute();

        expect(result, isNull);
      });

      test("returns null when response status is not OK", () async {
        fakeClient.setResponse(http.Response(
          json.encode({"status": "ZERO_RESULTS", "routes": <Map<String, dynamic>>[]}),
          200,
        ));

        final result = await fetchRoute();

        expect(result, isNull);
      });

      test("returns null when routes array is empty", () async {
        fakeClient.setResponse(http.Response(
          json.encode({"status": "OK", "routes": <Map<String, dynamic>>[]}),
          200,
        ));

        final result = await fetchRoute();

        expect(result, isNull);
      });

      test("returns null when HTTP request throws exception", () async {
        fakeClient.setError(Exception("Network error"));

        final result = await fetchRoute();

        expect(result, isNull);
      });

      test("caches API key across multiple requests", () async {
        var callCount = 0;
        final countingApiKeyService = _CountingApiKeyService(() {
          callCount++;
          return "test-key";
        });

        fakeClient.setResponse(http.Response(
          json.encode({
            "status": "OK",
            "routes": [
              {
                "overview_polyline": {"points": ""},
                "legs": [
                  {"distance": {"value": 1000}, "duration": {"value": 300}}
                ],
              }
            ],
          }),
          200,
        ));

        final service = DirectionsService(
          httpClient: fakeClient,
          apiKeyService: countingApiKeyService,
        );

        await fetchRoute(serviceOverride: service);

        await fetchRoute(
          serviceOverride: service,
          mode: RouteMode.bicycling,
        );

        expect(callCount, 1); // API key fetched only once
      });
    });

    group("URI building", () {
      test("builds correct URI for walking mode", () async {
        fakeClient.setResponse(http.Response(
          json.encode({"status": "ZERO_RESULTS", "routes": <Map<String, dynamic>>[]}),
          200,
        ));

        await fetchRoute();

        final uri = fakeClient.capturedUris[0];
        expect(uri.scheme, "https");
        expect(uri.host, "maps.googleapis.com");
        expect(uri.path, "/maps/api/directions/json");
        expect(uri.queryParameters["origin"], "45.5,-73.5");
        expect(uri.queryParameters["destination"], "45.6,-73.6");
        expect(uri.queryParameters["mode"], "walking");
        expect(uri.queryParameters["alternatives"], "false");
        expect(uri.queryParameters["key"], "test-api-key");
      });

      test("includes transit_mode parameter for transit routes", () async {
        fakeClient.setResponse(http.Response(
          json.encode({"status": "ZERO_RESULTS", "routes": <Map<String, dynamic>>[]}),
          200,
        ));

        await fetchRoute(mode: RouteMode.transit);

        final uri = fakeClient.capturedUris[0];
        expect(uri.queryParameters["mode"], "transit");
        expect(uri.queryParameters["transit_mode"], "subway|bus|train|rail");
      });

      test("converts mode enum to correct string for all modes", () async {
        fakeClient.setResponse(http.Response(
          json.encode({"status": "ZERO_RESULTS", "routes": <Map<String, dynamic>>[]}),
          200,
        ));

        final modes = [
          (RouteMode.walking, "walking"),
          (RouteMode.bicycling, "bicycling"),
          (RouteMode.driving, "driving"),
          (RouteMode.transit, "transit"),
        ];

        for (final (mode, expectedString) in modes) {
          fakeClient.capturedUris.clear();
          await fetchRoute(mode: mode);

          final uri = fakeClient.capturedUris[0];
          expect(uri.queryParameters["mode"], expectedString,
              reason: "Mode $mode should convert to $expectedString");
        }
      });
    });

    group("route parsing", () {
      test("handles route with no legs", () async {
        fakeClient.setResponse(http.Response(
          json.encode({
            "status": "OK",
            "routes": [
              {
                "overview_polyline": {"points": ""},
                "legs": <Map<String, dynamic>>[],
              }
            ],
          }),
          200,
        ));

        final result = await fetchRoute();

        expect(result, isNotNull);
        expect(result?.steps, isEmpty);
      });

      test("handles missing optional fields gracefully", () async {
        fakeClient.setResponse(http.Response(
          json.encode({
            "status": "OK",
            "routes": [
              {
                "overview_polyline": {"points": ""},
                "legs": [
                  {
                    "steps": <Map<String, dynamic>>[],
                  }
                ],
              }
            ],
          }),
          200,
        ));

        final result = await fetchRoute();

        expect(result, isNotNull);
        expect(result?.distanceMeters, isNull);
        expect(result?.durationSeconds, isNull);
        expect(result?.summary, isNull);
      });

      test("parses empty polyline correctly", () async {
        fakeClient.setResponse(http.Response(
          json.encode({
            "status": "OK",
            "routes": [
              {
                "overview_polyline": {"points": ""},
                "legs": [
                  {"distance": {"value": 1000}, "duration": {"value": 300}}
                ],
              }
            ],
          }),
          200,
        ));

        final result = await fetchRoute();

        expect(result?.polyline, isEmpty);
      });
    });

    group("step parsing", () {
      test("parses multiple steps correctly", () async {
        fakeClient.setResponse(http.Response(
          json.encode({
            "status": "OK",
            "routes": [
              {
                "overview_polyline": {"points": ""},
                "legs": [
                  {
                    "steps": [
                      {
                        "distance": {"value": 500},
                        "duration": {"value": 300},
                        "travel_mode": "WALKING",
                        "html_instructions": "Step 1",
                        "polyline": {"points": ""},
                      },
                      {
                        "distance": {"value": 600},
                        "duration": {"value": 400},
                        "travel_mode": "WALKING",
                        "html_instructions": "Step 2",
                        "polyline": {"points": ""},
                      }
                    ],
                  }
                ],
              }
            ],
          }),
          200,
        ));

        final result = await fetchRoute();

        expect(result?.steps.length, 2);
        expect(result?.steps[0].distanceMeters, 500);
        expect(result?.steps[0].durationSeconds, 300);
        expect(result?.steps[1].distanceMeters, 600);
        expect(result?.steps[1].durationSeconds, 400);
      });

      test("handles step with missing fields", () async {
        fakeClient.setResponse(http.Response(
          json.encode({
            "status": "OK",
            "routes": [
              {
                "overview_polyline": {"points": ""},
                "legs": [
                  {
                    "steps": [
                      {
                        "travel_mode": "WALKING",
                        "polyline": {"points": ""},
                      }
                    ],
                  }
                ],
              }
            ],
          }),
          200,
        ));

        final result = await fetchRoute();

        expect(result?.steps.length, 1);
        expect(result?.steps[0].instruction, "");
        expect(result?.steps[0].distanceMeters, 0);
        expect(result?.steps[0].durationSeconds, 0);
      });
    });

    group("transit details parsing", () {
      test("parses all transit modes correctly", () async {
        final vehicleTypes = [
          ("SUBWAY", TransitMode.subway),
          ("METRO_RAIL", TransitMode.subway),
          ("BUS", TransitMode.bus),
          ("TRAIN", TransitMode.train),
          ("HEAVY_RAIL", TransitMode.train),
          ("TRAM", TransitMode.tram),
          ("RAIL", TransitMode.rail),
          ("UNKNOWN_TYPE", TransitMode.bus),
        ];

        for (final (vehicleType, expectedMode) in vehicleTypes) {
          fakeClient.setResponse(http.Response(
            json.encode({
              "status": "OK",
              "routes": [
                {
                  "overview_polyline": {"points": ""},
                  "legs": [
                    {
                      "steps": [
                        {
                          "travel_mode": "TRANSIT",
                          "polyline": {"points": ""},
                          "transit_details": {
                            "line": {
                              "name": "Test Line",
                              "short_name": "T",
                              "vehicle": {"type": vehicleType},
                            },
                            "departure_stop": {"name": "Stop A"},
                            "arrival_stop": {"name": "Stop B"},
                            "num_stops": 3,
                          },
                        }
                      ],
                    }
                  ],
                }
              ],
            }),
            200,
          ));

          final result = await fetchRoute(mode: RouteMode.transit);

          expect(result?.steps[0].transitDetails?.mode, expectedMode,
              reason: "Vehicle type $vehicleType should map to $expectedMode");
        }
      });

      test("parses complete transit details", () async {
        fakeClient.setResponse(http.Response(
          json.encode({
            "status": "OK",
            "routes": [
              {
                "overview_polyline": {"points": ""},
                "legs": [
                  {
                    "steps": [
                      {
                        "travel_mode": "TRANSIT",
                        "polyline": {"points": ""},
                        "transit_details": {
                          "line": {
                            "name": "Green Line",
                            "short_name": "G",
                            "vehicle": {"type": "SUBWAY"},
                          },
                          "departure_stop": {"name": "Station A"},
                          "arrival_stop": {"name": "Station B"},
                          "num_stops": 5,
                        },
                      }
                    ],
                  }
                ],
              }
            ],
          }),
          200,
        ));

        final result = await fetchRoute(mode: RouteMode.transit);

        final transitDetails = result?.steps[0].transitDetails;
        expect(transitDetails?.lineName, "Green Line");
        expect(transitDetails?.shortName, "G");
        expect(transitDetails?.mode, TransitMode.subway);
        expect(transitDetails?.departureStop, "Station A");
        expect(transitDetails?.arrivalStop, "Station B");
        expect(transitDetails?.numStops, 5);
      });

      test("handles missing transit details fields", () async {
        fakeClient.setResponse(http.Response(
          json.encode({
            "status": "OK",
            "routes": [
              {
                "overview_polyline": {"points": ""},
                "legs": [
                  {
                    "steps": [
                      {
                        "travel_mode": "TRANSIT",
                        "polyline": {"points": ""},
                        "transit_details": {
                          "line": {"vehicle": {"type": "BUS"}},
                        },
                      }
                    ],
                  }
                ],
              }
            ],
          }),
          200,
        ));

        final result = await fetchRoute(mode: RouteMode.transit);

        final transitDetails = result?.steps[0].transitDetails;
        expect(transitDetails?.lineName, "");
        expect(transitDetails?.shortName, "");
        expect(transitDetails?.departureStop, "");
        expect(transitDetails?.arrivalStop, "");
        expect(transitDetails?.numStops, isNull);
      });
    });

    group("HTML stripping", () {
      test("strips HTML tags from instructions", () async {
        fakeClient.setResponse(http.Response(
          json.encode({
            "status": "OK",
            "routes": [
              {
                "overview_polyline": {"points": ""},
                "legs": [
                  {
                    "steps": [
                      {
                        "travel_mode": "WALKING",
                        "html_instructions": "Walk to <b>Main St</b> and turn <i>left</i>",
                        "polyline": {"points": ""},
                      }
                    ],
                  }
                ],
              }
            ],
          }),
          200,
        ));

        final result = await fetchRoute();

        expect(result?.steps[0].instruction, "Walk to Main St and turn left");
      });

      test("converts HTML entities correctly", () async {
        fakeClient.setResponse(http.Response(
          json.encode({
            "status": "OK",
            "routes": [
              {
                "overview_polyline": {"points": ""},
                "legs": [
                  {
                    "steps": [
                      {
                        "travel_mode": "WALKING",
                        "html_instructions": "Turn&nbsp;left &amp; continue&lt;test&gt;&quot;quoted&quot;",
                        "polyline": {"points": ""},
                      }
                    ],
                  }
                ],
              }
            ],
          }),
          200,
        ));

        final result = await fetchRoute();

        expect(result?.steps[0].instruction, 'Turn left & continue<test>"quoted"');
      });

      test("handles nested HTML tags", () async {
        fakeClient.setResponse(http.Response(
          json.encode({
            "status": "OK",
            "routes": [
              {
                "overview_polyline": {"points": ""},
                "legs": [
                  {
                    "steps": [
                      {
                        "travel_mode": "WALKING",
                        "html_instructions": "<div><b><i>Nested</i> tags</b></div>",
                        "polyline": {"points": ""},
                      }
                    ],
                  }
                ],
              }
            ],
          }),
          200,
        ));

        final result = await fetchRoute();

        expect(result?.steps[0].instruction, "Nested tags");
      });
    });

    group("time parsing", () {
      test("parses Unix timestamps correctly", () async {
        fakeClient.setResponse(http.Response(
          json.encode({
            "status": "OK",
            "routes": [
              {
                "overview_polyline": {"points": ""},
                "legs": [
                  {
                    "departure_time": {"value": 1234567890},
                    "arrival_time": {"value": 1234568190},
                  }
                ],
              }
            ],
          }),
          200,
        ));

        final result = await fetchRoute(mode: RouteMode.transit);

        expect(result?.departureTime, DateTime.fromMillisecondsSinceEpoch(1234567890000));
        expect(result?.arrivalTime, DateTime.fromMillisecondsSinceEpoch(1234568190000));
      });

      test("handles missing time values", () async {
        fakeClient.setResponse(http.Response(
          json.encode({
            "status": "OK",
            "routes": [
              {
                "overview_polyline": {"points": ""},
                "legs": [
                  {"distance": {"value": 1000}}
                ],
              }
            ],
          }),
          200,
        ));

        final result = await fetchRoute();

        expect(result?.departureTime, isNull);
        expect(result?.arrivalTime, isNull);
      });
    });
  });
}

class _CountingApiKeyService extends ApiKeyService {
  _CountingApiKeyService(this.keyProvider);

  final String? Function() keyProvider;

  @override
  Future<String?> getGoogleMapsApiKey() async => keyProvider();
}
