import 'package:flutter/material.dart';
import 'package:ihsan_app_final/screens/exports.dart';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_analytics/firebase_analytics.dart';

import 'package:url_launcher/url_launcher.dart';

class QurbaniBanner extends StatefulWidget {
  const QurbaniBanner({super.key});

  @override
  State<QurbaniBanner> createState() => _QurbaniBannerState();
}

class _QurbaniBannerState extends State<QurbaniBanner> {
  bool isVisible = true;

  void openLink() async {
    final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
    await analytics.logEvent(name: 'qurbani_banner_click');
    final Uri url = Uri.parse("https://www.humanityappeal.org/qurbani");

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox();

    return Container(
      width: double.infinity,
      color: Colors.transparent,
      child: Stack(
        children: [
          GestureDetector(
            onTap: openLink,
            child: Image.asset(
              'assets/BannerAppQurbani.png', // 👈 your generated banner
              width: double.infinity,
              height: 90,
              fit: BoxFit.cover,
            ),
          ),

          // CLOSE BUTTON
          Positioned(
            right: 8,
            top: 8,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  isVisible = false;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(4),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String screenFrom = "Home";

Future<bool> isConnected() async {
  final connectivityResult = await Connectivity().checkConnectivity();

  if (connectivityResult.contains(ConnectivityResult.none)) {
    return false;
  }

  try {
    final result = await InternetAddress.lookup('example.com');
    return result.isNotEmpty;
  } catch (_) {
    return false;
  }
}

AppBar buildAppBarHome(BuildContext context) {
  return AppBar(
    backgroundColor: const Color.fromARGB(255, 10, 25, 60),
    foregroundColor: const Color(0xFFF5F5F5),
    leading: Builder(
      builder: (context) {
        return IconButton(
          icon: const Icon(Icons.menu, size: 40),
          onPressed: () {
            Scaffold.of(context).openDrawer();
          },
        );
      },
    ),
    actions: [
      Padding(
        padding: const EdgeInsets.only(right: 16.0),
        child: Image(
          image:
              const AssetImage('assets/Untitled_design-removebg-preview.png'),
          width: MediaQuery.of(context).size.width * 0.15,
          height: MediaQuery.of(context).size.height * 0.15,
        ),
      ),
    ],
  );
}

AppBar buildAppBar(
    BuildContext context, String title, Widget screento, String? screenFrom) {
  return AppBar(
    title: Text(title),
    backgroundColor: const Color.fromARGB(255, 10, 25, 60),
    foregroundColor: const Color(0xFFF5F5F5),
    elevation: 0,
    centerTitle: true,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        if (screenFrom == "Home") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomeScreen()),
          );
        } else if (screenFrom == "More") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => MoreOptionsScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => screento),
          );
        }
      },
    ),
  );
}

Widget buildBottomNavigationBar(
    BuildContext context, int currentIndex, Function(int) onTap) {
  return BottomNavigationBar(
    backgroundColor: const Color.fromARGB(255, 10, 25, 60),
    items: const <BottomNavigationBarItem>[
      BottomNavigationBarItem(
        icon: Icon(Icons.home),
        label: 'Home',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.access_time),
        label: 'Prayer Times',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.explore),
        label: 'Qibla',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.book),
        label: 'Quran',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.more_horiz),
        label: 'More Options',
      ),
    ],
    currentIndex: currentIndex,
    selectedItemColor: const Color.fromARGB(255, 212, 175, 95), // gold
    unselectedItemColor: const Color.fromARGB(255, 120, 155, 200), // muted blue
    showUnselectedLabels: true,
    type: BottomNavigationBarType.fixed,
    onTap: onTap,
  );
}
