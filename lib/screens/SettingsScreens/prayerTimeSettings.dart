import 'package:flutter/material.dart';
import 'package:ihsan_app_final/screens/moreoptionsScreen.dart';
import 'package:ihsan_app_final/screens/settings.dart';
import 'package:ihsan_app_final/sharedWidgets.dart';
import 'package:ihsan_app_final/screens/prayerTimesClass.dart';
import 'package:ihsan_app_final/screens/prayerScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class prayerTimeSettingsScreen extends StatefulWidget {
  const prayerTimeSettingsScreen({super.key});

  @override
  prayerTimeSettingsScreenState createState() =>
      prayerTimeSettingsScreenState();
}

Future<void> saveAllSettings() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('method', method);
  await prefs.setInt('school', school);
  await saveAdjustments();
}

class prayerTimeSettingsScreenState extends State<prayerTimeSettingsScreen> {
  void _TimeScreenGoTo() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const adjustTimeSettingsScreen()),
    );
  }

  void _PrayerScreenGoTo() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PrayerTimesScreen()),
    );
  }

  void _MethodScreenGoTo() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => const adjustMethodSettingsScreen()),
    );
  }

  void _SchoolScreenGoTo() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => const adjustSchoolSettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = [
      {
        'title': "Adjust Prayer Times",
        'onPressed': () => _TimeScreenGoTo(),
        'color': Colors.grey[200],
        'textColor': Colors.black,
        'padding': const EdgeInsets.symmetric(vertical: 20),
        'textFontSize': 16.0,
        'icon': Icons.adjust,
      },
      {
        'title': "Calculation Mehtod",
        'onPressed': () => _MethodScreenGoTo(),
        'color': Colors.grey[200],
        'textColor': Colors.black,
        'padding': const EdgeInsets.symmetric(vertical: 20),
        'textFontSize': 16.0,
        'icon': Icons.menu_book,
      },
      {
        'title': "Calculation time for School of Fiqh",
        'onPressed': () => _SchoolScreenGoTo(),
        'color': Colors.grey[200],
        'textColor': Colors.black,
        'padding': const EdgeInsets.symmetric(vertical: 20),
        'textFontSize': 16.0,
        'icon': Icons.school,
      },
    ];
    final deepBlue = const Color(0xFF003366);

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 105, 170, 190),
      appBar: buildAppBar(
          context, 'Prayer Time Settings', const SettingScreen(), null),
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

class adjustTimeSettingsScreen extends StatefulWidget {
  const adjustTimeSettingsScreen({super.key});

  @override
  _adjustTimeSettingsScreenState createState() =>
      _adjustTimeSettingsScreenState();
}

