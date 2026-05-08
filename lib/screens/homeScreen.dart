import 'package:flutter/material.dart';
import 'package:ihsan_app_final/screens/dailyActivities.dart';
import 'package:ihsan_app_final/screens/uploadMosque.dart';
import 'package:ihsan_app_final/screens/adminSubmissionsScreen.dart';
import 'package:ihsan_app_final/screens/userphotosubmit.dart';
import 'package:ihsan_app_final/screens/photoupload.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

import 'package:ihsan_app_final/sharedWidgets.dart';
import 'package:ihsan_app_final/screens/moreoptionsScreen.dart';
import 'package:ihsan_app_final/screens/prayerScreen.dart';
import 'package:ihsan_app_final/screens/qiblaScreen.dart';
import 'package:ihsan_app_final/screens/quranScreen.dart';
import 'package:ihsan_app_final/screens/prayerTimesClass.dart';
import 'package:ihsan_app_final/utils/prayer_scheduler.dart';
import 'package:ihsan_app_final/utils/widget_service.dart';
import 'package:ihsan_app_final/screens/mosqueadminscreen.dart' hide PrayerTime;

import 'package:ihsan_app_final/screens/accountsOptionsPage.dart';
import 'package:ihsan_app_final/screens/calender.dart';
import 'package:ihsan_app_final/screens/nearbyMosquesHalaScreen.dart';
import 'package:ihsan_app_final/screens/settings.dart';
import 'package:ihsan_app_final/screens/tasbih.dart';
import 'package:ihsan_app_final/screens/radio.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

