import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ihsan_app_final/sharedWidgets.dart';
import 'package:ihsan_app_final/screens/moreoptionsScreen.dart';
import 'package:ihsan_app_final/screens/prayerTimesClass.dart';
import 'package:ihsan_app_final/screens/photoupload.dart';
import 'package:ihsan_app_final/utils/api_keys.dart';

class UploadMosque extends StatefulWidget {
  const UploadMosque({super.key});

  @override
  _UploadMosqueState createState() => _UploadMosqueState();
}

class _UploadMosqueState extends State<UploadMosque> {
  late Position _currentPosition;
  GoogleMapController? _mapController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _mosques = [];
  String cityName = '';
  double? selectedMosqueLat;
  double? selectedMosqueLng;
  String adminAreaLevel2 = '';

  final TextEditingController _searchCityController = TextEditingController();
  final TextEditingController _mosqueController =
      TextEditingController(text: 'Masjid-e-Ibrahim');
  final TextEditingController _cityController = TextEditingController();

  List<Map<String, dynamic>> _citySuggestions = [];
  Timer? _debounceTimer;

  bool _isUploading = false;
  String _status = '';
  List<Map<String, dynamic>> _textSearchResults = [];

  @override
  void initState() {
    super.initState();
    _updateLocation();
  }

  @override
  void dispose() {
    _searchCityController.dispose();
    _mosqueController.dispose();
    _cityController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // ── Location ────────────────────────────────────────────────────────────────
  Future<void> _updateLocation() async {
    if (!context.mounted) return;
    if (await isConnected()) {
      await _getCurrentLocation();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _isLoading = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isLoading = false);
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() => _isLoading = false);
      return;
    }

