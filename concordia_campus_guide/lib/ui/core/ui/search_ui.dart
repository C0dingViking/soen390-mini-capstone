import "package:flutter/material.dart";

class SearchInputCard extends StatelessWidget {
  final List<Widget> children;
  final double elevation;
  final double radius;

  const SearchInputCard({
    super.key,
    required this.children,
    this.elevation = 4,
    this.radius = 12,
  });

  @override
  Widget build(final BuildContext context) {
    return Material(
      elevation: elevation,
      borderRadius: BorderRadius.circular(radius),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class SearchResultsDropdown extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  const SearchResultsDropdown({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(final BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 4),
        shrinkWrap: true,
        itemCount: itemCount,
        separatorBuilder: (final context, final index) =>
            const Divider(height: 1),
        itemBuilder: itemBuilder,
      ),
    );
  }
}
