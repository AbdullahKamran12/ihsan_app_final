import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:ihsan_app_final/screens/moreOptionsScreen.dart';
import 'package:ihsan_app_final/screens/login.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _searchCityController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  // Mosque preference
  String? _selectedMosque;
  List<String> _availableMosques = [];
  bool _isLoadingMosques = false;
  String _currentCity = '';
  List<Map<String, dynamic>> _citySuggestions = [];
  Timer? _debounceTimer;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _usernameController.dispose();
    _searchCityController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final displayName = _displayNameController.text.trim();
      final username = _usernameController.text.trim();

      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null) {
        await _firestore.collection('UserData').doc(user.uid).set({
          'email': user.email,
          'displayName': displayName,
          'mosquePreference': _selectedMosque ?? '',
          'postCount': 0,
          'username': username,
          'createdAt': FieldValue.serverTimestamp(),
        });

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MoreOptionsScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage =
              'This email is already registered. Please login or use another email.';
          break;
        case 'weak-password':
          errorMessage =
              'The password is too weak. Please use a stronger password.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        default:
          errorMessage = 'An error occurred during signup: ${e.message}';
      }
      setState(() {
        _errorMessage = errorMessage;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
        _isLoading = false;
      });
      print(e.toString());
    }
  }

  void login() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  // ── Mosque helpers (same logic as accountsOptionsPage) ──────────────────────

  Future<String> _getCityFromCoordinates(
      double latitude, double longitude) async {
    const String apiKey = 'AIzaSyBgsjMh_ojTBOMxLkSk5NSNYO7qSogbjdw';
    final String url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$latitude,$longitude&key=$apiKey';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final compound = data['plus_code']?['compound_code'];
        if (compound != null) {
          final parts = compound.split(' ');
          if (parts.length >= 2) {
            return parts.sublist(1).join(' ').replaceAll(', UK', '').trim();
          }
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
      debugPrint('Error getting city: $e');
    }
    return '';
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }

  Future<void> _loadNearbyMosques() async {
    setState(() {
      _isLoadingMosques = true;
      _availableMosques = [];
    });

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _isLoadingMosques = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isLoadingMosques = false);
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() => _isLoadingMosques = false);
      return;
    }

    final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    await _fetchMosquesNear(position.latitude, position.longitude);
  }

  Future<void> _fetchMosquesNear(double latitude, double longitude) async {
    _currentCity = await _getCityFromCoordinates(latitude, longitude);
    if (_currentCity.isEmpty) _currentCity = 'Unknown';

    const String apiKey = 'AIzaSyBgsjMh_ojTBOMxLkSk5NSNYO7qSogbjdw';
    final uris = [
      Uri.parse(
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$latitude,$longitude&radius=5000&type=mosque&key=$apiKey'),
      Uri.parse(
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$latitude,$longitude&radius=5000&keyword=masjid&key=$apiKey'),
      Uri.parse(
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$latitude,$longitude&radius=5000&keyword=islam&key=$apiKey'),
    ];

    final responses = await Future.wait(uris.map(http.get));
    final Set<String> seen = {};
    final List<Map<String, dynamic>> results = [];

    for (final response in responses) {
      if (response.statusCode != 200) continue;
      final data = json.decode(response.body);
      for (final result in data['results'] as List) {
        final placeId = result['place_id'] as String;
        if (seen.contains(placeId)) continue;
        seen.add(placeId);
        results.add({
          'name': result['name'] as String,
          'distance': _calculateDistance(
            latitude,
            longitude,
            result['geometry']['location']['lat'],
            result['geometry']['location']['lng'],
          ),
        });
      }
    }

    results.sort(
        (a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

    setState(() {
      _availableMosques = results.map((m) => m['name'] as String).toList();
      _isLoadingMosques = false;
    });
  }

  Future<void> _getCitySuggestions(String input) async {
    if (input.isEmpty) {
      setState(() => _citySuggestions.clear());
      return;
    }
    const String apiKey = 'AIzaSyBgsjMh_ojTBOMxLkSk5NSNYO7qSogbjdw';
    final url = 'https://maps.googleapis.com/maps/api/place/autocomplete.json'
        '?input=$input&types=(cities)&key=$apiKey';
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
    const String apiKey = 'AIzaSyBgsjMh_ojTBOMxLkSk5NSNYO7qSogbjdw';
    final response = await http.get(Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry&key=$apiKey'));
    final location =
        jsonDecode(response.body)['result']['geometry']['location'];
    return {
      'latitude': location['lat'],
      'longitude': location['lng'],
    };
  }

  @override
  Widget build(BuildContext context) {
    // ── Palette ────────────────────────────────────────────────────────
    const Color navy = Color.fromARGB(255, 10, 25, 60);
    const Color navyMid = Color.fromARGB(255, 18, 42, 95);
    const Color gold = Color.fromARGB(255, 212, 175, 95);
    const Color mintGreen = Color.fromARGB(255, 72, 200, 155);
    const Color mintLight = Color.fromARGB(255, 210, 245, 232);
    const Color white = Color.fromARGB(255, 255, 255, 255);
    const Color offWhite = Color.fromARGB(255, 247, 249, 255);
    const Color textDark = Color.fromARGB(255, 15, 30, 65);
    const Color textMid = Color.fromARGB(255, 90, 115, 160);
    const Color border = Color.fromARGB(255, 210, 220, 240);

    // ── Shared styled field builder ───────────────────────────────────
    Widget field({
      required TextEditingController controller,
      required String label,
      required IconData icon,
      String? hint,
      bool obscure = false,
      TextInputType keyboard = TextInputType.text,
      String? Function(String?)? validator,
    }) =>
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboard,
          style: const TextStyle(fontSize: 15, color: textDark),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            hintStyle:
                TextStyle(color: textMid.withOpacity(0.55), fontSize: 13),
            labelStyle: const TextStyle(color: textMid, fontSize: 13),
            prefixIcon: Icon(icon, color: navy, size: 20),
            filled: true,
            fillColor: white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: gold, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: Color.fromARGB(255, 200, 60, 60), width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: Color.fromARGB(255, 200, 60, 60), width: 1.5),
            ),
          ),
          validator: validator,
        );

    return Scaffold(
      backgroundColor: navy,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── TOP NAVY BRANDING ──────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                decoration: BoxDecoration(
                  color: navy,
                  border: Border(
                    bottom:
                        BorderSide(color: gold.withOpacity(0.35), width: 1.5),
                  ),
                ),
                child: Column(
                  children: [
                    // Back button row
                    Row(
                      children: [
                        GestureDetector(
                          onTap: login,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: navyMid,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: gold.withOpacity(0.35), width: 1),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_back_ios_rounded,
                                    color: gold, size: 12),
                                SizedBox(width: 4),
                                Text('Back',
                                    style: TextStyle(
                                        color: gold,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Logo + branding
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: navyMid,
                        border: Border.all(color: gold, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: gold.withOpacity(0.2),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.mosque_outlined,
                          color: gold, size: 34),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'Ihsan',
                      style: TextStyle(
                        color: white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      'Create your account',
                      style: TextStyle(
                        color: gold.withOpacity(0.7),
                        fontSize: 13,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),

              // ── FORM SECTION ───────────────────────────────────────
              Container(
                color: offWhite,
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Section: Account ────────────────────────────
                      _sectionLabel(
                          'ACCOUNT', Icons.lock_outline_rounded, navy),
                      const SizedBox(height: 10),

                      field(
                        controller: _emailController,
                        label: 'Email',
                        icon: Icons.email_outlined,
                        keyboard: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.isEmpty)
                            return 'Email is required';
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                              .hasMatch(v)) return 'Please enter a valid email';
                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      field(
                        controller: _passwordController,
                        label: 'Password',
                        icon: Icons.lock_outline_rounded,
                        obscure: true,
                        validator: (v) {
                          if (v == null || v.isEmpty)
                            return 'Password is required';
                          if (v.length < 6)
                            return 'Password must be at least 6 characters';
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      // ── Section: Profile ────────────────────────────
                      _sectionLabel(
                          'PROFILE', Icons.person_outline_rounded, navy),
                      const SizedBox(height: 10),

                      field(
                        controller: _displayNameController,
                        label: 'Full Name',
                        icon: Icons.person_outline_rounded,
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Full name is required'
                            : null,
                      ),

                      const SizedBox(height: 12),

                      field(
                        controller: _usernameController,
                        label: 'Username',
                        icon: Icons.alternate_email_rounded,
                        validator: (v) {
                          if (v == null || v.isEmpty)
                            return 'Username is required';
                          if (v.contains(' '))
                            return 'Username cannot contain spaces';
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      // ── Section: Mosque Preference ──────────────────
                      _sectionLabel(
                          'MOSQUE PREFERENCE', Icons.mosque_outlined, navy),
                      const SizedBox(height: 4),
                      Text(
                        'Optional — you can set this later in settings',
                        style: TextStyle(
                            fontSize: 11, color: textMid.withOpacity(0.7)),
                      ),
                      const SizedBox(height: 10),

                      // Search bar
                      TextField(
                        controller: _searchCityController,
                        style: const TextStyle(fontSize: 14, color: textDark),
                        decoration: InputDecoration(
                          hintText: 'Search another city',
                          hintStyle:
                              const TextStyle(color: textMid, fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded,
                              color: textMid, size: 18),
                          suffixIcon: _isLoadingMosques
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: navy)),
                                )
                              : null,
                          filled: true,
                          fillColor: white,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 11),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: border, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: gold, width: 1.5),
                          ),
                        ),
                        onChanged: (value) {
                          _debounceTimer?.cancel();
                          _debounceTimer = Timer(
                              const Duration(milliseconds: 600),
                              () => _getCitySuggestions(value));
                        },
                      ),

                      // City suggestions
                      if (_citySuggestions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: border, width: 1),
                            boxShadow: [
                              BoxShadow(
                                  color: navy.withOpacity(0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3))
                            ],
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _citySuggestions.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1, color: border),
                            itemBuilder: (context, index) {
                              final city = _citySuggestions[index];
                              return ListTile(
                                dense: true,
                                leading: const Icon(
                                    Icons.location_city_outlined,
                                    size: 16,
                                    color: textMid),
                                title: Text(city['description'],
                                    style: const TextStyle(
                                        fontSize: 13, color: textDark)),
                                onTap: () async {
                                  FocusScope.of(context).unfocus();
                                  _searchCityController.text = city['name'];
                                  setState(() => _citySuggestions.clear());
                                  final latLng = await _getLatLngFromPlaceId(
                                      city['place_id']);
                                  await _fetchMosquesNear(latLng['latitude']!,
                                      latLng['longitude']!);
                                },
                              );
                            },
                          ),
                        ),

                      const SizedBox(height: 10),

                      // Mosque list
                      if (_isLoadingMosques)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: CircularProgressIndicator(color: navy),
                          ),
                        )
                      else if (_availableMosques.isEmpty)
                        GestureDetector(
                          onTap: _loadNearbyMosques,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              color: white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: border, width: 1),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.mosque_outlined,
                                    size: 32, color: textMid.withOpacity(0.4)),
                                const SizedBox(height: 8),
                                const Text('Tap to find nearby mosques',
                                    style: TextStyle(
                                        fontSize: 13, color: textMid)),
                              ],
                            ),
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            color: white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: border, width: 1),
                            boxShadow: [
                              BoxShadow(
                                  color: navy.withOpacity(0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3))
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children:
                                _availableMosques.asMap().entries.map((entry) {
                              final int idx = entry.key;
                              final String mosque = entry.value;
                              final bool isSelected =
                                  _selectedMosque == '${_currentCity}_$mosque';
                              final bool isLast =
                                  idx == _availableMosques.length - 1;
                              return Column(
                                children: [
                                  GestureDetector(
                                    onTap: () => setState(() {
                                      final mosqueId =
                                          '${_currentCity}_$mosque';
                                      _selectedMosque =
                                          isSelected ? null : mosqueId;
                                    }),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 180),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                      color: isSelected
                                          ? mintGreen.withOpacity(0.06)
                                          : Colors.transparent,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 34,
                                            height: 34,
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? mintLight
                                                  : offWhite,
                                              borderRadius:
                                                  BorderRadius.circular(9),
                                              border: Border.all(
                                                  color: isSelected
                                                      ? mintGreen
                                                          .withOpacity(0.4)
                                                      : border,
                                                  width: 1),
                                            ),
                                            child: Icon(Icons.mosque_outlined,
                                                size: 16,
                                                color: isSelected
                                                    ? mintGreen
                                                    : textMid),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(mosque,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: isSelected
                                                      ? FontWeight.w600
                                                      : FontWeight.w400,
                                                  color: isSelected
                                                      ? textDark
                                                      : textMid,
                                                )),
                                          ),
                                          if (isSelected)
                                            const Icon(
                                                Icons.check_circle_rounded,
                                                size: 18,
                                                color: mintGreen),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (!isLast)
                                    const Divider(height: 1, color: border),
                                ],
                              );
                            }).toList(),
                          ),
                        ),

                      const SizedBox(height: 20),

                      // ── Create Account button ───────────────────────
                      _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(color: gold))
                          : GestureDetector(
                              onTap: () {
                                if (_formKey.currentState!.validate()) {
                                  _signUp();
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                                decoration: BoxDecoration(
                                  color: navy,
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(
                                      color: gold.withOpacity(0.55),
                                      width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: navy.withOpacity(0.25),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.person_add_rounded,
                                        color: gold, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      'Create Account',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: gold,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                      // Already have account
                      const SizedBox(height: 14),
                      Center(
                        child: GestureDetector(
                          onTap: login,
                          child: RichText(
                            text: TextSpan(
                              text: 'Already have an account?  ',
                              style:
                                  const TextStyle(fontSize: 13, color: textMid),
                              children: [
                                TextSpan(
                                  text: 'Log in',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: gold.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Error message
                      if (_errorMessage != null)
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 255, 228, 225),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color.fromARGB(255, 220, 100, 90)
                                  .withOpacity(0.4),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: Color.fromARGB(255, 190, 60, 50),
                                  size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Color.fromARGB(255, 170, 50, 40),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, IconData icon, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.3,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      );
}
