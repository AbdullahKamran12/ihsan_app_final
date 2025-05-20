import 'package:ihsan_app_final/screens/exports.dart';
import 'package:ihsan_app_final/screens/prayerTimesClass.dart';
import 'package:ihsan_app_final/utils/notification_service.dart';
//import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:ihsan_app_final/screens/login.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

bool guest = false;
Future<void> saveGuestStatus(bool isGuest) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('guest', isGuest);
}

Future<bool> getGuestStatus() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('guest') ?? false;
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('Workmanager: Task started - $task');
    try {
      await NotificationService.initialize();

      SharedPreferences prefs = await SharedPreferences.getInstance();
      print('SharedPreferences initialized');

      List<bool> notificationToggles = [
        prefs.getBool('notif_fajr') ?? false,
        prefs.getBool('notif_sunrise') ?? false,
        prefs.getBool('notif_dhuhr') ?? false,
        prefs.getBool('notif_asr') ?? false,
        prefs.getBool('notif_maghrib') ?? false,
        prefs.getBool('notif_isha') ?? false,
      ];
      print('Notification toggles loaded: $notificationToggles');

      String? jsonString = prefs.getString('monthlyPrayerTimes');
      if (jsonString != null) {
        List<dynamic> jsonList = jsonDecode(jsonString);
        List<PrayerTimes> monthlyPrayerTimesList =
            jsonList.map((json) => PrayerTimes.fromJson(json)).toList();
        print(
            'Monthly prayer times loaded: ${monthlyPrayerTimesList.length} entries');

        for (int i = 0; i < notificationToggles.length; i++) {
          if (notificationToggles[i]) {
            print('Scheduling notification for prayer index $i');
            await NotificationService.schedulePrayerNotification(
              index: i,
              monthlyPrayerTimesList: monthlyPrayerTimesList,
            );
          }
        }
      } else {
        print('No monthly prayer times found in SharedPreferences');
      }

      return Future.value(true);
    } catch (e, stackTrace) {
      print("Workmanager task failed: $e\n$stackTrace");
      return Future.value(false);
    }
  });
}

Future<void> _requestExactAlarmPermission() async {
  if (await Permission.scheduleExactAlarm.isDenied) {
    await Permission.scheduleExactAlarm.request();
  }
}

Future<void> _requestNotificationPermission() async {
  final status = await Permission.notification.request();
  if (status.isGranted) {
    print('Notification permission granted.');
  } else {
    print('Notification permission denied.');
  }
}

Future<void> _requestBatteryOptimizationPermission() async {
  if (Platform.isAndroid) {
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      final status = await Permission.ignoreBatteryOptimizations.request();
      if (status.isGranted) {
        print("Battery optimization exemption granted.");
      } else {
        print("Battery optimization exemption denied.");
      }
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //MobileAds.instance.initialize();
  await _requestExactAlarmPermission();
  await _requestNotificationPermission();
  await _requestBatteryOptimizationPermission();
  await NotificationService.initialize();

  tz.initializeTimeZones();
  print("Current time zone: ${tz.local}");

  try {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: androidSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    print('flutterLocalNotificationsPlugin: Initialization successful');
  } catch (e) {
    print('flutterLocalNotificationsPlugin: Initialization failed - $e');
  }
  Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  Workmanager().registerPeriodicTask(
    "rescheduleNotifications",
    "rescheduleNotificationsTask",
    frequency: Duration(hours: 24),
    initialDelay: Duration(seconds: 10),
    constraints: Constraints(
      networkType: NetworkType.not_required,
      requiresBatteryNotLow: false,
      requiresCharging: false,
      requiresDeviceIdle: false,
      requiresStorageNotLow: false,
    ),
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    bool isGuest = await getGuestStatus();
    Future.delayed(const Duration(seconds: 1), () {
      FirebaseAuth.instance.authStateChanges().listen((User? user) {
        if (user != null || isGuest == true) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 128, 128),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image(
              image: const AssetImage(
                  'assets/Untitled_design-removebg-preview.png'),
              width: MediaQuery.of(context).size.width * 0.6,
              height: MediaQuery.of(context).size.height * 0.45,
            ),
            const Text(
              "Your Path to Excellence in Faith",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
