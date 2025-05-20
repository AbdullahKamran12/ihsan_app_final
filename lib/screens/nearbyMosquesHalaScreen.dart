import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:ihsan_app_final/screens/moreoptionsScreen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ihsan_app_final/sharedWidgets.dart';

class MosqueScreen extends StatefulWidget {
  const MosqueScreen({super.key});

  @override
  _MosqueScreenState createState() => _MosqueScreenState();
}

class _MosqueScreenState extends State<MosqueScreen> {
  late Position _currentPosition;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    _currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentPosition.latitude, _currentPosition.longitude),
          14.0,
        ),
      );
    }

    _fetchNearbyMosques(_currentPosition.latitude, _currentPosition.longitude);
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    double distanceInMeters =
        Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    return distanceInMeters / 1000;
  }

  Future<void> _fetchNearbyMosques(double latitude, double longitude) async {
    const String apiKey = 'AIzaSyBgsjMh_ojTBOMxLkSk5NSNYO7qSogbjdw';
    final List<Uri> uris = [
      Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$latitude,$longitude&radius=5000&type=mosque&key=$apiKey',
      ),
      Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$latitude,$longitude&radius=5000&keyword=masjid&key=$apiKey',
      ),
      Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$latitude,$longitude&radius=5000&keyword=islam&key=$apiKey',
      ),
    ];

    final responses = await Future.wait(uris.map(http.get));

    Map<String, Marker> markersMap = {
      'current_location': Marker(
        markerId: const MarkerId('current_location'),
        position: LatLng(latitude, longitude),
        infoWindow: const InfoWindow(title: 'Your Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      )
    };

    for (var response in responses) {
      if (response.statusCode != 200) continue;

      final data = json.decode(response.body);
      final List results = data['results'];

      for (var result in results) {
        final placeId = result['place_id'];
        if (markersMap.containsKey(placeId)) continue;

        final lat = result['geometry']['location']['lat'];
        final lng = result['geometry']['location']['lng'];
        final name = result['name'];

        double distance = calculateDistance(latitude, longitude, lat, lng);

        markersMap[placeId] = Marker(
          markerId: MarkerId(placeId),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: name,
            snippet: '${distance.toStringAsFixed(2)} km away',
          ),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        );
      }
    }

    setState(() {
      _markers = markersMap.values.toSet();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(
        context,
        'Nearby Mosques',
        const MoreOptionsScreen(),
        screenFrom,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(51.5074, -0.1278),
              zoom: 14,
            ),
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  )
                ],
              ),
              child: const Text(
                "Tap on a marker for details\nRed is your location",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                  fontFamily: 'Roboto',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