    _currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    await _fetchNearbyMosques(
        _currentPosition.latitude, _currentPosition.longitude);
  }

  // ── City suggestions ────────────────────────────────────────────────────────
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

  // ── Reverse geocode to get city name ────────────────────────────────────────
  Future<void> _updateCityFromCoordinates(
      double latitude, double longitude) async {
    final String apiKey = await ApiKeys.getMapsKey();
    final String url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$latitude,$longitude&key=$apiKey';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return;

    final data = jsonDecode(response.body);

    final compound = data['plus_code']?['compound_code'];
    if (compound != null) {
      final parts = compound.split(' ');
      if (parts.length >= 2) {
        final area = parts.sublist(1).join(' ').replaceAll(', UK', '').trim();
        cityName = area;
        _cityController.text = cityName;
        setState(() {});
        return;
      }
    }

    if (data['results'] != null && (data['results'] as List).isNotEmpty) {
      String? foundCity;
      String? foundAdminArea2;

      for (var result in data['results']) {
        for (var component in result['address_components']) {
          final types = List<String>.from(component['types']);
          if (foundAdminArea2 == null &&
              types.contains('administrative_area_level_2')) {
            foundAdminArea2 = component['long_name'];
          }
          if (foundCity == null && types.contains('postal_town')) {
            foundCity = component['long_name'];
          }
        }
      }

      if (foundCity == null) {
        for (var component in data['results'][0]['address_components']) {
          final types = List<String>.from(component['types']);
          if (types.contains('locality') ||
              types.contains('administrative_area_level_2')) {
            foundCity = component['long_name'];
            break;
          }
        }
      }

      adminAreaLevel2 = foundAdminArea2 ?? '';

      if (foundCity != null) {
        cityName = foundCity;
        _cityController.text = cityName;
        setState(() {});
        return;
      }
    }

    cityName = 'Unknown Location';
    _cityController.text = cityName;
    setState(() {});
  }

  // ── Nearby mosques ──────────────────────────────────────────────────────────
  Future<void> _fetchNearbyMosques(double latitude, double longitude) async {
    final String apiKey = await ApiKeys.getMapsKey();
    final List<Uri> uris = [
      Uri.parse(
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$latitude,$longitude&radius=5000&type=mosque&key=$apiKey'),
      Uri.parse(
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$latitude,$longitude&radius=5000&keyword=masjid&key=$apiKey'),
      Uri.parse(
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$latitude,$longitude&radius=5000&keyword=islam&key=$apiKey'),
    ];

    final responses = await Future.wait(uris.map(http.get));

    List<Map<String, dynamic>> mosqueList = [];

    for (var response in responses) {
      if (response.statusCode != 200) continue;
      final data = jsonDecode(response.body);
      final List results = data['results'];

      for (var result in results) {
        final placeId = result['place_id'];
        if (mosqueList.any((m) => m['place_id'] == placeId)) continue;

        final lat = result['geometry']['location']['lat'] as double;
        final lng = result['geometry']['location']['lng'] as double;
        final name = result['name'] as String;
        final distance =
            Geolocator.distanceBetween(latitude, longitude, lat, lng) / 1000;

        mosqueList.add({
          'place_id': placeId,
          'name': name,
          'lat': lat,
          'lng': lng,
          'distance': distance,
        });
      }
    }

    mosqueList.sort(
        (a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

    setState(() {
      _mosques = mosqueList;
      _isLoading = false;
    });
  }

  // ── Date normalisation ──────────────────────────────────────────────────────
  /// Converts DD/MM/YYYY (from PhotoUpload rows) to yyyy-MM-dd for Firestore.
  String _normaliseDate(String raw) {
    raw = raw.trim();

    // Already ISO
    if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(raw)) {
      return raw.substring(0, 10);
    }

    // DD/MM/YYYY
    final ukMatch = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(raw);
    if (ukMatch != null) {
      final day = int.parse(ukMatch.group(1)!);
      final month = int.parse(ukMatch.group(2)!);
      final year = int.parse(ukMatch.group(3)!);
      return DateTime(year, month, day).toIso8601String().substring(0, 10);
    }

    throw Exception('Invalid date format: $raw');
  }

  // ── Delete existing prayerTimes subcollection ────────────────────────────────
  Future<void> _deleteExistingPrayerTimes(
      FirebaseFirestore firestore, String mosqueId) async {
    final snapshot = await firestore
        .collection('mosques')
        .doc(mosqueId)
        .collection('prayerTimes')
        .get();

    // Delete in batches of 400
    WriteBatch batch = firestore.batch();
    int count = 0;
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
      count++;
      if (count == 400) {
        await batch.commit();
        batch = firestore.batch();
        count = 0;
      }
    }
    if (count > 0) await batch.commit();
  }

  // ── Upload rows to Firestore ─────────────────────────────────────────────────
  /// [rows] comes back from PhotoUploadPage — each row is:
  /// [0]=date(DD/MM/YYYY), [1]=day, [2]=fajrB, [3]=fajrJ, [4]=sunrise,
  /// [5]=dhuhrB, [6]=dhuhrJ, [7]=asrB, [8]=asrJ, [9]=maghrib,
  /// [10]=ishaB, [11]=ishaJ
  Future<void> _uploadRowsToFirestore(List<List<String>> rows) async {
    if (selectedMosqueLat == null || selectedMosqueLng == null) {
      throw Exception('No mosque selected');
    }

    final mosqueName = _mosqueController.text.trim();
    final city = _cityController.text.trim();

    if (mosqueName.isEmpty || city.isEmpty) {
      throw Exception('Mosque name and city are required');
    }

    final mosqueId = '${city}_$mosqueName';
    final firestore = FirebaseFirestore.instance;

    // Update mosque document
    await firestore.collection('mosques').doc(mosqueId).set({
      'name': mosqueName,
      'city': city,
      'Area': adminAreaLevel2,
      'lat': selectedMosqueLat,
      'long': selectedMosqueLng,
      'location': GeoPoint(selectedMosqueLat!, selectedMosqueLng!),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Write new docs — existing dates are overwritten, other months are untouched
    WriteBatch batch = firestore.batch();
    int batchCount = 0;

    for (final row in rows) {
      if (row.length < 12) continue;

      final dateId = _normaliseDate(row[0]);

      final docRef = firestore
          .collection('mosques')
          .doc(mosqueId)
          .collection('prayerTimes')
          .doc(dateId);

      // Jummah times are appended at [12]..[15] for Friday rows only
      final List<String> jummahTimes = [];
      if (row.length > 12) {
        for (int j = 12; j <= 15 && j < row.length; j++) {
          if (row[j].isNotEmpty) jummahTimes.add(row[j]);
        }
      }

      final Map<String, dynamic> data = {
        'fajrB': row[2], // Fajr Begin
        'fajrJ': row[3], // Fajr Jamaat
        'sunrise': row[4], // Sunrise
        'dhuhrB': row[5], // Dhuhr Begin
        'dhuhrJ': row[6], // Dhuhr Jamaat
        'asrB': row[7], // Asr Begin
        'asrJ': row[8], // Asr Jamaat
        'maghrib': row[9], // Maghrib
        'ishaB': row[10], // Isha Begin
        'ishaJ': row[11], // Isha Jamaat
      };

      if (jummahTimes.isNotEmpty) {
        data['jummahTimes'] = jummahTimes;
      }

      batch.set(docRef, data);

      batchCount++;
      if (batchCount == 400) {
        await batch.commit();
        batch = firestore.batch();
        batchCount = 0;
      }
    }

    if (batchCount > 0) await batch.commit();
  }

  // ── Main flow: mosque tapped → PhotoUpload → confirm → upload ──────────────
  Future<void> _openScannerAndUpload(
      BuildContext context, Map<String, dynamic> mosque) async {
    // Set selected mosque details
    setState(() {
      _mosqueController.text = mosque['name'];
      selectedMosqueLat = mosque['lat'];
      selectedMosqueLng = mosque['lng'];
    });

    if (await isConnected()) {
      await _updateCityFromCoordinates(mosque['lat'], mosque['lng']);
    }

    final mosqueName = _mosqueController.text.trim();
    final city = _cityController.text.trim();
    final mosqueId = '${city}_$mosqueName';

    if (!context.mounted) return;

    // Navigate to PhotoUpload; wait for filled rows to come back
    final List<List<String>>? scannedRows = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoUploadPage(
          mosqueName: mosqueName,
          mosqueId: mosqueId,
          city: city,
        ),
      ),
    );

    // User pressed back without completing
    if (scannedRows == null || scannedRows.isEmpty) return;
    if (!context.mounted) return;

    // Confirm dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Upload'),
        content: Text(
          'Mosque: $mosqueName\n'
          'City: $city\n'
          '${scannedRows.length} days scanned\n\n'
          'New days will be added and existing days updated. Previous months will not be affected. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Upload'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Upload
    setState(() {
      _isUploading = true;
      _status = 'Uploading to database...';
    });

    try {
      await _uploadRowsToFirestore(scannedRows);
      setState(() {
        _status = '✅ Upload successful';
        _isUploading = false;
      });

      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Upload Successful'),
          content:
              Text('Timetable for $mosqueName in $city uploaded successfully.\n'
                  '${scannedRows.length} days written to database.'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
        _isUploading = false;
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  // ── Place text search ───────────────────────────────────────────────────────
  Future<void> _searchPlaceByText(String query) async {
    if (query.trim().isEmpty) return;
    final String apiKey = await ApiKeys.getMapsKey();
    final url =
        'https://maps.googleapis.com/maps/api/place/textsearch/json?query=${Uri.encodeComponent(query)}&key=$apiKey';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return;
      final results = jsonDecode(response.body)['results'] as List? ?? [];
      final List<Map<String, dynamic>> found = [];
      for (final r in results.take(10)) {
        final lat = r['geometry']['location']['lat'] as double;
        final lng = r['geometry']['location']['lng'] as double;
        found.add({
          'place_id': r['place_id'],
          'name': r['name'] as String,
          'lat': lat,
          'lng': lng,
          'distance': 0.0,
          'address': r['formatted_address'] ?? '',
        });
      }
      if (mounted) setState(() => _textSearchResults = found);
    } catch (e) {
      debugPrint('Text search error: $e');
    }
  }

  void _showPlaceSearchSheet() {
    final TextEditingController sheetController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color.fromARGB(255, 18, 42, 95),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 14),
              TextField(
                controller: sheetController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g. "Masjid Noor Bolton" or "34 Church Street"',
                  hintStyle:
                      const TextStyle(color: Colors.white38, fontSize: 13),
                  filled: true,
                  fillColor: const Color.fromARGB(255, 10, 25, 60),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded,
                        color: Color.fromARGB(255, 212, 175, 95)),
                    onPressed: () async {
                      setState(() => _textSearchResults = []);
                      await _searchPlaceByText(sheetController.text);
                      setSheet(() {});
                    },
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
                onSubmitted: (val) async {
                  setState(() => _textSearchResults = []);
                  await _searchPlaceByText(val);
                  setSheet(() {});
                },
              ),
              const SizedBox(height: 10),
              if (_textSearchResults.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _textSearchResults.length,
                    itemBuilder: (ctx, i) {
                      final place = _textSearchResults[i];
                      return ListTile(
                        leading: const Icon(Icons.place_outlined,
                            color: Color.fromARGB(255, 212, 175, 95)),
                        title: Text(place['name'],
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(place['address'],
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 11)),
                        onTap: () {
                          Navigator.pop(ctx);
                          if (!_mosques
                              .any((m) => m['place_id'] == place['place_id'])) {
                            setState(() => _mosques.insert(0, place));
                          }
                          _openScannerAndUpload(context, place);
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 10, 25, 60),
      appBar: buildAppBar(
        context,
        'Upload Mosque Times',
        const MoreOptionsScreen(),
        screenFrom,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color.fromARGB(255, 212, 175, 95),
        foregroundColor: const Color.fromARGB(255, 10, 25, 60),
        icon: const Icon(Icons.search_rounded),
        label: const Text('Search by name/address',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        onPressed: () => _showPlaceSearchSheet(),
      ),
      body: Column(
        children: [
          // Status bar
          if (_status.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: _status.startsWith('✅')
                  ? const Color.fromARGB(255, 20, 80, 50)
                  : _status.startsWith('❌')
                      ? const Color.fromARGB(255, 100, 20, 20)
                      : const Color.fromARGB(255, 18, 42, 95),
              child: Text(_status,
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),

          if (_isUploading)
            const LinearProgressIndicator(
              backgroundColor: Color.fromARGB(255, 18, 42, 95),
              valueColor: AlwaysStoppedAnimation<Color>(
                  Color.fromARGB(255, 212, 175, 95)),
            ),

          // City search
          Padding(
            padding: const EdgeInsets.all(10),
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
                            setState(() {
                              _citySuggestions.clear();
                              _isLoading = true;
                              _mosques.clear();
                            });
                            final latLng =
                                await _getLatLngFromPlaceId(city['place_id']);
                            await _fetchNearbyMosques(
                                latLng.latitude, latLng.longitude);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Mosque list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _mosques.isEmpty
                    ? const Center(
                        child: Text('No mosques found nearby',
                            style: TextStyle(color: Colors.white70)))
                    : ListView.builder(
                        itemCount: _mosques.length,
                        itemBuilder: (context, index) {
                          final mosque = _mosques[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 5, horizontal: 10),
                            child: ElevatedButton(
                              onPressed: _isUploading
                                  ? null
                                  : () =>
                                      _openScannerAndUpload(context, mosque),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color.fromARGB(255, 18, 42, 95),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14, horizontal: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.mosque_outlined,
                                      size: 18,
                                      color: Color.fromARGB(255, 212, 175, 95)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      mosque['name'],
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Text(
                                    '${(mosque['distance'] as double).toStringAsFixed(2)} km',
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
