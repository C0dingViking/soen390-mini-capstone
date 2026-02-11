import "package:flutter/material.dart";
import "package:flutter_svg/svg.dart";

class CampusAppBar extends StatelessWidget implements PreferredSizeWidget {
  static const double _height = 60;

  const CampusAppBar({super.key});

  @override
  Widget build(final BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: IconButton(
        onPressed: Scaffold.of(context).openDrawer, 
        icon: Icon(Icons.menu)
      ),
      actions: [
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
