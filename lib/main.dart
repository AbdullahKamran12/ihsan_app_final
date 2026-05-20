import 'package:ihsan_app_final/screens/exports.dart';
import 'package:ihsan_app_final/screens/prayerTimesClass.dart';
import 'package:ihsan_app_final/utils/notification_service.dart';
import 'package:ihsan_app_final/utils/prayer_scheduler.dart';
import 'package:ihsan_app_final/screens/mosqueDisplayScreen.dart';
import 'package:ihsan_app_final/screens/prayerScreen.dart';
import 'package:flutter/services.dart';
import 'package:ihsan_app_final/utils/widget_service.dart';
import 'package:ihsan_app_final/utils/api_keys.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:ihsan_app_final/screens/login.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:home_widget/home_widget.dart';

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  ApiKeys.getMapsKey();
  await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
  await FirebaseAnalytics.instance.setUserProperty(
    name: 'platform',
    value: kIsWeb ? 'web' : 'mobile',
  );
  if (!kIsWeb) {
    // Mobile/TV only — these don't exist on web
    await PrayerScheduler.init();
    await WidgetService.init();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateRoute: (settings) {
        if (settings.name == '/prayerScreen') {
          return MaterialPageRoute(builder: (_) => const PrayerTimesScreen());
        }
        return null;
      },
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child!,
        );
      },
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Animation controllers ────────────────────────────────────────
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;

  // Logo
  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<Offset> _logoSlide;

  // Text
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;

  // Subtitle
  late Animation<double> _subtitleFade;

  // Gold ring pulse around logo
  late Animation<double> _ringScale;
  late Animation<double> _ringOpacity;

  // Shimmer line under title
  late Animation<double> _shimmerWidth;

  @override
  void initState() {
    super.initState();

    // ── Controllers ────────────────────────────────────────────────
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // ── Logo animations ─────────────────────────────────────────────
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
      ),
    );

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
      ),
    );

    _logoSlide = Tween<Offset>(
      begin: const Offset(0, -0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // ── Text animations ─────────────────────────────────────────────
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.4, 0.80, curve: Curves.easeOut),
      ),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: const Interval(0.35, 0.75, curve: Curves.easeOut),
      ),
    );

    // ── Subtitle animation ──────────────────────────────────────────
    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.65, 1.0, curve: Curves.easeOut),
      ),
    );

    // ── Gold ring pulse ─────────────────────────────────────────────
    _ringScale = Tween<double>(begin: 0.75, end: 1.15).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _ringOpacity = Tween<double>(begin: 0.7, end: 0.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // ── Shimmer line ────────────────────────────────────────────────
    _shimmerWidth = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _shimmerController,
        curve: Curves.easeOut,
      ),
    );

    // ── Sequence: start animations ──────────────────────────────────
    _fadeController.forward();
    _slideController.forward();

    // Ring starts after logo appears
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _pulseController.repeat(reverse: true);
      }
    });

    // Shimmer after text appears
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _shimmerController.forward();
    });
    HomeWidget.widgetClicked.listen((uri) {
      if (uri != null && uri.path == '/prayerScreen') {
        Navigator.pushNamed(context, '/prayerScreen');
      }
    });

    // Navigate after animation settles
    _checkUserStatus();
  }

  Future<void> _requestPermissions() async {
    // 1. Notification permission (Android 13+)
    final notifStatus = await Permission.notification.status;
    if (!notifStatus.isGranted) {
      await Permission.notification.request();
    }

    // 2. Exact alarm permission — needed for prayer time scheduling
    //    This is handled inside NotificationService, but we prime it here
    //    so the dialog appears during splash rather than mid-prayer-screen
    await NotificationService.init();
    final hasExact = await NotificationService.hasExactAlarmPermission();
    if (!hasExact) {
      // This opens Android's "Alarms & reminders" settings page
      await Permission.scheduleExactAlarm.request();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _checkUserStatus() async {
    // ── 1. Platform check — must come FIRST, before any delay ────────────
    final bool isWebOrDesktop = true;

    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 400),
            pageBuilder: (_, __, ___) => const MosqueDisplayScreen(),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        );
      });
      return;
    }

    // ── 2. Mobile — wait for splash animations to breathe, then auth ─────
    bool isGuest = await getGuestStatus();
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;
    await _requestPermissions();

    // ── 3. Check for update in background (doesn't block navigation) ─────
    // Capture the navigator NOW, before we navigate away and this context dies
    final navigator = Navigator.of(context);
    _checkForUpdate(navigator);

    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (!mounted) return;
      if (user != null || isGuest == true) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 600),
            pageBuilder: (_, __, ___) => const HomeScreen(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.04),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOut,
                  )),
                  child: child,
                ),
              );
            },
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 600),
            pageBuilder: (_, __, ___) => const LoginPage(),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        );
      }
    });
  }

  Future<void> _checkForUpdate(NavigatorState navigator) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version; // e.g. "1.1.0"

      String? storeVersion;

      if (Platform.isAndroid) {
        // Use Firestore config doc — more reliable than scraping Play Store HTML
        // Add a document at config/latestVersion with field: android: "1.2.0"
        try {
          final doc = await FirebaseFirestore.instance
              .collection('config')
              .doc('latestVersion')
              .get()
              .timeout(const Duration(seconds: 8));
          storeVersion = doc.data()?['android'] as String?;
        } catch (_) {
          // config doc not set up yet — silently skip
        }
      } else if (Platform.isIOS) {
        // iTunes lookup API — stable and official
        final url = Uri.parse(
          'https://itunes.apple.com/lookup?bundleId=com.ihsan.ihsanapp',
        );
        final response =
            await http.get(url).timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final results = decoded['results'] as List?;
          if (results != null && results.isNotEmpty) {
            storeVersion = results[0]['version'] as String?;
          }
        }
      }

      if (storeVersion == null) return;

      // Compare versions — pad shorter list with zeros so "1.2" vs "1.2.1" works
      final current = currentVersion.split('.').map(int.parse).toList();
      final store = storeVersion.split('.').map(int.parse).toList();
      final maxLen =
          current.length > store.length ? current.length : store.length;

      bool updateAvailable = false;
      for (int i = 0; i < maxLen; i++) {
        final s = i < store.length ? store[i] : 0;
        final c = i < current.length ? current[i] : 0;
        if (s > c) {
          updateAvailable = true;
          break;
        }
        if (s < c) break;
      }

      if (!updateAvailable) return;

      // Small delay so the home screen has fully settled before showing dialog
      await Future.delayed(const Duration(milliseconds: 1500));

      // Use the captured navigator's overlay context — safe even after splash is gone
      final overlayContext = navigator.overlay?.context;
      if (overlayContext == null) return;

      _showUpdateDialog(storeVersion, overlayContext);
    } catch (_) {
      // Silently fail — update check should never crash the app
    }
  }

  void _showUpdateDialog(String storeVersion, BuildContext dialogContext) {
    const Color navy = Color.fromARGB(255, 10, 25, 60);
    const Color navyMid = Color.fromARGB(255, 18, 42, 95);
    const Color gold = Color.fromARGB(255, 212, 175, 95);
    const Color white = Color.fromARGB(255, 255, 255, 255);

    showDialog(
      context: dialogContext,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: navyMid,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: gold.withOpacity(0.45), width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.system_update_rounded, color: gold, size: 22),
            SizedBox(width: 8),
            Text(
              'Update Available',
              style: TextStyle(
                color: gold,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          'A new version ($storeVersion) of Ihsan is available. Update now for the latest features and fixes.',
          style: TextStyle(
            color: white.withOpacity(0.85),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Later',
              style: TextStyle(color: white.withOpacity(0.5), fontSize: 14),
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.pop(ctx);
              final storeUrl = Platform.isIOS
                  ? Uri.parse(
                      'https://apps.apple.com/app/id6745788124') // replace with your real Apple ID
                  : Uri.parse(
                      'https://play.google.com/store/apps/details?id=com.ihsan.ihsanapp');
              launchUrl(storeUrl, mode: LaunchMode.externalApplication);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: gold,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Update',
                style: TextStyle(
                  color: navy,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenW = MediaQuery.of(context).size.width;
    final double screenH = MediaQuery.of(context).size.height;

    // ── Colours matching the app redesign ────────────────────────────
    const Color navy = Color.fromARGB(255, 10, 25, 60);
    const Color navyMid = Color.fromARGB(255, 18, 42, 95);
    const Color gold = Color.fromARGB(255, 212, 175, 95);
    const Color goldDim = Color.fromARGB(255, 180, 148, 72);
    const Color skyBlue = Color.fromARGB(255, 100, 180, 240);
    const Color mintGreen = Color.fromARGB(255, 72, 200, 155);
    const Color white = Color.fromARGB(255, 255, 255, 255);

    return Scaffold(
      backgroundColor: navy,
      body: Stack(
        children: [
          // ── Background gradient ───────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.3),
                radius: 1.2,
                colors: [
                  navyMid,
                  navy,
                ],
              ),
            ),
          ),

          // ── Subtle decorative circles (background depth) ──────────
          Positioned(
            top: -screenH * 0.12,
            right: -screenW * 0.2,
            child: Container(
              width: screenW * 0.7,
              height: screenW * 0.7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: gold.withOpacity(0.07),
                  width: 1.5,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -screenH * 0.08,
            left: -screenW * 0.15,
            child: Container(
              width: screenW * 0.55,
              height: screenW * 0.55,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: skyBlue.withOpacity(0.07),
                  width: 1.5,
                ),
              ),
            ),
          ),
          // Small mint dot accent top left
          Positioned(
            top: screenH * 0.12,
            left: screenW * 0.08,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: mintGreen.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Small gold dot accent bottom right
          Positioned(
            bottom: screenH * 0.15,
            right: screenW * 0.1,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: gold.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // ── Main content ──────────────────────────────────────────
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with pulsing gold ring
                SlideTransition(
                  position: _logoSlide,
                  child: FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Pulsing gold ring behind logo
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (_, __) => Transform.scale(
                              scale: _ringScale.value,
                              child: Opacity(
                                opacity: _ringOpacity.value,
                                child: Container(
                                  width: screenW * 0.62,
                                  height: screenW * 0.62,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: gold,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Static gold circle border behind logo
                          Container(
                            width: screenW * 0.58,
                            height: screenW * 0.58,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: gold.withOpacity(0.3),
                                width: 1.5,
                              ),
                              color: navyMid.withOpacity(0.5),
                            ),
                          ),

                          // App logo
                          Image.asset(
                            'assets/Untitled_design-removebg-preview.png',
                            width: screenW * 0.52,
                            height: screenH * 0.30,
                            fit: BoxFit.contain,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(height: screenH * 0.045),

                // App name + shimmer underline
                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textFade,
                    child: Column(
                      children: [
                        // "Ihsan" title
                        const Text(
                          'Ihsan',
                          style: TextStyle(
                            color: white,
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // "Perfection" subtitle in gold
                        const Text(
                          'P E R F E C T I O N',
                          style: TextStyle(
                            color: gold,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 4.0,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Animated gold shimmer line
                        AnimatedBuilder(
                          animation: _shimmerWidth,
                          builder: (_, __) => Container(
                            width: screenW * 0.38 * _shimmerWidth.value,
                            height: 1.5,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  gold.withOpacity(0),
                                  gold,
                                  gold.withOpacity(0),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: screenH * 0.030),

                // Tagline
                FadeTransition(
                  opacity: _subtitleFade,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: screenW * 0.1),
                    child: Text(
                      'Your Path to Excellence in Faith',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: white.withOpacity(0.65),
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.3,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: screenH * 0.065),

                // Loading dots
                FadeTransition(
                  opacity: _subtitleFade,
                  child: _LoadingDots(
                    color: gold.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated loading dots ─────────────────────────────────────────
class _LoadingDots extends StatefulWidget {
  final Color color;
  const _LoadingDots({required this.color});

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      ),
    );
    _anims = _controllers
        .map((c) => Tween<double>(begin: 0.3, end: 1.0).animate(
              CurvedAnimation(parent: c, curve: Curves.easeInOut),
            ))
        .toList();

    // Stagger each dot
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 180), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _anims[i],
          builder: (_, __) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withOpacity(_anims[i].value),
            ),
          ),
        );
      }),
    );
  }
}
