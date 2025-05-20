import 'package:flutter_test/flutter_test.dart';
import 'package:ihsan_app_final/screens/qiblaScreen.dart';
import 'dart:math';

void main() {
  group('Qiblah Calculation Tests', () {
    test('calculateQibla returns correct direction for known lat/long', () {
      // ARRANGE
      // Coordinates for user near Kaaba for simplicity
      double userLatitude = 21.4225;
      double userLongitude = 39.8262;

      // We expect the Qiblah direction to be ~0 if user is basically "at" Kaaba
      final qiblaScreenState = QiblaScreen().createState();

      // ACT
      double result =
          qiblaScreenState.calculateQibla(userLatitude, userLongitude);

      // ASSERT
      // Because user is essentially at Kaaba, Qiblah direction should be near 0
      // We'll allow a small margin of error for floating-point math
      expect(result, closeTo(0.0, 0.1));
    });

    test('calculateQibla returns a valid direction (0-359) for random coords',
        () {
      // ARRANGE
      final randomLat = 40.7128; // e.g., NYC
      final randomLong = -74.0060;

      final qiblaScreenState = QiblaScreen().createState();

      // ACT
      double result = qiblaScreenState.calculateQibla(randomLat, randomLong);

      // ASSERT
      // Check result is between 0 and 360
      expect(result >= 0 && result < 360, true);
    });
  });
}
