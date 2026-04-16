import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ihsan_app_final/screens/mosqueDisplayScreen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WebUploadMosque  —  admin-only, web only
// Uses bytes (not File.path) for CSV reading — required on Flutter Web.
// ─────────────────────────────────────────────────────────────────────────────

class WebUploadMosque extends StatefulWidget {
  const WebUploadMosque({super.key});
  @override
  State<WebUploadMosque> createState() => _WebUploadMosqueState();
}

class _WebUploadMosqueState extends State<WebUploadMosque> {
  // ── Palette ───────────────────────────────────────────────────────
  static const Color navy = Color.fromARGB(255, 10, 25, 60);
  static const Color navyMid = Color.fromARGB(255, 18, 42, 95);
  static const Color navyLight = Color.fromARGB(255, 28, 58, 120);
  static const Color gold = Color.fromARGB(255, 212, 175, 95);
  static const Color mintGreen = Color.fromARGB(255, 72, 200, 155);
  static const Color skyBlue = Color.fromARGB(255, 100, 180, 240);
  static const Color white = Color.fromARGB(255, 255, 255, 255);
  static const Color offWhite = Color.fromARGB(255, 247, 249, 255);
  static const Color textDark = Color.fromARGB(255, 15, 30, 65);
  static const Color textMid = Color.fromARGB(255, 90, 115, 160);
  static const Color borderCol = Color.fromARGB(255, 210, 220, 240);
  static const String _apiKey = 'AIzaSyBxRyh6L7yPp8YkStN3q9dnUJK0N6rp71I';

  // ── Controllers ───────────────────────────────────────────────────
  final TextEditingController _searchCityCtrl = TextEditingController();
  final TextEditingController _mosqueCtrl =
      TextEditingController(text: 'Masjid-e-Ibrahim');
  final TextEditingController _cityCtrl = TextEditingController();

  // ── State ─────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _citySuggestions = [];
  List<Map<String, dynamic>> _mosques = [];
  Timer? _debounce;

  bool _isLoadingMosques = false;
  bool _isUploading = false;
  bool _isSearching = false;
  String _status = '';

  double? _selectedLat;
  double? _selectedLng;
  String _adminAreaLevel2 = '';

  late final Future<bool> _adminFuture;

