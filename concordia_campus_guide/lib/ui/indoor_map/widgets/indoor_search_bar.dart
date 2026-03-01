import "package:concordia_campus_guide/ui/core/themes/app_theme.dart";
import "package:flutter/material.dart";

class IndoorSearchBar extends StatefulWidget {
  final TextEditingController? startController;
  final TextEditingController? destinationController;

  const IndoorSearchBar({super.key, this.startController, this.destinationController});

  @override
  State<IndoorSearchBar> createState() => _IndoorSearchBarState();
}

class _IndoorSearchBarState extends State<IndoorSearchBar> {
  static const double _cardRadius = 12;
  static const double _cardElevation = 4.0;

  late TextEditingController _startController;
  late TextEditingController _destinationController;
  late bool _ownsStartController;
  late bool _ownsDestinationController;

  @override
  void initState() {
    super.initState();
    _startController = widget.startController ?? TextEditingController();
    _destinationController = widget.destinationController ?? TextEditingController();
    _ownsStartController = widget.startController == null;
    _ownsDestinationController = widget.destinationController == null;

    _startController.addListener(_onFieldTextChanged);
    _destinationController.addListener(_onFieldTextChanged);
  }

  @override
  void didUpdateWidget(covariant final IndoorSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.startController != widget.startController) {
      _startController.removeListener(_onFieldTextChanged);
      if (_ownsStartController) {
        _startController.dispose();
      }

      _startController = widget.startController ?? TextEditingController();
      _ownsStartController = widget.startController == null;
      _startController.addListener(_onFieldTextChanged);
    }

    if (oldWidget.destinationController != widget.destinationController) {
      _destinationController.removeListener(_onFieldTextChanged);
      if (_ownsDestinationController) {
        _destinationController.dispose();
      }

      _destinationController = widget.destinationController ?? TextEditingController();
      _ownsDestinationController = widget.destinationController == null;
      _destinationController.addListener(_onFieldTextChanged);
    }
  }

  void _onFieldTextChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _startController.removeListener(_onFieldTextChanged);
    _destinationController.removeListener(_onFieldTextChanged);

    if (_ownsStartController) {
      _startController.dispose();
    }

    if (_ownsDestinationController) {
      _destinationController.dispose();
    }

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
