import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ihsan_app_final/screens/accountsOptionsPage.dart';
import 'package:ihsan_app_final/screens/calender.dart';
import 'package:ihsan_app_final/screens/zakat.dart';
import 'package:ihsan_app_final/screens/radio.dart';
import 'package:ihsan_app_final/screens/login.dart';
import 'package:ihsan_app_final/screens/nearbyMosquesHalaScreen.dart';
import 'package:ihsan_app_final/screens/infoScreen.dart';
import 'package:ihsan_app_final/screens/settings.dart';
import 'package:ihsan_app_final/screens/tasbih.dart';

import 'package:ihsan_app_final/sharedWidgets.dart';
import 'package:ihsan_app_final/screens/homeScreen.dart';
import 'package:ihsan_app_final/screens/prayerScreen.dart';
import 'package:ihsan_app_final/screens/qiblaScreen.dart';
import 'package:ihsan_app_final/screens/quranScreen.dart';

class MoreOptionsScreen extends StatefulWidget {
  const MoreOptionsScreen({super.key});

  @override
  _MoreOptionsScreenState createState() => _MoreOptionsScreenState();
}

class _MoreOptionsScreenState extends State<MoreOptionsScreen> {
  int _selectedIndex = 0;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  final deepBlue = const Color(0xFF003366);

  @override
  void initState() {
    super.initState();
    _fetchUserData();
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
          _isLoading = false;
        });
      } else {
        print('No user data found for UID: ${user.uid}');
        setState(() {
          _userData = null;
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

  Future<void> _logOut() async {
    await _auth.signOut();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  void _accountsPageGoTo() {
    screenFrom = "More";
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AccountsOptionsScreen()),
    );
  }

  void _MosqueScreenGoTo() {
    screenFrom = "More";
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MosqueScreen()),
    );
  }

  void _SettingsScreenGoTo() {
    screenFrom = "More";
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingScreen()),
    );
  }

  void _CalenderScreenGoTo() {
    screenFrom = "More";
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CalendarScreen()),
    );
  }

  void _TasbihScreenGoTo() {
    screenFrom = "More";
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TasbihScreen()),
    );
  }

  void _ZakatScreenGoTo() {
    screenFrom = "More";
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ZakatScreen()),
    );
  }

  void _RadioScreenGoTo() {
    screenFrom = "More";
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RadioScreen()),
    );
  }

  void _InfoScreenGoTo() {
    screenFrom = "More";
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const InfoScreen()),
    );
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

  void _showLogOutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Log Out'),
          content: const Text('Are you sure you want to log out?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _logOut();
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = [
      {
        'title': _userData != null
            ? 'Profile: ${_userData!['displayName']}'
            : 'Profile: Loading...',
        'onPressed': () => _accountsPageGoTo(),
        'color': Colors.grey[200],
        'textColor': Colors.black,
        'padding': const EdgeInsets.symmetric(vertical: 20),
        'textFontSize': 20.0,
        'icon': Icons.person,
      },
      {
        'title': 'Nearby Mosques',
        'onPressed': () => _MosqueScreenGoTo(),
        'color': Colors.grey[200],
        'textColor': Colors.black,
        'padding': const EdgeInsets.symmetric(vertical: 15),
        'textFontSize': 16.0,
        'icon': Icons.mosque,
      },
      {
        'title': 'Islamic Calendar',
        'onPressed': () => _CalenderScreenGoTo(),
        'color': Colors.grey[200],
        'textColor': Colors.black,
        'padding': const EdgeInsets.symmetric(vertical: 15),
        'textFontSize': 16.0,
        'icon': Icons.calendar_today,
      },
      {
        'title': 'Tasbih/Zikr',
        'onPressed': () => _TasbihScreenGoTo(),
        'color': Colors.grey[200],
        'textColor': Colors.black,
        'padding': const EdgeInsets.symmetric(vertical: 15),
        'textFontSize': 16.0,
        'icon': Icons.fiber_manual_record,
      },
      {
        'title': 'Settings',
        'onPressed': () => _SettingsScreenGoTo(),
        'color': Colors.grey[200],
        'textColor': Colors.black,
        'padding': const EdgeInsets.symmetric(vertical: 15),
        'textFontSize': 16.0,
        'icon': Icons.settings,
      },
      {
        'title': 'Radio',
        'onPressed': () => _RadioScreenGoTo(),
        'color': Colors.grey[200],
        'textColor': Colors.black,
        'padding': const EdgeInsets.symmetric(vertical: 15),
        'textFontSize': 16.0,
        'icon': Icons.radio,
      },
      {
        'title':
            'Basics Rulings and Information of Islam(Salah, Wudu, Duaas, etc.)',
        'onPressed': () => _InfoScreenGoTo(),
        'color': Colors.grey[200],
        'textColor': Colors.black,
        'padding': const EdgeInsets.symmetric(vertical: 15),
        'textFontSize': 16.0,
        'icon': Icons.info,
      },
      {
        'title': 'Zakat Calculator',
        'onPressed': () => _ZakatScreenGoTo(),
        'color': Colors.grey[200],
        'textColor': Colors.black,
        'padding': const EdgeInsets.symmetric(vertical: 15),
        'textFontSize': 16.0,
        'icon': Icons.money_rounded,
      },
      {
        'title': 'Log Out',
        'onPressed': _showLogOutDialog,
        'color': Colors.grey[200],
        'textColor': Colors.black,
        'padding': const EdgeInsets.symmetric(vertical: 15),
        'textFontSize': 16.0,
        'icon': Icons.logout,
      },
    ];

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 105, 170, 190),
      appBar: buildAppBar(context, 'More Options', const HomeScreen(), null),
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
      bottomNavigationBar: buildBottomNavigationBar(context, 4, _onItemTapped),
    );
  }
}
