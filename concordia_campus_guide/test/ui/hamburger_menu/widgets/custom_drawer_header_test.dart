import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:network_image_mock/network_image_mock.dart";
import "package:concordia_campus_guide/ui/hamburger_menu/widgets/custom_drawer_header.dart";
import "package:concordia_campus_guide/ui/core/themes/app_theme.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("CustomDrawerHeader Widget Tests", () {
    const String testName = "John Doe";
    const String testEmail = "john.doe@example.com";
    const String testImageUrl =
        "https://api.dicebear.com/9.x/bottts/png?seed=Jessica";

    Future<void> pumpDrawerHeader(
      final WidgetTester tester, {
      required final String name,
      required final String email,
      required final String imageUrl,
    }) async {
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(size: Size(400, 800)),
              child: Scaffold(
                body: CustomDrawerHeader(
                  name: name,
                  email: email,
                  imageUrl: imageUrl,
                ),
              ),
            ),
          ),
        );
      });
    }

    testWidgets("displays first name and last name", (final tester) async {
      await pumpDrawerHeader(
        tester,
        name: testName,
        email: testEmail,
        imageUrl: testImageUrl,
      );

      expect(find.text("John"), findsOneWidget);
      expect(find.text("Doe"), findsOneWidget);
    });

    testWidgets("hides last name when not provided", (final tester) async {
      await pumpDrawerHeader(
        tester,
        name: "John",
        email: testEmail,
        imageUrl: testImageUrl,
      );

      expect(find.text("John"), findsOneWidget);
      expect(find.text("Doe"), findsNothing);
    });

    testWidgets("displays email address", (final tester) async {
      await pumpDrawerHeader(
        tester,
        name: testName,
        email: testEmail,
        imageUrl: testImageUrl,
      );

      expect(find.text(testEmail), findsOneWidget);
    });

    testWidgets("renders profile image using Image.network", (
      final tester,
    ) async {
      await pumpDrawerHeader(
        tester,
        name: testName,
        email: testEmail,
        imageUrl: testImageUrl,
      );

      final Finder imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final Image image = tester.widget(imageFinder);
      expect(image.image, isA<NetworkImage>());
      expect((image.image as NetworkImage).url, equals(testImageUrl));
    });

    testWidgets("uses Concordia maroon background color", (final tester) async {
      await pumpDrawerHeader(
        tester,
        name: testName,
        email: testEmail,
        imageUrl: testImageUrl,
      );

      final Container container = tester.widget(find.byType(Container).first);
      expect(container.color, AppTheme.concordiaMaroon);
    });

    testWidgets("header height is proportional to screen height", (
      final tester,
    ) async {
      await pumpDrawerHeader(
        tester,
        name: testName,
        email: testEmail,
        imageUrl: testImageUrl,
      );

      final RenderBox box = tester.renderObject(find.byType(Container).first);

      expect(box.size.height, closeTo(800 * 0.25, 0.1));
    });
  });
}
