import "package:concordia_campus_guide/ui/core/themes/app_theme.dart";
import "package:concordia_campus_guide/ui/core/ui/campus_app_bar.dart";
import "package:concordia_campus_guide/ui/home/view_models/home_view_model.dart";
import "package:concordia_campus_guide/ui/home/widgets/calendar_picker.dart";
import "package:google_fonts/google_fonts.dart";

import "package:flutter/material.dart";
import "package:concordia_campus_guide/ui/hamburger_menu/widgets/custom_drawer_header.dart";
import "package:concordia_campus_guide/ui/auth/widgets/login_screen.dart";
import "package:concordia_campus_guide/ui/auth/view_models/login_view_model.dart";
import "package:provider/provider.dart";
import "package:firebase_auth/firebase_auth.dart";

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
          CustomDrawerHeader(currentUser: currentUser),
          ListTile(
            key: const Key("hamburger_login_tile"),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0),
            leading: Icon(isSignedIn ? Icons.logout_sharp : Icons.login_sharp),
            title: Text(
              isSignedIn ? "Logout" : "Login",
              style: GoogleFonts.roboto(color: AppTheme.concordiaForeground, fontSize: 18.0),
            ),
            onTap: () async {
              if (isSignedIn) {
                context.read<HomeViewModel?>()?.toggleNextClassFabVisibility(false);
                await FirebaseAuth.instance.signOut();
              } else {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: const CampusAppBar(),
                      drawer: const HamburgerMenu(),
                      body: LoginScreen(),
                    ),
                  ),
                );
              }
            },
          ),
          if (isSignedIn)
            ListTile(
              key: const Key("hamburger_calendar"),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12.0),
              leading: const Icon(Icons.calendar_today),
              title: Text(
                "Import Google Calendar",
                style: GoogleFonts.roboto(color: AppTheme.concordiaForeground, fontSize: 18.0),
              ),
              onTap: () async {
                if (!context.mounted) return;

                await context.read<HomeViewModel>().loadCalendarTitles();
                if (!context.mounted) return;

                Navigator.of(context).pop();

                showDialog<void>(
                  context: context,
                  builder: (final context) => const CalendarPicker(),
                );
              },
            ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0),
            leading: const Icon(Icons.stars_rounded),
            title: Text(
              "Give us a Rating",
              style: GoogleFonts.roboto(color: AppTheme.concordiaForeground, fontSize: 18.0),
            ),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0),
            leading: const Icon(Icons.settings),
            title: Text(
              "Settings",
              style: GoogleFonts.roboto(color: AppTheme.concordiaForeground, fontSize: 18.0),
            ),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0),
            leading: const Icon(Icons.info_outline),
            title: Text(
              "Version 1.0.0",
              style: GoogleFonts.roboto(color: AppTheme.concordiaForeground, fontSize: 18.0),
            ),
          ),
        ],
      ),
    );
  }
}