  @override
  void initState() {
    super.initState();
    _adminFuture = _checkAdmin();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCityCtrl.dispose();
    _mosqueCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════
  // ADMIN CHECK
  // ══════════════════════════════════════════════════════════════════
  Future<bool> _checkAdmin() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final doc = await FirebaseFirestore.instance
          .collection('Admins')
          .doc(user.uid)
          .get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // CITY SEARCH
  // ══════════════════════════════════════════════════════════════════
  Future<void> _getCitySuggestions(String input) async {
    if (input.trim().isEmpty) {
      setState(() {
        _citySuggestions.clear();
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    final url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(input)}&types=(cities)&key=$_apiKey';
    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) {
        setState(() => _isSearching = false);
        return;
      }
      final predictions = (jsonDecode(resp.body)['predictions'] as List? ?? []);
      setState(() {
        _citySuggestions = predictions
            .take(8)
            .map<Map<String, dynamic>>((p) => {
                  'name': p['structured_formatting']?['main_text'] ??
                      (p['description'] as String).split(',').first,
                  'place_id': p['place_id'],
                  'description': p['description'],
                })
            .toList();
        _isSearching = false;
      });
    } catch (_) {
      setState(() => _isSearching = false);
    }
  }

  Future<Map<String, double>> _getLatLngFromPlaceId(String placeId) async {
    final url = 'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId&fields=geometry&key=$_apiKey';
    final resp = await http.get(Uri.parse(url));
    final loc = jsonDecode(resp.body)['result']['geometry']['location'];
    return {
      'lat': (loc['lat'] as num).toDouble(),
      'lng': (loc['lng'] as num).toDouble()
    };
  }

  // ══════════════════════════════════════════════════════════════════
  // NEARBY MOSQUES
  // ══════════════════════════════════════════════════════════════════
  Future<void> _fetchNearbyMosques(double lat, double lng) async {
    setState(() {
      _isLoadingMosques = true;
      _mosques = [];
    });
    final uris = [
      Uri.parse(
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng&radius=5000&type=mosque&key=$_apiKey'),
      Uri.parse(
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng&radius=5000&keyword=masjid&key=$_apiKey'),
      Uri.parse(
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng&radius=5000&keyword=islam&key=$_apiKey'),
    ];
    final responses = await Future.wait(uris.map(http.get));
    final mosqueList = <Map<String, dynamic>>[];
    for (final resp in responses) {
      if (resp.statusCode != 200) continue;
      for (final r in (jsonDecode(resp.body)['results'] as List)) {
        final pid = r['place_id'] as String;
        if (mosqueList.any((m) => m['place_id'] == pid)) continue;
        mosqueList.add({
          'place_id': pid,
          'name': r['name'] as String,
          'lat': (r['geometry']['location']['lat'] as num).toDouble(),
          'lng': (r['geometry']['location']['lng'] as num).toDouble(),
        });
      }
    }
    mosqueList
        .sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    setState(() {
      _mosques = mosqueList;
      _isLoadingMosques = false;
    });
  }

  // ══════════════════════════════════════════════════════════════════
  // REVERSE GEOCODE
  // ══════════════════════════════════════════════════════════════════
  Future<void> _resolveCityFromLatLng(double lat, double lng) async {
    final url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_apiKey';
    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) return;
      final data = jsonDecode(resp.body);
      final compound = data['plus_code']?['compound_code'] as String?;
      if (compound != null) {
        final parts = compound.split(' ');
        if (parts.length >= 2) {
          _cityCtrl.text =
              parts.sublist(1).join(' ').replaceAll(', UK', '').trim();
          setState(() {});
          return;
        }
      }
      String? foundCity, foundAdmin2;
      for (final result in data['results'] ?? []) {
        for (final comp in result['address_components']) {
          final types = List<String>.from(comp['types']);
          foundAdmin2 ??= types.contains('administrative_area_level_2')
              ? comp['long_name'] as String
              : null;
          foundCity ??= types.contains('postal_town')
              ? comp['long_name'] as String
              : null;
        }
      }
      if (foundCity == null) {
        final first = (data['results'] as List?)?.first;
        if (first != null) {
          for (final comp in first['address_components']) {
            final types = List<String>.from(comp['types']);
            if (types.contains('locality') ||
                types.contains('administrative_area_level_2')) {
              foundCity = comp['long_name'] as String;
              break;
            }
          }
        }
      }
      _adminAreaLevel2 = foundAdmin2 ?? '';
      if (foundCity != null) {
        _cityCtrl.text = foundCity;
        setState(() {});
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // CSV  —  bytes only, no dart:io / File.path (web safe)
  // ══════════════════════════════════════════════════════════════════
  String _normaliseDate(dynamic value) {
    final raw = value.toString().trim();
    if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(raw))
      return raw.substring(0, 10);
    final num? excel = num.tryParse(raw);
    if (excel != null) {
      return DateTime(1899, 12, 30)
          .add(Duration(days: excel.toInt()))
          .toIso8601String()
          .substring(0, 10);
    }
    final uk = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(raw);
    if (uk != null) {
      return DateTime(int.parse(uk.group(3)!), int.parse(uk.group(2)!),
              int.parse(uk.group(1)!))
          .toIso8601String()
          .substring(0, 10);
    }
    throw Exception('Invalid date format: $raw');
  }

  /// Pick a CSV file and return its raw bytes.
  /// withData: true is required on Flutter Web — path is unavailable.
  Future<Uint8List?> _pickCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true, // ← loads bytes into memory instead of returning a path
    );
    if (result == null || result.files.single.bytes == null) return null;
    return result.files.single.bytes!;
  }

  Future<void> _uploadCsvToFirestore(Uint8List csvBytes) async {
    if (_selectedLat == null || _selectedLng == null) {
      throw Exception('Please select a mosque from the list first');
    }
    // Decode bytes → string.  No File.readAsString needed — works on web.
    final content = utf8.decode(csvBytes);
    final rows =
        const CsvToListConverter(shouldParseNumbers: false).convert(content);
    if (rows.isEmpty) throw Exception('CSV is empty');

    final header = rows.first.map((e) => e.toString().trim()).toList();
    const expectedHeader = [
      'Date',
      'Fajr J',
      'Sunrise',
      'Dhuhr J',
      'Asr J',
      'Maghrib J',
      'Isha J'
    ];
    for (int i = 0; i < expectedHeader.length; i++) {
      if (i >= header.length || header[i] != expectedHeader[i]) {
        throw Exception(
            'Invalid CSV headers.\nExpected:\n$expectedHeader\nFound:\n$header');
      }
    }

    final mosqueName = _mosqueCtrl.text.trim();
    final city = _cityCtrl.text.trim();
    if (mosqueName.isEmpty || city.isEmpty)
      throw Exception('Mosque name and city are required');

    final mosqueId = '${city}_$mosqueName';
    final firestore = FirebaseFirestore.instance;

    await firestore.collection('mosques').doc(mosqueId).set({
      'name': mosqueName,
      'city': city,
      'Area': _adminAreaLevel2,
      'lat': _selectedLat,
      'long': _selectedLng,
      'location': GeoPoint(_selectedLat!, _selectedLng!),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    WriteBatch batch = firestore.batch();
    int batchCount = 0;
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 7) continue;
      final docRef = firestore
          .collection('mosques')
          .doc(mosqueId)
          .collection('prayerTimes')
          .doc(_normaliseDate(row[0]));
      batch.set(docRef, {
        'fajrJ': row[1].toString(),
        'sunrise': row[2].toString(),
        'dhuhrJ': row[3].toString(),
        'asrJ': row[4].toString(),
        'maghrib': row[5].toString(),
        'ishaJ': row[6].toString(),
      });
      if (++batchCount == 400) {
        await batch.commit();
        batch = firestore.batch();
        batchCount = 0;
      }
    }
    if (batchCount > 0) await batch.commit();
  }

  Future<void> _confirmAndUpload() async {
    final mosqueName = _mosqueCtrl.text.trim();
    final city = _cityCtrl.text.trim();
    if (mosqueName.isEmpty || city.isEmpty || _selectedLat == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a mosque from the list first'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final Uint8List? csvBytes = await _pickCsv();
    if (csvBytes == null) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: navyMid,
        title: const Text('Confirm Upload',
            style: TextStyle(color: gold, fontWeight: FontWeight.w700)),
        content: Text(
            'Mosque: $mosqueName\nCity: $city\n\nUpload this timetable?',
            style: TextStyle(color: white.withOpacity(0.85))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                Text('Cancel', style: TextStyle(color: white.withOpacity(0.5))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: gold),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Upload',
                style: TextStyle(color: navy, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _isUploading = true;
      _status = 'Uploading…';
    });
    try {
      await _uploadCsvToFirestore(csvBytes);
      setState(() {
        _status = '✅ Upload successful';
        _isUploading = false;
      });
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: navyMid,
          title: const Text('Upload Successful',
              style: TextStyle(color: mintGreen, fontWeight: FontWeight.w700)),
          content: Text(
            'The timetable for $mosqueName in $city has been uploaded successfully.',
            style: TextStyle(color: white.withOpacity(0.85)),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: gold),
              onPressed: () => Navigator.pop(context),
              child: const Text('OK',
                  style: TextStyle(color: navy, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MosqueDisplayScreen()),
      );
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
        _isUploading = false;
      });
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navy,
      body: FutureBuilder<bool>(
        future: _adminFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator(color: gold));
          if (snap.data != true) return _buildAccessDenied();
          return _buildUploadUI();
        },
      ),
    );
  }

  Widget _buildAccessDenied() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.lock_outline_rounded,
              color: gold.withOpacity(0.4), size: 52),
          const SizedBox(height: 16),
          const Text('Access Denied',
              style: TextStyle(
                  color: gold, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Only admins can upload mosque timetables.',
              style: TextStyle(color: white.withOpacity(0.4), fontSize: 13)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const MosqueDisplayScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              decoration: BoxDecoration(
                color: navyMid,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: gold.withOpacity(0.4), width: 1),
              ),
              child: const Text('Go Back',
                  style: TextStyle(
                      color: gold, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      );

  Widget _buildUploadUI() {
    return Column(children: [
      // ── Header ────────────────────────────────────────────────────
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 36, 16, 10),
        color: navyMid,
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const MosqueDisplayScreen())),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: navyLight,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: gold.withOpacity(0.35), width: 1),
              ),
              child:
                  const Icon(Icons.arrow_back_rounded, color: gold, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Upload Mosque Times',
                  style: TextStyle(
                      color: gold,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3)),
              Text('Admin only',
                  style: TextStyle(
                      color: Color.fromARGB(100, 255, 255, 255),
                      fontSize: 10,
                      letterSpacing: 0.5)),
            ]),
          ),
          // Status chip
          if (_status.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _status.startsWith('✅')
                    ? mintGreen.withOpacity(0.15)
                    : _status.startsWith('❌')
                        ? Colors.red.withOpacity(0.15)
                        : navyLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _status.startsWith('✅')
                      ? mintGreen.withOpacity(0.5)
                      : _status.startsWith('❌')
                          ? Colors.red.withOpacity(0.4)
                          : gold.withOpacity(0.2),
                ),
              ),
              child: Text(
                _status,
                style: TextStyle(
                  color: _status.startsWith('✅')
                      ? mintGreen
                      : _status.startsWith('❌')
                          ? Colors.red[300]
                          : gold,
                  fontSize: 11,
                ),
              ),
            ),
        ]),
      ),

      // ── Body ──────────────────────────────────────────────────────
      Expanded(
        child: LayoutBuilder(
          builder: (context, c) =>
              c.maxWidth > 700 ? _buildWideLayout() : _buildNarrowLayout(),
        ),
      ),
    ]);
  }

  // ── Wide: city search + details left, mosque list right ──────────
  Widget _buildWideLayout() {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 280,
        child: Column(children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCitySearchSection(),
                    const SizedBox(height: 10),
                    if (_selectedLat != null) ...[
                      _buildSelectedCard(),
                      const SizedBox(height: 10)
                    ],
                    _buildMosqueNameField(),
                    const SizedBox(height: 8),
                    _buildCityField(),
                  ]),
            ),
          ),
          Padding(
              padding: const EdgeInsets.all(12), child: _buildUploadButton()),
        ]),
      ),
      Container(width: 1, color: gold.withOpacity(0.18)),
      Expanded(child: _buildMosqueListPanel()),
    ]);
  }

  // ── Narrow: stacked ──────────────────────────────────────────────
  Widget _buildNarrowLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildCitySearchSection(),
        const SizedBox(height: 12),
        SizedBox(height: 300, child: _buildMosqueListPanel()),
        const SizedBox(height: 12),
        if (_selectedLat != null) ...[
          _buildSelectedCard(),
          const SizedBox(height: 12)
        ],
        _buildMosqueNameField(),
        const SizedBox(height: 8),
        _buildCityField(),
        const SizedBox(height: 14),
        _buildUploadButton(),
        const SizedBox(height: 16),
      ]),
    );
  }

  // ── City search field + gold search button + suggestions ─────────
  Widget _buildCitySearchSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('SEARCH CITY'),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: navyLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: gold.withOpacity(0.35), width: 1),
        ),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _searchCityCtrl,
              style: const TextStyle(color: white, fontSize: 14),
              cursorColor: gold,
              decoration: InputDecoration(
                hintText: 'e.g. Bolton, Manchester…',
                hintStyle:
                    TextStyle(color: white.withOpacity(0.3), fontSize: 13),
                prefixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(11),
                        child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: gold)))
                    : Icon(Icons.location_city_rounded,
                        color: gold.withOpacity(0.6), size: 18),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
              ),
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 500),
                  () => _getCitySuggestions(v),
                );
              },
              onSubmitted: (_) => _getCitySuggestions(_searchCityCtrl.text),
            ),
          ),
          // ── Search button ──────────────────────────────────────
          GestureDetector(
            onTap: () {
              _debounce?.cancel();
              _getCitySuggestions(_searchCityCtrl.text);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: gold,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(11),
                  bottomRight: Radius.circular(11),
                ),
              ),
              child: const Icon(Icons.search_rounded, color: navy, size: 18),
            ),
          ),
        ]),
      ),

      // Suggestions dropdown
      if (_citySuggestions.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 4),
          constraints: const BoxConstraints(maxHeight: 240),
          decoration: BoxDecoration(
            color: navyLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: gold.withOpacity(0.25), width: 1),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: _citySuggestions.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: white.withOpacity(0.07)),
            itemBuilder: (context, i) {
              final city = _citySuggestions[i];
              return ListTile(
                dense: true,
                leading: Icon(Icons.location_on_outlined,
                    size: 15, color: gold.withOpacity(0.6)),
                title: Text(city['name'],
                    style: const TextStyle(color: white, fontSize: 13)),
                subtitle: Text(city['description'],
                    style: TextStyle(
                        color: white.withOpacity(0.35), fontSize: 11)),
                onTap: () async {
                  FocusScope.of(context).unfocus();
                  _searchCityCtrl.text = city['name'];
                  setState(() {
                    _citySuggestions.clear();
                    _isLoadingMosques = true;
                    _mosques = [];
                  });
                  final latLng = await _getLatLngFromPlaceId(city['place_id']);
                  await _fetchNearbyMosques(latLng['lat']!, latLng['lng']!);
                },
              );
            },
          ),
        ),
    ]);
  }

  // ── Mosque list ───────────────────────────────────────────────────
  Widget _buildMosqueListPanel() {
    if (_isLoadingMosques) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
            child: CircularProgressIndicator(color: gold, strokeWidth: 2)),
      );
    }
    if (_mosques.isEmpty && _searchCityCtrl.text.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(children: [
          Icon(Icons.search_rounded, color: white.withOpacity(0.1), size: 40),
          const SizedBox(height: 12),
          Text('Search a city above to see nearby mosques',
              textAlign: TextAlign.center,
              style: TextStyle(color: white.withOpacity(0.3), fontSize: 13)),
        ]),
      );
    }
    if (_mosques.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(children: [
          Icon(Icons.mosque_outlined, color: white.withOpacity(0.1), size: 40),
          const SizedBox(height: 12),
          Text('No mosques found nearby',
              style: TextStyle(color: white.withOpacity(0.3), fontSize: 13)),
        ]),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      itemCount: _mosques.length + 1,
      separatorBuilder: (_, i) =>
          i == 0 ? const SizedBox(height: 6) : const SizedBox(height: 6),
      itemBuilder: (context, i) {
        if (i == 0)
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: _label('SELECT MOSQUE  (${_mosques.length} found)'),
          );
        final mosque = _mosques[i - 1];
        final isSelected =
            _mosqueCtrl.text == mosque['name'] && _selectedLat == mosque['lat'];
        return GestureDetector(
          onTap: () async {
            setState(() {
              _mosqueCtrl.text = mosque['name'];
              _selectedLat = mosque['lat'];
              _selectedLng = mosque['lng'];
            });
            await _resolveCityFromLatLng(mosque['lat'], mosque['lng']);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: isSelected ? gold.withOpacity(0.12) : navyMid,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? gold.withOpacity(0.65)
                    : white.withOpacity(0.08),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(children: [
              Icon(Icons.mosque_outlined,
                  color: isSelected ? gold : white.withOpacity(0.3), size: 16),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                mosque['name'],
                style: TextStyle(
                  color: isSelected ? gold : white,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              )),
              if (isSelected)
                const Icon(Icons.check_rounded, color: gold, size: 14),
            ]),
          ),
        );
      },
    );
  }

  // ── Selected mosque summary card ──────────────────────────────────
  Widget _buildSelectedCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: navyLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gold.withOpacity(0.45), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                  color: mintGreen, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          const Text('SELECTED',
              style: TextStyle(
                  color: mintGreen,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
        ]),
        const SizedBox(height: 5),
        Text(_mosqueCtrl.text,
            style: const TextStyle(
                color: white, fontSize: 14, fontWeight: FontWeight.w600)),
        if (_cityCtrl.text.isNotEmpty)
          Text(_cityCtrl.text,
              style: TextStyle(color: white.withOpacity(0.45), fontSize: 12)),
      ]),
    );
  }

  // ── Editable mosque name ──────────────────────────────────────────
  Widget _buildMosqueNameField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('MOSQUE NAME'),
      const SizedBox(height: 5),
      Container(
        decoration: BoxDecoration(
          color: navyLight,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: gold.withOpacity(0.3), width: 1),
        ),
        child: TextField(
          controller: _mosqueCtrl,
          style: const TextStyle(color: white, fontSize: 14),
          cursorColor: gold,
          decoration: InputDecoration(
            hintText: 'e.g. Masjid-e-Ibrahim',
            hintStyle: TextStyle(color: white.withOpacity(0.3), fontSize: 13),
            prefixIcon: Icon(Icons.mosque_outlined,
                color: gold.withOpacity(0.5), size: 16),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          ),
        ),
      ),
    ]);
  }

  // ── Editable city ─────────────────────────────────────────────────
  Widget _buildCityField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('CITY'),
      const SizedBox(height: 5),
      Container(
        decoration: BoxDecoration(
          color: navyLight,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: gold.withOpacity(0.3), width: 1),
        ),
        child: TextField(
          controller: _cityCtrl,
          style: const TextStyle(color: white, fontSize: 14),
          cursorColor: gold,
          decoration: InputDecoration(
            hintText: 'Auto-filled when you tap a mosque',
            hintStyle: TextStyle(color: white.withOpacity(0.3), fontSize: 12),
            prefixIcon: Icon(Icons.location_on_outlined,
                color: gold.withOpacity(0.5), size: 16),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          ),
        ),
      ),
    ]);
  }

  // ── Upload button ─────────────────────────────────────────────────
  Widget _buildUploadButton() {
    return GestureDetector(
      onTap: _isUploading ? null : _confirmAndUpload,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _isUploading ? gold.withOpacity(0.4) : gold,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _isUploading
              ? []
              : [
                  BoxShadow(
                      color: gold.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (_isUploading)
            const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: navy))
          else
            const Icon(Icons.upload_rounded, size: 18, color: navy),
          const SizedBox(width: 8),
          Text(
            _isUploading ? 'Uploading…' : 'Pick CSV & Upload',
            style: const TextStyle(
                color: navy, fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ]),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: TextStyle(
          color: gold.withOpacity(0.8),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1));
}
