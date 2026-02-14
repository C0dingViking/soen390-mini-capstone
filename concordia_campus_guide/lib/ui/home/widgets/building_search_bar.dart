import "package:concordia_campus_guide/domain/models/building.dart";
import "package:concordia_campus_guide/ui/home/view_models/home_view_model.dart";
import "package:concordia_campus_guide/utils/campus.dart";
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

  void _selectBuilding(final Building building) {
    _controller.text = building.name;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
    context.read<HomeViewModel>().selectSearchBuilding(building);
    widget.onBuildingSelected(building);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(final BuildContext context) {
    final results = context.select(
      (final HomeViewModel vm) => vm.searchResults,
    );
    final showClear = _controller.text.isNotEmpty;

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
              hintText: "Search for a building",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: showClear
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _clearQuery,
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
                final building = results[index];
                return ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(building.name),
                  subtitle: Text(
                    "${_campusLabel(building.campus)} · ${building.id.toUpperCase()}",
                  ),
                  onTap: () => _selectBuilding(building),
                );
              },
            ),
          ),
      ],
    );
  }

  String _campusLabel(final Campus campus) {
    return campus == Campus.sgw ? "SGW" : "LOY";
  }
}
