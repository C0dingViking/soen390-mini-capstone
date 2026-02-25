import "package:concordia_campus_guide/ui/core/themes/app_theme.dart";
import "package:concordia_campus_guide/ui/core/ui/campus_app_bar.dart";
import "package:concordia_campus_guide/ui/indoor_map/view_models/indoor_view_model.dart";
import "package:flutter/material.dart";
import "package:flutter_svg/svg.dart";
import "package:provider/provider.dart";

class IndoorMapView extends StatefulWidget {
  const IndoorMapView({super.key});

  @override
  State<IndoorMapView> createState() => _IndoorMapViewState();
}

class _IndoorMapViewState extends State<IndoorMapView> {
  final TransformationController _controller = TransformationController();
  final minMapZoom = 1.0;
  final maxMapZoom = 4.0;

  late IndoorViewModel _viewModel;

  @override
  void initState() {
    super.initState();

    // needed to start the map at a 2x zoom and avoid a snap on first zoom
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _viewModel = Provider.of<IndoorViewModel>(context, listen: false);
    _viewModel.addListener(_onViewModelChange);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChange);
    super.dispose();
  }

  void _onViewModelChange() {
    if (!mounted) return;
  }

  @override
  Widget build(final BuildContext context) {
    return Scaffold(
      appBar: CampusAppBar(),
      body: Container(
        color: AppTheme.concordiaGold,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _controller,
                minScale: minMapZoom,
                maxScale: maxMapZoom,
                boundaryMargin: EdgeInsets.zero,
                clipBehavior: Clip.hardEdge,
                child: SvgPicture.asset("assets/floorplans/mb-1.svg", fit: BoxFit.contain),
              ),
            ),

            Positioned(
              top: 0.0, // align in the top-left most corner
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                  constraints: const BoxConstraints(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
