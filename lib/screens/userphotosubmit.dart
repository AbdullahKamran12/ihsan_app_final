import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ihsan_app_final/sharedWidgets.dart';
import 'package:ihsan_app_final/screens/moreoptionsScreen.dart';
import 'package:ihsan_app_final/screens/prayerTimesClass.dart';
import 'package:intl/intl.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _navy = Color.fromARGB(255, 10, 25, 60);
const Color _navyMid = Color.fromARGB(255, 18, 42, 95);
const Color _gold = Color.fromARGB(255, 212, 175, 95);
const Color _white = Colors.white;

// ─────────────────────────────────────────────────────────────────────────────
// Step 1 — Mosque picker
// ─────────────────────────────────────────────────────────────────────────────
class UserMosquePickerPage extends StatefulWidget {
  const UserMosquePickerPage({super.key});

  @override
  State<UserMosquePickerPage> createState() => _UserMosquePickerPageState();
}

class _UserMosquePickerPageState extends State<UserMosquePickerPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _mosques = [];
  String _cityName = '';

  final TextEditingController _searchCityController = TextEditingController();
  List<Map<String, dynamic>> _citySuggestions = [];
  Timer? _debounceTimer;
  List<Map<String, dynamic>> _textSearchResults = [];

  static const String _apiKey = 'AIzaSyBgsjMh_ojTBOMxLkSk5NSNYO7qSogbjdw';

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _searchCityController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    if (!context.mounted) return;
    if (!await isConnected()) {
      setState(() => _isLoading = false);
      return;
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _isLoading = false);
      return;
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) {
        setState(() => _isLoading = false);
        return;
      }
    }
    if (perm == LocationPermission.deniedForever) {
      setState(() => _isLoading = false);
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    _cityName = await _getCityFromCoordinates(pos.latitude, pos.longitude);
    await _fetchNearbyMosques(pos.latitude, pos.longitude);
  }

  Future<String> _getCityFromCoordinates(double lat, double lng) async {
    final url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_apiKey';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final compound = data['plus_code']?['compound_code'];
        if (compound != null) {
          final parts = (compound as String).split(' ');
          if (parts.length >= 2)
            return parts.sublist(1).join(' ').replaceAll(', UK', '').trim();
        }
        if (data['results'] != null && (data['results'] as List).isNotEmpty) {
          for (var result in data['results']) {
            for (var component in result['address_components']) {
              final types = List<String>.from(component['types']);
              if (types.contains('postal_town') ||
                  types.contains('locality') ||
                  types.contains('administrative_area_level_2')) {
                return component['long_name'];
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Geocode error: $e');
    }
    return '';
  }

  Future<void> _fetchNearbyMosques(double lat, double lng) async {
    final uris = [
      Uri.parse(
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng&radius=5000&type=mosque&key=$_apiKey'),
      Uri.parse(
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng&radius=5000&keyword=masjid&key=$_apiKey'),
      Uri.parse(
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng&radius=5000&keyword=islam&key=$_apiKey'),
    ];

    final responses = await Future.wait(uris.map(http.get));
    final List<Map<String, dynamic>> list = [];
    final Set<String> seen = {};

    for (final response in responses) {
      if (response.statusCode != 200) continue;
      final results = jsonDecode(response.body)['results'] as List;
      for (final r in results) {
        final placeId = r['place_id'] as String;
        if (seen.contains(placeId)) continue;
        seen.add(placeId);
        final rLat = r['geometry']['location']['lat'] as double;
        final rLng = r['geometry']['location']['lng'] as double;
        list.add({
          'place_id': placeId,
          'name': r['name'] as String,
          'lat': rLat,
          'lng': rLng,
          'distance': Geolocator.distanceBetween(lat, lng, rLat, rLng) / 1000,
        });
      }
    }

    list.sort(
        (a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
    setState(() {
      _mosques = list;
      _isLoading = false;
    });
  }

  Future<void> _getCitySuggestions(String input) async {
    if (input.isEmpty) {
      setState(() => _citySuggestions.clear());
      return;
    }
    final url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&types=(cities)&key=$_apiKey';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return;
      final predictions =
          jsonDecode(response.body)['predictions'] as List? ?? [];
      setState(() {
        _citySuggestions = predictions
            .take(8)
            .map<Map<String, dynamic>>((p) => {
                  'name': p['structured_formatting']?['main_text'] ??
                      p['description'].split(',').first,
                  'place_id': p['place_id'],
                  'description': p['description'],
                })
            .toList();
      });
    } catch (e) {
      debugPrint('Autocomplete error: $e');
    }
  }

  Future<Map<String, double>> _getLatLngFromPlaceId(String placeId) async {
    final url =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry&key=$_apiKey';
    final response = await http.get(Uri.parse(url));
    final location =
        jsonDecode(response.body)['result']['geometry']['location'];
    return {'lat': location['lat'], 'lng': location['lng']};
  }

  void _onMosqueTapped(Map<String, dynamic> mosque) {
    final mosqueName = mosque['name'] as String;
    final mosqueId = '${_cityName}_$mosqueName';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserPhotoSubmitPage(
          mosqueName: mosqueName,
          mosqueId: mosqueId,
          city: _cityName,
        ),
      ),
    );
  }

  // ── Place text search ─────────────────────────────────────────────────────
  Future<void> _searchPlaceByText(String query) async {
    if (query.trim().isEmpty) return;
    final url =
        'https://maps.googleapis.com/maps/api/place/textsearch/json?query=${Uri.encodeComponent(query)}&key=$_apiKey';
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
      backgroundColor: _navyMid,
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
                style: const TextStyle(color: _white),
                decoration: InputDecoration(
                  hintText: 'e.g. "Masjid Noor Bolton" or "34 Church Street"',
                  hintStyle:
                      const TextStyle(color: Colors.white38, fontSize: 13),
                  filled: true,
                  fillColor: _navy,
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded, color: _gold),
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
                        leading: const Icon(Icons.place_outlined, color: _gold),
                        title: Text(place['name'],
                            style: const TextStyle(
                                color: _white,
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
                          _onMosqueTapped(place);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      appBar: buildAppBar(context, 'Submit Timetable Photo',
          const MoreOptionsScreen(), screenFrom),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _gold,
        foregroundColor: _navy,
        icon: const Icon(Icons.search_rounded),
        label: const Text('Search by name/address',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        onPressed: () => _showPlaceSearchSheet(),
      ),
      body: Column(
        children: [
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
                    fillColor: _white,
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
                        color: _white, borderRadius: BorderRadius.circular(12)),
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
                            _cityName = city['name'];
                            await _fetchNearbyMosques(
                                latLng['lat']!, latLng['lng']!);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _gold))
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
                              onPressed: () => _onMosqueTapped(mosque),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _navyMid,
                                foregroundColor: _white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14, horizontal: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.mosque_outlined,
                                      size: 18, color: _gold),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(mosque['name'],
                                        style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600)),
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

// ─────────────────────────────────────────────────────────────────────────────
// Step 2 — Photo capture & upload
// ─────────────────────────────────────────────────────────────────────────────
class UserPhotoSubmitPage extends StatefulWidget {
  final String mosqueName;
  final String mosqueId;
  final String city;

  const UserPhotoSubmitPage({
    super.key,
    required this.mosqueName,
    required this.mosqueId,
    required this.city,
  });

  @override
  State<UserPhotoSubmitPage> createState() => _UserPhotoSubmitPageState();
}

class _UserPhotoSubmitPageState extends State<UserPhotoSubmitPage> {
  File? _photo;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickPhoto(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission is required to take a photo'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 95);
      if (picked != null) setState(() => _photo = File(picked.path));
    } catch (e) {
      debugPrint('Image picker error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open image picker: $e')),
      );
    }
  }

  Future<void> _uploadPhoto() async {
    if (_photo == null) return;
    setState(() => _isUploading = true);

    try {
      final now = DateTime.now();
      final month = DateFormat('MMMM').format(now);
      final year = now.year.toString();

      // Flat storage path — all submissions in one folder, easy to browse
      final fileName = '${widget.mosqueId}_${month}_$year.jpg';
      final storagePath = 'mosque_submissions/$fileName';

      // 1 — Upload photo to Storage
      final ref = FirebaseStorage.instance.ref().child(storagePath);
      await ref.putFile(_photo!);

      // 2 — Log to Firestore mosque_submissions collection
      //     In Firebase console: go to mosque_submissions → sort by submittedAt desc
      //     to see latest uploads with mosque name, city, user and storage path
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('mosque_submissions').add({
        'mosqueName': widget.mosqueName,
        'mosqueId': widget.mosqueId,
        'city': widget.city,
        'userId': user?.uid ?? 'unknown',
        'storagePath': storagePath,
        'fileName': fileName,
        'submittedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => _isUploading = false);

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  color: Color.fromARGB(255, 72, 200, 155), size: 24),
              SizedBox(width: 10),
              Text('Submitted!', style: TextStyle(fontSize: 17)),
            ],
          ),
          content: Text(
            'Your timetable photo for ${widget.mosqueName} has been submitted successfully.\n\n'
            'It will be reviewed and uploaded shortly. JazakAllah Khayran 🤲',
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _navy),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Done', style: TextStyle(color: _gold)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      appBar: buildAppBar(
          context, 'Submit Timetable', const MoreOptionsScreen(), screenFrom),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Mosque info ──────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _navyMid,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _gold.withOpacity(0.4), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mosque_outlined, color: _gold, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.mosqueName,
                            style: const TextStyle(
                                color: _white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                        Text(widget.city,
                            style: TextStyle(
                                color: _white.withOpacity(0.55), fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Photo guidelines ─────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:
                    const Color.fromARGB(255, 140, 100, 20).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _gold.withOpacity(0.5), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: _gold, size: 18),
                      SizedBox(width: 8),
                      Text('Photo Requirements',
                          style: TextStyle(
                              color: _gold,
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...[
                    '📄  Capture the entire timetable page — no cropping whatsoever',
                    '💡  Good lighting only — no shadows, glare or blur',
                    '📐  Hold camera straight above the page — no angles',
                    '🕌  Jumu\'ah times must be fully visible if printed',
                    '🔍  Every time, column and header must be clearly readable',
                    '📅  Month and year of the timetable must be visible',
                  ].map((tip) => Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Text(tip,
                            style: const TextStyle(
                                color: _white, fontSize: 13, height: 1.4)),
                      )),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.4)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.cancel_outlined,
                            color: Colors.redAccent, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Blurry, dark, angled or partial photos will be rejected '
                            'and times cannot be entered. Please retake if you are unsure.',
                            style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Photo preview + actions ──────────────────────────────────────
            if (_photo != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(
                  _photo!,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      icon: Icons.camera_alt_outlined,
                      label: 'Retake',
                      onTap: () => _pickPhoto(ImageSource.camera),
                      outlined: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _actionButton(
                      icon: Icons.photo_library_outlined,
                      label: 'Gallery',
                      onTap: () => _pickPhoto(ImageSource.gallery),
                      outlined: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _isUploading ? null : _uploadPhoto,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: _isUploading ? _navyMid : _navy,
                    borderRadius: BorderRadius.circular(13),
                    border:
                        Border.all(color: _gold.withOpacity(0.7), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: _navy.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: _isUploading
                      ? const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: _gold, strokeWidth: 2.5),
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_upload_outlined,
                                color: _gold, size: 20),
                            SizedBox(width: 8),
                            Text('Submit Timetable',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: _gold,
                                    letterSpacing: 0.3)),
                          ],
                        ),
                ),
              ),
            ] else ...[
              _actionButton(
                icon: Icons.camera_alt_outlined,
                label: 'Take Photo',
                onTap: () => _pickPhoto(ImageSource.camera),
              ),
              const SizedBox(height: 10),
              _actionButton(
                icon: Icons.photo_library_outlined,
                label: 'Choose from Gallery',
                onTap: () => _pickPhoto(ImageSource.gallery),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool outlined = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : _navyMid,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: outlined ? _gold.withOpacity(0.4) : _gold.withOpacity(0.6),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _gold, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: outlined ? _gold.withOpacity(0.8) : _white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
