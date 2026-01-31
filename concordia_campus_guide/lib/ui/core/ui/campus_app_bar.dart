import 'package:flutter/material.dart';

class CampusAppBar extends StatelessWidget implements PreferredSizeWidget {
  static const double _height = 60;

  const CampusAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Image.asset(
            'assets/images/app_icon.png',
            height: 64,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(_height);
}
