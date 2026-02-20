import "package:concordia_campus_guide/ui/core/themes/app_theme.dart";
import "package:google_fonts/google_fonts.dart";

import "package:flutter/material.dart";
import "package:concordia_campus_guide/ui/hamburger_menu/widgets/custom_drawer_header.dart";
import "package:concordia_campus_guide/ui/auth/widgets/login_screen.dart";
import "package:concordia_campus_guide/ui/auth/view_models/login_view_model.dart";
import "package:provider/provider.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:concordia_campus_guide/domain/interactors/calendar_interactor.dart";
import "package:concordia_campus_guide/utils/app_logger.dart";

class HamburgerMenu extends StatelessWidget {
  const HamburgerMenu({super.key});

  @override
  Widget build(final BuildContext context) {
    final loginViewModel = context.watch<LoginViewModel>();
    final User? currentUser = loginViewModel.currentUser;
    final bool isSignedIn = loginViewModel.isSignedIn;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          CustomDrawerHeader(
            name: currentUser?.displayName ?? "Guest",
            email: currentUser?.email ?? "Not signed in",
            imageUrl:
                currentUser?.photoURL ??
                "https://api.dicebear.com/9.x/bottts/png",
          ),
          ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 12.0),
            leading: Icon(isSignedIn ? Icons.logout : Icons.login_sharp),
            title: Text(
              isSignedIn ? "Logout" : "Login",
              style: GoogleFonts.roboto(
                color: AppTheme.concordiaForeground,
                fontSize: 18.0,
              ),
            ),
            onTap: () {
              if (isSignedIn) {
                FirebaseAuth.instance.signOut();
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (final context) => const LoginScreen(),
                  ),
                );
              }
            },
          ),
          if (isSignedIn)
            ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 12.0),
              leading: const Icon(Icons.calendar_today),
              title: Text(
                "My Calendar",
                style: GoogleFonts.roboto(
                  color: AppTheme.concordiaForeground,
                  fontSize: 18.0,
                ),
              ),
              onTap: () async {
                Navigator.of(context).pop();
                final calendarInteractor = CalendarInteractor();
                try {
                  final now = DateTime.now();
                  final endTime = now.add(const Duration(days: 3));
                  final classes = await calendarInteractor.getClassInRange(
                    startDate: now,
                    endDate: endTime,
                  );

                  logger.i("Fetched ${classes.length} upcoming classes:");
                  for (final academicClass in classes) {
                    logger.i(academicClass);
                  }
                } catch (e, stackTrace) {
                  logger.e(
                    "Failed to fetch calendar events",
                    error: e,
                    stackTrace: stackTrace,
                  );
                }
              },
            ),
        ],
      ),
    );
  }
}
