import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ihsan_app_final/screens/homeScreen.dart';
import 'package:ihsan_app_final/screens/moreoptionsScreen.dart';
import 'package:ihsan_app_final/screens/prayerScreen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ihsan_app_final/screens/prayerTimesClass.dart';
import 'package:ihsan_app_final/screens/SettingsScreens/prayerTimeSettings.dart';
import 'package:ihsan_app_final/sharedWidgets.dart';

// ── Palette (matches app) ─────────────────────────────────────────────────────
const Color _navy = Color.fromARGB(255, 10, 25, 60);
const Color _navyMid = Color.fromARGB(255, 18, 42, 95);
const Color _gold = Color.fromARGB(255, 212, 175, 95);
const Color _goldLight = Color.fromARGB(255, 252, 243, 210);
const Color _skyLight = Color.fromARGB(255, 220, 240, 255);
const Color _mintGreen = Color.fromARGB(255, 72, 200, 155);
const Color _mintLight = Color.fromARGB(255, 210, 245, 232);
const Color _white = Color.fromARGB(255, 255, 255, 255);
const Color _offWhite = Color.fromARGB(255, 247, 249, 255);
const Color _textDark = Color.fromARGB(255, 15, 30, 65);
const Color _textMid = Color.fromARGB(255, 90, 115, 160);
const Color _border = Color.fromARGB(255, 210, 220, 240);

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});
  @override
  _SettingScreenState createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  // ── Location dialog (manual city entry) ──────────────────────────────────
  Future<void> showTownInputDialog(BuildContext context) async {
    final textController = TextEditingController();
    List<Map<String, dynamic>> citySuggestions = [];
    Timer? debounceTimer;
    bool hasSelectedOption = false;

    Future<void> getCitySuggestions(String input) async {
      if (input.isEmpty) return;
      const apiKey = 'AIzaSyBgsjMh_ojTBOMxLkSk5NSNYO7qSogbjdw';
      final url =
          'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&types=(cities)&key=$apiKey';
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['predictions'] != null &&
              (data['predictions'] as List).isNotEmpty) {
            citySuggestions.clear();
            for (var p in (data['predictions'] as List).take(10)) {
              final display = p['structured_formatting']?['main_text'] ??
                  p['description'].split(',')[0];
              if (display.isNotEmpty &&
                  !citySuggestions.any((s) => s['displayName'] == display)) {
                citySuggestions.add({
                  'displayName': display,
                  'fullDisplayName': p['description'],
                  'place_id': p['place_id'],
                });
              }
            }
          }
        }
      } catch (e) {
        debugPrint('City suggestions error: $e');
      }
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          bool isLoading = false;
          return AlertDialog(
            backgroundColor: _offWhite,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Enter Town Name',
                style: TextStyle(
                    color: _textDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
            content: Autocomplete<Map<String, dynamic>>(
              optionsBuilder: (TextEditingValue value) async {
                debounceTimer?.cancel();
                if (value.text.isEmpty) {
                  citySuggestions.clear();
                  hasSelectedOption = false;
                  setS(() {});
                  return const Iterable<Map<String, dynamic>>.empty();
                }
                hasSelectedOption = false;
                final completer = Completer<Iterable<Map<String, dynamic>>>();
                setS(() => isLoading = true);
                debounceTimer =
                    Timer(const Duration(milliseconds: 800), () async {
                  await getCitySuggestions(value.text);
                  setS(() => isLoading = false);
                  completer.complete(citySuggestions);
                });
                return completer.future;
              },
              displayStringForOption: (o) => o['fullDisplayName'],
              onSelected: (city) {
                textController.text = city['displayName'];
                townName = city['displayName'];
                hasSelectedOption = true;
                setS(() {});
              },
              fieldViewBuilder: (ctx, ctrl, focus, onDone) => TextField(
                controller: ctrl,
                focusNode: focus,
                decoration: InputDecoration(
                  hintText: 'Start typing a city…',
                  hintStyle: const TextStyle(color: _textMid, fontSize: 14),
                  filled: true,
                  fillColor: _white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _border),
                  ),
                  prefixIcon:
                      const Icon(Icons.search, color: _textMid, size: 18),
                ),
                onEditingComplete: onDone,
              ),
              optionsViewBuilder: (ctx, onSelected, options) {
                if (isLoading) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 300,
                        padding: const EdgeInsets.all(14),
                        child: const Row(children: [
                          SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _navy)),
                          SizedBox(width: 10),
                          Text('Searching…',
                              style: TextStyle(color: _textMid, fontSize: 13)),
                        ]),
                      ),
                    ),
                  );
                }
                if (options.isEmpty) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 300,
                        padding: const EdgeInsets.all(14),
                        child: const Text('No results found',
                            style: TextStyle(color: _textMid, fontSize: 13)),
                      ),
                    ),
                  );
                }
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 300,
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (ctx, i) {
                          final opt = options.elementAt(i);
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.location_on_outlined,
                                size: 16, color: _textMid),
                            title: Text(opt['fullDisplayName'],
                                style: const TextStyle(
                                    fontSize: 13, color: _textDark)),
                            onTap: () => onSelected(opt),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () {
                  debounceTimer?.cancel();
                  Navigator.pop(ctx);
                },
                child: const Text('Cancel', style: TextStyle(color: _textMid)),
              ),
              ElevatedButton(
                onPressed: hasSelectedOption
                    ? () async {
                        debounceTimer?.cancel();
                        townName = textController.text;
                        if (await isConnected()) {
                          final ll = await getLatLngFromCity(townName);
                          latitude = ll[0];
                          longitude = ll[1];
                        }
                        await saveLocation(latitude, longitude);
                        change = true;
                        Navigator.pop(ctx);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: _gold,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Location method picker ────────────────────────────────────────────────
  Future<void> _locationPopup() async {
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _offWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Change Location',
            style: TextStyle(
                color: _textDark, fontWeight: FontWeight.w700, fontSize: 16)),
        content: const Text(
          'How would you like your prayer times to be retrieved?',
          style: TextStyle(color: _textMid, fontSize: 14),
        ),
        actions: [
          _dialogBtn(ctx, 0, Icons.edit_outlined, 'Type City'),
          _dialogBtn(ctx, 1, Icons.my_location_rounded, 'Use GPS'),
          _dialogBtn(ctx, 2, Icons.mosque_outlined,
              'Use Mosque Timetable\n(Change in Home Screen)'),
        ],
      ),
    );

    if (result == 0) {
      await clearLocalMosqueId();
      if (await isConnected()) {
        await showTownInputDialog(context);
        final ll = await getLatLngFromCity(townName);
        latitude = ll[0];
        longitude = ll[1];
      }
      await saveLocation(latitude, longitude);
      if (mounted) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const PrayerTimesScreen()));
      }
    } else if (result == 1) {
      await clearLocalMosqueId();
      change = true;
      await _getCurrentLocation();
      if (mounted) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const PrayerTimesScreen()));
      }
    } else if (result == 2) {
      if (mounted) {
        // Write a flag so HomeScreen auto-opens the mosque timetable picker on arrival
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('open_mosque_picker', true);
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    }
  }

  Widget _dialogBtn(BuildContext ctx, int value, IconData icon, String label) {
    return TextButton.icon(
      onPressed: () => Navigator.pop(ctx, value),
      icon: Icon(icon, size: 16, color: _navy),
      label: Text(label,
          style: const TextStyle(
              color: _textDark, fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }

  Future<void> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (await isConnected()) await showTownInputDialog(context);
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      latitude = pos.latitude;
      longitude = pos.longitude;
      await saveLocation(latitude, longitude);
      if (await isConnected()) {
        await updateTownNameFromCoordinates(latitude, longitude);
      }
      await saveTownName(townName);
    } catch (e) {
      if (await isConnected()) await showTownInputDialog(context);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      appBar: buildAppBar(
          context, 'Settings', const MoreOptionsScreen(), screenFrom),
      body: Container(
        color: _offWhite,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 10, top: 4),
              child: Text('GENERAL',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.w700,
                      color: _textMid)),
            ),
            _settingsTile(
              icon: Icons.my_location_rounded,
              iconBg: _skyLight,
              iconColor: _navy,
              title: 'Change Begining Time Location',
              subtitle: townName.isNotEmpty ? townName : 'Tap to set location',
              onTap: _locationPopup,
            ),
            const SizedBox(height: 8),
            _settingsTile(
              icon: Icons.access_time_rounded,
              iconBg: _goldLight,
              iconColor: const Color.fromARGB(255, 140, 105, 30),
              title: 'Prayer Time Settings',
              subtitle: 'Adjustments, method & madhab',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const prayerTimeSettingsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border, width: 1),
          boxShadow: [
            BoxShadow(
                color: _navy.withOpacity(0.07),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _textDark)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 12, color: _textMid)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: _textMid),
          ],
        ),
      ),
    );
  }
}
