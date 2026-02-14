import "package:concordia_campus_guide/domain/models/search_suggestion.dart";
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
    if (!mounted) return;
    final shouldAutoSetStart =
        _activeField == SearchField.destination && !_expanded;
    if (shouldAutoSetStart) {
      await context.read<HomeViewModel>().setStartToCurrentLocation();
      if (!mounted) return;
      _startController.text = "Current location";
      _startController.selection = TextSelection.fromPosition(
        TextPosition(offset: _startController.text.length),
      );
    }
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
    final selectedStartLabel = context.select(
      (final HomeViewModel vm) => vm.selectedStartLabel,
    );
    final selectedDestinationLabel = context.select(
      (final HomeViewModel vm) => vm.selectedDestinationLabel,
    );

    // Update text controllers and expand if a selection was made
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (selectedStartLabel != _lastSyncedStartLabel && !_startFocusNode.hasFocus) {
        _lastSyncedStartLabel = selectedStartLabel;
        if (selectedStartLabel == null) {
          _startController.clear();
        } else if (_startController.text != selectedStartLabel) {
          _startController.text = selectedStartLabel;
        }
      }
      if (selectedDestinationLabel != _lastSyncedDestinationLabel && !_destinationFocusNode.hasFocus) {
        _lastSyncedDestinationLabel = selectedDestinationLabel;
        if (selectedDestinationLabel == null) {
          _destinationController.clear();
        } else if (_destinationController.text != selectedDestinationLabel) {
          _destinationController.text = selectedDestinationLabel;
        }
      }
      if ((selectedStartLabel != null || selectedDestinationLabel != null) && !_expanded) {
        setState(() {
          _expanded = true;
        });
      }
    });

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
              separatorBuilder: (final context, final index) =>
                  const Divider(height: 1),
              itemBuilder: (final context, final index) {
                final suggestion = results[index];
                final isBuilding =
                    suggestion.type == SearchSuggestionType.building;
                return ListTile(
                  leading: isBuilding
                      ? SvgPicture.asset(
                          "assets/images/app_logo.svg",
                          height: 24,
                          width: 24,
                        )
                      : const Icon(Icons.location_on_outlined),
                  title: Text(suggestion.title),
                  subtitle: suggestion.subtitle != null
                      ? Text(suggestion.subtitle!)
                      : null,
                  trailing: isBuilding && suggestion.building != null
                      ? IconButton(
                          icon: const Icon(Icons.info_outline),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (final context) =>
                                    BuildingDetailScreen(
                                  building: suggestion.building!,
                                ),
                              ),
                            );
                          },
                          tooltip: "View building info",
                        )
                      : null,
                  onTap: () => _selectSuggestion(suggestion),
                );
              },
            ),
          ),
      ],
    );
  }
}
