import "package:concordia_campus_guide/ui/core/themes/app_theme.dart";
import "package:concordia_campus_guide/ui/core/ui/search_ui.dart";
import "package:flutter/material.dart";

class IndoorSearchBar extends StatefulWidget {
  final List<String> queryableRooms;
  final TextEditingController? startController;
  final TextEditingController? destinationController;
  final FocusNode? destinationFocusNode;
  final bool isIndoorNavigationDisplayed;
  final void Function(String startRoom, String destinationRoom, bool accessibleMode)?
  onStartNavigation;
  final VoidCallback? onEndNavigation;

  const IndoorSearchBar({
    super.key,
    this.startController,
    this.destinationController,
    this.destinationFocusNode,
    this.isIndoorNavigationDisplayed = false,
    this.onStartNavigation,
    this.onEndNavigation,
    required this.queryableRooms,
  });

  @override
  State<IndoorSearchBar> createState() => _IndoorSearchBarState();
}

enum FocusedField { onStart, onDestination, neither }

class _IndoorSearchBarState extends State<IndoorSearchBar> {
  static const double _cardRadius = 12;
  static const double _cardElevation = 4.0;
  static const double _buttonHeight = 8.0;

  late TextEditingController _startController;
  late TextEditingController _destinationController;
  late bool _ownsStartController;
  late bool _ownsDestinationController;
  late bool _ownsDestinationFocus;
  late FocusNode _startFocus;
  late FocusNode _destinationFocus;
  late FocusedField _activeField;
  late String _lastStartValue;
  late String _lastDestinationValue;
  bool _isClearingFields = false;
  bool _accessibleMode = false;

  List<String> _filteredRoomList = [];

  TextEditingController? get _activeController {
    switch (_activeField) {
      case FocusedField.onStart:
        return _startController;
      case FocusedField.onDestination:
        return _destinationController;
      case FocusedField.neither:
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _startController = widget.startController ?? TextEditingController();
    _destinationController = widget.destinationController ?? TextEditingController();
    _ownsStartController = widget.startController == null;
    _ownsDestinationController = widget.destinationController == null;
    _startFocus = FocusNode();
    _destinationFocus = widget.destinationFocusNode ?? FocusNode();
    _ownsDestinationFocus = widget.destinationFocusNode == null;
    _activeField = FocusedField.neither;
    _lastStartValue = _startController.text;
    _lastDestinationValue = _destinationController.text;

    _startFocus.addListener(_handleFocusChange);
    _destinationFocus.addListener(_handleFocusChange);
    _startController.addListener(_onFieldTextChanged);
    _destinationController.addListener(_onFieldTextChanged);
  }

  void _handleFocusChange() {
    setState(() {
      if (_startFocus.hasFocus) {
        _activeField = FocusedField.onStart;
      } else if (_destinationFocus.hasFocus) {
        _activeField = FocusedField.onDestination;
      } else {
        _activeField = FocusedField.neither;
      }

      _filteredRoomList = [];
    });
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
      _lastStartValue = _startController.text;
    }

    if (oldWidget.destinationController != widget.destinationController) {
      _destinationController.removeListener(_onFieldTextChanged);
      if (_ownsDestinationController) {
        _destinationController.dispose();
      }

      _destinationController = widget.destinationController ?? TextEditingController();
      _ownsDestinationController = widget.destinationController == null;
      _destinationController.addListener(_onFieldTextChanged);
      _lastDestinationValue = _destinationController.text;
    }

    if (oldWidget.destinationFocusNode != widget.destinationFocusNode) {
      _destinationFocus.removeListener(_handleFocusChange);
      if (_ownsDestinationFocus) {
        _destinationFocus.dispose();
      }

      _destinationFocus = widget.destinationFocusNode ?? FocusNode();
      _ownsDestinationFocus = widget.destinationFocusNode == null;
      _destinationFocus.addListener(_handleFocusChange);
    }
  }

  void _onFieldTextChanged() {
    if (!mounted) {
      return;
    }

    _endNavigationIfLocationChanged();

    if (_isClearingFields) {
      return;
    }

    final activeController = _activeController;

    if (activeController != null) {
      setState(() {
        _filteredRoomList = _getFilteredRoomList(activeController.text);
      });
    }
  }

  void _endNavigationIfLocationChanged() {
    final currentStart = _startController.text;
    final currentDestination = _destinationController.text;

    if (!widget.isIndoorNavigationDisplayed) {
      _lastStartValue = currentStart;
      _lastDestinationValue = currentDestination;
      return;
    }

    final startChanged = currentStart != _lastStartValue;
    final destinationChanged = currentDestination != _lastDestinationValue;

    if (startChanged || destinationChanged) {
      widget.onEndNavigation?.call();
    }

    _lastStartValue = currentStart;
    _lastDestinationValue = currentDestination;
  }