class _adjustTimeSettingsScreenState extends State<adjustTimeSettingsScreen> {
  void _PrayerScreenGoTo() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PrayerTimesScreen()),
    );
  }

  Widget _buildAdjustmentRow(String label, int value, VoidCallback onDecrement,
      VoidCallback onIncrement) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: onDecrement,
                ),
                Text(
                  '$value min',
                  style: const TextStyle(fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: onIncrement,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateTimeAdjustments() async {
    setState(() {
      adjustments[0] = Duration(minutes: fajrAdj);
      adjustments[1] = Duration(minutes: sunriseAdj);
      adjustments[2] = Duration(minutes: dhuhrAdj);
      adjustments[3] = Duration(minutes: asrAdj);
      adjustments[4] = Duration(minutes: maghribAdj);
      adjustments[5] = Duration(minutes: ishaAdj);
    });
    await saveAdjustments();

    try {
      change = true;
      _PrayerScreenGoTo();
    } catch (e) {
      print("Error updating prayer times: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adjust Time Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildAdjustmentRow(
              'Fajr Adjustment',
              fajrAdj,
              () => setState(() => fajrAdj--),
              () => setState(() => fajrAdj++),
            ),
            _buildAdjustmentRow(
              'Sunrise Adjustment',
              sunriseAdj,
              () => setState(() => sunriseAdj--),
              () => setState(() => sunriseAdj++),
            ),
            _buildAdjustmentRow(
              'Dhuhr Adjustment',
              dhuhrAdj,
              () => setState(() => dhuhrAdj--),
              () => setState(() => dhuhrAdj++),
            ),
            _buildAdjustmentRow(
              'Asr Adjustment',
              asrAdj,
              () => setState(() => asrAdj--),
              () => setState(() => asrAdj++),
            ),
            _buildAdjustmentRow(
              'Maghrib Adjustment',
              maghribAdj,
              () => setState(() => maghribAdj--),
              () => setState(() => maghribAdj++),
            ),
            _buildAdjustmentRow(
              'Isha Adjustment',
              ishaAdj,
              () => setState(() => ishaAdj--),
              () => setState(() => ishaAdj++),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _updateTimeAdjustments,
              child: const Text('Save Adjustments',
                  style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}

class adjustMethodSettingsScreen extends StatefulWidget {
  const adjustMethodSettingsScreen({super.key});

  @override
  _adjustMethodSettingsScreenState createState() =>
      _adjustMethodSettingsScreenState();
}

class _adjustMethodSettingsScreenState
    extends State<adjustMethodSettingsScreen> {
  int selectedMethod = method;

  void _PrayerScreenGoTo() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PrayerTimesScreen()),
    );
  }

  Future<void> loadAllSettings() async {
    final prefs = await SharedPreferences.getInstance();

    method = prefs.getInt('method') ?? 3;

    await loadAdjustments();
  }

  @override
  void initState() {
    super.initState();
    loadAllSettings();
  }

  Future<void> _applyMethodUpdate() async {
    setState(() {
      method = selectedMethod;
      // Reset all adjustment values to 0
      fajrAdj = 0;
      sunriseAdj = 0;
      dhuhrAdj = 0;
      asrAdj = 0;
      maghribAdj = 0;
      ishaAdj = 0;

      // Reset the Duration objects in the adjustments list
      for (int i = 0; i < adjustments.length; i++) {
        adjustments[i] = Duration.zero;
      }
    });

    // Save the reset adjustments to SharedPreferences
    await saveAdjustments();

    try {
      change = true;
      await saveAllSettings();
      _PrayerScreenGoTo();
    } catch (e) {
      print("Error updating prayer times with new method: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adjust Calculation Method'),
      ),
      body: ListView(
        children: [
          RadioListTile<int>(
            title: const Text("0 - Jafari / Shia Ithna-Ashari"),
            value: 0,
            groupValue: selectedMethod,
            onChanged: (newMethod) {
              setState(() {
                selectedMethod = newMethod!;
              });
            },
          ),
          RadioListTile<int>(
            title: const Text("1 - University of Islamic Sciences, Karachi"),
            value: 1,
            groupValue: selectedMethod,
            onChanged: (newMethod) {
              setState(() {
                selectedMethod = newMethod!;
              });
            },
          ),
          RadioListTile<int>(
            title: const Text("2 - Islamic Society of North America"),
            value: 2,
            groupValue: selectedMethod,
            onChanged: (newMethod) {
              setState(() {
                selectedMethod = newMethod!;
              });
            },
          ),
          RadioListTile<int>(
            title: const Text("3 - Muslim World League"),
            value: 3,
            groupValue: selectedMethod,
            onChanged: (newMethod) {
              setState(() {
                selectedMethod = newMethod!;
              });
            },
          ),
          RadioListTile<int>(
            title: const Text("4 - Umm Al-Qura University, Makkah"),
            value: 4,
            groupValue: selectedMethod,
            onChanged: (newMethod) {
              setState(() {
                selectedMethod = newMethod!;
              });
            },
          ),
          RadioListTile<int>(
            title: const Text("5 - Egyptian General Authority of Survey"),
            value: 5,
            groupValue: selectedMethod,
            onChanged: (newMethod) {
              setState(() {
                selectedMethod = newMethod!;
              });
            },
          ),
          RadioListTile<int>(
            title:
                const Text("7 - Institute of Geophysics, University of Tehran"),
            value: 7,
            groupValue: selectedMethod,
            onChanged: (newMethod) {
              setState(() {
                selectedMethod = newMethod!;
              });
            },
          ),
          RadioListTile<int>(
            title: const Text("8 - Gulf Region"),
            value: 8,
            groupValue: selectedMethod,
            onChanged: (newMethod) {
              setState(() {
                selectedMethod = newMethod!;
              });
            },
          ),
          RadioListTile<int>(
            title: const Text("9 - Kuwait"),
            value: 9,
            groupValue: selectedMethod,
            onChanged: (newMethod) {
              setState(() {
                selectedMethod = newMethod!;
              });
            },
          ),
          RadioListTile<int>(
            title: const Text("10 - Qatar"),
            value: 10,
            groupValue: selectedMethod,
            onChanged: (newMethod) {
              setState(() {
                selectedMethod = newMethod!;
              });
            },
          ),
          RadioListTile<int>(
            title: const Text("11 - Majlis Ugama Islam Singapura, Singapore"),
            value: 11,
            groupValue: selectedMethod,
            onChanged: (newMethod) {
              setState(() {
                selectedMethod = newMethod!;
              });
            },
          ),
          RadioListTile<int>(
            title: const Text("12 - Union Organization islamic de France"),
            value: 12,
            groupValue: selectedMethod,
            onChanged: (newMethod) {
              setState(() {
                selectedMethod = newMethod!;
              });
            },
          ),
          RadioListTile<int>(
            title: const Text("13 - Diyanet İşleri Başkanlığı, Turkey"),
            value: 13,
            groupValue: selectedMethod,
            onChanged: (newMethod) {
              setState(() {
                selectedMethod = newMethod!;
              });
            },
          ),
          RadioListTile<int>(
            title: const Text(
                "14 - Spiritual Administration of Muslims of Russia"),
            value: 14,
            groupValue: selectedMethod,
            onChanged: (newMethod) {
              setState(() {
                selectedMethod = newMethod!;
              });
            },
          ),
          RadioListTile<int>(
            title: const Text(
                "15 - Moonsighting Committee Worldwide (also requires shafaq parameter)"),
            value: 15,
            groupValue: selectedMethod,
            onChanged: (newMethod) {
              setState(() {
                selectedMethod = newMethod!;
              });
            },
          ),
          RadioListTile<int>(
            title: const Text("16 - Dubai (experimental)"),
            value: 16,
            groupValue: selectedMethod,
            onChanged: (newMethod) {
              setState(() {
                selectedMethod = newMethod!;
              });
            },
          ),
          RadioListTile<int>(
            title: const Text("17 - Jabatan Kemajuan Islam Malaysia (JAKIM)"),
            value: 17,
            groupValue: selectedMethod,
            onChanged: (newMethod) {
              setState(() {
                selectedMethod = newMethod!;
              });
            },
          ),
          RadioListTile<int>(
            title: const Text("18 - Tunisia"),
            value: 18,
            groupValue: selectedMethod,
            onChanged: (newMethod) {
              setState(() {
                selectedMethod = newMethod!;
              });
            },
          ),
          RadioListTile<int>(
            title: const Text("19 - Algeria"),
            value: 19,
            groupValue: selectedMethod,
            onChanged: (newMethod) {
              setState(() {
                selectedMethod = newMethod!;
              });
            },
          ),
          RadioListTile<int>(
            title: const Text(
                "20 - KEMENAG - Kementerian Agama Republik Indonesia"),
            value: 20,
            groupValue: selectedMethod,
            onChanged: (newMethod) {
              setState(() {
                selectedMethod = newMethod!;
              });
            },
          ),
          RadioListTile<int>(
            title: const Text("21 - Morocco"),
            value: 21,
            groupValue: selectedMethod,
            onChanged: (newMethod) {
              setState(() {
                selectedMethod = newMethod!;
              });
            },
          ),
          RadioListTile<int>(
            title: const Text("22 - Comunidade Islamica de Lisboa"),
            value: 22,
            groupValue: selectedMethod,
            onChanged: (newMethod) {
              setState(() {
                selectedMethod = newMethod!;
              });
            },
          ),
          RadioListTile<int>(
            title: const Text(
                "23 - Ministry of Awqaf, Islamic Affairs and Holy Places, Jordan"),
            value: 23,
            groupValue: selectedMethod,
            onChanged: (newMethod) {
              setState(() {
                selectedMethod = newMethod!;
              });
            },
          ),
          RadioListTile<int>(
            title: const Text(
                "99 - Custom. See https://aladhan.com/calculation-methods"),
            value: 99,
            groupValue: selectedMethod,
            onChanged: (newMethod) {
              setState(() {
                selectedMethod = newMethod!;
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _applyMethodUpdate,
              child: const Text("Update Method"),
            ),
          ),
        ],
      ),
    );
  }
}

class adjustSchoolSettingsScreen extends StatefulWidget {
  const adjustSchoolSettingsScreen({super.key});

  @override
  _adjustSchoolSettingsScreenState createState() =>
      _adjustSchoolSettingsScreenState();
}

class _adjustSchoolSettingsScreenState
    extends State<adjustSchoolSettingsScreen> {
  int selectedSchool = school;

  void _PrayerScreenGoTo() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PrayerTimesScreen()),
    );
  }

  Future<void> loadAllSettings() async {
    final prefs = await SharedPreferences.getInstance();

    school = prefs.getInt('school') ?? 1;

    await loadAdjustments();
  }

  @override
  void initState() {
    super.initState();
    loadAllSettings();
  }

  Future<void> _applySchoolUpdate() async {
    setState(() {
      school = selectedSchool;
      // Reset all adjustment values to 0
      fajrAdj = 0;
      sunriseAdj = 0;
      dhuhrAdj = 0;
      asrAdj = 0;
      maghribAdj = 0;
      ishaAdj = 0;

      // Reset the Duration objects in the adjustments list
      for (int i = 0; i < adjustments.length; i++) {
        adjustments[i] = Duration.zero;
      }
    });

    // Save the reset adjustments to SharedPreferences
    await saveAdjustments();

    try {
      change = true;
      await saveAllSettings();
      _PrayerScreenGoTo();
    } catch (e) {
      print("Error updating prayer times with new school: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adjust Madhab/School Settings'),
      ),
      body: ListView(
        children: [
          RadioListTile<int>(
            title: const Text("Shafi (Standard)"),
            value: 0,
            groupValue: selectedSchool,
            onChanged: (newSchool) {
              setState(() {
                selectedSchool = newSchool!;
              });
            },
          ),
          RadioListTile<int>(
            title: const Text("Hanafi"),
            value: 1,
            groupValue: selectedSchool,
            onChanged: (newSchool) {
              setState(() {
                selectedSchool = newSchool!;
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _applySchoolUpdate,
              child: const Text("Update School"),
            ),
          ),
        ],
      ),
    );
  }
}
