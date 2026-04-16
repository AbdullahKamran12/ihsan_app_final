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
    // ── Palette ────────────────────────────────────────────────────────
    const Color navy = Color.fromARGB(255, 10, 25, 60);
    const Color navyMid = Color.fromARGB(255, 18, 42, 95);
    const Color gold = Color.fromARGB(255, 212, 175, 95);
    const Color goldLight = Color.fromARGB(255, 252, 243, 210);
    const Color skyBlue = Color.fromARGB(255, 100, 180, 240);
    const Color skyLight = Color.fromARGB(255, 220, 240, 255);
    const Color mintGreen = Color.fromARGB(255, 72, 200, 155);
    const Color mintLight = Color.fromARGB(255, 210, 245, 232);
    const Color white = Color.fromARGB(255, 255, 255, 255);
    const Color offWhite = Color.fromARGB(255, 247, 249, 255);
    const Color textDark = Color.fromARGB(255, 15, 30, 65);
    const Color textMid = Color.fromARGB(255, 90, 115, 160);
    const Color border = Color.fromARGB(255, 210, 220, 240);

    // Alternating icon accent colours — sky/mint/sky/mint...
    // Log Out gets its own warm orange
    final List<Color> iconColors = [
      navy, skyBlue, mintGreen, skyBlue, mintGreen,
      skyBlue, mintGreen, skyBlue,
      const Color.fromARGB(255, 200, 80, 60), // Log Out — red-ish
    ];
    final List<Color> iconBgs = [
      skyLight,
      skyLight,
      mintLight,
      skyLight,
      mintLight,
      skyLight,
      mintLight,
      skyLight,
      const Color.fromARGB(255, 255, 228, 225),
    ];

    final options = [
      {
        'title': _userData != null ? _userData!['displayName'] : 'Loading...',
        'subtitle': 'View & edit your profile',
        'onPressed': () => _accountsPageGoTo(),
        'icon': Icons.person_outline_rounded,
        'isProfile': true,
      },
      {
        'title': 'Nearby Mosques and Halal Places',
        'subtitle': 'Find mosques near you',
        'onPressed': () => _MosqueScreenGoTo(),
        'icon': Icons.mosque_outlined,
        'isProfile': false,
      },
      {
        'title': 'Islamic Calendar',
        'subtitle': 'Hijri dates & Islamic events',
        'onPressed': () => _CalenderScreenGoTo(),
        'icon': Icons.calendar_today_outlined,
        'isProfile': false,
      },
      {
        'title': 'Tasbih / Zikr',
        'subtitle': 'Dhikr counter & collections',
        'onPressed': () => _TasbihScreenGoTo(),
        'icon': Icons.radio_button_checked_outlined,
        'isProfile': false,
      },
      {
        'title': 'Settings',
        'subtitle': 'Notifications & preferences',
        'onPressed': () => _SettingsScreenGoTo(),
        'icon': Icons.settings_outlined,
        'isProfile': false,
      },
      {
        'title': 'Radio',
        'subtitle': 'Islamic radio stations',
        'onPressed': () => _RadioScreenGoTo(),
        'icon': Icons.radio_outlined,
        'isProfile': false,
      },
      {
        'title': 'Islamic Basics',
        'subtitle': 'Salah, Wudu, Du\'as & more',
        'onPressed': () => _InfoScreenGoTo(),
        'icon': Icons.menu_book_rounded,
        'isProfile': false,
      },
      {
        'title': 'Zakat Calculator',
        'subtitle': 'Calculate your Zakat',
        'onPressed': () => _ZakatScreenGoTo(),
        'icon': Icons.calculate_outlined,
        'isProfile': false,
      },
      {
        'title': 'Log Out',
        'subtitle': 'Sign out of your account',
        'onPressed': _showLogOutDialog,
        'icon': Icons.logout_rounded,
        'isProfile': false,
      },
    ];

    return Scaffold(
      backgroundColor: navy,
      appBar: buildAppBar(context, 'More Options', const HomeScreen(), null),
      bottomNavigationBar: buildBottomNavigationBar(context, 4, _onItemTapped),
      body: Column(
        children: [
          const QurbaniBanner(),
          // ── HERO HEADER ─────────────────────────────────────────────
          Container(
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
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: navyMid,
                    border: Border.all(color: gold, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: gold.withOpacity(0.15),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _userData != null &&
                              (_userData!['displayName'] as String).isNotEmpty
                          ? (_userData!['displayName'] as String)[0]
                              .toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 24,
                        color: gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userData != null
                            ? _userData!['displayName']
                            : 'Loading...',
                        style: const TextStyle(
                          color: white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _userData != null ? _userData!['email'] ?? '' : '',
                        style: TextStyle(
                          color: white.withOpacity(0.45),
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Quick edit button
                GestureDetector(
                  onTap: () => _accountsPageGoTo(),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(
                      color: navyMid,
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: gold.withOpacity(0.4), width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined, color: gold, size: 12),
                        SizedBox(width: 4),
                        Text('Profile',
                            style: TextStyle(
                                color: gold,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── OPTIONS LIST ─────────────────────────────────────────────
          Expanded(
            child: Container(
              color: offWhite,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                // Skip index 0 (profile — shown in header above)
                itemCount: options.length - 1,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  // +1 because we skip the profile tile
                  final option = options[index + 1];
                  final int colorIndex =
                      (index + 1).clamp(0, iconColors.length - 1);
                  final Color iColor = iconColors[colorIndex];
                  final Color iBg = iconBgs[colorIndex];
                  final bool isLogOut = option['title'] == 'Log Out';

                  return GestureDetector(
                    onTap: option['onPressed'] as void Function(),
                    child: Container(
                      decoration: BoxDecoration(
                        color: white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isLogOut
                              ? const Color.fromARGB(255, 255, 200, 195)
                              : border,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: navy.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 13),
                        child: Row(
                          children: [
                            // Icon badge
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: iBg,
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(
                                  color: iColor.withOpacity(0.25),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                option['icon'] as IconData,
                                size: 20,
                                color: iColor,
                              ),
                            ),

                            const SizedBox(width: 13),

                            // Title + subtitle
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option['title'] as String,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isLogOut
                                          ? const Color.fromARGB(
                                              255, 180, 60, 50)
                                          : textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    option['subtitle'] as String,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: textMid,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Chevron
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: isLogOut
                                  ? const Color.fromARGB(255, 200, 80, 60)
                                      .withOpacity(0.6)
                                  : textMid.withOpacity(0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
