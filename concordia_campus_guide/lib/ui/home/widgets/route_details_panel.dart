import "package:concordia_campus_guide/domain/models/route_option.dart";
import "package:concordia_campus_guide/ui/core/themes/app_theme.dart";
import "package:concordia_campus_guide/ui/home/view_models/home_view_model.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class RouteDetailsPanel extends StatefulWidget {
  const RouteDetailsPanel({super.key});

  @override
  State<RouteDetailsPanel> createState() => _RouteDetailsPanelState();
}

class _RouteDetailsPanelState extends State<RouteDetailsPanel> {
  double _panelHeight = _minHeight;
  bool _isDragging = false;

  static const double _minHeight = 120;

  void _toggleExpanded() {
    final screenHeight = MediaQuery.of(context).size.height;
    final targets = _panelTargets(screenHeight);
    final current = _panelHeight;
    final currentIndex = _nearestTargetIndex(targets, current);
    final nextIndex = (currentIndex + 1) % targets.length;
    setState(() {
      _panelHeight = targets[nextIndex];
    });
  }

  List<double> _panelTargets(final double screenHeight) {
    return <double>[
      _minHeight,
      screenHeight * 0.5,
      screenHeight * (2 / 3),
    ];
  }

  int _nearestTargetIndex(final List<double> targets, final double value) {
    var bestIndex = 0;
    var bestDistance = (targets.first - value).abs();
    for (var i = 1; i < targets.length; i++) {
      final distance = (targets[i] - value).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  bool get _isCollapsed => _panelHeight <= _minHeight + 1;

  void _exitNavigation() {
    context.read<HomeViewModel>().exitNavigation();
  }

  @override
  Widget build(final BuildContext context) {
    final hasRoutes = context.select(
      (final HomeViewModel vm) => vm.routeOptions.isNotEmpty,
    );
    final isLoadingRoutes = context.select(
      (final HomeViewModel vm) => vm.isLoadingRoutes,
    );
    final routeOptions = context.select(
      (final HomeViewModel vm) => vm.routeOptions,
    );
    final selectedMode = context.select(
      (final HomeViewModel vm) => vm.selectedRouteMode,
    );
    final routeError = context.select(
      (final HomeViewModel vm) => vm.routeErrorMessage,
    );

    if (!hasRoutes && !isLoadingRoutes) {
      return const SizedBox.shrink();
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * (2 / 3);
    final clampedHeight = _panelHeight.clamp(_minHeight, maxHeight);
    final targets = _panelTargets(screenHeight);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: GestureDetector(
        onVerticalDragStart: (_) {
          setState(() {
            _isDragging = true;
          });
        },
        onVerticalDragUpdate: (final details) {
          final nextHeight = (_panelHeight - details.delta.dy)
              .clamp(_minHeight, maxHeight);
          setState(() {
            _panelHeight = nextHeight;
          });
        },
        onVerticalDragEnd: (_) {
          final nearestIndex = _nearestTargetIndex(targets, _panelHeight);
          setState(() {
            _panelHeight = targets[nearestIndex];
            _isDragging = false;
          });
        },
        child: AnimatedContainer(
          height: clampedHeight,
          duration: _isDragging
              ? Duration.zero
              : const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHandle(),
              Expanded(
                child: isLoadingRoutes
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : _buildContent(
                        routeOptions: routeOptions,
                        selectedMode: selectedMode,
                        routeError: routeError,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    final isLoadingRoutes = context.select(
      (final HomeViewModel vm) => vm.isLoadingRoutes,
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _exitNavigation,
            icon: Icon(
              Icons.close,
              color: Colors.grey[600],
            ),
            tooltip: "Exit navigation",
          ),
          Expanded(
            child: GestureDetector(
              key: const Key("route_details_handle"),
              onTap: _toggleExpanded,
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: isLoadingRoutes
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.grey[600]!,
                      ),
                    ),
                  )
                : Icon(
                    Icons.refresh,
                    color: Colors.grey[600],
                  ),
            onPressed: isLoadingRoutes
                ? null
                : () async {
                    final viewModel = context.read<HomeViewModel>();
                    await viewModel.refreshRoutes();
                  },
            tooltip: "Refresh routes",
          ),
        ],
      ),
    );
  }

  Widget _buildContent({
    required final Map<RouteMode, RouteOption> routeOptions,
    required final RouteMode selectedMode,
    required final String? routeError,
  }) {
    if (routeError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            routeError,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (routeOptions.isEmpty) {
      return const SizedBox.shrink();
    }

    final option = routeOptions[selectedMode];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimeSelector(),
          const SizedBox(height: 12),
          _buildModeSelector(routeOptions, selectedMode),
          const SizedBox(height: 12),
          _buildRouteSummary(option, selectedMode),
          if (!_isCollapsed && selectedMode == RouteMode.transit && option != null)
            ...[
            const SizedBox(height: 16),
            _buildTransitSteps(option.steps),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeSelector() {
    final viewModel = context.read<HomeViewModel>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Departure Time",
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                onSelected: (_) {
                  viewModel.setDepartureMode(DepartureMode.now);
                },
                selected: viewModel.departureMode == DepartureMode.now,
                label: const Text("Now"),
              ),
              FilterChip(
                onSelected: (_) async {
                  final now = DateTime.now();
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(
                      viewModel.selectedDepartureTime ?? now,
                    ),
                  );
                  if (time != null) {
                    final dateTime = DateTime(
                      now.year,
                      now.month,
                      now.day,
                      time.hour,
                      time.minute,
                    );
                    viewModel.setDepartureTime(dateTime);
                  }
                },
                selected: viewModel.departureMode == DepartureMode.departAt,
                label: Text(
                  'Depart at ${viewModel.selectedDepartureTime != null ? _formatTime(viewModel.selectedDepartureTime!) : ''}',
                ),
              ),
              FilterChip(
                onSelected: (_) async {
                  final now = DateTime.now();
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(
                      viewModel.selectedArrivalTime ?? now,
                    ),
                  );
                  if (time != null) {
                    final dateTime = DateTime(
                      now.year,
                      now.month,
                      now.day,
                      time.hour,
                      time.minute,
                    );
                    viewModel.setArrivalTime(dateTime);
                  }
                },
                selected: viewModel.departureMode == DepartureMode.arriveBy,
                label: Text(
                  'Arrive by ${viewModel.selectedArrivalTime != null ? _formatTime(viewModel.selectedArrivalTime!) : ''}',
                ),
              ),
            ],
          ),
          if (viewModel.departureMode == DepartureMode.arriveBy &&
              viewModel.suggestedDepartureTime != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                "Leave at ${_formatTime(viewModel.suggestedDepartureTime!)} to arrive on time",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(final DateTime time) {
    final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, "0");
    final period = time.hour < 12 ? "AM" : "PM";
    return "$hour12:$minute $period";
  }

  DateTime? _suggestedTransitDepartureTime(final List<RouteStep> steps) {
    var secondsBeforeTransit = 0;
    for (final step in steps) {
      if (step.travelMode == "TRANSIT" &&
          step.transitDetails?.departureDateTime != null) {
        final transitDeparture = step.transitDetails!.departureDateTime!;
        return transitDeparture.subtract(
          Duration(seconds: secondsBeforeTransit),
        );
      }
      secondsBeforeTransit += step.durationSeconds;
    }
    return null;
  }

  Widget _buildModeSelector(
    final Map<RouteMode, RouteOption> routeOptions,
    final RouteMode selectedMode,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: RouteMode.values.map((final mode) {
        if (!routeOptions.containsKey(mode)) return const SizedBox.shrink();
        final option = routeOptions[mode];
        return FilterChip(
          avatar: Icon(
            _modeIcon(mode),
            size: 18,
            color: selectedMode == mode ? Colors.white : null,
          ),
          label: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_modeLabel(mode)),
              if (option != null)
                Text(
                  _formatDuration(option.durationSeconds) ?? "",
                  style: TextStyle(
                    fontSize: 10,
                    color: selectedMode == mode
                        ? Colors.white70
                        : Colors.grey[600],
                  ),
                ),
            ],
          ),
          selected: selectedMode == mode,
          onSelected: (_) =>
              context.read<HomeViewModel>().selectRouteMode(mode),
          selectedColor: _getModeColor(mode),
          backgroundColor: Colors.grey[200],
          labelStyle: TextStyle(
            color: selectedMode == mode ? Colors.white : Colors.black87,
          ),
          showCheckmark: false,
        );
      }).toList(),
    );
  }

  Widget _buildRouteSummary(final RouteOption? option, final RouteMode selectedMode) {
    if (option == null) return const SizedBox.shrink();

    final distance = _formatDistance(option.distanceMeters);
    final duration = _formatDuration(option.durationSeconds);
    
    // Calculate arrival time based on current departure time and duration
    final viewModel = context.read<HomeViewModel>();
    String? arrivalTimeText;
    
    if (option.durationSeconds != null && option.durationSeconds! > 0) {
      final departureTime = viewModel.selectedDepartureTime ?? DateTime.now();
      final arrivalTime = departureTime.add(
        Duration(seconds: option.durationSeconds!),
      );
      arrivalTimeText = _formatTime(arrivalTime);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.access_time,
            size: 20,
            color: Colors.grey[700],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (duration != null)
                  Text(
                    duration,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (distance != null)
                  Text(
                    distance,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                if (arrivalTimeText != null)
                  Text(
                    "Arrive at $arrivalTimeText",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (option.summary != null)
                  Text(
                    option.summary!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (_isCollapsed &&
              selectedMode == RouteMode.transit &&
              option.steps.isNotEmpty)
            Icon(
              Icons.keyboard_arrow_up,
              color: Colors.grey[700],
            ),
        ],
      ),
    );
  }

  Widget _buildTransitSteps(final List<RouteStep> steps) {
    final suggestedTransitDeparture = _suggestedTransitDepartureTime(steps);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Route Details",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (suggestedTransitDeparture != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              "Suggested depart at ${_formatTime(suggestedTransitDeparture)}",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const SizedBox(height: 8),
        ...steps.map((final step) => _buildStepItem(step)),
      ],
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
          iconColor = AppTheme.concordiaDarkBlue;
          break;
        case TransitMode.bus:
          icon = Icons.directions_bus;
          iconColor = AppTheme.concordiaBusCyan;
          break;
        case TransitMode.train:
          icon = Icons.train;
          iconColor = AppTheme.concordiaTrainMauve;
          break;
        default:
          icon = Icons.directions_transit;
          iconColor = AppTheme.concordiaDarkBlue;
      }
    } else {
      icon = Icons.directions_walk;
      iconColor = AppTheme.concordiaTurquoise;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (transitDetails != null) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: iconColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          transitDetails.shortName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          transitDetails.lineName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Board at ${transitDetails.departureStop}",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    "Exit at ${transitDetails.arrivalStop}",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                  if ((transitDetails.departureTime ??
                          transitDetails.arrivalTime) !=
                      null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "Vehicle arrives at ${transitDetails.departureTime ?? transitDetails.arrivalTime}",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  if (transitDetails.numStops != null)
                    Text(
                      "${transitDetails.numStops} stops • $duration",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ] else ...[
                  Text(
                    instruction,
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (duration != null)
                    Text(
                      duration,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
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
        return "Drive";
      case RouteMode.transit:
        return "Transit";
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

  Color _getModeColor(final RouteMode mode) {
    switch (mode) {
      case RouteMode.walking:
        return AppTheme.concordiaTurquoise;
      case RouteMode.bicycling:
        return AppTheme.concordiaTurquoise;
      case RouteMode.driving:
        return AppTheme.concordiaMaroon;
      case RouteMode.transit:
        return AppTheme.concordiaDarkBlue;
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
    if (minutes < 60) return "$minutes min";
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    return "$hours h $remaining min";
  }
}
