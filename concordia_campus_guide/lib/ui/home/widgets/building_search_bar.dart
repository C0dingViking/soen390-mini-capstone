import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/domain/models/search_suggestion.dart";
import "package:concordia_campus_guide/ui/home/view_models/home_view_model.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class BuildingSearchBar extends StatefulWidget {
  final void Function(Building) onBuildingSelected;

  const BuildingSearchBar({super.key, required this.onBuildingSelected});

  @override
  State<BuildingSearchBar> createState() => _BuildingSearchBarState();
}

class _BuildingSearchBarState extends State<BuildingSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      context.read<HomeViewModel>().clearSearchResults();
    }
  }

  void _handleQueryChanged(final String query) {
    context.read<HomeViewModel>().updateSearchQuery(query);
    setState(() {});
  }

  void _clearQuery() {
    _controller.clear();
    context.read<HomeViewModel>().clearSearchResults();
    setState(() {});
  }

  Future<void> _selectBuilding(final Building building) async {
    _controller.text = building.name;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
    context.read<HomeViewModel>().selectSearchBuilding(building);
    widget.onBuildingSelected(building);
    FocusScope.of(context).unfocus();
  }

  Future<void> _selectPlace(final SearchSuggestion suggestion) async {
    final place = suggestion.place;
    if (place == null) return;
    _controller.text = suggestion.title;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
    await context.read<HomeViewModel>().selectPlaceSuggestion(place);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(final BuildContext context) {
    final results = context.select(
      (final HomeViewModel vm) => vm.searchResults,
    );
    final showClear = _controller.text.isNotEmpty;
    final isSearchingPlaces = context.select(
      (final HomeViewModel vm) => vm.isSearchingPlaces,
    );
    final isResolvingPlace = context.select(
      (final HomeViewModel vm) => vm.isResolvingPlace,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: _handleQueryChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: "Search for a place or address",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: isResolvingPlace
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : showClear
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _clearQuery,
                        )
                      : isSearchingPlaces
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 12,
              ),
            ),
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
                  onTap: () => isBuilding
                      ? _selectBuilding(suggestion.building!)
                      : _selectPlace(suggestion),
                );
              },
            ),
          ),
      ],
    );
  }
}
