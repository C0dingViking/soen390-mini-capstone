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

    return Container(
      height: headerHeight,
      color: AppTheme.concordiaMaroon,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                height: headerHeight * 0.45,
                width: headerHeight * 0.45,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.concordiaGold,
                ),
                child: ClipOval(
                  child: Image.network(imageUrl, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Text(
                  name,
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
          const SizedBox(height: 12),
          Text(
            email,
            style: GoogleFonts.roboto(
              color: Colors.white,

              fontSize: 16
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
