import "package:firebase_ui_auth/firebase_ui_auth.dart";
import "package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart";
import "package:flutter/material.dart";

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(final BuildContext context) {
    return SignInScreen(
      providers: [
        GoogleProvider(
          clientId:
              "501981294191-foqhoe1c7cvhtco1i0oa2gmk8aljqrp7.apps.googleusercontent.com",
        ),
      ],
      actions: [
        AuthStateChangeAction<SignedIn>((final context, final state) {
          Navigator.of(context).pop();
        }),
        AuthStateChangeAction<UserCreated>((final context, final state) {
          Navigator.of(context).pop();
        }),
      ],
      headerBuilder: (final context, final constraints, final shrinkOffset) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.account_circle,
                size: 80,
                color: Color(0xFF912338),
              ),
              const SizedBox(height: 16),
              Text(
                "Welcome to Concordia Campus Guide",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}
