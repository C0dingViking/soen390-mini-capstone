import "package:concordia_campus_guide/data/repositories/building_repository.dart";
import "package:concordia_campus_guide/domain/interactors/map_data_interactor.dart";
import "package:concordia_campus_guide/ui/home/view_models/home_view_model.dart";
import "package:concordia_campus_guide/ui/home/widgets/home_screen.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:concordia_campus_guide/ui/core/themes/app_theme.dart";
import "package:firebase_core/firebase_core.dart";
import "firebase_options.dart";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(final BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(
        create: (_) => HomeViewModel(
          mapInteractor: MapDataInteractor(
            buildingRepo: BuildingRepository()
          )
        )
      )],
      child: MaterialApp(
        title: "Concordia Campus Guide",
        theme: AppTheme.mainTheme,
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false
      ),
    );
  }
}
