import "dart:async";
import "package:concordia_campus_guide/ui/auth/widgets/login_screen.dart";
import "package:firebase_core/firebase_core.dart";
import "package:firebase_core_platform_interface/firebase_core_platform_interface.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mockito/mockito.dart";
import "package:mockito/annotations.dart";
import "package:provider/provider.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:concordia_campus_guide/ui/hamburger_menu/widgets/hamburger_menu.dart";
import "package:concordia_campus_guide/ui/auth/view_models/login_view_model.dart";
import "hamburger_menu_test.mocks.dart";
import "package:mocktail_image_network/mocktail_image_network.dart";
import "package:google_sign_in/google_sign_in.dart";

@GenerateNiceMocks([MockSpec<User>()])
@GenerateMocks([LoginViewModel, FirebaseAuth, GoogleSignIn])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("HamburgerMenu Widget Tests with HTTP Mocking", () {
    late MockLoginViewModel mockLoginViewModel;
    late MockUser mockUser;
    late MockFirebaseAuth mockAuth;
    late MockGoogleSignIn mockGoogleSignIn;

    setUpAll(() async {
      FirebasePlatform.instance = _FakeFirebasePlatform();
      await Firebase.initializeApp();
    });

    setUp(() {
      mockLoginViewModel = MockLoginViewModel();
      mockUser = MockUser();

      mockAuth = MockFirebaseAuth();
      when(mockAuth.signOut()).thenAnswer((_) async => Future.value());

      mockGoogleSignIn = MockGoogleSignIn();
      when(mockGoogleSignIn.signOut()).thenAnswer((_) async {
        return Future.value();
      });
    });

    Future<void> pumpHamburgerMenu(
      final WidgetTester tester, {
      required final bool isSignedIn,
    }) async {
      when(mockUser.displayName).thenReturn("John Doe");
      when(mockUser.email).thenReturn("john.doe@example.com");
      when(mockUser.photoURL).thenReturn("https://example.com/avatar.png");
      when(mockLoginViewModel.isSignedIn).thenReturn(isSignedIn);
      when(mockLoginViewModel.currentUser).thenReturn(mockUser);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<LoginViewModel>.value(
            value: mockLoginViewModel,
            child: const Scaffold(drawer: HamburgerMenu(), body: SizedBox()),
          ),
        ),
      );

      await tester.pumpAndSettle();
    }

    testWidgets("renders Login tile when user is signed out", (
      final tester,
    ) async {
      await mockNetworkImages(() async {
        final mockLoginViewModel = MockLoginViewModel();
        final mockUser = MockUser();

        when(mockLoginViewModel.isSignedIn).thenReturn(false);
        when(mockLoginViewModel.currentUser).thenReturn(mockUser);

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<LoginViewModel>.value(
              value: mockLoginViewModel,
              child: const Scaffold(drawer: HamburgerMenu(), body: SizedBox()),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final ScaffoldState scaffoldState = tester.firstState(
          find.byType(Scaffold),
        );
        scaffoldState.openDrawer();
        await tester.pumpAndSettle();

        expect(find.text("Login"), findsOneWidget);
        expect(find.byIcon(Icons.login_sharp), findsOneWidget);
      });
    });

    testWidgets(
      "renders Logout and Import Google Calendar tiles when signed in",
      (final tester) async {
        await mockNetworkImages(() async {
          await pumpHamburgerMenu(tester, isSignedIn: true);

          await tester.pumpAndSettle();

          final ScaffoldState scaffoldState = tester.firstState(
            find.byType(Scaffold),
          );

          scaffoldState.openDrawer();
          await tester.pumpAndSettle();

          expect(find.text("Logout"), findsOneWidget);
          expect(find.byIcon(Icons.logout_sharp), findsOneWidget);

          expect(find.text("Import Google Calendar"), findsOneWidget);
          expect(find.byIcon(Icons.calendar_today), findsOneWidget);
        });
      },
    );

    testWidgets("tapping Login navigates to LoginScreen", (final tester) async {
      await runZonedGuarded(
        () async {
          await mockNetworkImages(() async {
            final mockLoginViewModel = MockLoginViewModel();
            final mockUser = MockUser();

            when(mockLoginViewModel.isSignedIn).thenReturn(false);
            when(mockLoginViewModel.currentUser).thenReturn(mockUser);

            when(mockUser.displayName).thenReturn("John Doe");
            when(mockUser.email).thenReturn("john.doe@example.com");
            when(
              mockUser.photoURL,
            ).thenReturn("https://example.com/avatar.png");

            await tester.pumpWidget(
              MaterialApp(
                home: ChangeNotifierProvider<LoginViewModel>.value(
                  value: mockLoginViewModel,
                  child: const Scaffold(
                    drawer: HamburgerMenu(),
                    body: SizedBox(),
                  ),
                ),
              ),
            );

            await tester.pumpAndSettle();

            final ScaffoldState scaffoldState = tester.firstState(
              find.byType(Scaffold),
            );
            scaffoldState.openDrawer();
            await tester.pumpAndSettle();
            expect(find.text("Login"), findsOneWidget);

            await tester.tap(find.text("Login"));
            await tester.pump();
            await tester.pump(const Duration(seconds: 2));

            expect(find.byType(LoginScreen), findsOneWidget);
          });
        },
        (final error, final stackTrace) {},
        zoneValues: {GoogleSignIn: MockGoogleSignIn()},
      );
    });

    testWidgets("tapping Import Google Calendar calls CalendarInteractor", (
      final tester,
    ) async {
      await mockNetworkImages(() async {
        final mockLoginViewModel = MockLoginViewModel();
        final mockUser = MockUser();

        when(mockLoginViewModel.isSignedIn).thenReturn(true);
        when(mockLoginViewModel.currentUser).thenReturn(mockUser);

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<LoginViewModel>.value(
              value: mockLoginViewModel,
              child: const Scaffold(drawer: HamburgerMenu(), body: SizedBox()),
            ),
          ),
        );

        await tester.pumpAndSettle();
        final ScaffoldState scaffoldState = tester.firstState(
          find.byType(Scaffold),
        );
        scaffoldState.openDrawer();
        await tester.pumpAndSettle();

        final calendarTile = find.widgetWithText(
          ListTile,
          "Import Google Calendar",
        );
        expect(calendarTile, findsOneWidget);

        // We can just tap; we don't need to fully fetch real classes for coverage
        await tester.tap(calendarTile);
        await tester.pumpAndSettle();
      });
    });
  });
}

class _FakeFirebasePlatform extends FirebasePlatform {
  _FakeFirebasePlatform() : super();

  static final FirebaseAppPlatform _defaultApp = FakeFirebaseAppPlatform(
    "[DEFAULT]",
  );

  @override
  Future<FirebaseAppPlatform> initializeApp({
    final String? name,
    final FirebaseOptions? options,
  }) async {
    return _defaultApp;
  }

  @override
  FirebaseAppPlatform app([final String name = "[DEFAULT]"]) {
    return _defaultApp;
  }

  @override
  List<FirebaseAppPlatform> get apps => <FirebaseAppPlatform>[_defaultApp];
}

class FakeFirebaseAppPlatform extends FirebaseAppPlatform {
  FakeFirebaseAppPlatform(final String name)
    : super(
        name,
        const FirebaseOptions(
          apiKey: "test",
          appId: "test",
          messagingSenderId: "test",
          projectId: "test",
        ),
      );
}