  List<String> _getFilteredRoomList(final String query) {
    if (query.isEmpty) return [];

    return widget.queryableRooms
        .where((final room) => room.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  void _selectRoomOption(final String roomName) {
    final activeController = _activeController;

    if (activeController != null) {
      setState(() {
        activeController.text = roomName;
        activeController.selection = TextSelection.fromPosition(
          TextPosition(offset: activeController.text.length),
        );

        _filteredRoomList = [];
        _activeField = FocusedField.neither;
      });
    }
  }

  bool _isValidRoom(final String roomName) {
    final normalizedRoomName = roomName.trim().toLowerCase();
    if (normalizedRoomName.isEmpty) {
      return false;
    }

    return widget.queryableRooms.any(
      (final room) => room.trim().toLowerCase() == normalizedRoomName,
    );
  }

  bool get _canStartNavigation {
    return _isValidRoom(_startController.text) && _isValidRoom(_destinationController.text);
  }

  void _handleStartNavigationPressed() {
    FocusScope.of(context).unfocus();
    widget.onStartNavigation?.call(
      _startController.text.trim(),
      _destinationController.text.trim(),
      _accessibleMode,
    );
  }

  void _handleEndNavigationPressed() {
    FocusScope.of(context).unfocus();
    _clearBothFields();
    widget.onEndNavigation?.call();
  }

  void _clearBothFields() {
    _isClearingFields = true;
    _startController.clear();
    _destinationController.clear();
    _lastStartValue = _startController.text;
    _lastDestinationValue = _destinationController.text;
    _isClearingFields = false;

    setState(() {
      _filteredRoomList = [];
      _activeField = FocusedField.neither;
    });
  }

  void _clearController(final TextEditingController controller) {
    controller.clear();
    setState(() {});
  }

  @override
  void dispose() {
    _startController.removeListener(_onFieldTextChanged);
    _destinationController.removeListener(_onFieldTextChanged);
    _startFocus.removeListener(_handleFocusChange);
    _destinationFocus.removeListener(_handleFocusChange);

    if (_ownsStartController) {
      _startController.dispose();
    }

    if (_ownsDestinationController) {
      _destinationController.dispose();
    }

    _startFocus.dispose();

    if (_ownsDestinationFocus) {
      _destinationFocus.dispose();
    }

    super.dispose();
  }

  Widget _buildResultsList(final BuildContext context, final List<String> results) {
    return SearchResultsDropdown(
      itemCount: results.length,
      itemBuilder: (final context, final index) {
        final room = results[index];
        return ListTile(
          title: Text(room),
          onTap: () {
            _selectRoomOption(room);
            FocusScope.of(context).unfocus();
          },
        );
      },
    );
  }

  Widget _buildSearchField({
    required final TextEditingController controller,
    required final FocusNode focusNode,
    required final String hintText,
    required final Widget prefixIcon,
    final TextInputAction? textInputAction,
  }) {
    final showClearButton = controller.text.isNotEmpty;

    return TextField(
      controller: controller,
      focusNode: focusNode,
      textInputAction: textInputAction,
      decoration: AppTheme.indoorSearchFieldDecoration.copyWith(
        hintText: hintText,
        prefixIcon: prefixIcon,
        suffixIcon: showClearButton
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => _clearController(controller),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(final BuildContext context) {
    final showStartNavigationButton = _canStartNavigation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.indoorSearchFieldDecoration.fillColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(_cardRadius),
              topRight: Radius.circular(_cardRadius),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ModeToggleIcon(
                icon: Icons.directions_walk,
                isSelected: !_accessibleMode,
                tooltip: "Normal walking route",
                onTap: () {
                  setState(() => _accessibleMode = false);
                },
              ),
              const SizedBox(width: 24),
              _ModeToggleIcon(
                icon: Icons.accessible_forward,
                isSelected: _accessibleMode,
                tooltip: "Accessible route (avoid stairs)",
                onTap: () {
                  setState(() => _accessibleMode = true);
                },
              ),
            ],
          ),
        ),
        SearchInputCard(
          elevation: _cardElevation,
          radius: _cardRadius,
          children: [
            _buildSearchField(
              controller: _startController,
              focusNode: _startFocus,
              hintText: "Current location",
              prefixIcon: const Icon(Icons.trip_origin),
            ),
            const Divider(height: 1),
            _buildSearchField(
              controller: _destinationController,
              focusNode: _destinationFocus,
              textInputAction: TextInputAction.search,
              hintText: "Choose destination",
              prefixIcon: const Icon(Icons.place_outlined),
            ),
          ],
        ),
        if (_filteredRoomList.isNotEmpty) _buildResultsList(context, _filteredRoomList),
        if (widget.isIndoorNavigationDisplayed) ...[
          const SizedBox(height: _buttonHeight),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _handleEndNavigationPressed,
              style: AppTheme.indoorNavigationButtonStyle,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text("End Navigation"),
            ),
          ),
        ] else if (showStartNavigationButton) ...[
          const SizedBox(height: _buttonHeight),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _handleStartNavigationPressed,
              style: AppTheme.indoorNavigationButtonStyle,
              icon: const Icon(Icons.navigation),
              label: const Text("Start Navigation"),
            ),
          ),
        ],
      ],
    );
  }
}

class _ModeToggleIcon extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final String tooltip;
  final VoidCallback onTap;

  const _ModeToggleIcon({
    required this.icon,
    required this.isSelected,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(final BuildContext context) {
    const Color selectedFillColor = AppTheme.concordiaButtonCyanSolid;
    const Color unselectedBorderColor = Colors.transparent;
    const Color selectedBorderColor = AppTheme.concordiaButtonCyanSolid;
    const Color unselectedFillColor = Colors.white;
    const Color iconColor = AppTheme.concordiaForeground;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? selectedBorderColor : unselectedBorderColor,
              width: 2,
            ),
            color: isSelected ? selectedFillColor : unselectedFillColor,
          ),
          child: Icon(icon, color: iconColor),
        ),
      ),
    );
  }
}
