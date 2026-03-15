import "package:concordia_campus_guide/domain/models/search_suggestion.dart";
import "package:concordia_campus_guide/ui/core/ui/search_ui.dart";
import "package:concordia_campus_guide/ui/home/view_models/home_view_model.dart";
import "package:concordia_campus_guide/ui/home/widgets/building_detail_screen.dart";
import "package:flutter/material.dart";
import "package:flutter_svg/flutter_svg.dart";
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
  String? _lastSyncedStartLabel;
  String? _lastSyncedDestinationLabel;
  int _lastUnfocusSignal = 0;

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
    final viewModel = context.read<HomeViewModel>();

    if (_startFocusNode.hasFocus) {
      _activeField = SearchField.start;
      viewModel.setActiveSearchField(SearchField.start);
      viewModel.updateSearchQuery(_startController.text);
      return;
    }
    if (_destinationFocusNode.hasFocus) {
      _activeField = SearchField.destination;
      viewModel.setActiveSearchField(SearchField.destination);
      viewModel.updateSearchQuery(_destinationController.text);
      return;
    }

    if (!_startFocusNode.hasFocus && !_destinationFocusNode.hasFocus) {
      viewModel.clearSearchResults();
    }
  }

  void _handleQueryChanged(final String query, final SearchField field) {
    _activeField = field;
    final viewModel = context.read<HomeViewModel>();
    viewModel.setActiveSearchField(field);
    viewModel.updateSearchQuery(query);
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
    final viewModel = context.read<HomeViewModel>();
    viewModel.clearSearchResults();
    viewModel.clearRouteSelection();
    viewModel.setSearchBarExpanded(false);
    FocusScope.of(context).unfocus();
    setState(() {});
  }

  Future<void> _selectSuggestion(final SearchSuggestion suggestion) async {
    final controller = _activeField == SearchField.start
        ? _startController
        : _destinationController;
    controller.text = suggestion.title;
    controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));

    final viewModel = context.read<HomeViewModel>();
    await viewModel.selectSearchSuggestion(suggestion, _activeField);
    if (!mounted) return;

    final shouldAutoSetStart =
        _activeField == SearchField.destination && !_expanded && viewModel.startCoordinate == null;
    if (shouldAutoSetStart) {
      await viewModel.setStartToCurrentLocation();
      if (!mounted) return;
      _startController.text = "Current location";
      _startController.selection = TextSelection.fromPosition(
        TextPosition(offset: _startController.text.length),
      );
    }
    if (!_expanded) {
      _expanded = true;
      viewModel.setSearchBarExpanded(true);
    }
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(final BuildContext context) {
    final results = context.select((final HomeViewModel vm) => vm.searchResults);
    final showClearStart = _startController.text.isNotEmpty;
    final showClearDestination = _destinationController.text.isNotEmpty;
    final isSearchingPlaces = context.select((final HomeViewModel vm) => vm.isSearchingPlaces);
    final isSearchingNearbyPlaces = context.select(
      (final HomeViewModel vm) => vm.isSearchingNearbyPlaces,
    );
    final isResolvingPlace = context.select((final HomeViewModel vm) => vm.isResolvingPlace);
    final isResolvingStart = context.select(
      (final HomeViewModel vm) => vm.isResolvingStartLocation,
    );
    final selectedStartLabel = context.select((final HomeViewModel vm) => vm.selectedStartLabel);
    final selectedDestinationLabel = context.select(
      (final HomeViewModel vm) => vm.selectedDestinationLabel,
    );
    final unfocusSignal = context.select((final HomeViewModel vm) => vm.unfocusSearchBarSignal);
    final isSearchBarExpanded = context.select((final HomeViewModel vm) => vm.isSearchBarExpanded);

    _schedulePostFrameSync(
      context: context,
      unfocusSignal: unfocusSignal,
      isSearchBarExpanded: isSearchBarExpanded,
      selectedStartLabel: selectedStartLabel,
      selectedDestinationLabel: selectedDestinationLabel,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSearchCard(
          context,
          showClearStart: showClearStart,
          showClearDestination: showClearDestination,
          isResolvingStart: isResolvingStart,
          isResolvingPlace: isResolvingPlace,
          isSearchingPlaces: isSearchingPlaces || isSearchingNearbyPlaces,
        ),
        if (results.isNotEmpty) _buildResultsList(context, results),
      ],
    );
  }

  void _schedulePostFrameSync({
    required final BuildContext context,
    required final int unfocusSignal,
    required final bool isSearchBarExpanded,
    required final String? selectedStartLabel,
    required final String? selectedDestinationLabel,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _handleUnfocusSignal(unfocusSignal);
      _syncExpandedState(context, isSearchBarExpanded);
      _syncStartLabel(selectedStartLabel);
      _syncDestinationLabel(selectedDestinationLabel);
      _expandIfSelected(context, selectedStartLabel, selectedDestinationLabel);
    });
  }

  void _syncExpandedState(final BuildContext context, final bool isSearchBarExpanded) {
    if (_expanded == isSearchBarExpanded) return;

    setState(() {
      _expanded = isSearchBarExpanded;
      if (!isSearchBarExpanded) {
        _activeField = SearchField.destination;
      }
    });

    if (!isSearchBarExpanded) {
      context.read<HomeViewModel>().clearSearchResults();
      FocusScope.of(context).unfocus();
    }
  }

  void _handleUnfocusSignal(final int unfocusSignal) {
    if (unfocusSignal == _lastUnfocusSignal) return;
    _lastUnfocusSignal = unfocusSignal;
    _startFocusNode.unfocus();
    _destinationFocusNode.unfocus();
    FocusScope.of(context).unfocus();
  }

  void _syncStartLabel(final String? selectedStartLabel) {
    if (_startFocusNode.hasFocus || selectedStartLabel == _lastSyncedStartLabel) {
      return;
    }
    _lastSyncedStartLabel = selectedStartLabel;
    if (selectedStartLabel == null) {
      _startController.clear();
    } else if (_startController.text != selectedStartLabel) {
      _startController.text = selectedStartLabel;
    }
  }

  void _syncDestinationLabel(final String? selectedDestinationLabel) {
    if (_destinationFocusNode.hasFocus ||
        selectedDestinationLabel == _lastSyncedDestinationLabel) {
      return;
    }
    _lastSyncedDestinationLabel = selectedDestinationLabel;
    if (selectedDestinationLabel == null) {
      _destinationController.clear();
    } else if (_destinationController.text != selectedDestinationLabel) {
      _destinationController.text = selectedDestinationLabel;
    }
  }

  void _expandIfSelected(
    final BuildContext context,
    final String? selectedStartLabel,
    final String? selectedDestinationLabel,
  ) {
    if (_expanded) return;
    if (!context.read<HomeViewModel>().isSearchBarExpanded) return;
    if (selectedStartLabel == null && selectedDestinationLabel == null) return;

    setState(() {
      _expanded = true;
    });
    context.read<HomeViewModel>().setSearchBarExpanded(true);
  }

  Widget _buildSearchCard(
    final BuildContext context, {
    required final bool showClearStart,
    required final bool showClearDestination,
    required final bool isResolvingStart,
    required final bool isResolvingPlace,
    required final bool isSearchingPlaces,
  }) {
    return SearchInputCard(
      children: [
        if (_expanded)
          _buildStartField(
            context,
            showClearStart: showClearStart,
            isResolvingStart: isResolvingStart,
          ),
        if (_expanded) const Divider(height: 1),
        _buildDestinationField(
          context,
          showClearDestination: showClearDestination,
          isResolvingPlace: isResolvingPlace,
          isSearchingPlaces: isSearchingPlaces,
        ),
      ],
    );
  }

  Widget _buildStartField(
    final BuildContext context, {
    required final bool showClearStart,
    required final bool isResolvingStart,
  }) {
    return TextField(
      controller: _startController,
      focusNode: _startFocusNode,
      onChanged: (final value) => _handleQueryChanged(value, SearchField.start),
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        hintText: "Choose starting point",
        prefixIcon: const Icon(Icons.trip_origin),
        suffixIcon: _buildStartSuffix(
          context,
          showClearStart: showClearStart,
          isResolvingStart: isResolvingStart,
        ),
        filled: true,
        fillColor: Colors.white,
        border: const OutlineInputBorder(borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      ),
    );
  }

  Widget _buildStartSuffix(
    final BuildContext context, {
    required final bool showClearStart,
    required final bool isResolvingStart,
  }) {
    if (isResolvingStart) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.my_location),
          onPressed: () async {
            await context.read<HomeViewModel>().setStartToCurrentLocation();
            _startController.text = "Current location";
            _startController.selection = TextSelection.fromPosition(
              TextPosition(offset: _startController.text.length),
            );
          },
        ),
        if (showClearStart)
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _clearQuery(SearchField.start),
          ),
      ],
    );
  }

  Widget _buildDestinationField(
    final BuildContext context, {
    required final bool showClearDestination,
    required final bool isResolvingPlace,
    required final bool isSearchingPlaces,
  }) {
    return TextField(
      controller: _destinationController,
      focusNode: _destinationFocusNode,
      onChanged: (final value) => _handleQueryChanged(value, SearchField.destination),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: _expanded
            ? "Choose destination"
            : "Search for a place, address, or category",
        prefixIcon: const Icon(Icons.place_outlined),
        suffixIcon: _buildDestinationSuffix(
          context,
          showClearDestination: showClearDestination,
          isResolvingPlace: isResolvingPlace,
          isSearchingPlaces: isSearchingPlaces,
        ),
        filled: true,
        fillColor: Colors.white,
        border: const OutlineInputBorder(borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      ),
    );
  }

  Widget _buildDestinationSuffix(
    final BuildContext context, {
    required final bool showClearDestination,
    required final bool isResolvingPlace,
    required final bool isSearchingPlaces,
  }) {
    final nearbyLimit = context.select((final HomeViewModel vm) => vm.nearbySearchResultLimit);

    return SizedBox(
      width: _expanded ? 48 : 96,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_expanded)
            PopupMenuButton<int>(
              tooltip: "Choose how many nearby results to show",
              initialValue: nearbyLimit,
              icon: const Icon(Icons.tune),
              onSelected: (final value) {
                context.read<HomeViewModel>().setNearbySearchResultLimit(value);
              },
              itemBuilder: (final context) => const [
                PopupMenuItem<int>(value: 3, child: Text("Show 3 nearby")),
                PopupMenuItem<int>(value: 5, child: Text("Show 5 nearby")),
                PopupMenuItem<int>(value: 10, child: Text("Show 10 nearby")),
              ],
            ),
          if (isResolvingPlace || isSearchingPlaces)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_expanded)
            IconButton(icon: const Icon(Icons.close), onPressed: _cancelSearch)
          else if (showClearDestination)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => _clearQuery(SearchField.destination),
            ),
        ],
      ),
    );
  }

  Widget _buildResultsList(final BuildContext context, final List<SearchSuggestion> results) {
    return SearchResultsDropdown(
      itemCount: results.length,
      itemBuilder: (final context, final index) {
        final suggestion = results[index];
        final isBuilding = suggestion.type == SearchSuggestionType.building;
        return ListTile(
          leading: isBuilding
              ? SvgPicture.asset("assets/images/app_logo.svg", height: 24, width: 24)
              : const Icon(Icons.location_on_outlined),
          title: Text(suggestion.title),
          subtitle: suggestion.subtitle != null ? Text(suggestion.subtitle!) : null,
          trailing: isBuilding && suggestion.building != null
              ? IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (final context) =>
                            BuildingDetailScreen(building: suggestion.building!),
                      ),
                    );
                  },
                  tooltip: "View building info",
                )
              : null,
          onTap: () => _selectSuggestion(suggestion),
        );
      },
    );
  }
}
