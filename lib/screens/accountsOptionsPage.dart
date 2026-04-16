import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ihsan_app_final/screens/login.dart';
import 'package:ihsan_app_final/screens/moreoptionsScreen.dart';
import 'package:ihsan_app_final/sharedWidgets.dart';
import 'package:ihsan_app_final/screens/prayerTimesClass.dart';

import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AccountsOptionsScreen extends StatefulWidget {
  const AccountsOptionsScreen({super.key});

  @override
  _AccountsOptionsScreenState createState() => _AccountsOptionsScreenState();
}

class _AccountsOptionsScreenState extends State<AccountsOptionsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isEditing = false;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  String? _selectedMosque;

  List<String> _availableMosques = [];
  bool _isLoadingMosques = false;
  final TextEditingController _searchCityController = TextEditingController();
  List<Map<String, dynamic>> _citySuggestions = [];
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _searchCityController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<String> getCityFromCoordinates(
      double latitude, double longitude) async {
    final String apiKey = 'AIzaSyBgsjMh_ojTBOMxLkSk5NSNYO7qSogbjdw';
    final String url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$latitude,$longitude&key=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Try to get from plus_code first
        final compound = data['plus_code']?['compound_code'];
        if (compound != null) {
          final parts = compound.split(' ');
          if (parts.length >= 2) {
            return parts.sublist(1).join(' ').replaceAll(', UK', '').trim();
          }
        }

        // Otherwise look in address components
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
      debugPrint('Error getting city from coordinates: $e');
    }

    return ''; // fallback
  }

  String _currentCity = '';

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
    _currentCity = await getCityFromCoordinates(latitude, longitude);
    if (_currentCity.isEmpty) {
      _currentCity = townName.isNotEmpty ? townName : 'Unknown';
    }
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
    final url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json'
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

  Future<LatLng> _getLatLngFromPlaceId(String placeId) async {
    const String apiKey = 'AIzaSyBgsjMh_ojTBOMxLkSk5NSNYO7qSogbjdw';
    final response = await http.get(Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry&key=$apiKey'));
    final location =
        jsonDecode(response.body)['result']['geometry']['location'];
    return LatLng(location['lat'], location['lng']);
  }

  Future<void> _fetchUserData() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (await isConnected()) {
        if (user != null) {
          String userDocPath = 'UserData/${user.uid}';
          DocumentSnapshot userDoc = await _firestore.doc(userDocPath).get();

          if (userDoc.exists) {
            Map<String, dynamic> userData =
                userDoc.data() as Map<String, dynamic>;
            setState(() {
              _userData = userData;
              _displayNameController.text = userData['displayName'] ?? '';
              _emailController.text = userData['email'] ?? '';
              _selectedMosque =
                  (userData['mosquePreference'] as String?)?.isNotEmpty == true
                      ? userData['mosquePreference'] as String
                      : null;
              mosqueIdFind = _selectedMosque ?? '';
              _isLoading = false;
            });
          } else {
            setState(() {
              _userData = null;
              _isLoading = false;
            });
          }
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching user data: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateUserData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Update display name in Firebase Auth if it changed
        if (_displayNameController.text != _userData!['displayName']) {
          await user.updateDisplayName(_displayNameController.text);
        }

        // Update email in Firebase Auth if it changed
        if (_emailController.text != _userData!['email']) {
          await user.verifyBeforeUpdateEmail(_emailController.text);
        }

        // Update user data in Firestore
        await _firestore.doc('UserData/${user.uid}').update({
          'displayName': _displayNameController.text,
          'email': _emailController.text,
          'mosquePreference': _selectedMosque ?? '',
        });
        mosqueIdFind = _selectedMosque ?? '';

        _fetchUserData(); // Refresh user data
        setState(() => _isEditing = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteAccount() async {
    setState(() => _isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Delete user data from Firestore
        await _firestore.doc('UserData/${user.uid}').delete();

        // Delete user account from Firebase Auth
        await user.delete();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting account: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Text(
              'Are you sure you want to delete your account? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAccount();
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logOut() async {
    await _auth.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  void _showLogOutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Log Out'),
          content: const Text('Are you sure you want to log out?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _logOut();
              },
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );
  }

  // ── Palette ────────────────────────────────────────────────────────
  static const Color navy = Color.fromARGB(255, 10, 25, 60);
  static const Color navyMid = Color.fromARGB(255, 18, 42, 95);
  static const Color navyLight = Color.fromARGB(255, 28, 58, 120);
  static const Color gold = Color.fromARGB(255, 212, 175, 95);
  static const Color goldLight = Color.fromARGB(255, 252, 243, 210);
  static const Color skyBlue = Color.fromARGB(255, 100, 180, 240);
  static const Color skyLight = Color.fromARGB(255, 220, 240, 255);
  static const Color mintGreen = Color.fromARGB(255, 72, 200, 155);
  static const Color mintLight = Color.fromARGB(255, 210, 245, 232);
  static const Color white = Color.fromARGB(255, 255, 255, 255);
  static const Color offWhite = Color.fromARGB(255, 247, 249, 255);
  static const Color textDark = Color.fromARGB(255, 15, 30, 65);
  static const Color textMid = Color.fromARGB(255, 90, 115, 160);
  static const Color border = Color.fromARGB(255, 210, 220, 240);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navy,
      appBar: AppBar(
        title: const Text(
          'Account',
          style: TextStyle(
            color: gold,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: 0.3,
          ),
        ),
        backgroundColor: navy,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_rounded, color: white, size: 18),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MoreOptionsScreen()),
          ),
        ),
        actions: [
          if (_userData != null && !_isEditing)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() => _isEditing = true);
                  if (_availableMosques.isEmpty)
                    _loadNearbyMosques(); // ← add this
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: navyMid,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: gold.withOpacity(0.45), width: 1),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.edit_outlined, color: gold, size: 14),
                      SizedBox(width: 5),
                      Text('Edit',
                          style: TextStyle(
                              color: gold,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: gold.withOpacity(0.3),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: gold))
          : _userData != null
              ? _buildUserContent()
              : _buildNotLoggedInContent(),
    );
  }

  Widget _buildUserContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _isEditing ? _buildEditForm() : _buildProfileView(),
        ],
      ),
    );
  }

  Widget _buildProfileView() {
    final String initial = (_userData!['displayName'] as String).isNotEmpty
        ? (_userData!['displayName'] as String)[0].toUpperCase()
        : '?';

    return Column(
      children: [
        // ── HERO HEADER ──────────────────────────────────────────────
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: navy,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(26),
              bottomRight: Radius.circular(26),
            ),
            border: Border(
              bottom: BorderSide(color: gold.withOpacity(0.45), width: 1.5),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          child: Column(
            children: [
              // Avatar
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: navyMid,
                  border: Border.all(color: gold, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: gold.withOpacity(0.2),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 40,
                      color: gold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              Text(
                _userData!['displayName'],
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: white,
                  letterSpacing: 0.3,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                _userData!['email'],
                style: TextStyle(
                  fontSize: 13,
                  color: white.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),

        // ── INFO CARDS ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 20, 14, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('ACCOUNT DETAILS', Icons.person_outline_rounded),
              const SizedBox(height: 10),

              _infoCard('Email', _userData!['email'], Icons.email_outlined,
                  skyBlue, skyLight),
              _infoCard(
                'Username',
                _userData!['username'] ?? 'Not set',
                Icons.alternate_email_rounded,
                mintGreen,
                mintLight,
              ),
              _infoCard(
                'Mosque Preference',
                (_userData!['mosquePreference'] as String?)?.isNotEmpty == true
                    ? _userData!['mosquePreference'] as String
                    : 'None set',
                Icons.mosque_outlined,
                gold,
                goldLight,
              ),

              const SizedBox(height: 20),
              _sectionLabel('ACCOUNT ACTIONS', Icons.settings_outlined),
              const SizedBox(height: 10),

              // Log Out
              _actionCard(
                label: 'Log Out',
                icon: Icons.logout_rounded,
                description: 'Sign out of your account',
                iconColor: const Color.fromARGB(255, 230, 140, 50),
                iconBg: const Color.fromARGB(255, 255, 237, 213),
                onTap: _showLogOutDialog,
              ),

              const SizedBox(height: 10),

              // Delete Account
              _actionCard(
                label: 'Delete Account',
                icon: Icons.delete_forever_rounded,
                description: 'Permanently remove your data',
                iconColor: const Color.fromARGB(255, 200, 60, 60),
                iconBg: const Color.fromARGB(255, 255, 220, 220),
                onTap: _showDeleteConfirmationDialog,
              ),

              const SizedBox(height: 28),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(
          children: [
            Icon(icon, size: 14, color: navy),
            const SizedBox(width: 6),
            Text(
              text,
              style: const TextStyle(
                fontSize: 10,
                letterSpacing: 1.3,
                fontWeight: FontWeight.w700,
                color: navy,
              ),
            ),
          ],
        ),
      );

  Widget _infoCard(String title, String value, IconData icon, Color accentColor,
      Color accentBg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 1),
        boxShadow: [
          BoxShadow(
            color: navy.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accentBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accentColor.withOpacity(0.3), width: 1),
            ),
            child: Icon(icon, size: 18, color: accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontSize: 11, color: textMid)),
                const SizedBox(height: 3),
                Text(value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textDark,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard({
    required String label,
    required String description,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 1),
          boxShadow: [
            BoxShadow(
              color: navy.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textDark,
                      )),
                  Text(description,
                      style: const TextStyle(fontSize: 11, color: textMid)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: textMid.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }

  // ── EDIT FORM ──────────────────────────────────────────────────────
  Widget _buildEditForm() {
    return Column(
      children: [
        // Edit header
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: navy,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(26),
              bottomRight: Radius.circular(26),
            ),
            border: Border(
              bottom: BorderSide(color: gold.withOpacity(0.45), width: 1.5),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: navyMid,
                  border: Border.all(color: gold.withOpacity(0.5), width: 1.5),
                ),
                child: const Icon(Icons.edit_outlined, color: gold, size: 22),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Edit Profile',
                      style: TextStyle(
                        color: white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      )),
                  Text('Update your account details',
                      style: TextStyle(
                          color: Color.fromARGB(150, 255, 255, 255),
                          fontSize: 12)),
                ],
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(14, 20, 14, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel('PERSONAL INFO', Icons.person_outline_rounded),
                const SizedBox(height: 10),

                _styledTextField(
                  controller: _displayNameController,
                  label: 'Display Name',
                  icon: Icons.person_outline_rounded,
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Please enter your name'
                      : null,
                ),

                const SizedBox(height: 12),

                _styledTextField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty)
                      return 'Please enter your email';
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(v)) return 'Please enter a valid email';
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                _sectionLabel('MOSQUE PREFERENCES', Icons.mosque_outlined),
                const SizedBox(height: 10),

                _buildMosqueSelectionList(),

                const SizedBox(height: 24),

                // Cancel + Save
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isEditing = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: offWhite,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: border, width: 1),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.close_rounded,
                                  size: 16, color: textMid),
                              SizedBox(width: 6),
                              Text('Cancel',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: textMid)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _updateUserData,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: navy,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: gold.withOpacity(0.55), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: navy.withOpacity(0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_rounded, size: 16, color: gold),
                              SizedBox(width: 6),
                              Text('Save Changes',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: gold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _styledTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15, color: textDark),
      decoration: InputDecoration(
        labelText: label,
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
  }

  Widget _buildMosqueSelectionList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        TextField(
          controller: _searchCityController,
          style: const TextStyle(fontSize: 14, color: textDark),
          decoration: InputDecoration(
            hintText: 'Search another city',
            hintStyle: const TextStyle(color: textMid, fontSize: 13),
            prefixIcon:
                const Icon(Icons.search_rounded, color: textMid, size: 18),
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
            contentPadding: const EdgeInsets.symmetric(vertical: 11),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: gold, width: 1.5),
            ),
          ),
          onChanged: (value) {
            _debounceTimer?.cancel();
            _debounceTimer = Timer(const Duration(milliseconds: 600),
                () => _getCitySuggestions(value));
          },
        ),

        // City suggestions dropdown
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
                  leading: const Icon(Icons.location_city_outlined,
                      size: 16, color: textMid),
                  title: Text(city['description'],
                      style: const TextStyle(fontSize: 13, color: textDark)),
                  onTap: () async {
                    FocusScope.of(context).unfocus();
                    _searchCityController.text = city['name'];
                    setState(() => _citySuggestions.clear());
                    final latLng =
                        await _getLatLngFromPlaceId(city['place_id']);
                    await _fetchMosquesNear(latLng.latitude, latLng.longitude);
                  },
                );
              },
            ),
          ),

        const SizedBox(height: 10),

        // Mosque list — empty / loading / populated
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
                      style: TextStyle(fontSize: 13, color: textMid)),
                ],
              ),
            ),
          )
        else
          // existing checkbox list UI — unchanged
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
              children: _availableMosques.asMap().entries.map((entry) {
                final int idx = entry.key;
                final String mosque = entry.value;
                final bool isSelected =
                    _selectedMosque == '$_currentCity\_$mosque';
                final bool isLast = idx == _availableMosques.length - 1;
                return Column(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() {
                        String mosqueId = '$_currentCity\_$mosque';
                        _selectedMosque = isSelected ? null : mosqueId;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
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
                                color: isSelected ? mintLight : offWhite,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                    color: isSelected
                                        ? mintGreen.withOpacity(0.4)
                                        : border,
                                    width: 1),
                              ),
                              child: Icon(Icons.mosque_outlined,
                                  size: 16,
                                  color: isSelected ? mintGreen : textMid),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(mosque,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: isSelected ? textDark : textMid,
                                  )),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color:
                                    isSelected ? mintGreen : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: isSelected ? mintGreen : border,
                                    width: 1.5),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check_rounded,
                                      size: 13, color: white)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!isLast) const Divider(height: 1, color: border),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  // ── NOT LOGGED IN ──────────────────────────────────────────────────
  Widget _buildNotLoggedInContent() {
    return Container(
      color: offWhite,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: navyMid,
                  shape: BoxShape.circle,
                  border: Border.all(color: gold.withOpacity(0.45), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: navy.withOpacity(0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.person_outline_rounded,
                    size: 40, color: gold),
              ),
              const SizedBox(height: 20),
              const Text('Not Logged In',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  )),
              const SizedBox(height: 8),
              const Text(
                'Please log in to access your account information',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: textMid, height: 1.5),
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  decoration: BoxDecoration(
                    color: navy,
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: gold.withOpacity(0.55), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: navy.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.login_rounded, color: gold, size: 18),
                      SizedBox(width: 8),
                      Text('Log In',
                          style: TextStyle(
                            color: gold,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          )),
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
}
