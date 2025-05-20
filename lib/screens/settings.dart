import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:ihsan_app_final/screens/moreoptionsScreen.dart';
import 'package:ihsan_app_final/screens/prayerScreen.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:ihsan_app_final/screens/prayerTimesClass.dart';
import 'package:ihsan_app_final/screens/SettingsScreens/prayerTimeSettings.dart';
import 'package:ihsan_app_final/sharedWidgets.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  _SettingScreenState createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  Future<PrayerTimes>? _prayerTimesFuture;

  String nextPrayerName = "Loading...";
  String nextPrayerTime = "Loading...";
  String currentPrayerName = "Loading...";
  String currentPrayerTime = "Loading...";
  String timeRemaining = "Loading...";

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
                    change = true;
                    Navigator.of(context).pop();
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

  final deepBlue = const Color(0xFF003366);

  Future<void> getCurrentLocation() async {
    PermissionStatus permissionStatus = await Permission.location.status;

    if (!permissionStatus.isGranted) {
      PermissionStatus status = await Permission.location.request();

      if (status.isGranted) {
        print('Location permission granted');
      } else {
        print('Location permission denied');
        await showTownInputDialog(context);
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

  void locationPopup() async {
    print('clicked pop-up button');
    int result = await showSimpleDialog(context);

    if (result == 0) {
      await showTownInputDialog(context);
      List<double> latLng = await getLatLngFromCity(townName);
      latitude = latLng[0];
      longitude = latLng[1];
      await saveLocation(latitude, longitude);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PrayerTimesScreen()),
      );
    } else if (result == 1) {
      setState(() {
        getCurrentLocation();
      });
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PrayerTimesScreen()),
      );
    }
  }

  void _TimeScreenGoTo() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const prayerTimeSettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = [
      {
        'title': "Change Location",
        'onPressed': () => locationPopup(),
        'color': Colors.grey[200],
        'textColor': Colors.black,
        'padding': const EdgeInsets.symmetric(vertical: 20),
        'textFontSize': 16.0,
        'icon': Icons.location_on,
      },
      {
        'title': "Prayer Time Settings",
        'onPressed': () => _TimeScreenGoTo(),
        'color': Colors.grey[200],
        'textColor': Colors.black,
        'padding': const EdgeInsets.symmetric(vertical: 20),
        'textFontSize': 16.0,
        'icon': Icons.access_time,
      },
    ];

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 105, 170, 190),
      appBar: buildAppBar(
          context, 'Settings', const MoreOptionsScreen(), screenFrom),
      body: ListView.builder(
        itemCount: options.length,
        itemBuilder: (context, index) {
          final option = options[index];
          return Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
            child: ElevatedButton(
              onPressed: option['onPressed'] as void Function(),
              style: ElevatedButton.styleFrom(
                padding: option['padding'] as EdgeInsets,
                backgroundColor: option['color'] as Color?,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    option['icon'] as IconData,
                    size: 24,
                    color: deepBlue,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      option['title'] as String,
                      style: TextStyle(
                        fontSize: option['textFontSize'] as double,
                        color: option['textColor'] as Color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
