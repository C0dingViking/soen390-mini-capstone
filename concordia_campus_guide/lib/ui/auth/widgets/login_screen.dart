import "package:concordia_campus_guide/ui/core/themes/app_theme.dart";
import "package:google_fonts/google_fonts.dart";

import "package:firebase_ui_auth/firebase_ui_auth.dart";
import "package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart";
import "package:flutter/material.dart";
import "package:googleapis/calendar/v3.dart" as calendar;
import "package:google_sign_in/google_sign_in.dart";
import "package:concordia_campus_guide/ui/home/view_models/home_view_model.dart";
import "package:provider/provider.dart";

class LoginScreen extends StatelessWidget {
  final GoogleSignIn googleSignIn;

  LoginScreen({super.key, final GoogleSignIn? googleSignIn})
    : googleSignIn = googleSignIn ?? GoogleSignIn();

  /// Signs out of all cached accounts to ensure a clean login state.
  /// This is necessary because Firebase may cache previous sign-ins, which can lead to unexpected behavior when trying to sign in with a different account.
  /// This could be removed in the future if we decide that we want the accounts to be cached for convenience, but for now it allows for easier testing.
  Future<void> _signOutCachedAccounts() async {
    await googleSignIn.signOut();
  }

  @override
  Widget build(final BuildContext context) {
    return FutureBuilder<void>(
      future: _signOutCachedAccounts(),
      builder: (final context, final snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppTheme.concordiaGold,
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.concordiaMaroon),
            ),
          );
        }

        return Theme(
          data: Theme.of(context).copyWith(
            scaffoldBackgroundColor: AppTheme.concordiaGold,
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppTheme.concordiaMaroon,
              surface: AppTheme.concordiaGold,
            ),
            textTheme: GoogleFonts.robotoTextTheme(Theme.of(context).textTheme),
          ),
          child: SignInScreen(
            providers: [
              GoogleProvider(
                clientId:
                    "501981294191-foqhoe1c7cvhtco1i0oa2gmk8aljqrp7.apps.googleusercontent.com",
                scopes: [calendar.CalendarApi.calendarScope],
              ),
            ],
            actions: [
              AuthStateChangeAction<SignedIn>((final context, final state) {
                context.read<HomeViewModel>().notifyLoginSuccess();
                Navigator.of(context).pop();
              }),
              AuthStateChangeAction<UserCreated>((final context, final state) {
                context.read<HomeViewModel>().notifyLoginSuccess();
                Navigator.of(context).pop();
              }),
            ],
            headerBuilder:
                (final context, final constraints, final shrinkOffset) {
                  return Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: const Icon(
                        Icons.account_circle,
                        size: 100.0,
                        color: AppTheme.concordiaMaroon,
                      ),
                    ),
                  );
                },
          ),
        );
      },
    );
  }
}
