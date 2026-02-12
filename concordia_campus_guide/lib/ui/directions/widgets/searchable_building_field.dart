import "package:flutter/material.dart";
import "package:concordia_campus_guide/domain/models/building.dart";

class SearchableBuildingField extends StatefulWidget {
  final List<Building> buildings;
  final Building? selected;
  final String label;
  final void Function(Building) onSelected;

  const SearchableBuildingField({
    super.key,
    required this.buildings,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  @override
  State<SearchableBuildingField> createState() => _SearchableBuildingFieldState();
}

class _SearchableBuildingFieldState extends State<SearchableBuildingField> {
  final TextEditingController _controller = TextEditingController();
  List<Building> _filtered = [];
  bool _showList = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.selected?.name ?? "";
    _filtered = widget.buildings;
  }

  @override void didUpdateWidget(covariant final SearchableBuildingField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected?.name != oldWidget.selected?.name) {
      _controller.text = widget.selected?.name ?? "";
    }
  }

  void _filter(final String text) {
    setState(() {
      _filtered = widget.buildings
          .where((final b) => b.name.toLowerCase().contains(text.toLowerCase()))
          .toList();
      _showList = true;
    });
  }

  @override
  Widget build(final BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        TextField(
          controller: _controller,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: "Type or select a building",
          ),
          onChanged: _filter,
          onTap: () => _filter(_controller.text),
        ),

        if (_showList)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(
              maxHeight: 180,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ListView(
              shrinkWrap: true,
              children: _filtered.map((final b) {
                return ListTile(
                  title: Text("${b.name} (${b.id.toUpperCase()})"),
                  onTap: () {
                    widget.onSelected(b);
                    _controller.text = b.name;
                    setState(() => _showList = false);
                    FocusScope.of(context).unfocus();
                  },
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
