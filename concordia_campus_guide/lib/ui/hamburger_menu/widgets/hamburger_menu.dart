import "package:concordia_campus_guide/ui/core/themes/app_theme.dart";
import "package:google_fonts/google_fonts.dart";

import "package:flutter/material.dart";
import "package:concordia_campus_guide/ui/hamburger_menu/widgets/custom_drawer_header.dart";

class HamburgerMenu extends StatelessWidget {
  const HamburgerMenu({super.key});

  @override
  Widget build(final BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          CustomDrawerHeader(
            name: "Bot Clanker",
            email: "bot.clanker@example.com",
            imageUrl: "https://api.dicebear.com/9.x/bottts/png", //placeholder image, should be replaced with actual user profile picture
          ),
          ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 12.0),
            leading: const Icon(Icons.login_sharp),
            title: Text(
              "Login",
              style: GoogleFonts.roboto(
                color: AppTheme.concordiaForeground,
                fontSize: 18.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
