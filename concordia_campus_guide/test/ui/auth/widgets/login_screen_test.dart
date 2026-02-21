// ignore_for_file: prefer_final_parameters

import "dart:async";

import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mockito/annotations.dart";
import "package:mockito/mockito.dart";
import "package:provider/provider.dart";

import "package:concordia_campus_guide/ui/auth/widgets/login_screen.dart";
import "package:concordia_campus_guide/ui/home/view_models/home_view_model.dart";
import "package:concordia_campus_guide/ui/core/themes/app_theme.dart";

import "package:google_sign_in/google_sign_in.dart";
import "package:firebase_ui_auth/firebase_ui_auth.dart";
import "package:firebase_core/firebase_core.dart";
import "package:firebase_core_platform_interface/firebase_core_platform_interface.dart";

import "login_screen_test.mocks.dart";

@GenerateMocks([HomeViewModel, GoogleSignIn, User, UserCredential])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockGoogleSignIn mockGoogleSignIn;
  late MockHomeViewModel mockHomeViewModel;
  late MockUser mockUser;
  late MockUserCredential mockUserCredential;

  setUpAll(() async {
    FirebasePlatform.instance = _FakeFirebasePlatform();
    await Firebase.initializeApp();
  });

  setUp(() {
    mockGoogleSignIn = MockGoogleSignIn();
    mockHomeViewModel = MockHomeViewModel();
    mockUser = MockUser();
    mockUserCredential = MockUserCredential();

    when(mockHomeViewModel.notifyLoginSuccess()).thenReturn(null);
  });

  Future<void> pumpLoginScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<HomeViewModel>.value(
        value: mockHomeViewModel,
        child: MaterialApp(
          home: Navigator(
            pages: [MaterialPage(child: LoginScreen())],
            // ignore: deprecated_member_use
            onPopPage: (route, result) => route.didPop(
              result,
            ), // deprecated but required for Navigator to work in tests
          ),
        ),
      ),
    );

    await tester.pump();
  }

  Future<void> withMockGoogleSignIn(final Future<void> Function() body) {
    const MethodChannel channel = MethodChannel(
      "plugins.flutter.io/google_sign_in",
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (final call) async {
          if (call.method == "signOut") {
            return null;
          }
          return null;
        });

    return body();
  }

  group("LoginScreen Widget Tests", () {
    testWidgets("properly renders loading indicator", (tester) async {
      await pumpLoginScreen(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      final Scaffold scaffold = tester.widget<Scaffold>(find.byType(Scaffold));

      expect(scaffold.backgroundColor, AppTheme.concordiaGold);
    });

    testWidgets(
      "renders SignInScreen after 'googleSignIn.signOut()' completes",
      (tester) async {
        await withMockGoogleSignIn(() async {
          await runZonedGuarded(
            () async {
              await pumpLoginScreen(tester);
            },
            (error, stackTrace) {
              fail(
                "LoginScreen threw an unexpected error: $error\n$stackTrace",
              );
            },
            zoneValues: {GoogleSignIn: mockGoogleSignIn},
          );

          // pump twice to allow FutureBuilder to rebuild with new state
          await tester.pump();
          await tester.pump();

          expect(find.byIcon(Icons.account_circle), findsOneWidget);
          expect(find.byType(SignInScreen), findsOneWidget);
        });
      },
    );
    testWidgets("calls notifyLoginSuccess when SignedIn action fires", (
      tester,
    ) async {
      await withMockGoogleSignIn(() async {
        await runZonedGuarded(
          () async {
            await pumpLoginScreen(tester);
          },
          (error, stackTrace) {
            fail("LoginScreen threw an unexpected error: $error\n$stackTrace");
          },
          zoneValues: {GoogleSignIn: mockGoogleSignIn},
        );

        await tester.pump();
        await tester.pump();

        final signInFinder = find.byType(SignInScreen);
        expect(signInFinder, findsOneWidget);

        final SignInScreen signInWidget = tester.widget(signInFinder);

        final signedInAction = signInWidget.actions
            .whereType<AuthStateChangeAction<SignedIn>>()
            .first;

        signedInAction.callback(
          tester.element(signInFinder),
          SignedIn(mockUser),
        );

        verify(mockHomeViewModel.notifyLoginSuccess()).called(1);
      });
    });

    testWidgets("calls notifyLoginSuccess when UserCreated action fires", (
      tester,
    ) async {
      await withMockGoogleSignIn(() async {
        await runZonedGuarded(
          () async {
            await pumpLoginScreen(tester);
          },
          (error, stackTrace) {
            fail("LoginScreen threw an unexpected error: $error\n$stackTrace");
          },
          zoneValues: {GoogleSignIn: mockGoogleSignIn},
        );

        await tester.pump();
        await tester.pump();

        final signInFinder = find.byType(SignInScreen);
        expect(signInFinder, findsOneWidget);

        final SignInScreen signInWidget = tester.widget(signInFinder);

        final userCreatedAction = signInWidget.actions
            .whereType<AuthStateChangeAction<UserCreated>>()
            .first;

        userCreatedAction.callback(
          tester.element(signInFinder),
          UserCreated(mockUserCredential),
        );

        verify(mockHomeViewModel.notifyLoginSuccess()).called(1);
      });
    });

    testWidgets("calls notifyLoginSuccess when UserCreated action fires", (
      tester,
    ) async {
      await withMockGoogleSignIn(() async {
        await runZonedGuarded(
          () async {
            await pumpLoginScreen(tester);
          },
          (error, stackTrace) {
            fail("LoginScreen threw an unexpected error: $error\n$stackTrace");
          },
          zoneValues: {GoogleSignIn: mockGoogleSignIn},
        );

        await tester.pump();
        await tester.pump();

        final signInFinder = find.byType(SignInScreen);
        expect(signInFinder, findsOneWidget);

        final SignInScreen signInWidget = tester.widget(signInFinder);

        final userCreatedAction = signInWidget.actions
            .whereType<AuthStateChangeAction<UserCreated>>()
            .first;

        userCreatedAction.callback(
          tester.element(signInFinder),
          UserCreated(mockUserCredential),
        );

        verify(mockHomeViewModel.notifyLoginSuccess()).called(1);
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
    String? name,
    FirebaseOptions? options,
  }) async {
    return _defaultApp;
  }

  @override
  FirebaseAppPlatform app([String name = "[DEFAULT]"]) {
    return _defaultApp;
  }

  @override
  List<FirebaseAppPlatform> get apps => <FirebaseAppPlatform>[_defaultApp];
}

class FakeFirebaseAppPlatform extends FirebaseAppPlatform {
  FakeFirebaseAppPlatform(String name)
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
