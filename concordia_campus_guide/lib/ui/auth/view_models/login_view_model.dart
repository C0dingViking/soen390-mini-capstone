import "package:flutter/material.dart";
import "package:firebase_auth/firebase_auth.dart";

class LoginViewModel extends ChangeNotifier {
  final FirebaseAuth _firebaseAuth;

  LoginViewModel({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance {
    _initializeAuthState();
  }

  User? _currentUser;

  User? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  void _initializeAuthState() {
    _currentUser = _firebaseAuth.currentUser;

    _firebaseAuth.authStateChanges().listen((final User? user) {
      _currentUser = user;
      notifyListeners();
    });
  }
}
