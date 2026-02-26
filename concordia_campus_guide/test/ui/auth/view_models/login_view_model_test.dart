import "dart:async";
import "package:concordia_campus_guide/ui/auth/view_models/login_view_model.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mockito/annotations.dart";
import "package:mockito/mockito.dart";
import "package:firebase_auth/firebase_auth.dart";
import "login_view_model_test.mocks.dart";

@GenerateMocks([FirebaseAuth, User])
void main() {
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
  });

  group("LoginViewModel tests", () {
    test("initial state uses currentUser", () {
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockAuth.authStateChanges()).thenAnswer((_) => const Stream<User?>.empty());

      final vm = LoginViewModel(firebaseAuth: mockAuth);

      expect(vm.currentUser, mockUser);
      expect(vm.isSignedIn, true);
    });

    test("authStateChanges updates user and notifies listeners", () async {
      final controller = StreamController<User?>();
      when(mockAuth.currentUser).thenReturn(null);
      when(mockAuth.authStateChanges()).thenAnswer((_) => controller.stream);

      final vm = LoginViewModel(firebaseAuth: mockAuth);

      bool notified = false;
      vm.addListener(() {
        notified = true;
      });

      // emit a new user
      controller.add(mockUser);

      // wait for the FutureBuilder-like microtask
      await Future<void>.delayed(Duration.zero);

      expect(vm.currentUser, mockUser);
      expect(vm.isSignedIn, true);
      expect(notified, true);

      await controller.close();
    });

    test("authStateChanges emits null (sign out)", () async {
      final controller = StreamController<User?>();
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockAuth.authStateChanges()).thenAnswer((_) => controller.stream);

      final vm = LoginViewModel(firebaseAuth: mockAuth);

      bool notified = false;
      vm.addListener(() {
        notified = true;
      });

      // emit null (sign out)
      controller.add(null);

      await Future<void>.delayed(Duration.zero);

      expect(vm.currentUser, null);
      expect(vm.isSignedIn, false);
      expect(notified, true);

      await controller.close();
    });
  });
}
