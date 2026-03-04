import "package:concordia_campus_guide/ui/core/themes/app_theme.dart";
import "package:flutter/material.dart";

class IndoorSearchBar extends StatefulWidget {
  final List<String> queryableRooms;
  final TextEditingController? startController;
  final TextEditingController? destinationController;
  final void Function(String startRoom, String destinationRoom)? onStartNavigation;

  const IndoorSearchBar({
    super.key,
    this.startController,
    this.destinationController,
    this.onStartNavigation,
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
  late FocusNode _startFocus;
  late FocusNode _destinationFocus;
  late FocusedField _activeField;

  List<String> _filteredRoomList = [];

  @override
  void initState() {
    super.initState();
    _startController = widget.startController ?? TextEditingController();
    _destinationController = widget.destinationController ?? TextEditingController();
    _ownsStartController = widget.startController == null;
    _ownsDestinationController = widget.destinationController == null;
    _startFocus = FocusNode();
    _destinationFocus = FocusNode();
    _activeField = FocusedField.neither;

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

    TextEditingController? activeController;
    if (_activeField == FocusedField.onStart) {
      activeController = _startController;
    } else if (_activeField == FocusedField.onDestination) {
      activeController = _destinationController;
    }

    if (activeController != null) {
      setState(() {
        _filteredRoomList = _getFilteredRoomList(activeController!.text);
      });
    }
  }

  List<String> _getFilteredRoomList(final String query) {
    if (query.isEmpty) return [];

    return widget.queryableRooms
        .where((final room) => room.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  void _selectRoomOption(final String roomName) async {
    TextEditingController? activeController;

    if (_activeField == FocusedField.onStart) {
      activeController = _startController;
    } else if (_activeField == FocusedField.onDestination) {
      activeController = _destinationController;
    }

    if (activeController != null) {
      setState(() {
        activeController!.text = roomName;
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
    );
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
    _destinationFocus.dispose();

    super.dispose();
  }

  Widget _buildResultsList(final BuildContext context, final List<String> results) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 4),
        shrinkWrap: true,
        itemCount: results.length,
        separatorBuilder: (final context, final index) => const Divider(height: 1),
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
      ),
    );
  }

  @override
  Widget build(final BuildContext context) {
    final showClearStart = _startController.text.isNotEmpty;
    final showClearDestination = _destinationController.text.isNotEmpty;
    final showStartNavigationButton = _canStartNavigation;

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
                focusNode: _startFocus,
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
                focusNode: _destinationFocus,
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
        if (_filteredRoomList.isNotEmpty) _buildResultsList(context, _filteredRoomList),
        if (showStartNavigationButton) ...[
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
