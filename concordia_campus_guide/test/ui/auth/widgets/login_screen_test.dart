import "dart:async";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mockito/mockito.dart";
import "package:mockito/annotations.dart";
import "package:provider/provider.dart";
import "package:concordia_campus_guide/ui/auth/widgets/login_screen.dart";
import "package:concordia_campus_guide/ui/home/view_models/home_view_model.dart";
import "package:concordia_campus_guide/ui/core/themes/app_theme.dart";
import "package:google_sign_in/google_sign_in.dart";
import "package:firebase_ui_auth/firebase_ui_auth.dart";
import "package:firebase_core/firebase_core.dart";
import "package:firebase_core_platform_interface/firebase_core_platform_interface.dart";

import "login_screen_test.mocks.dart";

@GenerateMocks([HomeViewModel, GoogleSignIn])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("LoginScreen Widget Tests", () {
    late MockGoogleSignIn mockGoogleSignIn;
    late MockHomeViewModel mockHomeViewModel;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();

      FirebasePlatform.instance = _FakeFirebasePlatform();

      await Firebase.initializeApp();
    });

    setUp(() {
      mockGoogleSignIn = MockGoogleSignIn();
      mockHomeViewModel = MockHomeViewModel();

      when(mockGoogleSignIn.signOut()).thenAnswer((_) async => Future.value());
      when(mockHomeViewModel.notifyLoginSuccess()).thenReturn(null);
    });

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

    Future<void> pumpLoginScreen(final WidgetTester tester) async {
      //await runZonedGuarded(() async {
      await tester.pumpWidget(
        ChangeNotifierProvider<HomeViewModel>.value(
          value: mockHomeViewModel,
          child: MaterialApp(home: LoginScreen()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      // },
      // (final error, final stack) {},
      // zoneValues: {GoogleSignIn: mockGoogleSignIn},
      //);
    }

    testWidgets(
      "renders SignInScreen after 'googleSignIn.signOut()' completes",
      (final tester) async {
        await withMockGoogleSignIn(() async {
          await runZonedGuarded(
            () async {
              await pumpLoginScreen(tester);
            },
            (final error, final stack) {},
            zoneValues: {GoogleSignIn: mockGoogleSignIn},
          );

          await tester.pump();
          await tester.pump();

          expect(find.byType(SignInScreen), findsOneWidget);
          expect(find.byIcon(Icons.account_circle), findsOneWidget);
        });
      },
    );

    testWidgets("properly renders loading indicator", (final tester) async {
      await pumpLoginScreen(tester);

      final Finder scaffoldFinder = find.byType(Scaffold);
      expect(scaffoldFinder, findsOneWidget);

      final Scaffold scaffold = tester.widget<Scaffold>(scaffoldFinder);
      expect(scaffold.backgroundColor, AppTheme.concordiaGold);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
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