bool _isDialogShown = false;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  int _selectedIndex = 0;
  bool postMidnight = false;
  bool isCheckingConnection = true;
  bool firstCheck = false;
  String? userArea;

  bool _isAdmin = false;
  bool _isForumAdmin = false;
  bool _isMosqueAdmin = false;
  String _adminMosqueName = '';
  String _adminMosqueId = ''; // ADD THIS
  String _adminMosqueCity = ''; // ADD THIS

  List<Map<String, dynamic>> nearbyMosques = [];
  bool isLoadingJamaat = true;
  String? selectedPrayerBox;

  bool isLoadingMosques = true;
  bool _sortByTime = false;
  bool _sortLoading = false;
  bool _isRefreshingLocation = false;

  // Temporary city for nearby mosque jamaat times ONLY.
  // null = use the user's real saved location.
  // Never affects beginning times or prayer calculations.
  String? _browseCity;

  Future<PrayerTimes>? _prayerTimesFuture;

  String _hijriDate = ''; // e.g. "12 Rajab 1446"

  static const Map<String, String> prayerFieldMap = {
    'Fajr': 'fajrJ',
    'Sunrise': 'sunrise',
    'Dhuhr': 'dhuhrJ',
    'Asr': 'asrJ',
    'Maghrib': 'maghrib',
    'Isha': 'ishaJ',
  };

  String nextPrayerName = "Loading...";
  String nextPrayerTime = "Loading...";
  String currentPrayerName = "Loading...";
  String currentPrayerTime = "Loading...";
  String timeRemaining = "Loading...";

  String nextPrayer = '';
  String nextTime = '';
  String currentPrayer = '';
  String currentTime = '';
  String remainingTime = '';

  List<PrayerTime> prayerTimesList = [];

  final TextEditingController forumMessageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, dynamic>? _userData;

  final DateTime _todayDate = DateTime.now();
  Timer? _timer;

  PrayerTime? get firstPrayer =>
      prayerTimesList.isNotEmpty ? prayerTimesList.first : null;

  Future<void> GetData() async {
    DateTime now = DateTime.now();
    for (var prayer in prayerTimesList) {
      final timeParts = prayer.time.split(':');
      DateTime prayerTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );

      if (prayerTime.isAfter(now)) {
        nextPrayer = prayer.name;
        nextTime = prayer.time;
        Duration remaining = prayerTime.difference(now);
        int? remainingMinutes;
        remainingMinutes = remaining.inMinutes;
        selectedPrayerBox = remainingMinutes <= 20 ? nextPrayer : currentPrayer;
        if (selectedPrayerBox == "Jumu'ah") selectedPrayerBox = 'Dhuhr';
        if (nextPrayer == 'Fajr' && postMidnight == true) {
          if (!mounted) return;
          setState(() {
            selectedPrayerBox = nextPrayer;
          });
        }
        if (currentPrayer == 'Sunrise') {
          if (!mounted) return;
          setState(() {
            selectedPrayerBox = 'Dhuhr';
          });
        }
        if (currentPrayer == 'Fajr' && nextPrayer == 'Sunrise') {
          setState(() {
            selectedPrayerBox = 'Fajr';
          });
        }
        if (!mounted) return;
        setState(() {
          remainingTime =
              '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m';
        });
        break;
      } else if (prayerTime.isBefore(now)) {
        currentPrayer = prayer.name;
        currentTime = prayer.time;
        if (prayer.name == 'Fajr') postMidnight = false;
      }
    }

    if (nextPrayer.isEmpty) {
      nextPrayer = 'Fajr';

      final fajrParts = prayerTimesList[0].time.split(':');
      DateTime nextFajrTime = DateTime(
        now.year,
        now.month,
        now.day + 1,
        int.parse(fajrParts[0]),
        int.parse(fajrParts[1]),
      );
      nextTime =
          '${nextFajrTime.hour.toString().padLeft(2, '0')}:${nextFajrTime.minute.toString().padLeft(2, '0')}';

      Duration remaining = nextFajrTime.difference(now);
      if (!mounted) return;
      setState(() {
        selectedPrayerBox = 'Isha';
        remainingTime =
            '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m';
      });
    }
    if (currentPrayer.isEmpty && prayerTimesList.isNotEmpty) {
      currentPrayer = 'Isha';
      postMidnight = true;
      selectedPrayerBox = nextPrayer;
      if (selectedPrayerBox == "Jumu'ah") selectedPrayerBox = 'Dhuhr';
      currentTime = prayerTimesList.last.time;
    }
    if (mounted) {
      setState(() {
        nextPrayerName = nextPrayer;
        nextPrayerTime = nextTime;
        timeRemaining = remainingTime;
        currentPrayerName = currentPrayer;
        currentPrayerTime = currentTime;
      });
    }
  }

  Future<void> GetDataAuto() async {
    DateTime now = DateTime.now();
    for (var prayer in prayerTimesList) {
      final timeParts = prayer.time.split(':');
      DateTime prayerTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );

      if (prayerTime.isAfter(now)) {
        nextPrayer = prayer.name;
        nextTime = prayer.time;
        Duration remaining = prayerTime.difference(now);
        int? remainingMinutes;
        remainingMinutes = remaining.inMinutes;
        selectedPrayerBox = remainingMinutes <= 20 ? nextPrayer : currentPrayer;
        if (selectedPrayerBox == "Jumu'ah") selectedPrayerBox = 'Dhuhr';
        if (nextPrayer == 'Fajr' && postMidnight == true) {
          if (!mounted) return;
          setState(() {
            selectedPrayerBox = nextPrayer;
          });
        }
        if (currentPrayer == 'Sunrise') {
          if (!mounted) return;
          setState(() {
            selectedPrayerBox = 'Dhuhr';
          });
        }
        if (currentPrayer == 'Fajr' && nextPrayer == 'Sunrise') {
          setState(() {
            selectedPrayerBox = 'Fajr';
          });
        }
        if (!mounted) return;
        setState(() {
          remainingTime =
              '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m';
          timeRemaining = remainingTime;
        });
        break;
      } else if (prayerTime.isBefore(now)) {
        currentPrayer = prayer.name;
        currentTime = prayer.time;
        if (prayer.name == 'Fajr') postMidnight = false;
      }
    }

    if (nextPrayer.isEmpty) {
      nextPrayer = 'Fajr';

      final fajrParts = prayerTimesList[0].time.split(':');
      DateTime nextFajrTime = DateTime(
        now.year,
        now.month,
        now.day + 1,
        int.parse(fajrParts[0]),
        int.parse(fajrParts[1]),
      );
      nextTime =
          '${nextFajrTime.hour.toString().padLeft(2, '0')}:${nextFajrTime.minute.toString().padLeft(2, '0')}';

      Duration remaining = nextFajrTime.difference(now);
      if (!mounted) return;
      setState(() {
        selectedPrayerBox = 'Isha';
        remainingTime =
            '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m';
        timeRemaining = remainingTime;
      });
    }
    if (currentPrayer.isEmpty && prayerTimesList.isNotEmpty) {
      currentPrayer = 'Isha';
      postMidnight = true;
      selectedPrayerBox = nextPrayer;
      if (selectedPrayerBox == "Jumu'ah") selectedPrayerBox = 'Dhuhr';
      currentTime = prayerTimesList.last.time;
    }
    if (mounted) {
      setState(() {
        nextPrayerName = nextPrayer;
        nextPrayerTime = nextTime;
        timeRemaining = remainingTime;
        currentPrayerName = currentPrayer;
        currentPrayerTime = currentTime;
      });
    }
  }

  Future<void> _refreshAll() async {
    if (await isConnected()) {
      _fetchUserData();
      loadAdjustments();
      await _initializeData();
      if (!mounted) return;
      setState(() {
        isLoadingJamaat = true;
        isLoadingMosques = true;
      });
      await _loadNearbyMosques();
      await GetDataAuto();
      setState(() {
        isLoadingJamaat = false;
        isLoadingMosques = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                color: Color.fromARGB(255, 72, 200, 155),
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'Prayer times refreshed',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          backgroundColor: const Color.fromARGB(255, 18, 42, 95),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(
                Icons.wifi_off_rounded,
                color: Color.fromARGB(255, 212, 175, 95),
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'No internet — showing cached data',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          backgroundColor: const Color.fromARGB(255, 18, 42, 95),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 3),
        ),
      );
    }
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const QiblaScreen()),
        );
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

  Future<void> showLoadingDialog(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text("Retrieving location...\nMay take a couple minutes"),
            ],
          ),
        );
      },
    );
  }

  Future<int> showSimpleDialog(BuildContext context) async {
    int? result = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color.fromARGB(255, 247, 249, 255),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 220, 240, 255),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.my_location_rounded,
                    size: 18, color: Color.fromARGB(255, 10, 25, 60)),
              ),
              const SizedBox(width: 10),
              const Text('Beginning Times Location',
                  style: TextStyle(
                      color: Color.fromARGB(255, 15, 30, 65),
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'How would you like your beginning times to be calculated?',
                style: TextStyle(
                    color: Color.fromARGB(255, 90, 115, 160),
                    fontSize: 13,
                    height: 1.4),
              ),
              const SizedBox(height: 14),
              _locationOption(
                context: context,
                value: 0,
                icon: Icons.edit_outlined,
                iconBg: const Color.fromARGB(255, 220, 240, 255),
                iconColor: const Color.fromARGB(255, 10, 25, 60),
                title: 'Type City',
                subtitle: 'Manually search for your city',
              ),
              const SizedBox(height: 8),
              _locationOption(
                context: context,
                value: 1,
                icon: Icons.my_location_rounded,
                iconBg: const Color.fromARGB(255, 210, 245, 232),
                iconColor: const Color.fromARGB(255, 30, 140, 105),
                title: 'Use GPS',
                subtitle: 'Automatically detect your location',
              ),
              const SizedBox(height: 8),
              _locationOption(
                context: context,
                value: 2,
                icon: Icons.mosque_outlined,
                iconBg: const Color.fromARGB(255, 252, 243, 210),
                iconColor: const Color.fromARGB(255, 140, 105, 30),
                title: 'Use Mosque Timetable',
                subtitle: 'Use a local mosque\'s uploaded times',
                highlight: true,
              ),
            ],
          ),
          actions: [
            if (_isDialogShown)
              TextButton(
                onPressed: () => Navigator.of(context).pop(-1),
                child: const Text('Cancel',
                    style: TextStyle(
                        color: Color.fromARGB(255, 90, 115, 160),
                        fontSize: 13)),
              ),
          ],
        );
      },
    );

    return result ?? -1;
  }

  Widget _locationOption({
    required BuildContext context,
    required int value,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    bool highlight = false,
  }) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: highlight
              ? const Color.fromARGB(255, 252, 243, 210)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlight
                ? const Color.fromARGB(255, 212, 175, 95).withOpacity(0.6)
                : const Color.fromARGB(255, 210, 220, 240),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: highlight
                              ? const Color.fromARGB(255, 120, 85, 20)
                              : const Color.fromARGB(255, 15, 30, 65))),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color.fromARGB(255, 90, 115, 160))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 16,
                color: highlight
                    ? const Color.fromARGB(255, 160, 125, 40)
                    : const Color.fromARGB(255, 90, 115, 160)),
          ],
        ),
      ),
    );
  }

  Future<void> showTownInputDialog(BuildContext context) async {
    TextEditingController textController = TextEditingController();
    List<Map<String, dynamic>> citySuggestions = [];
    Timer? debounceTimer;
    bool hasLoadedOptions = false;
    bool hasSelectedOption = false;

    Future<void> getCitySuggestions(String input) async {
      if (input.isEmpty) return;

      final String apiKey = 'AIzaSyBgsjMh_ojTBOMxLkSk5NSNYO7qSogbjdw';
      // Using Places Autocomplete API instead of Geocoding
      final String url =
          'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&types=(cities)&key=$apiKey';

      try {
        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          if (data['predictions'] != null &&
              (data['predictions'] as List).isNotEmpty) {
            citySuggestions.clear();

            final resultsToShow = (data['predictions'] as List).take(10);

            for (var prediction in resultsToShow) {
              String displayName = '';
              String fullDisplayName = prediction['description'];

              // Extract the main city name from structured_formatting
              if (prediction['structured_formatting'] != null) {
                displayName =
                    prediction['structured_formatting']['main_text'] ?? '';
              }

              // If no structured formatting, fall back to description
              if (displayName.isEmpty) {
                displayName = prediction['description'].split(',')[0];
              }

              // Check for duplicates based on display name only
              bool isDuplicate = citySuggestions.any(
                (suggestion) => suggestion['displayName'] == displayName,
              );

              if (displayName.isNotEmpty && !isDuplicate) {
                citySuggestions.add({
                  'displayName': displayName,
                  'fullDisplayName': fullDisplayName,
                  'place_id': prediction['place_id'], // Store for later use
                });
              }
            }
            if (!mounted) return;
            setState(() {});
          }
        }
      } catch (e) {
        debugPrint('Error fetching city suggestions: $e');
      }
    }

    bool isLoadingBool = false;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Enter Town Name"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Autocomplete<Map<String, dynamic>>(
                    optionsBuilder: (TextEditingValue value) async {
                      debounceTimer?.cancel();

                      if (value.text.isEmpty) {
                        citySuggestions.clear();
                        hasLoadedOptions = false;
                        hasSelectedOption = false;
                        setDialogState(() {});
                        return const Iterable<Map<String, dynamic>>.empty();
                      }

                      hasSelectedOption = false;

                      final completer =
                          Completer<Iterable<Map<String, dynamic>>>();

                      setDialogState(() {
                        isLoadingBool = true;
                        hasLoadedOptions = false;
                      });

                      debounceTimer = Timer(
                        const Duration(seconds: 1),
                        () async {
                          await getCitySuggestions(value.text);
                          setDialogState(() {
                            isLoadingBool = false;
                            hasLoadedOptions = citySuggestions.isNotEmpty;
                          });
                          completer.complete(citySuggestions);
                        },
                      );

                      return completer.future;
                    },
                    displayStringForOption: (Map<String, dynamic> option) =>
                        option['fullDisplayName'],
                    onSelected: (Map<String, dynamic> selectedCity) {
                      textController.text = selectedCity['displayName'];
                      townName = selectedCity['displayName'];
                      hasSelectedOption = true;
                      setDialogState(() {});
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onEditingComplete) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          hintText: "Enter town name",
                          helperText: "Start typing and wait for suggestions",
                        ),
                        onEditingComplete: onEditingComplete,
                      );
                    },
                    optionsViewBuilder: (
                      BuildContext context,
                      AutocompleteOnSelected<Map<String, dynamic>> onSelected,
                      Iterable<Map<String, dynamic>> options,
                    ) {
                      if (isLoadingBool) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4.0,
                            child: Container(
                              width: 300,
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  CircularProgressIndicator(),
                                  SizedBox(width: 8),
                                  Text("Loading options..."),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      if (options.isEmpty) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4.0,
                            child: Container(
                              width: 300,
                              padding: const EdgeInsets.all(16.0),
                              child: const Text("No results found"),
                            ),
                          ),
                        );
                      }

                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4.0,
                          child: Container(
                            width: 300,
                            constraints: const BoxConstraints(
                              maxHeight: 250,
                            ),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(8.0),
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  title: Text(
                                    option['fullDisplayName'],
                                    style: const TextStyle(
                                      fontSize: 14,
                                    ),
                                  ),
                                  onTap: () {
                                    onSelected(option);
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    debounceTimer?.cancel();
                    Navigator.of(context).pop();
                  },
                  child: const Text("Cancel"),
                ),
                isLoadingBool
                    ? const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : TextButton(
                        onPressed: hasSelectedOption
                            ? () async {
                                debounceTimer?.cancel();
                                townName = textController.text;
                                setDialogState(
                                  () => isLoadingBool = true,
                                ); // ← trigger spinner
                                if (await isConnected()) {
                                  List<double> latLng = await getLatLngFromCity(
                                    townName,
                                  );
                                  latitude = latLng[0];
                                  longitude = latLng[1];
                                }
                                await saveLocation(latitude, longitude);
                                change = true;
                                await initializeMonthlyPrayerTimes();
                                await GetData();
                                Navigator.of(context).pop();
                              }
                            : null,
                        child: Text(
                          "Update",
                          style: TextStyle(
                            color: hasSelectedOption ? null : Colors.grey,
                          ),
                        ),
                      ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (await isConnected()) await showTownInputDialog(context);
        await GetData();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (await isConnected()) await showTownInputDialog(context);
      await GetData();
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      latitude = position.latitude;
      longitude = position.longitude;
      saveLocation(latitude, longitude);
      if (await isConnected()) {
        await updateTownNameFromCoordinates(latitude, longitude);
      }
      await saveTownName(townName);
    } catch (e) {
      print('Failed to get location: $e');
      if (await isConnected()) await showTownInputDialog(context);
    }
  }

  Future<String?> _selectMosqueFromCity(String cityName) async {
    if (cityName.isEmpty) return null;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('mosques')
          .where('city', isEqualTo: cityName)
          .get();

      if (snapshot.docs.isEmpty) {
        if (!mounted) return null;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('No Mosques Found'),
            content: Text(
                'No mosques found in $cityName. Using standard calculation.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
            ],
          ),
        );
        return null;
      }

      // ── CHANGED: only show mosques that have today's prayer times ──
      final today = DateTime.now().toIso8601String().substring(0, 10);
      List<Map<String, dynamic>> mosqueOptions = [];
      for (var doc in snapshot.docs) {
        final prayerDoc = await FirebaseFirestore.instance
            .collection('mosques')
            .doc(doc.id)
            .collection('prayerTimes')
            .doc(today)
            .get();
        if (!prayerDoc.exists) continue;
        mosqueOptions.add(
            {'id': doc.id, 'name': doc.data()['name'] ?? 'Unnamed Mosque'});
      }

      if (mosqueOptions.isEmpty) {
        if (!mounted) return null;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('No Timetables Available'),
            content: Text(
                'No mosques in $cityName have a timetable for today. Using standard calculation.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
            ],
          ),
        );
        return null;
      }
      // ── END CHANGE ──

      if (!mounted) return null;
      return await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text.rich(TextSpan(
            text: 'Select Mosque in $cityName\n',
            style: Theme.of(ctx).textTheme.titleLarge,
            children: [
              TextSpan(
                  text: 'Choose any from the list, it works for the whole city',
                  style: Theme.of(ctx).textTheme.bodyMedium)
            ],
          )),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: mosqueOptions.length,
              itemBuilder: (ctx, index) {
                final mosque = mosqueOptions[index];
                return ListTile(
                  title: Text(mosque['name']),
                  onTap: () => Navigator.pop(ctx, mosque['id']),
                );
              },
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Cancel'))
          ],
        ),
      );
    } catch (e) {
      print("Error selecting mosque: $e");
      return null;
    }
  }

  Future<String?> getUserAreaFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      if (userArea == null) {
        final String apiKey = 'AIzaSyBgsjMh_ojTBOMxLkSk5NSNYO7qSogbjdw';
        final url = 'https://maps.googleapis.com/maps/api/geocode/json'
            '?latlng=$latitude,$longitude&key=$apiKey';

        final response = await http.get(Uri.parse(url));
        if (response.statusCode != 200) return null;

        final data = jsonDecode(response.body);

        final compound = data['plus_code']?['compound_code'];
        if (compound != null) {
          final parts = compound.split(' ');
          if (parts.length >= 2) {
            final area =
                parts.sublist(1).join(' ').replaceAll(', UK', '').trim();

            final prefs = await SharedPreferences.getInstance();
            userArea = area;
            await prefs.setString('user_area', area);
            return area;
          }
        }

        for (var result in data['results'] ?? []) {
          for (var component in result['address_components']) {
            final types = List<String>.from(component['types']);
            if (types.contains('postal_town') ||
                types.contains('locality') ||
                types.contains('administrative_area_level_2')) {
              final area = component['long_name'];

              final prefs = await SharedPreferences.getInstance();
              userArea = area;
              await prefs.setString('user_area', area);
              return area;
            }
          }
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        userArea = prefs.getString('user_area');
        return userArea;
      }
    } catch (e) {
      debugPrint('Geocoding failed: $e');
    }
    return null;
  }

  double distanceKm(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }

  Future<List<Map<String, dynamic>>> getNearbyMosquesWithPrayerTimes(
      {String? overrideCity}) async {
    final firestore = FirebaseFirestore.instance;

    final location = await getLastKnownLocation();
    if (location == null) return [];

    double userLat = location['latitude']!;
    double userLng = location['longitude']!;

    if (overrideCity != null) {
      final latLng = await getLatLngFromCity(overrideCity);
      userLat = latLng[0];
      userLng = latLng[1];
    }

    // When browsing another city, use it directly and don't pollute userArea cache
    String? searchCity;
    if (overrideCity != null) {
      searchCity = overrideCity;
    } else {
      if (await isConnected()) {
        userArea = await getUserAreaFromCoordinates(userLat, userLng);
      } else {
        if (mounted) {
          setState(() {
            isLoadingMosques = false;
          });
        }
      }
      searchCity = userArea;
    }
    if (searchCity == null) return [];

    final mosqueSnapshot = await firestore
        .collection('mosques')
        .where('city', isEqualTo: searchCity)
        .get();

    final today = DateTime.now().toIso8601String().substring(0, 10);

    List<Map<String, dynamic>> nearbyMosques = [];

    for (var doc in mosqueSnapshot.docs) {
      final data = doc.data();
      final GeoPoint geo = data['location'];

      final dist = distanceKm(userLat, userLng, geo.latitude, geo.longitude);

      // When browsing another city skip the 10 km filter — user explicitly chose it
      if (overrideCity == null && dist > 10) continue;

      final prayerDoc = await firestore
          .collection('mosques')
          .doc(doc.id)
          .collection('prayerTimes')
          .doc(today)
          .get();

      if (!prayerDoc.exists) continue;

      nearbyMosques.add({
        'mosqueId': doc.id,
        'name': data['name'],
        'distance': dist,
        'prayerTimes': prayerDoc.data(),
      });
    }

    if (_sortByTime) {
      nearbyMosques.sort((a, b) {
        final fieldKey = prayerFieldMap[selectedPrayerBox ?? 'Fajr'] ?? 'fajrJ';
        String toComparable(Map pt) {
          final raw = (pt[fieldKey] ?? '99:99') as String;
          final parts = raw.split(':');
          if (parts.length < 2) return '9999';
          return parts[0].padLeft(2, '0') + parts[1].padLeft(2, '0');
        }

        return toComparable(a['prayerTimes'] ?? {})
            .compareTo(toComparable(b['prayerTimes'] ?? {}));
      });
    } else {
      nearbyMosques.sort(
        (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
      );
    }
    if (mounted) {
      setState(() {
        isLoadingMosques = false;
      });
    }

    return nearbyMosques;
  }

  Future<List<Map<String, dynamic>>> getAllMosques() async {
    final firestore = FirebaseFirestore.instance;

    final mosqueSnapshot = await firestore.collection('mosques').get();

    List<Map<String, dynamic>> mosques = [];

    for (var doc in mosqueSnapshot.docs) {
      final data = doc.data();
      final GeoPoint geo = data['location'];

      mosques.add({
        'mosqueId': doc.id,
        'name': data['name'],
        'latitude': geo.latitude,
        'longitude': geo.longitude,
      });
    }

    return mosques;
  }

  Future<void> initializeMonthlyPrayerTimes() async {
    // ===== NEW: Check for saved mosque preference FIRST =====
    final savedMosqueId = await getLocalMosqueId();

    if (savedMosqueId.isNotEmpty) {
      try {
        final todayDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
        final prefs = await SharedPreferences.getInstance();
        final cachedDate = prefs.getString('prayerTimesDate');
        final needsRefresh = cachedDate != todayDate || change == true;

        if (await isConnected() && needsRefresh) {
          final mosqueTimes = await fetchMosquePrayerTimes(savedMosqueId);

          if (mosqueTimes.isNotEmpty) {
            monthlyPrayerTimesList = mosqueTimes;
            await saveMonthlyPrayerTimes(monthlyPrayerTimesList);

            try {
              todayPrayerTimes = monthlyPrayerTimesList.firstWhere(
                (prayerTime) => prayerTime.date == todayDate,
              );
            } catch (e) {
              if (monthlyPrayerTimesList.isNotEmpty) {
                todayPrayerTimes = monthlyPrayerTimesList.first;
              }
            }

            if (todayPrayerTimes != null) {
              _savePrayerTimesToLocal(
                  todayPrayerTimes!, todayPrayerTimes!.date);
              updatePrayerTimesList();
              if (!mounted) return;
              setState(() => change = false);
              return;
            }
          }
        } else if (!needsRefresh) {
          // Today's times already cached — load from stored list
          final storedTimes = await loadMonthlyPrayerTimes();
          if (storedTimes.isNotEmpty) {
            monthlyPrayerTimesList = storedTimes;
            try {
              todayPrayerTimes =
                  monthlyPrayerTimesList.firstWhere((p) => p.date == todayDate);
            } catch (_) {
              todayPrayerTimes = monthlyPrayerTimesList.first;
            }
            updatePrayerTimesList();
            if (!mounted) return;
            return;
          }
        }
      } catch (e) {
        print("Error fetching mosque prayer times: $e");
        // Fall through to Aladhan
      }
    }

    // ===== ORIGINAL Aladhan flow (unchanged) =====
    List<PrayerTimes> storedPrayerTimes = await loadMonthlyPrayerTimes();
    String todayDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
    DateTime now = DateTime.now();
    if (storedPrayerTimes.isEmpty ||
        storedPrayerTimes.any((prayerTime) {
          DateTime prayerDate = DateFormat('dd-MM-yyyy').parse(prayerTime.date);
          return prayerDate.year != now.year;
        }) ||
        change == true ||
        (await SharedPreferences.getInstance()).getString('prayerTimesDate') !=
            todayDate) {
      try {
        List<PrayerTimes> yearlyTimes = [];
        if (await isConnected()) {
          for (int m = 1; m <= 12; m++) {
            final monthlyTimes = await fetchMonthlyPrayerTimes(
              latitude,
              longitude,
              method,
              school,
              year,
              m,
            );
            yearlyTimes.addAll(monthlyTimes);
          }
        }
        monthlyPrayerTimesList = yearlyTimes;
        await saveMonthlyPrayerTimes(monthlyPrayerTimesList);

        todayPrayerTimes = yearlyTimes.firstWhere(
          (prayerTime) => prayerTime.date == todayDate,
          orElse: () => throw Exception('No prayer times for today'),
        );

        updatePrayerTimesList();
        _savePrayerTimesToLocal(todayPrayerTimes!, todayPrayerTimes!.date);
        if (await isConnected()) {
          await updateTownNameFromCoordinates(latitude, longitude);
        }
        if (!mounted) return;
        setState(() => change = false);
      } catch (error) {
        print("Error fetching prayer times from API: $error");
      }
    } else {
      monthlyPrayerTimesList = storedPrayerTimes;
      todayPrayerTimes = await setFuturePrayerTimes();
      updatePrayerTimesList();
    }
  }

  // ── Save / clear browse city in prefs ─────────────────────────────────────
  Future<void> _saveBrowseCity(String? city) async {
    final prefs = await SharedPreferences.getInstance();
    if (city == null) {
      await prefs.remove('browse_city');
    } else {
      await prefs.setString('browse_city', city);
    }
  }

  // ── Fetch city name from current GPS position ──────────────────────────────
  Future<String?> _getCityFromGPS() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return null;
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      const apiKey = 'AIzaSyBgsjMh_ojTBOMxLkSk5NSNYO7qSogbjdw';
      final url =
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=${pos.latitude},${pos.longitude}&key=$apiKey';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      // Try plus_code first
      final compound = data['plus_code']?['compound_code'];
      if (compound != null) {
        final parts = (compound as String).split(' ');
        if (parts.length >= 2) {
          return parts.sublist(1).join(' ').replaceAll(', UK', '').trim();
        }
      }
      // Fall back to address components
      for (var result in data['results'] ?? []) {
        for (var comp in result['address_components']) {
          final types = List<String>.from(comp['types']);
          if (types.contains('postal_town') ||
              types.contains('locality') ||
              types.contains('administrative_area_level_2')) {
            return comp['long_name'] as String;
          }
        }
      }
    } catch (e) {
      debugPrint('GPS city lookup error: $e');
    }
    return null;
  }

  // ── Jumu'ah city-wide sheet ───────────────────────────────────────────────
  // Fetches all mosques in the current city (or browse city) and shows their
  // next upcoming Jumu'ah times grouped and sorted by earliest first.
  Future<void> _showJummahCitySheet() async {
    // Work out which city to query
    final String? city = _browseCity ?? userArea;
    if (city == null || city.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.info_outline_rounded,
                color: Color.fromARGB(255, 212, 175, 95), size: 16),
            SizedBox(width: 8),
            Text('Location not set yet — set your location first',
                style: TextStyle(color: Colors.white)),
          ]),
          backgroundColor: const Color.fromARGB(255, 18, 42, 95),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ),
      );
      return;
    }

    // Work out the next upcoming Friday date
    final now = DateTime.now();
    final daysUntilFriday = (DateTime.friday - now.weekday + 7) % 7;
    final nextFriday =
        daysUntilFriday == 0 ? now : now.add(Duration(days: daysUntilFriday));
    final nextFridayStr = nextFriday.toIso8601String().substring(0, 10);
    final fridayLabel = daysUntilFriday == 0
        ? 'This Friday'
        : 'Fri ${nextFriday.day}/${nextFriday.month}';

    // Show sheet immediately with a loading state
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _JummahCitySheet(
        city: city,
        fridayDateStr: nextFridayStr,
        fridayLabel: fridayLabel,
        userLat: latitude,
        userLng: longitude,
      ),
    );
  }

  // ── Browse nearby city dialog ─────────────────────────────────────────────
  // Lets user pick a TEMPORARY city for the nearby mosque jamaat list only.
  // Does NOT affect beginning times or prayer calculations.
  Future<void> _browseNearbyCityDialog() async {
    List<Map<String, dynamic>> citySuggestions = [];
    Timer? debounceTimer;
    bool hasSelectedOption = false;
    String? pickedCity;
    bool isSearchLoading = false;
    bool isGpsLoading = false;

    Future<void> fetchSuggestions(
        String input, void Function(void Function()) setS) async {
      if (input.isEmpty) return;
      const apiKey = 'AIzaSyBgsjMh_ojTBOMxLkSk5NSNYO7qSogbjdw';
      final url =
          'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&types=(cities)&key=$apiKey';
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          citySuggestions.clear();
          for (var p in (data['predictions'] as List? ?? []).take(10)) {
            final display =
                p['structured_formatting']?['main_text'] as String? ??
                    (p['description'] as String).split(',')[0];
            if (display.isNotEmpty &&
                !citySuggestions.any((s) => s['displayName'] == display)) {
              citySuggestions.add({
                'displayName': display,
                'fullDisplayName': p['description'],
              });
            }
          }
          setS(() {});
        }
      } catch (e) {
        debugPrint('Browse city suggestions: $e');
      }
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          backgroundColor: const Color.fromARGB(255, 247, 249, 255),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Browse Mosque Times',
                  style: TextStyle(
                      color: Color.fromARGB(255, 15, 30, 65),
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
              const SizedBox(height: 4),
              const Text('Pick a city to see its mosque jamaat times.',
                  style: TextStyle(
                      color: Color.fromARGB(255, 90, 115, 160), fontSize: 12)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Info banner
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 220, 240, 255),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color.fromARGB(255, 100, 180, 240)
                          .withOpacity(0.5)),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline,
                      size: 14, color: Color.fromARGB(255, 10, 25, 60)),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Your beginning times always use your saved location. '
                      'This only changes which city\'s jamaat times appear below.',
                      style: TextStyle(
                          fontSize: 11, color: Color.fromARGB(255, 15, 30, 65)),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              // GPS button
              GestureDetector(
                onTap: isGpsLoading
                    ? null
                    : () async {
                        setS(() => isGpsLoading = true);
                        final city = await _getCityFromGPS();
                        setS(() => isGpsLoading = false);
                        if (city != null) {
                          pickedCity = city;
                          hasSelectedOption = true;
                          setS(() {});
                        }
                      },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 10, 25, 60),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: isGpsLoading
                      ? const Center(
                          child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white)))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.my_location_rounded,
                                size: 14,
                                color: Color.fromARGB(255, 212, 175, 95)),
                            const SizedBox(width: 7),
                            Text(
                              pickedCity != null && hasSelectedOption
                                  ? 'Detected: $pickedCity'
                                  : 'Use My Current Location',
                              style: const TextStyle(
                                  color: Color.fromARGB(255, 212, 175, 95),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 10),
              const Row(children: [
                Expanded(
                    child: Divider(color: Color.fromARGB(255, 210, 220, 240))),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('or search',
                      style: TextStyle(
                          color: Color.fromARGB(255, 90, 115, 160),
                          fontSize: 11)),
                ),
                Expanded(
                    child: Divider(color: Color.fromARGB(255, 210, 220, 240))),
              ]),
              const SizedBox(height: 10),
              // City search autocomplete
              Autocomplete<Map<String, dynamic>>(
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
                  setS(() => isSearchLoading = true);
                  debounceTimer =
                      Timer(const Duration(milliseconds: 800), () async {
                    await fetchSuggestions(value.text, setS);
                    setS(() => isSearchLoading = false);
                    completer.complete(citySuggestions);
                  });
                  return completer.future;
                },
                displayStringForOption: (o) => o['fullDisplayName'] as String,
                onSelected: (city) {
                  pickedCity = city['displayName'] as String;
                  hasSelectedOption = true;
                  setS(() {});
                },
                fieldViewBuilder: (ctx, ctrl, focus, onDone) => TextField(
                  controller: ctrl,
                  focusNode: focus,
                  decoration: const InputDecoration(
                    hintText: 'Search city…',
                    hintStyle: TextStyle(
                        color: Color.fromARGB(255, 90, 115, 160), fontSize: 13),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    prefixIcon: Icon(Icons.search,
                        color: Color.fromARGB(255, 90, 115, 160), size: 18),
                  ),
                  onEditingComplete: onDone,
                ),
                optionsViewBuilder: (ctx, onSel, options) {
                  if (isSearchLoading) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 280,
                          padding: const EdgeInsets.all(12),
                          child: const Row(children: [
                            SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color.fromARGB(255, 10, 25, 60))),
                            SizedBox(width: 8),
                            Text('Searching…',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Color.fromARGB(255, 90, 115, 160))),
                          ]),
                        ),
                      ),
                    );
                  }
                  if (options.isEmpty) return const SizedBox.shrink();
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 280,
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (ctx, i) {
                            final opt = options.elementAt(i);
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.location_on_outlined,
                                  size: 14,
                                  color: Color.fromARGB(255, 90, 115, 160)),
                              title: Text(opt['fullDisplayName'] as String,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color.fromARGB(255, 15, 30, 65))),
                              onTap: () => onSel(opt),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          actions: [
            // "Use my real location" — only shown when browsing elsewhere
            if (_browseCity != null)
              TextButton.icon(
                onPressed: () => Navigator.pop(ctx, '__clear__'),
                icon: const Icon(Icons.close_rounded,
                    size: 14, color: Color.fromARGB(255, 200, 80, 80)),
                label: const Text('Clear & use my location',
                    style: TextStyle(
                        color: Color.fromARGB(255, 200, 80, 80), fontSize: 12)),
              ),
            TextButton(
              onPressed: () {
                debounceTimer?.cancel();
                Navigator.pop(ctx, null);
              },
              child: const Text('Cancel',
                  style: TextStyle(color: Color.fromARGB(255, 90, 115, 160))),
            ),
            ElevatedButton(
              onPressed: hasSelectedOption
                  ? () {
                      debounceTimer?.cancel();
                      Navigator.pop(ctx, pickedCity);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 10, 25, 60),
                foregroundColor: const Color.fromARGB(255, 212, 175, 95),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Show Mosques'),
            ),
          ],
        );
      }),
    ).then((result) async {
      if (result == '__clear__') {
        setState(() {
          _browseCity = null;
          isLoadingMosques = true;
        });
        await _saveBrowseCity(null);
        await _loadNearbyMosques();
      } else if (result != null) {
        setState(() {
          _browseCity = result as String;
          isLoadingMosques = true;
        });
        await _saveBrowseCity(_browseCity);
        await _loadNearbyMosques(overrideCity: _browseCity);
      }
    });
  }

  Future<void> _clearBrowseLocationCoords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('browse_lat');
    await prefs.remove('browse_lng');
  }

  Future<void> changeLocationDialog() async {
    int result = await showSimpleDialog(context);

    if (result == 0) {
      await clearLocalMosqueId();
      userArea = null;
      await _clearBrowseLocationCoords();
      if (await isConnected()) {
        await showTownInputDialog(context);
      }
      await saveLocation(latitude, longitude);
      setState(() => isLoadingMosques = true);
      await initializeMonthlyPrayerTimes();
      await GetData();
      await _loadNearbyMosques();
      await _logUserAndLocation(method: 'manual');
    } else if (result == 1) {
      userArea = null;
      await _clearBrowseLocationCoords();
      await clearLocalMosqueId();
      showLoadingDialog(context); // show loader
      change = true;
      setState(() => isLoadingMosques = true);
      await getCurrentLocation();
      await initializeMonthlyPrayerTimes();
      await GetDataAuto();
      await _loadNearbyMosques();
      await _logUserAndLocation(method: 'gps');
      if (mounted) {
        Navigator.of(context).pop(); // close loading dialog
      }
    } else if (result == 2) {
      userArea = null;
      await _clearBrowseLocationCoords();
      // Mosque Timetable - NEW
      showLoadingDialog(context);
      change = true;
      setState(() => isLoadingMosques = true);

      // Step 1: Get location first (same as Automatic)
      await getCurrentLocation(); // This sets townName, latitude, longitude

      // Step 2: Now we have city, let user pick a mosque
      Navigator.of(context).pop(); // Close loading dialog

      final selectedMosqueId = await _selectMosqueFromCity(townName);

      if (selectedMosqueId != null) {
        // Step 3: Save preference and load mosque data
        await saveLocalMosqueId(selectedMosqueId);

        // Show loading while fetching mosque data
        showLoadingDialog(context);
        await initializeMonthlyPrayerTimes(); // Will use mosque data now
        await GetDataAuto();
        await _loadNearbyMosques();
        if (mounted) {
          Navigator.of(context).pop(); // close loading dialog

          // Show success message with mosque name
          final mosqueName = await getMosqueNameFromId(selectedMosqueId);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Now using $mosqueName timetable'),
              backgroundColor: const Color.fromARGB(255, 72, 200, 155),
            ),
          );
          await _logUserAndLocation(method: 'mosque');
        }
      } else {
        // User cancelled or no mosques - fall back to Aladhan
        setState(() => isLoadingMosques = true);
        await initializeMonthlyPrayerTimes();
        await GetDataAuto();
        await _loadNearbyMosques();
        await _logUserAndLocation(method: 'gps');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No mosque selected, using standard calculation'),
            backgroundColor: Color.fromARGB(255, 212, 175, 95),
          ),
        );
      }
    }
  }

  Future<void> _initializeData() async {
    try {
      final lastKnownLocation = await getLastKnownLocation();

      if (lastKnownLocation == null && !_isDialogShown) {
        int result = await showSimpleDialog(context);

        _isDialogShown = true;
        if (result == 0) {
          await clearLocalMosqueId();
          if (await isConnected()) {
            await showTownInputDialog(context);

            List<double> latLng = await getLatLngFromCity(townName);
            latitude = latLng[0];
            longitude = latLng[1];
          }
          await saveLocation(latitude, longitude);
          await initializeMonthlyPrayerTimes();
          await GetData();
          await _loadNearbyMosques();
          await _logUserAndLocation(method: 'manual');
        } else if (result == 1) {
          await clearLocalMosqueId();
          change = true;
          await getCurrentLocation();
          await initializeMonthlyPrayerTimes();
          await GetDataAuto();
          await _loadNearbyMosques();
          await _logUserAndLocation(method: 'gps');
        } else if (result == 2) {
          // Mosque Timetable
          change = true;

          // Get location first
          await getCurrentLocation(); // Sets townName

          // Then let user pick mosque
          final selectedMosqueId = await _selectMosqueFromCity(townName);

          if (selectedMosqueId != null) {
            await saveLocalMosqueId(selectedMosqueId);
          }

          // Initialize with whatever we have (mosque or fallback)
          await initializeMonthlyPrayerTimes();
          await GetDataAuto();
          await _loadNearbyMosques();
          await _logUserAndLocation(method: 'mosque');
        }
      } else if (lastKnownLocation != null) {
        // Try to refresh GPS coordinates if permission is granted
        final permission = await Geolocator.checkPermission();
        if ((permission == LocationPermission.whileInUse ||
                permission == LocationPermission.always) &&
            (change == true)) {
          try {
            final pos = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high);
            latitude = pos.latitude;
            longitude = pos.longitude;
            await saveLocation(
                latitude, longitude); // overwrite prefs with fresh coords
          } catch (e) {
            // GPS failed — fall back to saved
            latitude = lastKnownLocation['latitude']!;
            longitude = lastKnownLocation['longitude']!;
          }
        } else {
          latitude = lastKnownLocation['latitude']!;
          longitude = lastKnownLocation['longitude']!;
        }

        userArea = null; // force area name to re-resolve from new coords
        if (await isConnected()) {
          await updateTownNameFromCoordinates(latitude, longitude);
        }
        await saveTownName(townName);
        await initializeMonthlyPrayerTimes();
        await GetDataAuto();
        await _loadNearbyMosques();
        await _logUserAndLocation(method: 'auto');
      }

      // Sync the home-screen widget with the prayer times we just loaded.
      // This must run after initializeMonthlyPrayerTimes() so todayPrayerTimes
      // is populated. Without this the widget reads stale/missing
      // SharedPreferences keys (w_fajr_adhan etc.) and shows --:-- on cold start.
      if (todayPrayerTimes != null) {
        // Read back the jamaat times prayerScreen previously saved to prefs
        // (keys: jamaah_fajr, jamaah_dhuhr, etc.) so we never blank them out.
        // Passing jamaat: null would wipe the widget's jamaah data on every
        // home navigation — that was the bug.
        final prefs = await SharedPreferences.getInstance();
        final jFajr = prefs.getString('jamaah_fajr') ?? '';
        final jSunrise = prefs.getString('jamaah_sunrise') ?? '';
        final jDhuhr = prefs.getString('jamaah_dhuhr') ?? '';
        final jAsr = prefs.getString('jamaah_asr') ?? '';
        final jMaghrib = prefs.getString('jamaah_maghrib') ?? '';
        final jIsha = prefs.getString('jamaah_isha') ?? '';
        final savedMosqueName = prefs.getString('widget_mosque_name') ?? '';

        // Only reconstruct a jamaat object if we actually have saved times
        PrayerTimesJamaat? savedJamaatObj;
        if (jFajr.isNotEmpty || jDhuhr.isNotEmpty || jIsha.isNotEmpty) {
          final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
          savedJamaatObj = PrayerTimesJamaat(
            date: todayStr,
            fajr: jFajr,
            sunrise: jSunrise,
            dhuhr: jDhuhr,
            asr: jAsr,
            maghrib: jMaghrib,
            isha: jIsha,
          );
        }

        await WidgetService.update(
          adhan: todayPrayerTimes!,
          jamaat: savedJamaatObj, // null only if prayerScreen hasn't run yet
          mosqueName: savedMosqueName,
          nextPrayerName: nextPrayerName,
          currentPrayerName: currentPrayerName,
        );
      }
    } catch (e) {
      print("Initialization error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load prayer times")),
      );
    }
  }

  Future<PrayerTimes> setFuturePrayerTimes() async {
    String todayDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
    todayPrayerTimes = monthlyPrayerTimesList.firstWhere(
      (prayerTime) => prayerTime.date == todayDate,
      orElse: () => throw Exception('No prayer times for today'),
    );
    return todayPrayerTimes!;
  }

  Future<void> _savePrayerTimesToLocal(
    PrayerTimes prayerTimes,
    String date,
  ) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    prefs.setString('fajr', prayerTimes.fajr);
    prefs.setString('sunrise', prayerTimes.sunrise);
    prefs.setString('dhuhr', prayerTimes.dhuhr);
    prefs.setString('asr', prayerTimes.asr);
    prefs.setString('maghrib', prayerTimes.maghrib);
    prefs.setString('isha', prayerTimes.isha);
    prefs.setString('prayerTimesDate', date);
  }

  void updatePrayerTimesList() {
    if (todayPrayerTimes != null) {
      setState(() {
        prayerTimesList = [
          PrayerTime('Fajr', todayPrayerTimes!.fajr, ""),
          PrayerTime('Sunrise', todayPrayerTimes!.sunrise, ""),
          PrayerTime(
            DateTime.now().weekday == DateTime.friday ? "Jumu'ah" : 'Dhuhr',
            todayPrayerTimes!.dhuhr,
            "",
          ),
          PrayerTime('Asr', todayPrayerTimes!.asr, ""),
          PrayerTime('Maghrib', todayPrayerTimes!.maghrib, ""),
          PrayerTime('Isha', todayPrayerTimes!.isha, ""),
        ];
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  // Fetches today's Hijri date from Aladhan's Gregorian→Hijri conversion endpoint.
  // Completely separate from prayer times — works regardless of mosque/Aladhan mode.
  Future<void> _fetchHijriDate() async {
    try {
      final now = DateTime.now();
      final ddmmyyyy =
          '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
      final url = 'https://api.aladhan.com/v1/gToH?date=$ddmmyyyy';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final hijri = data['data']['hijri'];
        final day = hijri['day'];
        final month = hijri['month']['en'];
        final year = hijri['year'];
        if (mounted) {
          setState(() => _hijriDate = '$day $month $year');
        }
      }
    } catch (e) {
      debugPrint('Hijri date fetch error: $e');
    }
  }

  void initState() {
    super.initState();
    //Internet Check
    _fetchUserData();
    loadAdjustments();
    _checkAdmin();
    _checkForumAdmin();
    _checkMosqueAdmin();
    _fetchHijriDate();
    _loadCachedData();
    FirebaseAnalytics.instance
        .logScreenView(screenName: 'home_screen')
        .catchError((e) => debugPrint('Analytics screenView error: $e'));

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Load saved browse city from prefs
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('browse_city');
      if (saved != null && mounted) setState(() => _browseCity = saved);

      // If settings sent us here to pick a mosque timetable, open immediately
      final openMosquePicker = prefs.getBool('open_mosque_picker') ?? false;
      if (openMosquePicker) {
        await prefs.remove('open_mosque_picker');
        // Open straight away — changeLocationDialog handles its own loading
        if (mounted) await changeLocationDialog();
      }

      await _initializeData();
      await _triggerScheduler();
    });
    _startTimer();
  }

  Future<void> _triggerScheduler() async {
    if (todayPrayerTimes == null) return;

    // Build beginning times map from todayPrayerTimes
    final beginningTimes = {
      'fajr': todayPrayerTimes!.fajr,
      'sunrise': todayPrayerTimes!.sunrise,
      'dhuhr': todayPrayerTimes!.dhuhr,
      'asr': todayPrayerTimes!.asr,
      'maghrib': todayPrayerTimes!.maghrib,
      'isha': todayPrayerTimes!.isha,
    };

    // Build jama'ah times map from prayerTimesListJamaat (if available)
    // Note: prayerTimesListJamaat is a global defined in prayerScreen.dart
    // so we read from SharedPreferences directly here instead
    // The prayerScreen will call PrayerScheduler.saveJamaahTimes() after its
    // Firebase load — see prayerScreen_scheduler_hook.dart
    await PrayerScheduler.scheduleNow(
      beginningTimes: beginningTimes,
      jamaahTimes: {}, // prayerScreen handles saving jamaah times separately
    );
  }

  Future<void> _loadNearbyMosques({String? overrideCity}) async {
    final mosques = await getNearbyMosquesWithPrayerTimes(
        overrideCity: overrideCity ?? _browseCity);
    if (!mounted) return;
    setState(() {
      nearbyMosques = mosques;
      isLoadingJamaat = false;
      isLoadingMosques = false;
      _sortLoading = false;
    });
  }

  // ── Refresh browse/nearby location from GPS ────────────────────────────────
  // Gets fresh GPS coordinates and reloads the nearby mosque list.
  // Only updates the location used for mosque proximity — never affects
  // beginning times or prayer calculations.
  Future<void> _refreshBrowseLocation() async {
    if (_isRefreshingLocation) return;
    setState(() => _isRefreshingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium);
        await saveLocation(pos.latitude, pos.longitude);
        userArea = null; // force re-resolve of area name
      }
      setState(() => isLoadingMosques = true);
      await _loadNearbyMosques();
    } catch (e) {
      debugPrint('Refresh location error: $e');
    } finally {
      if (mounted) setState(() => _isRefreshingLocation = false);
    }
  }

  void _startTimer() {
    // The countdown display is handled by _PrayerCountdown which owns its own
    // timer. _startTimer here is kept only to update nextPrayerName /
    // nextPrayerTime / selectedPrayerBox on the parent once per minute.
    _timer?.cancel();
    _updateRemainingTime();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _updateRemainingTime();
    });
  }

  void _updateRemainingTime() {
    DateTime now = DateTime.now();
    for (var prayer in prayerTimesList) {
      final timeParts = prayer.time.split(':');
      DateTime prayerTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );

      if (prayerTime.isAfter(now)) {
        nextPrayer = prayer.name;
        nextTime = prayer.time;

        Duration remaining = prayerTime.difference(now);
        int? remainingMinutes;
        remainingMinutes = remaining.inMinutes;
        selectedPrayerBox = remainingMinutes <= 20 ? nextPrayer : currentPrayer;
        if (selectedPrayerBox == "Jumu'ah") selectedPrayerBox = 'Dhuhr';

        if (nextPrayer == 'Fajr' && postMidnight == true) {
          if (!mounted) return;
          setState(() {
            selectedPrayerBox = nextPrayer;
          });
        }
        if (currentPrayer == 'Sunrise') {
          if (!mounted) return;
          setState(() {
            selectedPrayerBox = 'Dhuhr';
          });
        }
        if (currentPrayer == 'Fajr' && nextPrayer == 'Sunrise') {
          setState(() {
            selectedPrayerBox = 'Fajr';
          });
        }
        if (!mounted) return;
        setState(() {
          timeRemaining =
              '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m';
        });

        break;
      } else if (prayerTime.isBefore(now)) {
        currentPrayer = prayer.name;
        currentTime = prayer.time;
        if (prayer.name == 'Fajr') postMidnight = false;
      }
      if (nextPrayer.isEmpty) {
        nextPrayer = 'Fajr';

        final fajrParts = prayerTimesList[0].time.split(':');
        DateTime nextFajrTime = DateTime(
          now.year,
          now.month,
          now.day + 1,
          int.parse(fajrParts[0]),
          int.parse(fajrParts[1]),
        );
        nextTime =
            '${nextFajrTime.hour.toString().padLeft(2, '0')}:${nextFajrTime.minute.toString().padLeft(2, '0')}';

        Duration remaining = nextFajrTime.difference(now);
        if (!mounted) return;
        setState(() {
          selectedPrayerBox = 'Isha';
          timeRemaining =
              '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m';
        });
      }
      if (currentPrayer.isEmpty && prayerTimesList.isNotEmpty) {
        currentPrayer = 'Isha';
        postMidnight = true;
        selectedPrayerBox = nextPrayer;
        if (selectedPrayerBox == "Jumu'ah") selectedPrayerBox = 'Dhuhr';
        currentTime = prayerTimesList.last.time;
      }
    }
  }

  Future<void> _uploadForumData() async {
    if (forumMessageController.text.isNotEmpty) {
      try {
        User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          DocumentSnapshot userDoc =
              await _firestore.collection('UserData').doc(user.uid).get();
          if (userDoc.exists && userDoc.data() != null) {
            String username = userDoc.get('username') ?? 'Unknown User';
            Map<String, dynamic> forumData = {
              'message': forumMessageController.text,
              'datePosted': Timestamp.fromDate(DateTime.now()),
              'userId': user.uid,
              'username': username,
              'upvotes': 0,
              'downvotes': 0,
              'userVotes': {},
              'pinned': false, // ← add
              'replyCount': 0,
            };

            DocumentReference forumDoc =
                await _firestore.collection('ForumData').add(forumData);

            Map<String, dynamic> serializableForumData =
                Map<String, dynamic>.from(forumData);
            serializableForumData['datePosted'] =
                (forumData['datePosted'] as Timestamp)
                    .toDate()
                    .toIso8601String();
            await _firestore.collection('UserData').doc(user.uid).update({
              'postCount': FieldValue.increment(1),
            });

            await _saveForumMessageLocally(serializableForumData);

            forumMessageController.clear();

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Message posted successfully!")),
            );
          }
        } else {
          // ← ADD THIS
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in or sign up to post in the forum'),
              backgroundColor: Color.fromARGB(255, 18, 42, 95),
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to post. Please try again.")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a message before posting!")),
      );
    }
  }

  Future<void> _voteOnMessage(String forumDocId, bool isUpvote) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentReference forumDoc =
            _firestore.collection('ForumData').doc(forumDocId);
        DocumentSnapshot forumSnapshot = await forumDoc.get();

        if (forumSnapshot.exists) {
          Map<String, dynamic> forumData =
              forumSnapshot.data() as Map<String, dynamic>;

          if (forumData['userVotes'].containsKey(user.uid)) {
            String previousVote = forumData['userVotes'][user.uid];

            if (previousVote == (isUpvote ? 'upvote' : 'downvote')) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("You've already voted!")),
              );
              return;
            }

            if (previousVote == 'upvote') {
              forumDoc.update({'upvotes': FieldValue.increment(-1)});
            } else if (previousVote == 'downvote') {
              forumDoc.update({'downvotes': FieldValue.increment(-1)});
            }
          }

          if (isUpvote) {
            forumDoc.update({
              'upvotes': FieldValue.increment(1),
              'userVotes.${user.uid}': 'upvote',
            });
          } else {
            forumDoc.update({
              'downvotes': FieldValue.increment(1),
              'userVotes.${user.uid}': 'downvote',
            });
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isUpvote ? "Upvoted!" : "Downvoted!")),
          );
        }
      }
    } catch (e) {
      print("Error voting on forum message: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Error voting on message!")));
    }
  }

  Future<void> _saveForumMessageLocally(Map<String, dynamic> newMessage) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    List<String>? savedMessages = prefs.getStringList('forumMessages') ?? [];

    List<Map<String, dynamic>> forumMessages = savedMessages
        .map((message) => jsonDecode(message) as Map<String, dynamic>)
        .toList();

    forumMessages.add(newMessage);

    await prefs.setStringList(
      'forumMessages',
      forumMessages.map((message) => jsonEncode(message)).toList(),
    );
  }

  Future<List<Map<String, dynamic>>> _loadForumMessages() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedMessages = prefs.getStringList('forumMessages') ?? [];

    return savedMessages
        .map((message) => jsonDecode(message) as Map<String, dynamic>)
        .toList();
  }

  void _accountsPageGoTo() {
    screenFrom = "Home";
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AccountsOptionsScreen()),
    );
  }

  void _ActivitiesScreenGoTo() {
    screenFrom = "Home";
    DateTime selectedDay = DateTime.now();
    DateTime normalizedDay = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );
    DailyActivity? selectedActivity = dailyActivities[normalizedDay];

    if (dailyActivities.isEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => CalendarScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => dailyActivitiesScreen(
            selectedDate: selectedDay,
            dailyActivity: selectedActivity!,
          ),
        ),
      );
    }
  }

  void _MosqueScreenGoTo() {
    screenFrom = "Home";
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MosqueScreen()),
    );
  }

  void _RadioScreenGoTo() {
    screenFrom = "Home";
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RadioScreen()),
    );
  }

  void _SettingsScreenGoTo() {
    screenFrom = "Home";
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingScreen()),
    );
  }

  Future<void> _checkMosqueAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('displayMosques')
          .doc(user.uid)
          .get();
      if (doc.exists && (doc.data()?['mosqueId'] as String? ?? '').isNotEmpty) {
        final name = (doc.data()?['mosqueName'] as String?) ?? 'My Mosque';
        final id = (doc.data()?['mosqueId'] as String?) ?? '';
        final city = (doc.data()?['mosqueCity'] as String?) ?? ''; // ADD
        if (mounted) {
          setState(() {
            _isMosqueAdmin = true;
            _adminMosqueName = name;
            _adminMosqueId = id; // ADD
            _adminMosqueCity = city; // ADD
          });
        }
      }
    } catch (e) {
      debugPrint('checkMosqueAdmin error: $e');
    }
  }

  void _UploadMosqueGoTo(BuildContext context) async {
    _isAdmin = await isAdminUser();
    screenFrom = "Home";

    if (_isAdmin) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const UploadMosque()),
      );
    } else if (_isMosqueAdmin && _adminMosqueId.isNotEmpty) {
      // Display-screen user — go straight to AI scanner for their own mosque only
      final result = await Navigator.push<List<List<String>>>(
        context,
        MaterialPageRoute(
          builder: (_) => PhotoUploadPage(
            mosqueName: _adminMosqueName,
            mosqueId: _adminMosqueId,
            city: _adminMosqueCity,
          ),
        ),
      );
      if (result != null && mounted) {
        _uploadScannedDataForDisplayUser(result);
      }
    } else if (FirebaseAuth.instance.currentUser != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const UserMosquePickerPage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need to sign in to use this feature'),
          backgroundColor: Color.fromARGB(255, 18, 42, 95),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _uploadScannedDataForDisplayUser(List<List<String>> rows) async {
    // rows format matches PhotoUploadPage output:
    // [0]=date(DD/MM/YYYY), [1]=dayname, [2]=fajrB, [3]=fajrJ, [4]=sunrise,
    // [5]=dhuhrB, [6]=dhuhrJ, [7]=asrB, [8]=asrJ, [9]=maghrib,
    // [10]=ishaB, [11]=ishaJ, [12-15]=jummah1-4 (Fridays only)

    if (_adminMosqueId.isEmpty) return;

    final scaffoldMsg = ScaffoldMessenger.of(context);

    try {
      // Show uploading indicator
      scaffoldMsg.showSnackBar(
        const SnackBar(
          content: Row(children: [
            SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Uploading timetable…'),
          ]),
          backgroundColor: Color.fromARGB(255, 18, 42, 95),
          duration: Duration(seconds: 30),
        ),
      );

      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      for (final row in rows) {
        if (row.length < 12) continue;
        final dateParts = row[0].split('/');
        if (dateParts.length != 3) continue;
        final day = int.tryParse(dateParts[0]);
        final month = int.tryParse(dateParts[1]);
        final year = int.tryParse(dateParts[2]);
        if (day == null || month == null || year == null) continue;

        final isoDate =
            '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

        final jummahTimes = <String>[];
        if (row.length > 12) {
          for (int i = 12; i <= 15 && i < row.length; i++) {
            if (row[i].isNotEmpty) jummahTimes.add(row[i]);
          }
        }

        final docRef = firestore
            .collection('mosques')
            .doc(_adminMosqueId)
            .collection('prayerTimes')
            .doc(isoDate);

        batch.set(docRef, {
          'fajr': row[2],
          'fajrJ': row[3],
          'sunrise': row[4],
          'dhuhr': row[5],
          'dhuhrJ': row[6],
          'asr': row[7],
          'asrJ': row[8],
          'maghrib': row[9],
          'isha': row[10],
          'ishaJ': row[11],
          if (jummahTimes.isNotEmpty) 'jummahTimes': jummahTimes,
        });
      }

      await batch.commit();

      // Also set needsRefresh flag so TV display auto-reloads
      await firestore
          .collection('displayMosques')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({'needsRefresh': true});

      scaffoldMsg.hideCurrentSnackBar();
      scaffoldMsg.showSnackBar(
        SnackBar(
          content: Row(children: const [
            Icon(Icons.check_circle_outline_rounded,
                color: Color.fromARGB(255, 72, 200, 155), size: 18),
            SizedBox(width: 8),
            Text('Timetable uploaded successfully!',
                style: TextStyle(color: Colors.white)),
          ]),
          backgroundColor: const Color.fromARGB(255, 18, 42, 95),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      scaffoldMsg.hideCurrentSnackBar();
      scaffoldMsg.showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e',
              style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
        ),
      );
    }
  }

  void _UploadSubmitionsGoTo(BuildContext context) async {
    _isAdmin = await isAdminUser();
    screenFrom = "Home";

    if (_isAdmin) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AdminSubmissionsScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need to be an admin to use this feature'),
          backgroundColor: Color.fromARGB(255, 18, 42, 95),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _loadCachedData() async {
    final stored = await loadMonthlyPrayerTimes();
    if (stored.isEmpty) return;

    final today = DateFormat('dd-MM-yyyy').format(DateTime.now());
    todayPrayerTimes = stored.firstWhere(
      (p) => p.date == today,
      orElse: () => stored.first,
    );

    if (mounted) {
      updatePrayerTimesList(); // this calls setState internally
      await GetData();
    }
  }

  void _CalenderScreenGoTo() {
    screenFrom = "Home";
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CalendarScreen()),
    );
  }

  void _TasbihScreenGoTo() {
    screenFrom = "Home";
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TasbihScreen()),
    );
  }

  Future<void> _fetchUserData() async {
    try {
      if (!mounted) return;
      User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        print('User is logged in: ${user.email}');
        print('User UID: ${user.uid}');
      } else {
        print('User is not logged in.');
        return;
      }

      String userDocPath = 'UserData/${user.uid}';

      print('Fetching user data from path: $userDocPath');

      DocumentSnapshot userDoc = await _firestore.doc(userDocPath).get();

      if (userDoc.exists) {
        setState(() {
          _userData = userDoc.data() as Map<String, dynamic>;
        });
      } else {
        print('No user data found for UID: ${user.uid}');
        setState(() {
          _userData = null;
        });
      }
    } catch (e) {
      print("Error fetching user data: $e");
      setState(() {});
    }
  }

  // Analytics stripped down to GDPR minimum — only home_screen view is logged.
  // Location, user name, and device ID events removed.
  Future<void> _logUserAndLocation({required String method}) async {
    // no-op — retained so call sites compile without changes
  }

  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('device_id');

    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString('device_id', id);
    }
    return id;
  }

  Future<bool> isAdminUser() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      DocumentSnapshot adminDoc = await FirebaseFirestore.instance
          .collection('Admins')
          .doc(user.uid)
          .get();

      if (adminDoc.exists) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  Future<void> _checkAdmin() async {
    final admin = await isAdminUser();
    if (mounted) setState(() => _isAdmin = admin);
  }

  Future<bool> isForumAdminUser() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      DocumentSnapshot adminDoc = await FirebaseFirestore.instance
          .collection('ForumAdmin')
          .doc(user.uid)
          .get();

      if (adminDoc.exists) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  Future<void> _checkForumAdmin() async {
    final admin = await isForumAdminUser();
    if (mounted) setState(() => _isForumAdmin = admin);
  }

  Future<void> _pinMessage(String forumDocId, bool currentlyPinned) async {
    try {
      await _firestore
          .collection('ForumData')
          .doc(forumDocId)
          .update({'pinned': !currentlyPinned});
    } catch (e) {
      print("Error pinning message: $e");
    }
  }

  Future<void> _deleteMessage(String forumDocId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      // Get the post's userId before deleting
      final doc =
          await _firestore.collection('ForumData').doc(forumDocId).get();
      final postUserId = doc.data()?['userId'] as String?;

      await _firestore.collection('ForumData').doc(forumDocId).delete();

      // Decrement that user's postCount
      if (postUserId != null) {
        await _firestore.collection('UserData').doc(postUserId).update({
          'postCount': FieldValue.increment(-1),
        });
      }
    }
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.yMMMd().format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    double rowHeight = MediaQuery.of(context).size.height;

    const Color navy = Color.fromARGB(
      255,
      10,
      25,
      60,
    ); // ← APP BAR + NAV BAR BG
    const Color navyMid = Color.fromARGB(
      255,
      18,
      42,
      95,
    ); // card surface on hero
    const Color navyLight = Color.fromARGB(
      255,
      28,
      58,
      120,
    ); // lighter navy for borders/fills
    const Color gold = Color.fromARGB(
      255,
      212,
      175,
      95,
    ); // ← NAV BAR SELECTED ICON
    const Color goldLight = Color.fromARGB(
      255,
      252,
      243,
      210,
    ); // gold tint background
    const Color skyBlue = Color.fromARGB(
      255,
      100,
      180,
      240,
    ); // bright sky accent
    const Color skyLight = Color.fromARGB(255, 220, 240, 255); // light sky tint
    const Color mintGreen = Color.fromARGB(
      255,
      72,
      200,
      155,
    ); // mint/teal-green accent
    const Color mintLight = Color.fromARGB(255, 210, 245, 232); // mint tint
    const Color mutedBlue = Color.fromARGB(
      255,
      120,
      155,
      200,
    ); // ← NAV BAR UNSELECTED ICON
    const Color white = Color.fromARGB(255, 255, 255, 255);
    const Color offWhite = Color.fromARGB(
      255,
      247,
      249,
      255,
    ); // blue-tinted white bg
    const Color textDark = Color.fromARGB(255, 15, 30, 65); // deep navy text
    const Color textMid = Color.fromARGB(
      255,
      90,
      115,
      160,
    ); // mid blue-grey text
    const Color border = Color.fromARGB(
      255,
      210,
      220,
      240,
    ); // soft blue-white border
    const Color goldBorder = Color.fromARGB(255, 212, 175, 95); // gold outline

    // ── Shared card decoration ────────────────────────────────────────
    BoxDecoration card({bool goldOutline = false}) => BoxDecoration(
          color: white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: goldOutline ? goldBorder.withOpacity(0.6) : border,
            width: goldOutline ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: navy.withOpacity(0.10),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        );

    const TextStyle sectionLabel = TextStyle(
      fontSize: 11,
      letterSpacing: 1.3,
      fontWeight: FontWeight.w700,
      color: Color.fromARGB(255, 10, 25, 60),
    );

    return Scaffold(
      backgroundColor: navy,
      appBar: buildAppBarHome(context),

      body: RefreshIndicator(
        color: gold,
        backgroundColor: white,
        onRefresh: _refreshAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              const QurbaniBanner(),
              // ── TOP HERO (navy) ───────────────────────────────────
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: navy,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                  // Gold outline on the hero bottom edge
                  border: Border(
                    bottom: BorderSide(
                      color: gold.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Column(
                  children: [
                    // Date bar — gold outlined
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 9,
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        color: navyMid,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: gold.withOpacity(0.55),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            DateFormat('EEEE, d MMM yyyy')
                                .format(DateTime.now()),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: gold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (_hijriDate.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              _hijriDate,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: gold.withOpacity(0.7),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ── Beginning times location button ───────────────
                    GestureDetector(
                      onTap: () async => await changeLocationDialog(),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 18, 42, 95),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: gold.withOpacity(0.4),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.my_location_rounded,
                                size: 14,
                                color: Color.fromARGB(255, 212, 175, 95)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Beginning times location',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Color.fromARGB(180, 212, 175, 95),
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  Text(
                                    townName.isNotEmpty
                                        ? townName
                                        : 'Tap to set location',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: gold,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: gold.withOpacity(0.6),
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(Icons.edit_outlined,
                                  size: 13, color: gold),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Current + Next — kept shorter in height
                    IntrinsicHeight(
                      child: Row(
                        children: [
                          // Current prayer — mint green accent
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: gold.withOpacity(0.55),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: navy.withOpacity(0.25),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: mintGreen,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      const Text(
                                        'CURRENT',
                                        style: TextStyle(
                                          fontSize: 9,
                                          letterSpacing: 1.5,
                                          fontWeight: FontWeight.w700,
                                          color: mintGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    currentPrayerName,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: textDark,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: mintLight,
                                      borderRadius: BorderRadius.circular(7),
                                      border: Border.all(
                                        color: mintGreen.withOpacity(0.4),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      currentPrayerTime,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Color.fromARGB(
                                          255,
                                          30,
                                          140,
                                          105,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),

                          // Next prayer — sky blue accent
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: navyMid,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: gold.withOpacity(0.45),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: skyBlue,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      const Text(
                                        'NEXT',
                                        style: TextStyle(
                                          fontSize: 9,
                                          letterSpacing: 1.5,
                                          fontWeight: FontWeight.w700,
                                          color: skyBlue,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    nextPrayerName,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    nextPrayerTime,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: skyBlue,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  _PrayerCountdown(
                                    nextPrayerTime: nextPrayerTime,
                                    textColor: mutedBlue.withOpacity(0.9),
                                    fontSize: 11,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── WHITE CONTENT AREA ────────────────────────────────
              Container(
                color: offWhite,
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── MOSQUE SECTION HEADER ────────────────────────
                    Row(
                      children: [
                        const Icon(
                          Icons.mosque_outlined,
                          size: 18,
                          color: navy,
                        ),
                        const SizedBox(width: 7),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NEARBY MOSQUE TIMES',
                                style: sectionLabel,
                              ),
                              Text(
                                'Tap a mosque below to view more prayer times',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Color.fromARGB(255, 140, 105, 30),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _sortByTime = !_sortByTime;
                              _sortLoading = true;
                            });
                            _loadNearbyMosques();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _sortByTime
                                  ? const Color.fromARGB(255, 220, 235, 255)
                                  : goldLight,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _sortByTime
                                    ? const Color.fromARGB(255, 80, 120, 200)
                                        .withOpacity(0.7)
                                    : gold.withOpacity(0.6),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _sortLoading
                                    ? const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 1.5,
                                            color: Color.fromARGB(
                                                255, 40, 80, 180)),
                                      )
                                    : Icon(
                                        _sortByTime
                                            ? Icons.access_time_rounded
                                            : Icons.near_me_rounded,
                                        size: 12,
                                        color: _sortByTime
                                            ? const Color.fromARGB(
                                                255, 40, 80, 180)
                                            : const Color.fromARGB(
                                                255, 160, 125, 40),
                                      ),
                                const SizedBox(width: 5),
                                Text(
                                  _sortByTime ? 'Earliest' : 'Nearest',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _sortByTime
                                        ? const Color.fromARGB(255, 40, 80, 180)
                                        : const Color.fromARGB(
                                            255, 140, 105, 30),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        GestureDetector(
                          onTap: () async => await _browseNearbyCityDialog(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _browseCity != null
                                  ? const Color.fromARGB(255, 210, 245, 232)
                                  : goldLight,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _browseCity != null
                                    ? const Color.fromARGB(255, 72, 200, 155)
                                        .withOpacity(0.7)
                                    : gold.withOpacity(0.6),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _browseCity != null
                                      ? Icons.location_city_rounded
                                      : Icons.search_rounded,
                                  size: 12,
                                  color: _browseCity != null
                                      ? const Color.fromARGB(255, 30, 140, 105)
                                      : const Color.fromARGB(255, 160, 125, 40),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _browseCity ?? 'Browse City',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _browseCity != null
                                        ? const Color.fromARGB(
                                            255, 30, 140, 105)
                                        : const Color.fromARGB(
                                            255, 140, 105, 30),
                                  ),
                                ),
                                if (_browseCity != null) ...[
                                  const SizedBox(width: 5),
                                  GestureDetector(
                                    onTap: () async {
                                      setState(() {
                                        _browseCity = null;
                                        isLoadingMosques = true;
                                      });
                                      await _saveBrowseCity(null);
                                      await _loadNearbyMosques();
                                    },
                                    child: const Icon(Icons.close_rounded,
                                        size: 12,
                                        color:
                                            Color.fromARGB(255, 30, 140, 105)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        // ── Refresh browse/nearby location ───────────────
                        GestureDetector(
                          onTap: _isRefreshingLocation
                              ? null
                              : _refreshBrowseLocation,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 220, 235, 255),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color.fromARGB(255, 80, 120, 200)
                                    .withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: _isRefreshingLocation
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: Color.fromARGB(255, 40, 80, 180),
                                    ),
                                  )
                                : const Icon(
                                    Icons.refresh_rounded,
                                    size: 12,
                                    color: Color.fromARGB(255, 40, 80, 180),
                                  ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // ── JUMU'AH CITY TIMES BANNER ────────────────────
                    GestureDetector(
                      onTap: _showJummahCitySheet,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color.fromARGB(255, 10, 25, 60),
                              const Color.fromARGB(255, 18, 42, 95),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color.fromARGB(255, 212, 175, 95)
                                  .withOpacity(0.55),
                              width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color.fromARGB(255, 10, 25, 60)
                                  .withOpacity(0.18),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 212, 175, 95)
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.people_rounded,
                                  color: Color.fromARGB(255, 212, 175, 95),
                                  size: 16),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Jumu\'ah Times',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color.fromARGB(255, 212, 175, 95),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  Text(
                                    'All city times for next Friday',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 212, 175, 95)
                                    .withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color.fromARGB(255, 212, 175, 95)
                                      .withOpacity(0.35),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Text('View',
                                      style: TextStyle(
                                          color:
                                              Color.fromARGB(255, 212, 175, 95),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                  SizedBox(width: 3),
                                  Icon(Icons.arrow_forward_ios_rounded,
                                      size: 10,
                                      color: Color.fromARGB(255, 212, 175, 95)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Mosque card — gold outlined, scrollable list
                    Container(
                      constraints: BoxConstraints(maxHeight: rowHeight * 0.40),
                      decoration: card(goldOutline: true),
                      clipBehavior: Clip.hardEdge,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Prayer selector tabs — sky blue selected
                          Container(
                            color: skyLight,
                            padding: const EdgeInsets.all(7),
                            child: Row(
                              children: [
                                ['Fajr', 'Fajr'],
                                [
                                  'Dhuhr',
                                  DateTime.now().weekday == DateTime.friday
                                      ? "Jumu'ah"
                                      : 'Dhuhr',
                                ],
                                ['Asr', 'Asr'],
                                ['Maghrib', 'Maghrib'],
                                ['Isha', 'Isha'],
                              ].map((pair) {
                                final String value = pair[0];
                                final String label = pair[1];
                                final bool isSelected = selectedPrayerBox ==
                                    value; // ← compares against 'Dhuhr', always works
                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() => selectedPrayerBox = value);
                                      if (_sortByTime) _loadNearbyMosques();
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? navy
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(
                                          10,
                                        ),
                                        border: isSelected
                                            ? Border.all(
                                                color: gold.withOpacity(
                                                  0.5,
                                                ),
                                                width: 1,
                                              )
                                            : null,
                                      ),
                                      child: Text(
                                        label, // ← displays "Jumu'ah" but stores 'Dhuhr'
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected ? gold : textMid,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                          // Mosque list — independently scrollable inside the fixed box
                          Flexible(
                            child: isLoadingMosques
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(20),
                                      child: CircularProgressIndicator(
                                        color: navy,
                                      ),
                                    ),
                                  )
                                : nearbyMosques.isEmpty
                                    ? const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(20),
                                          child: Text(
                                            'No mosques found nearby',
                                            style: TextStyle(
                                              color: textMid,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      )
                                    : ListView.separated(
                                        // Scrollable on its own — doesn't push forum away
                                        physics: const ClampingScrollPhysics(),
                                        shrinkWrap: false,
                                        itemCount: nearbyMosques.length,
                                        separatorBuilder: (_, __) =>
                                            const Divider(
                                                height: 1, color: border),
                                        itemBuilder: (context, index) {
                                          final mosque = nearbyMosques[index];
                                          final fieldKey = prayerFieldMap[
                                              selectedPrayerBox ?? 'Fajr'];
                                          final prayerTimes =
                                              Map<String, dynamic>.from(
                                            mosque['prayerTimes'] ?? {},
                                          );
                                          final prayerTime =
                                              prayerTimes[fieldKey];
                                          final bool isFriday =
                                              DateTime.now().weekday ==
                                                  DateTime.friday;
                                          final List<String> jummahTimes =
                                              isFriday
                                                  ? List<String>.from(
                                                      prayerTimes[
                                                              'jummahTimes'] ??
                                                          [])
                                                  : [];

                                          final String? displayTime = (isFriday &&
                                                  jummahTimes.isNotEmpty &&
                                                  (selectedPrayerBox ==
                                                      'Dhuhr'))
                                              ? null // ← signal to show jummah badges instead
                                              : prayerTimes[fieldKey];

                                          if (displayTime == null &&
                                              !(isFriday &&
                                                  jummahTimes.isNotEmpty &&
                                                  selectedPrayerBox == 'Dhuhr'))
                                            return const SizedBox.shrink();

                                          return InkWell(
                                            onTap: () {
                                              tempMosqueId = mosque['mosqueId'];
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      PrayerTimesScreen(),
                                                ),
                                              );
                                            },
                                            splashColor: navy.withOpacity(0.06),
                                            highlightColor:
                                                navy.withOpacity(0.03),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 11,
                                              ),
                                              child: isFriday &&
                                                      jummahTimes.isNotEmpty &&
                                                      selectedPrayerBox ==
                                                          'Dhuhr'
                                                  // ── Jumu'ah layout: icon + name row, then badges below ──
                                                  ? Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Row(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Container(
                                                              width: 38,
                                                              height: 38,
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: skyLight,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            10),
                                                                border:
                                                                    Border.all(
                                                                  color: skyBlue
                                                                      .withOpacity(
                                                                          0.4),
                                                                  width: 1,
                                                                ),
                                                              ),
                                                              child: const Icon(
                                                                Icons
                                                                    .mosque_outlined,
                                                                size: 18,
                                                                color: navy,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                width: 12),
                                                            Expanded(
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Text(
                                                                    mosque['name'] ??
                                                                        'Unnamed Mosque',
                                                                    style:
                                                                        const TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      fontSize:
                                                                          20,
                                                                      color:
                                                                          textDark,
                                                                    ),
                                                                    softWrap:
                                                                        true,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .visible,
                                                                  ),
                                                                  const SizedBox(
                                                                      height:
                                                                          2),
                                                                  Text(
                                                                    '${mosque['distance'].toStringAsFixed(1)} km away',
                                                                    style:
                                                                        const TextStyle(
                                                                      fontSize:
                                                                          12,
                                                                      color:
                                                                          textMid,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                            height: 8),
                                                        Wrap(
                                                          spacing: 4,
                                                          runSpacing: 4,
                                                          children: jummahTimes
                                                              .asMap()
                                                              .entries
                                                              .map((entry) {
                                                            final labels = [
                                                              "1st",
                                                              "2nd",
                                                              "3rd"
                                                            ];
                                                            final label = entry
                                                                        .key <
                                                                    labels
                                                                        .length
                                                                ? labels[
                                                                    entry.key]
                                                                : '${entry.key + 1}th';
                                                            return Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          8,
                                                                      vertical:
                                                                          5),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: navy,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            10),
                                                                border: Border.all(
                                                                    color: gold
                                                                        .withOpacity(
                                                                            0.7),
                                                                    width: 1.5),
                                                              ),
                                                              child: Text(
                                                                "$label  ${entry.value}",
                                                                style:
                                                                    const TextStyle(
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: gold,
                                                                ),
                                                              ),
                                                            );
                                                          }).toList(),
                                                        ),
                                                      ],
                                                    )
                                                  // ── Normal layout: icon + name + badge in a row ──
                                                  : Row(
                                                      children: [
                                                        Container(
                                                          width: 38,
                                                          height: 38,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: skyLight,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                            border: Border.all(
                                                              color: skyBlue
                                                                  .withOpacity(
                                                                      0.4),
                                                              width: 1,
                                                            ),
                                                          ),
                                                          child: const Icon(
                                                            Icons
                                                                .mosque_outlined,
                                                            size: 18,
                                                            color: navy,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 12),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                mosque['name'] ??
                                                                    'Unnamed Mosque',
                                                                style:
                                                                    const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontSize: 20,
                                                                  color:
                                                                      textDark,
                                                                ),
                                                                softWrap: true,
                                                                overflow:
                                                                    TextOverflow
                                                                        .visible,
                                                              ),
                                                              const SizedBox(
                                                                  height: 2),
                                                              Text(
                                                                '${mosque['distance'].toStringAsFixed(1)} km away',
                                                                style:
                                                                    const TextStyle(
                                                                  fontSize: 12,
                                                                  color:
                                                                      textMid,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      11,
                                                                  vertical: 7),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: navy,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                            border: Border.all(
                                                                color: gold
                                                                    .withOpacity(
                                                                        0.7),
                                                                width: 1.5),
                                                          ),
                                                          child: Text(
                                                            prayerTime ?? '--',
                                                            style: const TextStyle(
                                                                fontSize: 20,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: gold),
                                                          ),
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
                    ),

                    const SizedBox(height: 18),

                    // ── FORUM SECTION HEADER ─────────────────────────
                    Row(
                      children: [
                        const Icon(
                          Icons.forum_outlined,
                          size: 16,
                          color: Color.fromARGB(255, 10, 25, 60),
                        ),
                        const SizedBox(width: 7),
                        const Text('COMMUNITY FORUM', style: sectionLabel),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Forum — fixed height, always visible
                    Container(
                      height: rowHeight * 0.42,
                      decoration: card(goldOutline: true),
                      clipBehavior: Clip.antiAlias,
                      child: Column(children: [
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('ForumData')
                              .where('pinned', isEqualTo: true)
                              .snapshots(),
                          builder: (context, pinnedSnapshot) {
                            if (!pinnedSnapshot.hasData ||
                                pinnedSnapshot.data!.docs.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            final doc = pinnedSnapshot.data!.docs.first;
                            final message = doc.data() as Map<String, dynamic>;
                            message['docId'] = doc.id;
                            final String forumDocId = doc.id;
                            final int upvotes = message['upvotes'] ?? 0;
                            final int downvotes = message['downvotes'] ?? 0;
                            final bool isTrending = upvotes >= 10;
                            final currentUser =
                                FirebaseAuth.instance.currentUser;
                            String? currentVote;
                            if (currentUser != null &&
                                message['userVotes'] != null) {
                              currentVote = (message['userVotes']
                                  as Map<String, dynamic>)[currentUser.uid];
                            }
                            final Color upColor =
                                currentVote == 'upvote' ? mintGreen : textMid;
                            final Color downColor = currentVote == 'downvote'
                                ? const Color(0xFFEF5350)
                                : textMid;
                            final String initials =
                                ((message['username'] ?? 'U') as String)
                                        .trim()
                                        .isNotEmpty
                                    ? (message['username'] as String)
                                        .trim()[0]
                                        .toUpperCase()
                                    : 'U';
                            final DateTime? postedAt = message['datePosted'] !=
                                    null
                                ? (message['datePosted'] as Timestamp).toDate()
                                : null;

                            return Container(
                              margin: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 255, 248, 225),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: gold.withOpacity(0.6), width: 1.5),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 17,
                                        backgroundColor: skyLight,
                                        child: Text(initials,
                                            style: const TextStyle(
                                                color: navy,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13)),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              Text(
                                                  message['username'] ??
                                                      'Unknown',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 13,
                                                      color: textDark)),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: gold.withOpacity(0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                      color: gold
                                                          .withOpacity(0.5)),
                                                ),
                                                child: const Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text('📌',
                                                          style: TextStyle(
                                                              fontSize: 10)),
                                                      SizedBox(width: 3),
                                                      Text('Pinned',
                                                          style: TextStyle(
                                                              fontSize: 10,
                                                              color: Color
                                                                  .fromARGB(
                                                                      255,
                                                                      140,
                                                                      105,
                                                                      30),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600)),
                                                    ]),
                                              ),
                                              if (isTrending) ...[
                                                const SizedBox(width: 4),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange
                                                        .withOpacity(0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                    border: Border.all(
                                                        color: Colors.orange
                                                            .withOpacity(0.4)),
                                                  ),
                                                  child: const Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text('🔥',
                                                            style: TextStyle(
                                                                fontSize: 10)),
                                                        SizedBox(width: 3),
                                                        Text('Trending',
                                                            style: TextStyle(
                                                                fontSize: 10,
                                                                color: Colors
                                                                    .orange,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600)),
                                                      ]),
                                                ),
                                              ],
                                            ]),
                                            Text(
                                                postedAt != null
                                                    ? _timeAgo(postedAt)
                                                    : '',
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: textMid)),
                                          ],
                                        ),
                                      ),
                                      if (_isForumAdmin)
                                        Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              GestureDetector(
                                                onTap: () => _pinMessage(
                                                    forumDocId, true),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        gold.withOpacity(0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    border: Border.all(
                                                        color: gold
                                                            .withOpacity(0.5)),
                                                  ),
                                                  child: const Text('📌',
                                                      style: TextStyle(
                                                          fontSize: 13)),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              GestureDetector(
                                                onTap: () =>
                                                    _deleteMessage(forumDocId),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red
                                                        .withOpacity(0.08),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    border: Border.all(
                                                        color: Colors.red
                                                            .withOpacity(0.3)),
                                                  ),
                                                  child: const Icon(
                                                      Icons
                                                          .delete_outline_rounded,
                                                      size: 15,
                                                      color: Colors.red),
                                                ),
                                              ),
                                            ]),
                                    ],
                                  ),
                                  Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(44, 8, 0, 8),
                                    child: Text(message['message'] ?? '',
                                        style: const TextStyle(
                                            fontSize: 13.5,
                                            color: textDark,
                                            height: 1.4)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 36),
                                    child: Row(children: [
                                      _voteButton(
                                          icon: Icons.thumb_up_outlined,
                                          count: upvotes,
                                          color: upColor,
                                          onTap: () =>
                                              _voteOnMessage(forumDocId, true)),
                                      const SizedBox(width: 12),
                                      _voteButton(
                                          icon: Icons.thumb_down_outlined,
                                          count: downvotes,
                                          color: downColor,
                                          onTap: () => _voteOnMessage(
                                              forumDocId, false)),
                                    ]),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('ForumData')
                                .orderBy('datePosted', descending: true)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(color: navy),
                                );
                              }

                              if (!snapshot.hasData ||
                                  snapshot.data!.docs.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.forum_outlined,
                                        color: mutedBlue.withOpacity(0.4),
                                        size: 40,
                                      ),
                                      const SizedBox(height: 10),
                                      const Text(
                                        'No forum posts yet',
                                        style: TextStyle(
                                          color: textMid,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Be the first to share something!',
                                        style: TextStyle(
                                          color: textMid,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              final forumMessages = snapshot.data!.docs
                                  .map((doc) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    data['docId'] = doc.id;
                                    return data;
                                  })
                                  .where((msg) => msg['pinned'] != true)
                                  .toList();

                              return ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                itemCount: forumMessages.length,
                                separatorBuilder: (_, __) => const SizedBox(
                                    height:
                                        0), // cards handle their own spacing now
                                itemBuilder: (context, index) {
                                  final message = forumMessages[index];
                                  final String forumDocId =
                                      message['docId'] as String;
                                  final int upvotes = message['upvotes'] ?? 0;
                                  final int downvotes =
                                      message['downvotes'] ?? 0;
                                  final bool isPinned =
                                      message['pinned'] ?? false;
                                  final bool isTrending = upvotes >= 10;
                                  final int replyCount =
                                      message['replyCount'] ?? 0;

                                  final currentUser =
                                      FirebaseAuth.instance.currentUser;
                                  String? currentVote;
                                  if (currentUser != null &&
                                      message['userVotes'] != null) {
                                    currentVote = (message['userVotes'] as Map<
                                        String, dynamic>)[currentUser.uid];
                                  }

                                  final Color upColor = currentVote == 'upvote'
                                      ? mintGreen
                                      : textMid;
                                  final Color downColor =
                                      currentVote == 'downvote'
                                          ? const Color(0xFFEF5350)
                                          : textMid;

                                  final String initials =
                                      ((message['username'] ?? 'U') as String)
                                              .trim()
                                              .isNotEmpty
                                          ? (message['username'] as String)
                                              .trim()[0]
                                              .toUpperCase()
                                          : 'U';

                                  final DateTime? postedAt =
                                      message['datePosted'] != null
                                          ? (message['datePosted'] as Timestamp)
                                              .toDate()
                                          : null;

                                  return Container(
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isPinned
                                          ? const Color.fromARGB(
                                              255, 255, 248, 225)
                                          : white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isPinned
                                            ? gold.withOpacity(0.6)
                                            : border,
                                        width: isPinned ? 1.5 : 1,
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // ── Top row: avatar + name + badges + admin actions
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            CircleAvatar(
                                              radius: 17,
                                              backgroundColor: skyLight,
                                              child: Text(initials,
                                                  style: const TextStyle(
                                                      color: navy,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13)),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        message['username'] ??
                                                            'Unknown',
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontSize: 13,
                                                            color: textDark),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      if (isPinned)
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal: 6,
                                                                  vertical: 2),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: gold
                                                                .withOpacity(
                                                                    0.15),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        6),
                                                            border: Border.all(
                                                                color: gold
                                                                    .withOpacity(
                                                                        0.5)),
                                                          ),
                                                          child: const Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Text('📌',
                                                                  style: TextStyle(
                                                                      fontSize:
                                                                          10)),
                                                              SizedBox(
                                                                  width: 3),
                                                              Text('Pinned',
                                                                  style: TextStyle(
                                                                      fontSize:
                                                                          10,
                                                                      color: Color.fromARGB(
                                                                          255,
                                                                          140,
                                                                          105,
                                                                          30),
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600)),
                                                            ],
                                                          ),
                                                        ),
                                                      if (isTrending) ...[
                                                        const SizedBox(
                                                            width: 4),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal: 6,
                                                                  vertical: 2),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors.orange
                                                                .withOpacity(
                                                                    0.12),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        6),
                                                            border: Border.all(
                                                                color: Colors
                                                                    .orange
                                                                    .withOpacity(
                                                                        0.4)),
                                                          ),
                                                          child: const Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Text('🔥',
                                                                  style: TextStyle(
                                                                      fontSize:
                                                                          10)),
                                                              SizedBox(
                                                                  width: 3),
                                                              Text('Trending',
                                                                  style: TextStyle(
                                                                      fontSize:
                                                                          10,
                                                                      color: Colors
                                                                          .orange,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600)),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  Text(
                                                    postedAt != null
                                                        ? _timeAgo(postedAt)
                                                        : 'Unknown time',
                                                    style: const TextStyle(
                                                        fontSize: 11,
                                                        color: textMid),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Admin actions
                                            if (_isForumAdmin)
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  GestureDetector(
                                                    onTap: () => _pinMessage(
                                                        forumDocId, isPinned),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              6),
                                                      decoration: BoxDecoration(
                                                        color: isPinned
                                                            ? gold.withOpacity(
                                                                0.15)
                                                            : offWhite,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        border: Border.all(
                                                            color: isPinned
                                                                ? gold
                                                                    .withOpacity(
                                                                        0.5)
                                                                : border),
                                                      ),
                                                      child: Text(
                                                          isPinned
                                                              ? '📌'
                                                              : '📍',
                                                          style:
                                                              const TextStyle(
                                                                  fontSize:
                                                                      13)),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  GestureDetector(
                                                    onTap: () => _deleteMessage(
                                                        forumDocId),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              6),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red
                                                            .withOpacity(0.08),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        border: Border.all(
                                                            color: Colors.red
                                                                .withOpacity(
                                                                    0.3)),
                                                      ),
                                                      child: const Icon(
                                                          Icons
                                                              .delete_outline_rounded,
                                                          size: 15,
                                                          color: Colors.red),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),

                                        // ── Message body
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              44, 8, 0, 8),
                                          child: Text(
                                            message['message'] ?? '',
                                            style: const TextStyle(
                                                fontSize: 13.5,
                                                color: textDark,
                                                height: 1.4),
                                          ),
                                        ),

                                        // ── Bottom row: votes + reply count
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(left: 36),
                                          child: Row(
                                            children: [
                                              _voteButton(
                                                icon: Icons.thumb_up_outlined,
                                                count: upvotes,
                                                color: upColor,
                                                onTap: () => _voteOnMessage(
                                                    forumDocId, true),
                                              ),
                                              const SizedBox(width: 12),
                                              _voteButton(
                                                icon: Icons.thumb_down_outlined,
                                                count: downvotes,
                                                color: downColor,
                                                onTap: () => _voteOnMessage(
                                                    forumDocId, false),
                                              ),
                                              const Spacer(),
                                              if (replyCount > 0)
                                                Row(
                                                  children: [
                                                    Icon(
                                                        Icons
                                                            .mode_comment_outlined,
                                                        size: 13,
                                                        color: textMid
                                                            .withOpacity(0.7)),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                        '$replyCount ${replyCount == 1 ? 'reply' : 'replies'}',
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            color: textMid
                                                                .withOpacity(
                                                                    0.7))),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ]),
                    ),

                    const SizedBox(height: 12),

                    // ── FORUM INPUT ───────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: gold.withOpacity(0.45),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: navy.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.edit_outlined,
                            size: 17,
                            color: textMid,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                TextField(
                                  controller: forumMessageController,
                                  style: const TextStyle(
                                      fontSize: 14, color: textDark),
                                  decoration: const InputDecoration(
                                    hintText: 'Share with the community…',
                                    hintStyle:
                                        TextStyle(color: textMid, fontSize: 14),
                                    border: InputBorder.none,
                                    contentPadding:
                                        EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  maxLines: 1,
                                  maxLength: 280,
                                  maxLengthEnforcement:
                                      MaxLengthEnforcement.enforced,
                                  buildCounter: (_,
                                          {required currentLength,
                                          required isFocused,
                                          maxLength}) =>
                                      null,
                                ),
                                ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: forumMessageController,
                                  builder: (context, value, _) {
                                    return Text(
                                      '${value.text.length}/280',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: value.text.length > 260
                                            ? Colors.red
                                            : textMid,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _uploadForumData,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: navy,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: gold.withOpacity(0.6),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: navy.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.send_rounded,
                                color: gold,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      bottomNavigationBar: buildBottomNavigationBar(context, 0, _onItemTapped),

      // ══════════════════════════════════════════════════════════════════
      // DRAWER
      // ══════════════════════════════════════════════════════════════════
      drawer: Drawer(
        backgroundColor: offWhite,
        child: Builder(
          builder: (context) {
            double drawerWidth = MediaQuery.of(context).size.width;
            double drawerHeight = MediaQuery.of(context).size.height;

            final drawerOptions = [
              {
                'title': _userData != null
                    ? 'Profile: ${_userData!['displayName']}'
                    : 'Profile: Loading...',
                'onPressed': () {
                  Navigator.pop(context);
                  _accountsPageGoTo();
                },
                'icon': Icons.person_outline_rounded,
              },
              {
                'title': 'Nearby Mosques and Halal Places',
                'onPressed': () {
                  Navigator.pop(context);
                  _MosqueScreenGoTo();
                },
                'icon': Icons.mosque_outlined,
              },
              {
                'title': 'Islamic Calendar',
                'onPressed': () {
                  Navigator.pop(context);
                  _CalenderScreenGoTo();
                },
                'icon': Icons.calendar_today_outlined,
              },
              {
                'title': "Today's Activities",
                'onPressed': () {
                  Navigator.pop(context);
                  _ActivitiesScreenGoTo();
                },
                'icon': Icons.show_chart_rounded,
              },
              {
                'title': 'Tasbih / Zikr',
                'onPressed': () {
                  Navigator.pop(context);
                  _TasbihScreenGoTo();
                },
                'icon': Icons.radio_button_checked_outlined,
              },
              {
                'title': 'Radio',
                'onPressed': () {
                  Navigator.pop(context);
                  _RadioScreenGoTo();
                },
                'icon': Icons.radio_outlined,
              },
              {
                'title': 'Settings',
                'onPressed': () {
                  Navigator.pop(context);
                  _SettingsScreenGoTo();
                },
                'icon': Icons.settings_outlined,
              },
              {
                'title': 'Upload Mosque',
                'onPressed': () {
                  Navigator.pop(context);
                  _UploadMosqueGoTo(context);
                },
                'icon': Icons.upload_outlined,
              },
              if (_isForumAdmin)
                {
                  'title': 'Mosque Submissions',
                  'onPressed': () {
                    Navigator.pop(context);
                    _UploadSubmitionsGoTo(context);
                  },
                  'icon': Icons.download,
                },
              if (_isMosqueAdmin)
                {
                  'title': 'Mosque Admin',
                  'subtitle': _adminMosqueName, // shown as subtitle
                  'onPressed': () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MosqueAdminScreen(),
                      ),
                    );
                  },
                  'icon': Icons.admin_panel_settings_outlined,
                },
            ];

            // Cycle through accent colours for drawer icons
            const List<Color> iconBgs = [
              skyLight,
              mintLight,
              skyLight,
              mintLight,
              skyLight,
              mintLight,
              skyLight,
              mintLight,
              skyLight,
              mintLight,
            ];
            const List<Color> iconColors = [
              navy,
              Color.fromARGB(255, 30, 140, 105),
              navy,
              Color.fromARGB(255, 30, 140, 105),
              navy,
              Color.fromARGB(255, 30, 140, 105),
              navy,
              Color.fromARGB(255, 30, 140, 105),
              navy,
              Color.fromARGB(255, 30, 140, 105),
            ];

            return Column(
              children: [
                // Drawer header
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                    drawerWidth * 0.05,
                    drawerHeight * 0.06,
                    drawerWidth * 0.05,
                    drawerHeight * 0.03,
                  ),
                  decoration: BoxDecoration(
                    color: navy,
                    border: Border(
                      bottom: BorderSide(
                        color: gold.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_rounded,
                            color: white,
                            size: 18,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                'Ihsan',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                'Perfection',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: gold.withOpacity(0.85),
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 25),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    itemCount: drawerOptions.length,
                    itemBuilder: (context, index) {
                      final option = drawerOptions[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: border, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: navy.withOpacity(0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 2,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: iconBgs[index],
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(
                              option['icon'] as IconData,
                              size: 20,
                              color: iconColors[index],
                            ),
                          ),
                          title: Text(
                            option['title'] as String,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: textDark,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: textMid,
                          ),
                          onTap: option['onPressed'] as void Function(),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Helper: reusable vote button ──────────────────────────────────
  Widget _voteButton({
    required IconData icon,
    required int count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              count.toString(),
              style: TextStyle(fontSize: 13, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Self-contained countdown widget ──────────────────────────────────────────
// Owns its own 1-second timer so the parent screen never rebuilds on each tick.
class _PrayerCountdown extends StatefulWidget {
  final String nextPrayerTime; // "HH:mm"
  final Color textColor;
  final double fontSize;

  const _PrayerCountdown({
    required this.nextPrayerTime,
    required this.textColor,
    required this.fontSize,
  });

  @override
  State<_PrayerCountdown> createState() => _PrayerCountdownState();
}

class _PrayerCountdownState extends State<_PrayerCountdown> {
  Timer? _timer;
  String _display = '';

  @override
  void initState() {
    super.initState();
    _update();
    final msUntilNextSecond = 1000 - DateTime.now().millisecond;
    Future.delayed(Duration(milliseconds: msUntilNextSecond), () {
      if (!mounted) return;
      _update();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) _update();
      });
    });
  }

  @override
  void didUpdateWidget(_PrayerCountdown old) {
    super.didUpdateWidget(old);
    if (old.nextPrayerTime != widget.nextPrayerTime) _update();
  }

  void _update() {
    final now = DateTime.now();
    final parts = widget.nextPrayerTime.split(':');
    if (parts.length < 2) return;
    DateTime target = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }
    final remaining = target.difference(now);
    final h = remaining.inHours;
    final m = remaining.inMinutes.remainder(60);
    final s = remaining.inSeconds.remainder(60);
    final str = h > 0 ? '${h}h ${m}m ${s}s' : '${m}m ${s}s';
    if (mounted) setState(() => _display = str);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.timer_outlined, size: 11, color: widget.textColor),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            _display,
            style:
                TextStyle(fontSize: widget.fontSize, color: widget.textColor),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// JUMU'AH CITY SHEET
// Shows all mosques in the user's city with their next upcoming Jumu'ah times,
// sorted earliest first. Loads from Firestore on open.
// ══════════════════════════════════════════════════════════════════════════════
class _JummahCitySheet extends StatefulWidget {
  final String city;
  final String fridayDateStr; // ISO date of next Friday e.g. "2025-04-04"
  final String fridayLabel; // Display label e.g. "This Friday" or "Fri 4/4"
  final double userLat;
  final double userLng;

  const _JummahCitySheet({
    required this.city,
    required this.fridayDateStr,
    required this.fridayLabel,
    required this.userLat,
    required this.userLng,
  });

  @override
  State<_JummahCitySheet> createState() => _JummahCitySheetState();
}

class _JummahCitySheetState extends State<_JummahCitySheet> {
  static const Color _navy = Color.fromARGB(255, 10, 25, 60);
  static const Color _navyMid = Color.fromARGB(255, 18, 42, 95);
  static const Color _gold = Color.fromARGB(255, 212, 175, 95);
  static const Color _goldLight = Color.fromARGB(255, 252, 243, 210);
  static const Color _white = Color.fromARGB(255, 255, 255, 255);
  static const Color _offWhite = Color.fromARGB(255, 247, 249, 255);
  static const Color _textDark = Color.fromARGB(255, 15, 30, 65);
  static const Color _textMid = Color.fromARGB(255, 90, 115, 160);
  static const Color _border = Color.fromARGB(255, 210, 220, 240);
  static const Color _mintGreen = Color.fromARGB(255, 72, 200, 155);

  bool _isLoading = true;
  String? _error;
  bool _sortEarliest = true; // true = earliest first, false = nearest first

  // Each entry: { 'name': String, 'times': List<String> }
  List<Map<String, dynamic>> _entries = [];

  List<Map<String, dynamic>> get _sortedEntries {
    final list = List<Map<String, dynamic>>.from(_entries);
    if (_sortEarliest) {
      list.sort((a, b) {
        final aFirst = (a['times'] as List<String>).first;
        final bFirst = (b['times'] as List<String>).first;
        final cmp = _timeKey(aFirst).compareTo(_timeKey(bFirst));
        if (cmp != 0) return cmp;
        return (a['name'] as String).compareTo(b['name'] as String);
      });
    } else {
      list.sort((a, b) => ((a['distance'] as double?) ?? double.infinity)
          .compareTo((b['distance'] as double?) ?? double.infinity));
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('mosques')
          .where('city', isEqualTo: widget.city)
          .get();

      // Fetch each mosque's Friday prayer times doc in parallel
      final futures = snap.docs.map((doc) async {
        final name = (doc.data()['name'] ?? 'Unnamed') as String;
        final GeoPoint? geo = doc.data()['location'] as GeoPoint?;
        final double distKm = geo != null
            ? Geolocator.distanceBetween(widget.userLat, widget.userLng,
                    geo.latitude, geo.longitude) /
                1000
            : double.infinity;
        final fridayDoc = await FirebaseFirestore.instance
            .collection('mosques')
            .doc(doc.id)
            .collection('prayerTimes')
            .doc(widget.fridayDateStr)
            .get();

        if (!fridayDoc.exists) return null;
        final data = fridayDoc.data()!;
        final raw = data['jummahTimes'];
        if (raw == null) return null;
        final List<String> times = (raw as List)
            .map((v) => v?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        if (times.isEmpty) return null;
        return {'name': name, 'times': times, 'distance': distKm};
      }).toList();

      final results = await Future.wait(futures);
      final List<Map<String, dynamic>> entries =
          results.whereType<Map<String, dynamic>>().toList();

      if (mounted)
        setState(() {
          _entries = entries;
          _isLoading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = 'Failed to load: $e';
          _isLoading = false;
        });
    }
  }

  String _timeKey(String t) {
    final p = t.split(':');
    if (p.length < 2) return '9999';
    return p[0].padLeft(2, '0') + p[1].padLeft(2, '0');
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: _offWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          // ── Handle ───────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: _textMid.withOpacity(0.25),
                borderRadius: BorderRadius.circular(2)),
          ),

          // ── Header ───────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            decoration: const BoxDecoration(
              color: _navy,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _gold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.people_rounded,
                        color: _gold, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Jumu'ah Times",
                          style: TextStyle(
                              color: _gold,
                              fontSize: 17,
                              fontWeight: FontWeight.w700)),
                      Text('${widget.city}  ·  ${widget.fridayLabel}',
                          style: TextStyle(
                              color: _white.withOpacity(0.5), fontSize: 11)),
                    ],
                  )),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close_rounded,
                        color: _white.withOpacity(0.4), size: 20),
                  ),
                ]),
                const SizedBox(height: 10),
                // Summary pill + sort toggle
                if (!_isLoading && _entries.isNotEmpty)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _gold.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: _gold.withOpacity(0.3), width: 1),
                        ),
                        child: Text(
                          '${_entries.length} mosques with Jumu\'ah times',
                          style: TextStyle(
                              color: _gold.withOpacity(0.85),
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _sortEarliest = !_sortEarliest),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: _sortEarliest
                                ? const Color.fromARGB(255, 40, 60, 110)
                                : const Color.fromARGB(255, 30, 50, 95),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: _gold.withOpacity(0.35), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _sortEarliest
                                    ? Icons.access_time_rounded
                                    : Icons.near_me_rounded,
                                size: 11,
                                color: _gold.withOpacity(0.85),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _sortEarliest ? 'Earliest' : 'Nearest',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: _gold.withOpacity(0.85)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _gold))
                : _error != null
                    ? Center(
                        child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(_error!,
                                style: const TextStyle(color: _textMid),
                                textAlign: TextAlign.center)))
                    : _entries.isEmpty
                        ? Center(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                Icon(Icons.event_busy_rounded,
                                    size: 48, color: _textMid.withOpacity(0.3)),
                                const SizedBox(height: 12),
                                Text(
                                  'No Jumu\'ah times uploaded\nfor ${widget.city}',
                                  style: const TextStyle(
                                      color: _textMid,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500),
                                  textAlign: TextAlign.center,
                                ),
                              ]))
                        : ListView.separated(
                            controller: ctrl,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            itemCount: _sortedEntries.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final entry = _sortedEntries[i];
                              final String name = entry['name'] as String;
                              final List<String> times =
                                  entry['times'] as List<String>;
                              final labels = ['1st', '2nd', '3rd'];

                              return Container(
                                decoration: BoxDecoration(
                                  color: _white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: _border, width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _navy.withOpacity(0.06),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 38,
                                            height: 38,
                                            decoration: BoxDecoration(
                                              color: _goldLight,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                  color:
                                                      _gold.withOpacity(0.35),
                                                  width: 1),
                                            ),
                                            child: const Icon(
                                                Icons.mosque_outlined,
                                                size: 18,
                                                color: _navy),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: _textDark,
                                              ),
                                              softWrap: true,
                                              overflow: TextOverflow.visible,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children:
                                            times.asMap().entries.map((e) {
                                          final label = e.key < labels.length
                                              ? labels[e.key]
                                              : '${e.key + 1}th';
                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: _navy,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: _gold.withOpacity(0.7),
                                                  width: 1.5),
                                            ),
                                            child: Text(
                                              '$label  ${e.value}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: _gold,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
          ),
        ]),
      ),
    );
  }
}
