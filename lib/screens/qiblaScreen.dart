import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  GoogleMapController? _mapControllerGoogle;

  // FIX 3: Track whether the compass has ever fired instead of relying on heading == 0
  bool _compassAvailable = false;

  /// When true the map is locked: bearing = 0 (north up), no rotation.
  /// When false (default) the map rotates with the device heading.
  bool _mapLocked = false;

  @override
  void initState() {
    super.initState();
    _updateLocation();
    _startCompass();
  }

  Future<void> _updateLocation() async {
    await getCurrentLocationQiblah();
  }

  void _startCompass() {
    FlutterCompass.events?.listen((event) {
      if (event.heading != null && mounted) {
        setState(() {
          deviceHeading = event.heading!;
          // FIX 3: Mark compass as available on first real reading
          _compassAvailable = true;
        });

        // Only rotate the map when NOT locked
        if (!_mapLocked) {
          _mapControllerGoogle?.moveCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: _currentLocation ?? const LatLng(0, 0),
                zoom: 15,
                bearing: deviceHeading,
              ),
            ),
          );
        }
      } else {
        print("No heading data available or unsupported device");
      }
    });
  }

  /// Snap map back to north-up when locking, or resume rotation when unlocking.
  void _toggleMapLock() {
    setState(() {
      _mapLocked = !_mapLocked;
    });

    if (_mapLocked) {
      // Reset to north-up, no bearing
      _mapControllerGoogle?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentLocation ?? const LatLng(0, 0),
            zoom: 15,
            bearing: 0,
          ),
        ),
      );
    } else {
      // Immediately apply current heading so the map snaps back into sync
      _mapControllerGoogle?.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentLocation ?? const LatLng(0, 0),
            zoom: 15,
            bearing: deviceHeading,
          ),
        ),
      );
    }
  }

  Future<void> getCurrentLocationQiblah() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() {
        locationMessage = 'Location permission denied';
      });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      double latitude = position.latitude;
      double longitude = position.longitude;
      setState(() {
        _currentLocation = LatLng(latitude, longitude);
        locationMessage = 'Latitude: $latitude, Longitude: $longitude';
        // FIX 1: Actually calculate and store the qibla direction
        qiblaDirection = calculateQibla(latitude, longitude);
      });
      if (_currentLocation != null) {
        _mapControllerGoogle?.animateCamera(
          CameraUpdate.newLatLng(_currentLocation!),
        );
      }
    } catch (e) {
      setState(() {
        locationMessage = 'Failed to get location: $e';
      });
      print('Failed to get location: $e');
    }
  }

  double calculateQibla(double userLatitude, double userLongitude) {
    const double kaabaLatitude = 21.4225;
    const double kaabaLongitude = 39.8262;

    double x = cos(kaabaLatitude * pi / 180) *
        sin((kaabaLongitude - userLongitude) * pi / 180);
    double y = cos(userLatitude * pi / 180) * sin(kaabaLatitude * pi / 180) -
        sin(userLatitude * pi / 180) *
            cos(kaabaLatitude * pi / 180) *
            cos((kaabaLongitude - userLongitude) * pi / 180);

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
    // FIX 2: Proper angle calculation — wrap with % 360 to avoid negative/overflow values,
    // then convert to radians. This ensures the arrow aligns with the map polyline.
    final double arrowAngle =
        ((qiblaDirection - deviceHeading) % 360) * (pi / 180);

    double difference = (qiblaDirection - deviceHeading).abs() % 360;
    difference = difference > 180 ? 360 - difference : difference;

    bool isWithinQiblaRange = difference <= 30;
    final double accuracyPercentage = 100 - (difference / 180 * 100);

    final LatLng kaabaCoordinates = const LatLng(21.4225, 39.8262);

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 105, 170, 190),
      appBar: buildAppBar(context, 'Qibla', const HomeScreen(), null),
      body: Stack(
        children: [
          // Google Map Widget
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: GoogleMap(
                mapType: MapType.normal,
                initialCameraPosition: CameraPosition(
                  target: _currentLocation ?? const LatLng(0, 0),
                  zoom: 15,
                ),
                markers: {
                  if (_currentLocation != null)
                    Marker(
                      markerId: const MarkerId('currentLocation'),
                      position: _currentLocation!,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueRed),
                    ),
                  Marker(
                    markerId: const MarkerId('kaaba'),
                    position: kaabaCoordinates,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueAzure),
                  ),
                },
                polylines: {
                  if (_currentLocation != null)
                    Polyline(
                      polylineId: const PolylineId('qiblaLine'),
                      points: [_currentLocation!, kaabaCoordinates],
                      width: 3,
                      color: Colors.blue,
                    ),
                },
                onMapCreated: (GoogleMapController controller) {
                  _mapControllerGoogle = controller;
                  if (_currentLocation != null) {
                    controller.animateCamera(
                      CameraUpdate.newLatLng(_currentLocation!),
                    );
                  }
                },
                compassEnabled: false,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
              ),
            ),
          ),

          // Instruction Card
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
                  // FIX 3: Use _compassAvailable flag instead of deviceHeading != 0.0
                  if (_compassAvailable)
                    Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: Colors.blue, size: 24),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Calibrate your phone by moving it in an 8-shape movement. Turn towards the line until the arrow turns green.',
                            style: TextStyle(
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
                        const Icon(Icons.error_outline,
                            color: Colors.orange, size: 24),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Your device does not have a compass. Please use the map for guidance.',
                            style: TextStyle(
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
                      const Icon(Icons.location_on,
                          color: Colors.red, size: 24),
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

          // Qibla Circle & Arrow
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
                      // FIX 2: Use pre-computed arrowAngle with proper % 360 wrapping
                      Transform.rotate(
                        angle: arrowAngle,
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

          // ── Lock Map toggle button (bottom-left) ───────────────────────────
          Positioned(
            bottom: 24,
            left: 16,
            child: GestureDetector(
              onTap: _toggleMapLock,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _mapLocked
                      ? const Color.fromARGB(255, 10, 25, 60)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ],
                  border: Border.all(
                    color: _mapLocked
                        ? const Color.fromARGB(255, 212, 175, 95)
                        : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _mapLocked
                          ? Icons.lock_outline
                          : Icons.lock_open_outlined,
                      size: 18,
                      color: _mapLocked
                          ? const Color.fromARGB(255, 212, 175, 95)
                          : Colors.black54,
                    ),
                    const SizedBox(width: 6),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _mapLocked
                            ? const Color.fromARGB(255, 212, 175, 95)
                            : Colors.black54,
                      ),
                      child: Text(_mapLocked ? 'Map Locked' : 'Lock Map'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: buildBottomNavigationBar(context, 2, _onItemTapped),
    );
  }
}
