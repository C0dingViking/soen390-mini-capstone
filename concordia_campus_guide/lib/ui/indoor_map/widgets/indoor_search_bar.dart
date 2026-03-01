import "package:concordia_campus_guide/ui/core/themes/app_theme.dart";
import "package:flutter/material.dart";

class IndoorSearchBar extends StatefulWidget {
  const IndoorSearchBar({super.key});

  @override
  State<IndoorSearchBar> createState() => _IndoorSearchBarState();
}

class _IndoorSearchBarState extends State<IndoorSearchBar> {
  static const double _cardRadius = 12;
  static const double _cardElevation = 4.0;

  final TextEditingController _startController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  @override
  void dispose() {
    _startController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    final showClearStart = _startController.text.isNotEmpty;
    final showClearDestination = _destinationController.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          elevation: _cardElevation,
          borderRadius: BorderRadius.circular(_cardRadius),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _startController,
                onChanged: (_) => setState(() {}),
                decoration: AppTheme.indoorSearchFieldDecoration.copyWith(
                  hintText: "Current location",
                  prefixIcon: Icon(Icons.trip_origin),
                  suffixIcon: showClearStart
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _startController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
              ),
              const Divider(height: 1),
              TextField(
                controller: _destinationController,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: AppTheme.indoorSearchFieldDecoration.copyWith(
                  hintText: "Choose destination",
                  prefixIcon: const Icon(Icons.place_outlined),
                  suffixIcon: showClearDestination
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _destinationController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
