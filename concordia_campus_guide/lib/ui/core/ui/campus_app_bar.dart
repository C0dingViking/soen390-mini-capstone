import "package:flutter/material.dart";
import "package:flutter_svg/svg.dart";

class CampusAppBar extends StatelessWidget implements PreferredSizeWidget {
  static const double _height = 60;

  final VoidCallback? onDirectionsPressed;

  const CampusAppBar({super.key, this.onDirectionsPressed});

  @override
  Widget build(final BuildContext context) {
    return AppBar(
      actions: [
        if (onDirectionsPressed != null)
          IconButton(
            icon: const Icon(Icons.directions),
            onPressed: onDirectionsPressed,
          ),

        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: SvgPicture.asset(
            "assets/images/app_logo.svg",
            height: 60,
            width: 60,
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(_height);
}
