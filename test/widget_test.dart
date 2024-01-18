import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cam/main.dart';

void main() {
  group('TakePictureScreen', () {
    testWidgets('Displays camera preview', (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(MyApp());

      // Find the 'Go to Image Page' button
      final goToImagePageButton = find.text('Go to Image Page');

      // Ensure the camera preview is displayed
      expect(find.byType(CameraPreview), findsOneWidget);

      // Tap the 'Go to Image Page' button
      await tester.tap(goToImagePageButton);
      await tester.pumpAndSettle();

      // Ensure the ImagePage is displayed
      expect(find.byType(ImagePage), findsOneWidget);
    });
  });
}
