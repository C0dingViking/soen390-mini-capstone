import "package:concordia_campus_guide/domain/models/route_option.dart";
import "package:concordia_campus_guide/domain/models/search_suggestion.dart";
import "package:concordia_campus_guide/ui/home/view_models/home_view_model.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class BuildingSearchBar extends StatefulWidget {
  const BuildingSearchBar({super.key});

  @override
  State<BuildingSearchBar> createState() => _BuildingSearchBarState();
}

class _BuildingSearchBarState extends State<BuildingSearchBar> {
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _startFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();
  SearchField _activeField = SearchField.destination;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _startFocusNode.addListener(_handleFocusChange);
    _destinationFocusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _startFocusNode.removeListener(_handleFocusChange);
    _destinationFocusNode.removeListener(_handleFocusChange);
    _startFocusNode.dispose();
    _destinationFocusNode.dispose();
    _startController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_startFocusNode.hasFocus) {
      _activeField = SearchField.start;
      context.read<HomeViewModel>().updateSearchQuery(_startController.text);
      return;
    }
    if (_destinationFocusNode.hasFocus) {
      _activeField = SearchField.destination;
      context.read<HomeViewModel>().updateSearchQuery(
        _destinationController.text,
      );
      return;
    }

    if (!_startFocusNode.hasFocus && !_destinationFocusNode.hasFocus) {
      context.read<HomeViewModel>().clearSearchResults();
    }
  }

  void _handleQueryChanged(final String query, final SearchField field) {
    _activeField = field;
    context.read<HomeViewModel>().updateSearchQuery(query);
    setState(() {});
  }

  void _clearQuery(final SearchField field) {
    if (field == SearchField.start) {
      _startController.clear();
    } else {
      _destinationController.clear();
    }
    context.read<HomeViewModel>().clearSearchResults();
    setState(() {});
  }

  void _cancelSearch() {
    _startController.clear();
    _destinationController.clear();
    _expanded = false;
    _activeField = SearchField.destination;
    context.read<HomeViewModel>().clearSearchResults();
    context.read<HomeViewModel>().clearRouteSelection();
    FocusScope.of(context).unfocus();
    setState(() {});
  }

  Future<void> _selectSuggestion(final SearchSuggestion suggestion) async {
    final controller = _activeField == SearchField.start
        ? _startController
        : _destinationController;
    controller.text = suggestion.title;
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );

    await context.read<HomeViewModel>().selectSearchSuggestion(
          suggestion,
          _activeField,
        );
    if (!_expanded) {
      _expanded = true;
    }
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(final BuildContext context) {
    final results = context.select(
      (final HomeViewModel vm) => vm.searchResults,
    );
    final showClearStart = _startController.text.isNotEmpty;
    final showClearDestination = _destinationController.text.isNotEmpty;
    final isSearchingPlaces = context.select(
      (final HomeViewModel vm) => vm.isSearchingPlaces,
    );
    final isResolvingPlace = context.select(
      (final HomeViewModel vm) => vm.isResolvingPlace,
    );
    final isResolvingStart = context.select(
      (final HomeViewModel vm) => vm.isResolvingStartLocation,
    );
    final hasStart = context.select(
      (final HomeViewModel vm) => vm.startCoordinate != null,
    );
    final hasDestination = context.select(
      (final HomeViewModel vm) => vm.destinationCoordinate != null,
    );
    final isLoadingRoutes = context.select(
      (final HomeViewModel vm) => vm.isLoadingRoutes,
    );
    final routeError = context.select(
      (final HomeViewModel vm) => vm.routeErrorMessage,
    );
    final routeOptions = context.select(
      (final HomeViewModel vm) => vm.routeOptions,
    );
    final selectedMode = context.select(
      (final HomeViewModel vm) => vm.selectedRouteMode,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_expanded)
                TextField(
                  controller: _startController,
                  focusNode: _startFocusNode,
                  onChanged: (final value) => _handleQueryChanged(
                    value,
                    SearchField.start,
                  ),
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: "Choose starting point",
                    prefixIcon: const Icon(Icons.trip_origin),
                    suffixIcon: isResolvingStart
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.my_location),
                                onPressed: () async {
                                  await context
                                      .read<HomeViewModel>()
                                      .setStartToCurrentLocation();
                                  _startController.text = "Current location";
                                  _startController.selection =
                                      TextSelection.fromPosition(
                                    TextPosition(
                                      offset: _startController.text.length,
                                    ),
                                  );
                                },
                              ),
                              if (showClearStart)
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () =>
                                      _clearQuery(SearchField.start),
                                ),
                            ],
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    border: const OutlineInputBorder(
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 12,
                    ),
                  ),
                ),
              if (_expanded) const Divider(height: 1),
              TextField(
                controller: _destinationController,
                focusNode: _destinationFocusNode,
                onChanged: (final value) => _handleQueryChanged(
                  value,
                  SearchField.destination,
                ),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: _expanded
                      ? "Choose destination"
                      : "Search for a place or address",
                  prefixIcon: const Icon(Icons.place_outlined),
                  suffixIcon: isResolvingPlace
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _expanded
                          ? IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: _cancelSearch,
                            )
                          : showClearDestination
                              ? IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () =>
                                      _clearQuery(SearchField.destination),
                                )
                              : isSearchingPlaces
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: const OutlineInputBorder(
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            constraints: const BoxConstraints(maxHeight: 260),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              shrinkWrap: true,
              itemCount: results.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (final context, final index) {
                final suggestion = results[index];
                final isBuilding =
                    suggestion.type == SearchSuggestionType.building;
                return ListTile(
                  leading: Icon(
                    isBuilding
                        ? Icons.apartment_outlined
                        : Icons.location_on_outlined,
                  ),
                  title: Text(suggestion.title),
                  subtitle: suggestion.subtitle != null
                      ? Text(suggestion.subtitle!)
                      : null,
                  onTap: () => _selectSuggestion(suggestion),
                );
              },
            ),
          ),
        if (_expanded && hasStart && hasDestination)
          _buildRouteOptions(
            context,
            isLoadingRoutes: isLoadingRoutes,
            routeError: routeError,
            routeOptions: routeOptions,
            selectedMode: selectedMode,
          ),
      ],
    );
  }

  Widget _buildRouteOptions(
    final BuildContext context, {
    required final bool isLoadingRoutes,
    required final String? routeError,
    required final Map<RouteMode, RouteOption> routeOptions,
    required final RouteMode selectedMode,
  }) {
    if (isLoadingRoutes) {
      return const Padding(
        padding: EdgeInsets.only(top: 10),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (routeError != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(
          routeError,
          style: const TextStyle(color: Colors.red, fontSize: 12),
        ),
      );
    }

    if (routeOptions.isEmpty) return const SizedBox.shrink();

    final option = routeOptions[selectedMode];
    final distance = _formatDistance(option?.distanceMeters);
    final duration = _formatDuration(option?.durationSeconds);
    final hasTransitSteps = selectedMode == RouteMode.transit && 
                            option != null && 
                            option.steps.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: RouteMode.values.map((final mode) {
              if (!routeOptions.containsKey(mode)) return const SizedBox();
              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _modeIcon(mode),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(_modeLabel(mode)),
                  ],
                ),
                selected: selectedMode == mode,
                onSelected: (_) => context
                    .read<HomeViewModel>()
                    .selectRouteMode(mode),
              );
            }).toList(),
          ),
          if (distance != null || duration != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                [if (duration != null) duration, if (distance != null) distance]
                    .join(" - "),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          if (hasTransitSteps)
            _buildTransitSteps(option.steps),
        ],
      ),
    );
  }

  Widget _buildTransitSteps(final List<RouteStep> steps) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Route Details:",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...steps.map((step) => _buildStepItem(step)),
        ],
      ),
    );
  }

  Widget _buildStepItem(final RouteStep step) {
    final travelMode = step.travelMode;
    final instruction = step.instruction;
    final duration = _formatDuration(step.durationSeconds);
    final transitDetails = step.transitDetails;
    
    IconData icon;
    Color iconColor;
    
    if (travelMode == "TRANSIT" && transitDetails != null) {
      switch (transitDetails.mode) {
        case TransitMode.subway:
          icon = Icons.subway;
          iconColor = Colors.blue;
          break;
        case TransitMode.bus:
          icon = Icons.directions_bus;
          iconColor = Colors.green;
          break;
        case TransitMode.train:
          icon = Icons.train;
          iconColor = Colors.orange;
          break;
        default:
          icon = Icons.directions_transit;
          iconColor = Colors.blue;
      }
    } else {
      icon = Icons.directions_walk;
      iconColor = Colors.grey;
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (transitDetails != null) ...[
                  Text(
                    "${transitDetails.shortName} - ${transitDetails.lineName}",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    "From ${transitDetails.departureStop} to ${transitDetails.arrivalStop}",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                    ),
                  ),
                  if (transitDetails.numStops != null)
                    Text(
                      "${transitDetails.numStops} stops",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                ] else
                  Text(
                    instruction,
                    style: const TextStyle(fontSize: 11),
                  ),
                if (duration != null)
                  Text(
                    duration,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _modeLabel(final RouteMode mode) {
    switch (mode) {
      case RouteMode.walking:
        return "Walk";
      case RouteMode.bicycling:
        return "Bike";
      case RouteMode.driving:
        return "Car";
      case RouteMode.transit:
        return "Metro";
    }
  }

  IconData _modeIcon(final RouteMode mode) {
    switch (mode) {
      case RouteMode.walking:
        return Icons.directions_walk;
      case RouteMode.bicycling:
        return Icons.directions_bike;
      case RouteMode.driving:
        return Icons.directions_car;
      case RouteMode.transit:
        return Icons.directions_transit;
    }
  }

  String? _formatDistance(final double? meters) {
    if (meters == null) return null;
    if (meters >= 1000) {
      final km = meters / 1000;
      return "${km.toStringAsFixed(1)} km";
    }
    return "${meters.toStringAsFixed(0)} m";
  }

  String? _formatDuration(final int? seconds) {
    if (seconds == null) return null;
    final minutes = (seconds / 60).round();
    if (minutes < 60) return "${minutes} min";
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    return "${hours} h ${remaining} min";
  }
}
