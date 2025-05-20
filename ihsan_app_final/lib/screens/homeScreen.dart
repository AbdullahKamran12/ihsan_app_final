import 'package:flutter/material.dart';
import 'package:ihsan_app_final/screens/dailyActivities.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'package:ihsan_app_final/sharedWidgets.dart';
import 'package:ihsan_app_final/screens/moreoptionsScreen.dart';
import 'package:ihsan_app_final/screens/prayerScreen.dart';
import 'package:ihsan_app_final/screens/qiblaScreen.dart';
import 'package:ihsan_app_final/screens/quranScreen.dart';
import 'package:ihsan_app_final/screens/prayerTimesClass.dart';

import 'package:ihsan_app_final/screens/accountsOptionsPage.dart';
import 'package:ihsan_app_final/screens/calender.dart';
import 'package:ihsan_app_final/screens/nearbyMosquesHalaScreen.dart';
import 'package:ihsan_app_final/screens/settings.dart';
import 'package:ihsan_app_final/screens/tasbih.dart';
import 'package:ihsan_app_final/screens/radio.dart';

bool _isDialogShown = false;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _hasNavigated = false;

  Future<PrayerTimes>? _prayerTimesFuture;

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
        remainingTime =
            '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m';
        break;
      } else if (prayerTime.isBefore(now)) {
        currentPrayer = prayer.name;
        currentTime = prayer.time;
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
      remainingTime =
          '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m';
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
        remainingTime =
            '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m';
        break;
      } else if (prayerTime.isBefore(now)) {
        currentPrayer = prayer.name;
        currentTime = prayer.time;
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
      remainingTime =
          '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m';
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

  void refreshForumStream(Function setStateCallback) {
    setStateCallback();
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

  Future<int> showSimpleDialog(BuildContext context) async {
    int? result = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Location Retrieval"),
          content:
              const Text("How would you like your location to be retrieved?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(0);
                print("Manual selected");
              },
              child: const Text("Manual"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(1);
                print("Automatic selected");
              },
              child: const Text("Automatic"),
            ),
          ],
        );
      },
    );

    return result ?? -1;
  }

  Future<void> showTownInputDialog(BuildContext context) async {
    TextEditingController textController = TextEditingController();
    List<String> citySuggestions = [];

    Future<void> getCitySuggestions(String input) async {
      final String url =
          'https://nominatim.openstreetmap.org/search?q=$input&format=json&limit=5';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          citySuggestions = List<String>.from(
              data.map((city) => city['display_name'].toString()));
          setState(() {});
        }
      }
    }

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            bool isLoadingBool = false;
            return AlertDialog(
              title: const Text(
                  "Enter Town Name (Wait for the names dropdown to load)"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue value) async {
                      if (value.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      setState(() {
                        isLoadingBool = true;
                      });
                      await getCitySuggestions(value.text);
                      setState(() {
                        isLoadingBool = false;
                      });
                      return citySuggestions;
                    },
                    onSelected: (String selectedCity) {
                      textController.text = selectedCity;
                      townName = selectedCity;
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onEditingComplete) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration:
                            const InputDecoration(hintText: "Enter town name"),
                        onEditingComplete: onEditingComplete,
                      );
                    },
                    // Custom options view to show a loading indicator
                    optionsViewBuilder: (BuildContext context,
                        AutocompleteOnSelected<String> onSelected,
                        Iterable<String> options) {
                      if (isLoadingBool) {
                        return Center(
                          child: Container(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                CircularProgressIndicator(),
                                SizedBox(width: 8),
                                Text("Loading options, please wait..."),
                              ],
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
                            child: ListView.builder(
                              padding: const EdgeInsets.all(8.0),
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  title: Text(option),
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
                    Navigator.of(context).pop();
                  },
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () async {
                    townName = textController.text;
                    List<double> latLng = await getLatLngFromCity(townName);
                    latitude = latLng[0];
                    longitude = latLng[1];
                    await saveLocation(latitude, longitude);
                    await initializeMonthlyPrayerTimes(); // Ensure this is called
                    await GetData();
                    Navigator.of(context).pop();
                    GetData();
                  },
                  child: const Text("Update"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> getCurrentLocation() async {
    PermissionStatus permissionStatus = await Permission.location.status;

    if (!permissionStatus.isGranted) {
      PermissionStatus status = await Permission.location.request();

      if (status.isGranted) {
        print('Location permission granted');
      } else {
        print('Location permission denied');
        await showTownInputDialog(context);
        await GetData();
        return;
      }
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      latitude = position.latitude;
      longitude = position.longitude;
      saveLocation(latitude, longitude);

      print('Latitude: $latitude, Longitude: $longitude');

      await updateTownNameFromCoordinates(latitude, longitude);
    } catch (e) {
      print('Failed to get location: $e');
      await showTownInputDialog(context);
      await GetData();
    }
  }

  Future<void> updateTownNameFromCoordinates(
      double latitude, double longitude) async {
    final String url =
        'https://nominatim.openstreetmap.org/reverse?lat=$latitude&lon=$longitude&format=json';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['address'] != null && data['address']['town'] != null) {
        townName = data['address']['town'];
      } else if (data['address'] != null && data['address']['city'] != null) {
        townName = data['address']['city'];
      } else {
        townName = 'Unknown Location';
      }
    } else {
      print('Failed to fetch town name: ${response.reasonPhrase}');
      townName = 'Unknown Location';
    }
  }

  Future<void> initializeMonthlyPrayerTimes() async {
    List<PrayerTimes> storedPrayerTimes = await loadMonthlyPrayerTimes();
    String todayDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
    DateTime now = DateTime.now();

    if (storedPrayerTimes.isEmpty ||
        storedPrayerTimes.any((prayerTime) {
          DateTime prayerDate = DateFormat('dd-MM-yyyy').parse(prayerTime.date);
          return prayerDate.month != now.month || prayerDate.year != now.year;
        }) ||
        change == true) {
      try {
        List<PrayerTimes> monthlyPrayerTimes = await fetchMonthlyPrayerTimes(
            latitude, longitude, method, school, year, month);

        monthlyPrayerTimesList = monthlyPrayerTimes;
        await saveMonthlyPrayerTimes(monthlyPrayerTimesList);

        todayPrayerTimes = monthlyPrayerTimes.firstWhere(
            (prayerTime) => prayerTime.date == todayDate,
            orElse: () => throw Exception('No prayer times for today'));

        updatePrayerTimesList();
        await _savePrayerTimesToLocal(
            todayPrayerTimes!, todayPrayerTimes!.date);

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

  Future<void> _initializeData() async {
    try {
      final lastKnownLocation = await getLastKnownLocation();

      if (lastKnownLocation == null && !_isDialogShown) {
        _isDialogShown = true;
        int result = await showSimpleDialog(context);

        if (result == 0) {
          await showTownInputDialog(context);
          List<double> latLng = await getLatLngFromCity(townName);
          latitude = latLng[0];
          longitude = latLng[1];
          await saveLocation(latitude, longitude);
          await initializeMonthlyPrayerTimes();
          await GetData();
        } else if (result == 1) {
          await getCurrentLocation();
          await initializeMonthlyPrayerTimes();
          await GetDataAuto();
        }
      } else if (lastKnownLocation != null) {
        latitude = lastKnownLocation['latitude']!;
        longitude = lastKnownLocation['longitude']!;
        await updateTownNameFromCoordinates(latitude, longitude);
        await initializeMonthlyPrayerTimes();
        await GetDataAuto();
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

  Future<void> saveMonthlyPrayerTimes(List<PrayerTimes> prayerTimesList) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> jsonList =
        prayerTimesList.map((prayer) => prayer.toJson()).toList();
    String jsonString = jsonEncode(jsonList);
    await prefs.setString('monthlyPrayerTimes', jsonString);
  }

  Future<List<PrayerTimes>> loadMonthlyPrayerTimes() async {
    final prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString('monthlyPrayerTimes');

    if (jsonString != null) {
      List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => PrayerTimes.fromJson(json)).toList();
    } else {
      return [];
    }
  }

  Future<void> _savePrayerTimesToLocal(
      PrayerTimes prayerTimes, String date) async {
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
          PrayerTime('Dhuhr', todayPrayerTimes!.dhuhr, ""),
          PrayerTime('Asr', todayPrayerTimes!.asr, ""),
          PrayerTime('Maghrib', todayPrayerTimes!.maghrib, ""),
          PrayerTime('Isha', todayPrayerTimes!.isha, ""),
        ];
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    loadAdjustments();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeData();
    });
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    DateTime now = DateTime.now();
    int secondsUntilNextMinute = 60 - now.second;

    Future.delayed(Duration(seconds: secondsUntilNextMinute), () {
      _updateRemainingTime();
      _timer = Timer.periodic(Duration(minutes: 1), (timer) {
        _updateRemainingTime();
      });
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
        remainingTime =
            '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m';
        break;
      } else if (prayerTime.isBefore(now)) {
        currentPrayer = prayer.name;
        currentTime = prayer.time;
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
      remainingTime =
          '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m';
    }
    if (mounted) {
      setState(() {
        this.nextPrayerName = nextPrayer;
        this.nextPrayerTime = nextTime;
        this.timeRemaining = remainingTime;
        this.currentPrayerName = currentPrayer;
        this.currentPrayerTime = currentTime;
      });
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
            };

            DocumentReference forumDoc =
                await _firestore.collection('ForumData').add(forumData);

            Map<String, dynamic> serializableForumData =
                Map<String, dynamic>.from(forumData);
            serializableForumData['datePosted'] =
                (forumData['datePosted'] as Timestamp)
                    .toDate()
                    .toIso8601String();

            await _saveForumMessageLocally(serializableForumData);

            forumMessageController.clear();

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Message posted successfully!")),
            );
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Service not available without login")),
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
              forumDoc.update({
                'upvotes': FieldValue.increment(-1),
              });
            } else if (previousVote == 'downvote') {
              forumDoc.update({
                'downvotes': FieldValue.increment(-1),
              });
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error voting on message!")),
      );
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
    DateTime normalizedDay =
        DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
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

  @override
  Widget build(BuildContext context) {
    if (prayerTimesList.isEmpty) {
      return Scaffold(
        backgroundColor: const Color.fromARGB(255, 105, 170, 190),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    double rowWidth = MediaQuery.of(context).size.width;
    double rowHeight = MediaQuery.of(context).size.height;

    // Enhanced color scheme
    final deepBlue = const Color.fromARGB(255, 26, 77, 124);
    final accentBlue = const Color.fromARGB(255, 46, 108, 164);
    final lightGold = const Color.fromARGB(255, 255, 215, 0);
    const Color offWhite = Color.fromARGB(255, 248, 248, 248);
    const Color textDark = Color.fromARGB(255, 51, 51, 51);

    // Enhanced shadows for depth
    final boxShadow = [
      BoxShadow(
        color: Colors.black.withOpacity(0.15),
        offset: const Offset(0, 3),
        blurRadius: 6,
        spreadRadius: 1,
      )
    ];

    // Rich gradient for containers
    final blueGradient = LinearGradient(
      colors: [deepBlue, accentBlue],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 105, 170, 190),
      appBar: buildAppBarHome(context),
      body: RefreshIndicator(
        onRefresh: () async {
          refreshForumStream(() {});
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Column(
              children: [
                // Date Container - Enhanced with better spacing and typography
                Container(
                  width: double.infinity,
                  height: 56,
                  margin: const EdgeInsets.only(bottom: 12.0),
                  decoration: BoxDecoration(
                    gradient: blueGradient,
                    borderRadius: BorderRadius.circular(12.0),
                    boxShadow: boxShadow,
                    border: Border.all(color: lightGold, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      DateFormat.yMMMMd().format(DateTime.now()),
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: offWhite,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                // Prayer information cards with improved layout
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current Prayer Card
                    Expanded(
                      child: Container(
                        height: rowHeight * 0.15,
                        margin: const EdgeInsets.only(right: 6.0, bottom: 16.0),
                        decoration: BoxDecoration(
                          gradient: blueGradient,
                          borderRadius: BorderRadius.circular(12.0),
                          boxShadow: boxShadow,
                          border: Border.all(color: lightGold, width: 1.5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Current Prayer",
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                currentPrayerName,
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currentPrayerTime,
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withOpacity(0.95),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Next Prayer Card
                    Expanded(
                      child: Container(
                        height: rowHeight * 0.15,
                        margin: const EdgeInsets.only(left: 6.0, bottom: 16.0),
                        decoration: BoxDecoration(
                          gradient: blueGradient,
                          borderRadius: BorderRadius.circular(12.0),
                          boxShadow: boxShadow,
                          border: Border.all(color: lightGold, width: 1.5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Next Prayer",
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                nextPrayerName,
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                nextPrayerTime,
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    color: Colors.white.withOpacity(0.9),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    timeRemaining,
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Forum Section Header
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.forum_outlined,
                        color: deepBlue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Community Forum",
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: deepBlue,
                        ),
                      ),
                    ],
                  ),
                ),

                // Forum Stream Container with refined design
                Container(
                  width: double.infinity,
                  height: rowHeight * 0.35,
                  decoration: BoxDecoration(
                    color: offWhite,
                    borderRadius: BorderRadius.circular(16.0),
                    boxShadow: boxShadow,
                  ),
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('ForumData')
                        .orderBy('datePosted', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.forum_outlined,
                                color: Colors.grey[400],
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "No forum posts yet",
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Be the first to share something!",
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      var forumMessages = snapshot.data!.docs.map((doc) {
                        Map<String, dynamic> data =
                            doc.data() as Map<String, dynamic>;
                        data['docId'] = doc.id;
                        return data;
                      }).toList();

                      return ListView.separated(
                        padding: const EdgeInsets.all(12.0),
                        itemCount: forumMessages.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final message = forumMessages[index];
                          final String forumDocId = message['docId'] as String;
                          final int upvotes = message['upvotes'] ?? 0;
                          final int downvotes = message['downvotes'] ?? 0;

                          User? currentUser = FirebaseAuth.instance.currentUser;
                          String? currentVote;
                          if (currentUser != null &&
                              message['userVotes'] != null) {
                            currentVote = (message['userVotes']
                                as Map<String, dynamic>)[currentUser.uid];
                          }

                          Color upVoteColor = (currentVote == 'upvote')
                              ? Colors.green
                              : Colors.grey;
                          Color downVoteColor = (currentVote == 'downvote')
                              ? Colors.red
                              : Colors.grey;

                          return Card(
                            elevation: 0,
                            color: Colors.transparent,
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // User and Timestamp Row
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor:
                                          accentBlue.withOpacity(0.2),
                                      radius: 16,
                                      child: Text(
                                        (message['username'] ?? 'U')[0]
                                            .toUpperCase(),
                                        style: TextStyle(
                                          color: deepBlue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            message['username'] ??
                                                'Unknown User',
                                            style: TextStyle(
                                              fontFamily: 'Roboto',
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: deepBlue,
                                            ),
                                          ),
                                          Text(
                                            message['datePosted'] != null
                                                ? DateFormat.yMMMd()
                                                    .add_jm()
                                                    .format(
                                                      (message['datePosted']
                                                              as Timestamp)
                                                          .toDate(),
                                                    )
                                                : 'No timestamp',
                                            style: TextStyle(
                                              fontFamily: 'Roboto',
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                // Message Content
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12.0,
                                    horizontal: 8.0,
                                  ),
                                  child: Text(
                                    message['message'] ?? 'No content',
                                    style: const TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 14,
                                      color: textDark,
                                    ),
                                  ),
                                ),

                                // Voting Action Buttons
                                Row(
                                  children: [
                                    Material(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(20),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: () {
                                          _voteOnMessage(forumDocId, true);
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.thumb_up_outlined,
                                                size: 18,
                                                color: upVoteColor,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                upvotes.toString(),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: upVoteColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Material(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(20),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: () {
                                          _voteOnMessage(forumDocId, false);
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.thumb_down_outlined,
                                                size: 18,
                                                color: downVoteColor,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                downvotes.toString(),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: downVoteColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // Enhanced Forum Post Input Section
                Container(
                  margin: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    color: offWhite,
                    borderRadius: BorderRadius.circular(24.0),
                    boxShadow: boxShadow,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: forumMessageController,
                          decoration: InputDecoration(
                            hintText: 'Share whats happening...',
                            hintStyle: TextStyle(color: Colors.grey[500]),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12.0),
                          ),
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 15,
                            color: textDark,
                          ),
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Material(
                        color: deepBlue,
                        borderRadius: BorderRadius.circular(50),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(50),
                          onTap: _uploadForumData,
                          child: Container(
                            padding: const EdgeInsets.all(10.0),
                            child: const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
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
      ),
      bottomNavigationBar: buildBottomNavigationBar(context, 0, _onItemTapped),
      drawer: Drawer(
        backgroundColor: const Color.fromARGB(255, 105, 170, 190),
        child: Builder(
          builder: (context) {
            double drawerWidth = MediaQuery.of(context).size.width;
            double drawerHeight = MediaQuery.of(context).size.height;

            double horizontalPadding = drawerWidth * 0.02;
            double verticalPadding = drawerHeight * 0.04;

            final drawerOptions = [
              {
                'title': _userData != null
                    ? 'Profile: ${_userData!['displayName']}'
                    : 'Profile: Loading...',
                'onPressed': () {
                  Navigator.pop(context);
                  _accountsPageGoTo();
                },
                'icon': Icons.person,
              },
              {
                'title': 'Nearby Mosques',
                'onPressed': () {
                  Navigator.pop(context);
                  _MosqueScreenGoTo();
                },
                'icon': Icons.mosque,
              },
              {
                'title': 'Islamic Calendar',
                'onPressed': () {
                  Navigator.pop(context);
                  _CalenderScreenGoTo();
                },
                'icon': Icons.calendar_today,
              },
              {
                'title': "Today's Activites",
                'onPressed': () {
                  Navigator.pop(context);
                  _ActivitiesScreenGoTo();
                },
                'icon': Icons.show_chart,
              },
              {
                'title': 'Tasbih/Zikr',
                'onPressed': () {
                  Navigator.pop(context);
                  _TasbihScreenGoTo();
                },
                'icon': Icons.fiber_manual_record,
              },
              {
                'title': 'Radio',
                'onPressed': () {
                  Navigator.pop(context);
                  _RadioScreenGoTo();
                },
                'icon': Icons.radio,
              },
              {
                'title': 'Settings',
                'onPressed': () {
                  Navigator.pop(context);
                  _SettingsScreenGoTo();
                },
                'icon': Icons.settings,
              },
            ];

            return Column(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: verticalPadding,
                  ),
                  decoration: BoxDecoration(
                    color: deepBlue.withOpacity(0.8),
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        IconButton(
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                        Expanded(
                          child: Text(
                            'Ihsan - Perfection',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: offWhite,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 40), // Balance the back button
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12.0, horizontal: 16.0),
                    itemCount: drawerOptions.length,
                    itemBuilder: (context, index) {
                      final option = drawerOptions[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                            )
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 6.0,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: deepBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Icon(
                              option['icon'] as IconData,
                              size: 22,
                              color: deepBlue,
                            ),
                          ),
                          title: Text(
                            option['title'] as String,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: textDark,
                            ),
                          ),
                          onTap: option['onPressed'] as void Function(),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
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
}
