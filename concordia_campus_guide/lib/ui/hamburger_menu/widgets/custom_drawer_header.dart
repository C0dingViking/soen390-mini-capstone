import "package:concordia_campus_guide/ui/core/themes/app_theme.dart";

import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

class CustomDrawerHeader extends StatelessWidget {
  final String name;
  final String email;
  final String imageUrl;

  const CustomDrawerHeader({
    super.key,
    required this.name,
    required this.email,
    required this.imageUrl,
  });

  @override
  Widget build(final BuildContext context) {
    final double headerHeight = MediaQuery.of(context).size.height * 0.25;
    final double screenWidth = MediaQuery.of(context).size.width;

    final String firstName = name.split(" ").first;
    final String lastName = name.split(" ").length > 1
        ? name.split(" ").last
        : "";

    return Container(
      height: headerHeight,
      color: AppTheme.concordiaMaroon,
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: headerHeight * 0.01,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: headerHeight * 0.05,
        children: [
          SizedBox(height: headerHeight * 0.075),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                height: headerHeight * 0.45,
                width: headerHeight * 0.45, // use height for a perfect circle
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.concordiaGold,
                ),
                child: ClipOval(
                  child: Image.network(imageUrl, fit: BoxFit.cover),
                ),
              ),
              SizedBox(width: screenWidth * 0.04),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: headerHeight * 0.01,
                children: [
                  Text(
                    firstName,
                    style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (lastName.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(left: screenWidth * 0.025),
                      child: Text(
                        lastName,
                        style: GoogleFonts.roboto(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ],
          ),
          SizedBox(height: headerHeight * 0.01),
          SizedBox(
            width: double.infinity,
            child: Text(
              email,
              style: GoogleFonts.roboto(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
