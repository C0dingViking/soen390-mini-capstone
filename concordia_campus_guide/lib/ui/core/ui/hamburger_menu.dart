import "package:concordia_campus_guide/ui/core/themes/app_theme.dart";
import "package:google_fonts/google_fonts.dart";

import "package:flutter/material.dart";
import "package:flutter/widgets.dart";
import "package:concordia_campus_guide/ui/core/ui/custom_drawer_header.dart";

class HamburgerMenu extends StatelessWidget {
  const HamburgerMenu({super.key});

  @override
  Widget build(final BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          CustomDrawerHeader(
            name: "Bot Clanker",
            email: "bot.clanker@example.com",
            imageUrl: "https://api.dicebear.com/9.x/bottts/png",
          ),
          // UserAccountsDrawerHeader(
          //   accountEmail: null, // required by the widget, but we don't need it
          //   accountName: Row(
          //     children: [
          //       Container(
          //         width: 50,
          //         height: 50,
          //         decoration: BoxDecoration(shape: BoxShape.circle),
          //         child: CircleAvatar(
          //           minRadius: 30.0,
          //           maxRadius: 40.0,
          //           backgroundColor: Colors.white,
          //           backgroundImage: NetworkImage(
          //             "https://api.dicebear.com/9.x/bottts/png",
          //           ),
          //         ),
          //       ),
          //       Column(
          //         mainAxisAlignment: MainAxisAlignment.center,
          //         crossAxisAlignment: CrossAxisAlignment.start,
          //         children: [
          //           Text(
          //             "Bot Clanker",
          //             style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          //           ), 
          //           Text(
          //             "bot.clanker@example.com",
          //             style: TextStyle(fontSize: 10), 
          //           )
          //         ],
          //       ),
          //     ],
          //   ),
          //   decoration: BoxDecoration(color: AppTheme.concordiaMaroon),
          // ),
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
