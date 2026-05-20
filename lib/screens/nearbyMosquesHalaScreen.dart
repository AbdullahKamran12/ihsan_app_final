import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:ihsan_app_final/screens/moreoptionsScreen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ihsan_app_final/sharedWidgets.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ihsan_app_final/screens/prayerScreen.dart';
import 'package:ihsan_app_final/screens/prayerTimesClass.dart';
import 'package:ihsan_app_final/utils/api_keys.dart';

// Simple model to hold mosque list data for the bottom sheet
class _MosqueListItem {
  final String name;
  final double distance;
  final LatLng position;
  final bool hasTodayTimetable;

  _MosqueListItem({
    required this.name,
    required this.distance,
    required this.position,
    required this.hasTodayTimetable,
  });
}

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

  // Sorted mosque list for the bottom sheet (mosques only, not halal places)
  List<_MosqueListItem> _mosqueList = [];

  final TextEditingController _searchCityController = TextEditingController();
  List<Map<String, dynamic>> _citySuggestions = [];
  Timer? _debounceTimer;
  bool _isSearchingCity = false;

  // Controls for the draggable sheet
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    _updateLocation();
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _onMosqueTapped(String placeName, LatLng position) async {
    final bool? checkTimes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.mosque_outlined,
                color: Color.fromARGB(255, 10, 25, 60), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                placeName,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Would you like to check if prayer times are available for this mosque?',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actions: [
          if (position.latitude != null && position.longitude != null) ...[
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () =>
                  openNavigation(position.latitude!, position.longitude!),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color.fromARGB(255, 100, 180, 240),
                      width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.white,
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.navigation_rounded,
                        size: 16, color: Color.fromARGB(255, 100, 180, 240)),
                    SizedBox(width: 5),
                    Text('Go To',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color.fromARGB(255, 100, 180, 240))),
                  ],
                ),
              ),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 10, 25, 60),
              foregroundColor: const Color.fromARGB(255, 212, 175, 95),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.access_time_rounded, size: 16),
            label: const Text('Check Times',
                style: TextStyle(fontWeight: FontWeight.w600)),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (checkTimes != true) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(children: [
          SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 12),
          Text('Checking for prayer times...'),
        ]),
        duration: Duration(seconds: 10),
      ),
    );

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('mosques')
          .where('name', isEqualTo: placeName)
          .limit(1)
          .get();

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (snapshot.docs.isEmpty) {
        _showNoTimesDialog(placeName);
        return;
      }

      final mosqueDoc = snapshot.docs.first;
      final today = DateTime.now().toIso8601String().substring(0, 10);

      final prayerDoc = await FirebaseFirestore.instance
          .collection('mosques')
          .doc(mosqueDoc.id)
          .collection('prayerTimes')
          .doc(today)
          .get();

      if (!prayerDoc.exists) {
        _showNoTimesDialog(placeName);
        return;
      }

      mosqueIdFind = mosqueDoc.id;

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PrayerTimesScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showNoTimesDialog(placeName);
    }
  }

  void _showNoTimesDialog(String mosqueName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('No Times Available'),
        content: Text('No prayer timetable found for "$mosqueName".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateLocation() async {
    await _getCurrentLocation();
  }

  Future<void> openNavigation(double lat, double lng) async {
    final appUri = Uri.parse('google.navigation:q=$lat,$lng');
    final webUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );

    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _getCitySuggestions(String input) async {
    if (input.isEmpty) {
      setState(() => _citySuggestions.clear());
      return;
    }

    final String apiKey = await ApiKeys.getMapsKey();
    final String url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=$input&types=(cities)&key=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      final predictions = data['predictions'] as List? ?? [];

      final List<Map<String, dynamic>> results = [];

      for (final p in predictions.take(8)) {
        results.add({
          'name': p['structured_formatting']?['main_text'] ??
              p['description'].split(',').first,
          'place_id': p['place_id'],
          'description': p['description'],
        });
      }

      setState(() => _citySuggestions = results);
    } catch (e) {
      debugPrint('City autocomplete error: $e');
    }
  }

  Future<LatLng> _getLatLngFromPlaceId(String placeId) async {
    final String apiKey = await ApiKeys.getMapsKey();
    final url = 'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId&fields=geometry&key=$apiKey';

    final response = await http.get(Uri.parse(url));
    final data = jsonDecode(response.body);

    final location = data['result']['geometry']['location'];
    return LatLng(location['lat'], location['lng']);
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
    if (await isConnected()) {
      _fetchNearbyMosques(
          _currentPosition.latitude, _currentPosition.longitude);
    } else {
      _isLoading = false;
    }
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    double distanceInMeters =
        Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    return distanceInMeters / 1000;
  }

  Future<void> _fetchNearbyMosques(double latitude, double longitude) async {
    final String apiKey = await ApiKeys.getMapsKey();
    final today = DateTime.now().toIso8601String().substring(0, 10);

    Map<String, Marker> markersMap = {
      'current_location': Marker(
        markerId: const MarkerId('current_location'),
        position: LatLng(latitude, longitude),
        infoWindow: const InfoWindow(title: 'Your Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueViolet,
        ),
      )
    };

    // Accumulated mosque list for the bottom sheet
    final List<_MosqueListItem> mosqueListItems = [];

    // ── Step 1: Fetch Firestore mosques ────────────────────────────────────────
    // A mosque is green ONLY if it has a prayerTimes doc for today.
    final Set<String> firestoreNames = {};
    try {
      final firestoreSnapshot =
          await FirebaseFirestore.instance.collection('mosques').get();

      for (final doc in firestoreSnapshot.docs) {
        final data = doc.data();
        final GeoPoint? geo = data['location'];
        if (geo == null) continue;

        final lat = geo.latitude;
        final lng = geo.longitude;
        final name = (data['name'] ?? doc.id) as String;
        final distance = calculateDistance(latitude, longitude, lat, lng);
        if (distance > 5) continue;

        firestoreNames.add(name);

        // Check whether today's prayer times exist for this mosque
        bool hasTodayTimetable = false;
        try {
          final prayerDoc = await FirebaseFirestore.instance
              .collection('mosques')
              .doc(doc.id)
              .collection('prayerTimes')
              .doc(today)
              .get();
          hasTodayTimetable = prayerDoc.exists;
        } catch (_) {
          hasTodayTimetable = false;
        }

        markersMap[doc.id] = Marker(
          markerId: MarkerId(doc.id),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: name,
            snippet: hasTodayTimetable
                ? '${distance.toStringAsFixed(2)} km · Has timetable ✓'
                : '${distance.toStringAsFixed(2)} km · No timetable today',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            hasTodayTimetable
                ? BitmapDescriptor.hueGreen
                : BitmapDescriptor.hueRed,
          ),
          onTap: () => _onMosqueTapped(name, LatLng(lat, lng)),
        );

        mosqueListItems.add(_MosqueListItem(
          name: name,
          distance: distance,
          position: LatLng(lat, lng),
          hasTodayTimetable: hasTodayTimetable,
        ));
      }
    } catch (e) {
      debugPrint('Firestore fetch error: $e');
    }

    // ── Step 2: Google mosque queries — only plot if NOT already in Firestore ──
    final List<Uri> mosqueUris = [
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

    final mosqueResponses = await Future.wait(mosqueUris.map(http.get));
    final Set<String> googlePlaceIds = {};

    for (var response in mosqueResponses) {
      if (response.statusCode != 200) continue;
      final List results = json.decode(response.body)['results'];
      for (var result in results) {
        final placeId = result['place_id'] as String;
        if (googlePlaceIds.contains(placeId)) continue;
        googlePlaceIds.add(placeId);

        final lat = result['geometry']['location']['lat'] as double;
        final lng = result['geometry']['location']['lng'] as double;
        final name = result['name'] as String;
        final distance = calculateDistance(latitude, longitude, lat, lng);

        if (firestoreNames.contains(name)) continue;
        if (markersMap.containsKey(placeId)) continue;

        markersMap[placeId] = Marker(
          markerId: MarkerId(placeId),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: name,
            snippet: '${distance.toStringAsFixed(2)} km · No timetable',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          onTap: () => _onMosqueTapped(name, LatLng(lat, lng)),
        );

        mosqueListItems.add(_MosqueListItem(
          name: name,
          distance: distance,
          position: LatLng(lat, lng),
          hasTodayTimetable: false,
        ));
      }
    }

    // ── Step 3: Halal places — blue, skip anything already on map ─────────────
    final halalResponse = await http.get(Uri.parse(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$latitude,$longitude&radius=5000&keyword=halal&key=$apiKey',
    ));

    if (halalResponse.statusCode == 200) {
      final List results = json.decode(halalResponse.body)['results'];
      for (var result in results) {
        final placeId = result['place_id'] as String;
        if (markersMap.containsKey(placeId)) continue;

        final lat = result['geometry']['location']['lat'] as double;
        final lng = result['geometry']['location']['lng'] as double;
        final name = result['name'] as String;
        final distance = calculateDistance(latitude, longitude, lat, lng);

        markersMap[placeId] = Marker(
          markerId: MarkerId(placeId),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: name,
            snippet: '${distance.toStringAsFixed(2)} km · Halal place',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          onTap: () => _onHalalTapped(name, lat, lng),
        );
      }
    }

    // Sort mosque list closest → farthest
    mosqueListItems.sort((a, b) => a.distance.compareTo(b.distance));

    setState(() {
      _markers = markersMap.values.toSet();
      _mosqueList = mosqueListItems;
      _isLoading = false;
    });
  }

  // ── Halal place tapped ─────────────────────────────────────────────────────
  Future<void> _onHalalTapped(String placeName, double lat, double lng) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.restaurant_outlined,
                color: Color.fromARGB(255, 10, 25, 60), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(placeName,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        content: const Text(
          'This is a nearby halal place.\nWould you like to open it in Google Maps?',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 10, 25, 60),
              foregroundColor: const Color.fromARGB(255, 212, 175, 95),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.map_outlined, size: 16),
            label: const Text('Open in Maps',
                style: TextStyle(fontWeight: FontWeight.w600)),
            onPressed: () async {
              Navigator.pop(context);
              final uri = Uri.parse(
                  'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(placeName)}&query_place_id=$lat,$lng');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
    );
  }

  // ── Bottom sheet mosque list tile ─────────────────────────────────────────
  Widget _buildMosqueListTile(_MosqueListItem item) {
    return InkWell(
      onTap: () => _onMosqueTapped(item.name, item.position),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Colour dot indicating timetable status
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.hasTodayTimetable ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color.fromARGB(255, 10, 25, 60),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.hasTodayTimetable
                        ? 'Has timetable today'
                        : 'No timetable today',
                    style: TextStyle(
                      fontSize: 11,
                      color: item.hasTodayTimetable
                          ? Colors.green.shade700
                          : Colors.red.shade400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${item.distance.toStringAsFixed(2)} km',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: Colors.black38),
          ],
        ),
      ),
    );
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
          // ── Google Map ──────────────────────────────────────────────────────
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

          // ── Search bar ──────────────────────────────────────────────────────
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                TextField(
                  controller: _searchCityController,
                  decoration: InputDecoration(
                    hintText: 'Search another city',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    _debounceTimer?.cancel();
                    _debounceTimer = Timer(
                      const Duration(milliseconds: 600),
                      () => _getCitySuggestions(value),
                    );
                  },
                ),
                if (_citySuggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _citySuggestions.length,
                      itemBuilder: (context, index) {
                        final city = _citySuggestions[index];
                        return ListTile(
                          title: Text(city['description']),
                          onTap: () async {
                            FocusScope.of(context).unfocus();
                            _searchCityController.text = city['name'];
                            _citySuggestions.clear();
                            setState(() => _isLoading = true);

                            final latLng =
                                await _getLatLngFromPlaceId(city['place_id']);

                            _mapController?.animateCamera(
                              CameraUpdate.newLatLngZoom(latLng, 14),
                            );

                            await _fetchNearbyMosques(
                              latLng.latitude,
                              latLng.longitude,
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // ── Legend box ──────────────────────────────────────────────────────
          Positioned(
            top: _citySuggestions.isNotEmpty ? 280 : 80,
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
                "🟢 Has today's timetable  \n🔴 No timetable today  \n🔵 Halal place \nTap a marker for details",
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

          // ── Draggable bottom sheet: mosque list ────────────────────────────
          if (!_isLoading && _mosqueList.isNotEmpty)
            DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: 0.12, // collapsed — just the handle + header
              minChildSize: 0.12,
              maxChildSize: 0.55,
              snap: true,
              snapSizes: const [0.12, 0.55],
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, -2),
                      )
                    ],
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.zero,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 10, bottom: 6),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // Header row
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.mosque_outlined,
                                size: 18,
                                color: Color.fromARGB(255, 10, 25, 60)),
                            const SizedBox(width: 8),
                            Text(
                              'Nearby Mosques (${_mosqueList.length})',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color.fromARGB(255, 10, 25, 60),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Closest first',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 1),

                      // Mosque tiles
                      ..._mosqueList.map(_buildMosqueListTile),

                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            ),

          // ── Loading overlay ─────────────────────────────────────────────────
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
