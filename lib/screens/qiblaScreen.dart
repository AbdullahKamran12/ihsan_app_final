import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:ihsan_app_final/sharedWidgets.dart';
import 'package:ihsan_app_final/screens/homeScreen.dart';
import 'package:ihsan_app_final/screens/moreoptionsScreen.dart';
import 'package:ihsan_app_final/screens/prayerScreen.dart';
import 'package:ihsan_app_final/screens/quranScreen.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  _QiblaScreenState createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  int _selectedIndex = 0;
  double qiblaDirection = 0.0;
  String locationMessage = 'Getting location...';
  LatLng? _currentLocation;
  double deviceHeading = 0.0;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    getCurrentLocationQiblah();
    _startCompass();
  }

  void _startCompass() {
    FlutterCompass.events?.listen((event) {
      if (event.heading != null && mounted) {
        setState(() {
          deviceHeading = event.heading!;
          _mapController.rotate(-deviceHeading);
        });
      } else {
        print("No heading data available or unsupported device");
      }
    });
  }

  Future<void> getCurrentLocationQiblah() async {
    PermissionStatus status = await Permission.location.request();

    if (status.isGranted) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        double latitude = position.latitude;
        double longitude = position.longitude;

        qiblaDirection = calculateQibla(latitude, longitude);

        setState(() {
          _currentLocation = LatLng(latitude, longitude);
          locationMessage = 'Latitude: $latitude, Longitude: $longitude';
        });

        if (_currentLocation != null) {
          _mapController.move(_currentLocation!, 15.0);
        }
      } catch (e) {
        setState(() {
          locationMessage = 'Failed to get location: $e';
        });
        print('Failed to get location: $e');
      }
    } else {
      setState(() {
        locationMessage = 'Location permission denied';
      });
      print('Location permission denied');
    }
  }

  double calculateQibla(double userLatitude, double userLongitude) {
    const double kaabaLatitude = 21.4225;
    const double kaabaLongitude = 39.8262;

    double latDiff = kaabaLatitude - userLatitude;
    double longDiff = kaabaLongitude - userLongitude;

    double x = cos(kaabaLatitude * pi / 180) * sin(longDiff * pi / 180);
    double y = cos(userLatitude * pi / 180) * sin(kaabaLatitude * pi / 180) -
        sin(userLatitude * pi / 180) *
            cos(kaabaLatitude * pi / 180) *
            cos(longDiff * pi / 180);

    double qiblaDirection = atan2(x, y) * 180 / pi;
    qiblaDirection = (qiblaDirection + 360) % 360;

    return qiblaDirection;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PrayerTimesScreen()),
        );
        break;
      case 2:
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const QuranScreen()),
        );
        break;
      case 4:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MoreOptionsScreen()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    double difference = (qiblaDirection - deviceHeading).abs();
    difference = difference > 180 ? 360 - difference : difference;

    bool isWithinQiblaRange = difference <= 30;
    final double accuracyPercentage = 100 - (difference / 180 * 100);

    final LatLng kaabaCoordinates = LatLng(21.4225, 39.8262);
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 105, 170, 190),
      appBar: buildAppBar(context, 'Qibla', const HomeScreen(), null),
      body: Stack(
        children: [
          // Map Widget with simple styling
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentLocation ?? LatLng(0, 0),
                  initialZoom: 15.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                    subdomains: ['a', 'b', 'c'],
                    tileProvider: NetworkTileProvider(),
                  ),
                  if (_currentLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _currentLocation!,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                        Marker(
                          point: kaabaCoordinates,
                          width: 40,
                          height: 40,
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.location_city,
                              color: Colors.black,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (_currentLocation != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [_currentLocation!, kaabaCoordinates],
                          strokeWidth: 3.0,
                          color: Colors.blue,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // Simplified Instruction Card
          Positioned(
            top: 20,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    offset: const Offset(0, 2),
                    blurRadius: 6,
                  )
                ],
              ),
              child: Column(
                children: [
                  if (deviceHeading != 0.0)
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Calibrate your phone by moving it in an 8-shape movement. Turn towards the line until the arrow turns green.',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.orange,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your device does not have a compass. Please use the map for guidance.',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          locationMessage,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Align(
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.9),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Simple progress indicator
                      SizedBox(
                        width: 180,
                        height: 180,
                        child: CircularProgressIndicator(
                          value: accuracyPercentage / 100,
                          strokeWidth: 6,
                          backgroundColor: Colors.grey.withOpacity(0.3),
                          color:
                              isWithinQiblaRange ? Colors.green : Colors.blue,
                        ),
                      ),

                      // Direction Arrow
                      Transform.rotate(
                        angle: (qiblaDirection * (3.14159265359 / 180)) -
                            (deviceHeading * (3.14159265359 / 180)),
                        child: Icon(
                          Icons.arrow_upward,
                          size: 100,
                          color:
                              isWithinQiblaRange ? Colors.green : Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),

                // Status Text
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isWithinQiblaRange
                        ? Colors.green.withOpacity(0.1)
                        : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isWithinQiblaRange ? Colors.green : Colors.blue,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isWithinQiblaRange
                        ? 'Qibla Found!'
                        : 'Rotate to find Qibla',
                    style: TextStyle(
                      color: isWithinQiblaRange ? Colors.green : Colors.blue,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: buildBottomNavigationBar(context, 2, _onItemTapped),
    );
  }
}
