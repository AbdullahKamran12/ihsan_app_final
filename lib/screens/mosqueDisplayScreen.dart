import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
// ignore: avoid_web_libraries_in_flutter
// ignore: avoid_web_libraries_in_flutter
// ignore: unused_import
import 'package:http/http.dart' as http; // Kept for Aladhan API (future use)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:ihsan_app_final/screens/prayerTimesClass.dart';
// import 'package:ihsan_app_final/screens/webUploadMosque.dart'; // Upload feature — kept for future use
import 'package:ihsan_app_final/screens/web_login.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MosqueDisplayScreen  —  web / desktop ONLY
// Two modes:
//   LANDSCAPE → mosque display screen: full-screen, readable from distance,
//               large clock, bold prayer time cards in one row
//   PORTRAIT  → browser / phone UX: clean card layout, interactive search
//
// Prayer times: beginning times AND jamaat times are loaded from Firebase only.
// Aladhan API integration is preserved below in comments for future use.
// ─────────────────────────────────────────────────────────────────────────────

class MosqueDisplayScreen extends StatefulWidget {
  const MosqueDisplayScreen({super.key});
  @override
  State<MosqueDisplayScreen> createState() => _MosqueDisplayScreenState();
}

class _MosqueDisplayScreenState extends State<MosqueDisplayScreen>
    with TickerProviderStateMixin {
  // ── Palette ───────────────────────────────────────────────────────
  static const Color navy = Color.fromARGB(255, 8, 20, 52);
  static const Color navyMid = Color.fromARGB(255, 15, 36, 85);
  static const Color navyLight = Color.fromARGB(255, 24, 52, 110);
  static const Color navySurface = Color.fromARGB(255, 20, 44, 96);
  static const Color gold = Color.fromARGB(255, 212, 175, 95);
  static const Color goldDim = Color.fromARGB(255, 160, 130, 65);
  static const Color goldLight = Color.fromARGB(255, 252, 243, 210);
  static const Color skyBlue = Color.fromARGB(255, 100, 180, 240);
  static const Color skyLight = Color.fromARGB(255, 220, 240, 255);
  static const Color mintGreen = Color.fromARGB(255, 72, 200, 155);
  static const Color mintLight = Color.fromARGB(255, 210, 245, 232);
  static const Color white = Color.fromARGB(255, 255, 255, 255);
  static const Color offWhite = Color.fromARGB(255, 245, 248, 255);
  static const Color textDark = Color.fromARGB(255, 12, 28, 65);
  static const Color textMid = Color.fromARGB(255, 80, 108, 158);
  static const Color borderCol = Color.fromARGB(255, 205, 218, 240);

  // ── Prayer times cache (all documents fetched at mosque select) ──────
  // Key: 'yyyy-MM-dd', Value: raw Firestore doc data map.
  // Populated once when a mosque is selected (all-time fetch) and reused
  // on daily refresh when offline.
  Map<String, Map<String, dynamic>> _prayerCache = {};
  String _cachedMosqueId = ''; // mosque id whose data is in _prayerCache

  // ── Data ──────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _allMosques = [];
  List<Map<String, dynamic>> _filteredMosques = [];
  Map<String, dynamic>? _selectedMosque;
  PrayerTimes? _todayPrayerTimes;
  List<PrayerTime> _prayerRows = [];
  bool _isLoadingMosques = true;
  bool _isLoadingTimes = false;
  bool _noTimetable = false;
  String? _errorMsg;

  // ── Timer / clock ─────────────────────────────────────────────────
  String _nextPrayerName = '';
  String _timeRemaining = ''; // countdown to next JAMAAT
  String _beginningTimeRemaining = ''; // countdown to next BEGINNING (adhan)
  DateTime _now = DateTime.now();
  Timer? _minuteTimer;
  Timer? _clockTimer;

  StreamSubscription? _refreshSub;

  // ── Auth ──────────────────────────────────────────────────────────
  User? _currentUser;
  StreamSubscription? _authSub;
  String _displayName = '';

  // ── Search ────────────────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  bool _showSuggestions = false;

  // ── Animations ────────────────────────────────────────────────────
  late AnimationController _heroCtrl;
  late Animation<double> _heroFade;
  late AnimationController _tableCtrl;
  late Animation<double> _tableFade;
  late AnimationController _rowCtrl;
  late AnimationController _clockPulse;

  // ── Landscape extras: Hijri, seconds, ticker, adhan popup ────────
  String _hijriDate = '';
  String _secondsStr = '';
  Timer? _secondsTimer;
  bool _showAdhaan = false;
  String _adhaanPrayerName = '';
  Timer? _adhaanTimer;

  // ── Adhan Masjid overlay (fires 15 min before iqamah, 2 min duration) ──
  bool _showAdhanMasjid = false;
  String _adhanMasjidPrayerName = '';
  Timer? _adhanMasjidTimer;
  String _lastAdhanMasjidFired = '';
  String _adhanMasjidTimeLeft = '';
  Timer? _adhanMasjidCountdownTimer;

  // ── Adhan Dua overlay (fires after adhan masjid popup ends) ────────────
  bool _showAdhanDua = false;
  String _adhanDuaPrayerName = '';
  Timer? _adhanDuaTimer;
  double _tickerOffset = 0;
  Timer? _tickerTimer;

  // ── Derived times ─────────────────────────────────────────────────
  String _ishraqTime = '--';
  String _zawwalTime = '--';
  String _suhoorTime = '--'; // Fajr beginning - 10 minutes

  // ── Makrooh overlay ───────────────────────────────────────────────
  // Persistent for the ENTIRE makrooh window.
  bool _showMakrooh = false;
  String _makroohLabel = '';
  String _makroohSubLabel = '';
  String _makroohEndTime = ''; // HH:mm when window closes
  String _makroohTimeLeft = ''; // live countdown inside window
  String _lastMakroohFired = '';

  // ── Iqamah overlay ───────────────────────────────────────────────
  // Fires within 0–2 min window of each jamaat time, once per prayer per day.
  // Shows for 30 seconds then dismisses automatically.
  bool _showIqamah = false;
  String _iqamahPrayerName = '';
  Timer? _iqamahTimer;
  String _lastIqamahFired = '';

  bool _forceLandscape = true; // overridden in initState based on screen size

  // ── Post-jamaat blackout ──────────────────────────────────────────
  // 7-minute total blackout after each jamaat — pitch black + phone reminder.
  bool _showBlackout = false;
  String _blackoutPrayerName = '';
  String _blackoutTimeLeft = '';
  Timer? _blackoutTimer;
  Timer? _blackoutCountdownTimer;
  String _lastBlackoutFired = '';

  // ── Post-blackout Adhkar sequence ────────────────────────────────
  bool _showAdhkar = false;
  int _adhkarStep = 0; // 0–8 (steps in the sequence)
  String _adhkarPrayerName = ''; // so step 9 knows if it's Fajr/Maghrib
  Timer? _adhkarTimer;

  // ── Hadith overlay ────────────────────────────────────────────────
  // Driven by content sequence (step 1: 10 seconds).
  bool _showHadith = false;
  Timer? _hadithShowTimer;
  Timer? _hadithIntervalTimer;
  String _hadithDayKey = '';
  List<int> _todayHadithIndices = [0, 1, 2];

  // ── Content sequence overlays ─────────────────────────────────────
  bool _showSilenceOverlayFlag = false;
  bool _showMosqueImageFlag = false;
  bool _showAppPromoFlag = false;

  // ── Scaffold key for drawer ───────────────────────────────────────
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ── Taken mosques (already bound to another display account) ─────
  Set<String> _takenMosqueIds = {};

  // ── Custom ticker message ─────────────────────────────────────────
  String _customTickerMessage = '';

  // ── Daily-refresh tracking ────────────────────────────────────────
  late String _startDate;
  Timer? _dailyRefreshTimer;

  // ── Mosque binding (displayMosque) ────────────────────────────────
  // Saved to Firestore: displayMosques/{uid}
  bool _checkingBinding =
      false; // only true while actively resolving for logged-in users
  bool _showMosqueSetup = false; // show the one-time setup screen

  // ── Display images (Firebase Storage — bytes cached in RAM) ─────
  // Key: Storage path  (displayMosques/{mosqueId}/images/{filename})
  // Value: raw bytes downloaded once; re-fetched only on re-upload.
  Map<String, Uint8List> _displayImageMap = {};
  List<String> get _displayImagePaths => _displayImageMap.keys.toList();
  int _displayImageIndex = 0;
  bool _loadingImages = false;

  // ── Content sequence timer ────────────────────────────────────────
  // Cycle: hadith(10s) → 30s wait → silent(10s) → 30s wait → image(10s) → 30s wait → repeat
  Timer? _sequenceTimer;
  int _sequenceStep = 0; // 0-5 steps in the cycle

  // ── Jumuah jamaah adhan + khutbah overlay ────────────────────────
  // Fires at jamaah time for 1st and 2nd Jumu'ah: adhan (2:30) → khutbah (5 min) → iqamah → blackout
  bool _showJumuahJamaahAdhan = false;
  String _jumuahJamaahAdhanTimeLeft = '';
  Timer? _jumuahJamaahAdhanTimer;
  bool _showKhutbah = false;
  String _khutbahTimeLeft = '';
  Timer? _khutbahTimer;
  String _lastJumuahJamaahFired = '';

  // ── Jumuah times (1st, 2nd, 3rd) ─────────────────────────────────
  List<String> _jumuahTimes = [];

  // ── Tomorrow's Fajr time ──────────────────────────────────────────
  String _tomorrowFajr = '--';

  // ── True when the 30-second jamaat countdown is active ─────────────────
  // Derived purely from existing state — no extra timers or flags.
  bool get _isJamaahCountdownActive {
    if (!_timeRemaining.contains(':')) return false;
    try {
      final parts = _timeRemaining.split(':');
      final totalSecs = int.parse(parts[0]) * 60 + int.parse(parts[1]);
      return totalSecs <= 30;
    } catch (_) {
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // ANALYTICS — web identity + source tagging
  // Called once on init and re-called when auth state changes.
  // ══════════════════════════════════════════════════════════════════
  Future<void> _initWebAnalytics() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseAnalytics.instance.setUserId(id: user.uid);
        await FirebaseAnalytics.instance.setUserProperty(
          name: 'user_type',
          value: 'logged_in',
        );
      } else {
        await FirebaseAnalytics.instance.setUserProperty(
          name: 'user_type',
          value: 'guest',
        );
      }
      await FirebaseAnalytics.instance.setUserProperty(
        name: 'app_source',
        value: 'github_pages',
      );
      await FirebaseAnalytics.instance.setUserProperty(
        name: 'web_mode',
        value: 'display_screen',
      );
    } catch (e) {
      debugPrint('Analytics init error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ══════════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    // Detect orientation: landscape if width >= height, portrait otherwise.
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final mq = MediaQueryData.fromView(view);
    final double w = mq.size.width;
    final double h = mq.size.height;
    _forceLandscape = w >= h;
    if (!_forceLandscape) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scaffoldKey.currentState?.openEndDrawer());
    }
    if (_forceLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    FirebaseAnalytics.instance
        .logScreenView(screenName: 'display_screen')
        .catchError((e) => debugPrint('Analytics screenView error: $e'));
    _initWebAnalytics();

    _heroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _heroFade = CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut);

    _tableCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _tableFade = CurvedAnimation(parent: _tableCtrl, curve: Curves.easeOut);
    _rowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _clockPulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _startMinuteTimer();

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (!mounted) return;
      // If a user is present, show loading spinner while we resolve binding
      if (user != null) {
        setState(() => _checkingBinding = true);
      }
      String name = '';
      if (user != null) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('UserData')
              .doc(user.uid)
              .get();
          name = (doc.data()?['displayName'] as String?) ?? user.email ?? '';
        } catch (_) {
          name = user.email ?? '';
        }
      }
      setState(() {
        _currentUser = user;
        _displayName = name;
      });
      // Re-run analytics identity whenever auth state changes (login/logout)
      _initWebAnalytics();
      // Check if this account has a saved displayMosque binding
      if (user != null) {
        _checkMosqueBinding(user.uid);
      } else {
        // Logged out — clear state; build() gate will redirect to login
        setState(() {
          _checkingBinding = false;
          _showMosqueSetup = false;
          _selectedMosque = null;
          _prayerRows = [];
          _todayPrayerTimes = null;
        });
      }
    });
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _refreshSub = FirebaseFirestore.instance
          .collection('displayMosques')
          .doc(uid)
          .snapshots()
          .listen((snap) async {
        if (snap.data()?['needsRefresh'] == true) {
          // Clear the flag immediately so it doesn't re-trigger
          await FirebaseFirestore.instance
              .collection('displayMosques')
              .doc(uid)
              .set({'needsRefresh': false}, SetOptions(merge: true));

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              transitionDuration: Duration.zero,
              pageBuilder: (_, __, ___) => const MosqueDisplayScreen(),
            ),
          );
        }
      });
    }

    _loadAllMosques();
    _updateHijri(); // async — ignore future
    _secondsStr = DateFormat('ss').format(DateTime.now());
    _secondsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final n = DateTime.now();
      setState(() {
        _secondsStr = DateFormat('ss').format(n);
        _now = n;
      });
      _checkAdhan();
    });
    // Daily refresh at midnight: re-fetch from Firestore when online,
    // or reload today's data from the in-RAM prayer cache when offline.
    _startDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _dailyRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (today != _startDate) {
        _startDate = today; // advance so we only fire once per day
        _handleDailyRefresh(today);
      }
    });
    _tickerTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      setState(() => _tickerOffset += 2.0);
    });

    // Content sequence: replaces old hadith-only timer
    _pickTodayHadiths();
    _startContentSequence();
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();
    _clockTimer?.cancel();
    _secondsTimer?.cancel();
    _dailyRefreshTimer?.cancel();
    _adhaanTimer?.cancel();
    _adhanMasjidTimer?.cancel();
    _adhanMasjidCountdownTimer?.cancel();
    _adhanDuaTimer?.cancel();
    _tickerTimer?.cancel();
    _iqamahTimer?.cancel();
    _blackoutTimer?.cancel();
    _blackoutCountdownTimer?.cancel();
    _adhkarTimer?.cancel();
    _hadithShowTimer?.cancel();
    _hadithIntervalTimer?.cancel();
    _sequenceTimer?.cancel();
    _jumuahJamaahAdhanTimer?.cancel();
    _khutbahTimer?.cancel();
    _authSub?.cancel();
    _heroCtrl.dispose();
    _tableCtrl.dispose();
    _rowCtrl.dispose();
    _clockPulse.dispose();
    _searchCtrl.dispose();
    _refreshSub?.cancel();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([
      // re-lock when leaving
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════
  // TIMER
  // ══════════════════════════════════════════════════════════════════
  void _startMinuteTimer() {
    final now = DateTime.now();
    Future.delayed(Duration(seconds: 60 - now.second), () {
      if (!mounted) return;
      _updateRemainingTime();
      _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) _updateRemainingTime();
      });
    });
  }

  void _updateRemainingTime() {
    if (!mounted) return;
    if (_todayPrayerTimes == null) {
      setState(() => _now = DateTime.now());
      return;
    }
    final now = DateTime.now();

    // Build list of (name, targetTime) — prefer jamaat over beginning
    final candidates = <List<String>>[];
    for (final row in _prayerRows) {
      if (row.name == 'Sunrise') continue; // no jamaat for sunrise
      final target = (row.jamaatTime.isNotEmpty && row.jamaatTime != '--')
          ? row.jamaatTime
          : row.time;
      if (target.isNotEmpty && target != '--') {
        candidates.add([row.name, target]);
      }
    }

    String nextName = '', remaining = '';
    for (final c in candidates) {
      final parts = c[1].split(':');
      if (parts.length < 2) continue;
      final pt = DateTime(now.year, now.month, now.day, int.parse(parts[0]),
          int.parse(parts[1]));
      if (pt.isAfter(now)) {
        nextName = c[0];
        remaining = _formatCountdown(pt.difference(now));
        break;
      }
    }

    // Wrap to tomorrow's Fajr jamaat (or beginning)
    if (nextName.isEmpty) {
      final fajrRow = _prayerRows.isNotEmpty
          ? _prayerRows.firstWhere((r) => r.name == 'Fajr',
              orElse: () => PrayerTime('Fajr', '--', '--'))
          : PrayerTime('Fajr', '--', '--');
      nextName = 'Fajr';
      final target =
          (fajrRow.jamaatTime.isNotEmpty && fajrRow.jamaatTime != '--')
              ? fajrRow.jamaatTime
              : _todayPrayerTimes!.fajr;
      final fp = target.split(':');
      if (fp.length >= 2) {
        final nextFajr = DateTime(now.year, now.month, now.day + 1,
            int.parse(fp[0]), int.parse(fp[1]));
        remaining = _formatCountdown(nextFajr.difference(now));
      }
    }

    // Also compute beginning (adhan) countdown separately
    String beginningRemaining = '';
    final beginningTimes = [
      ['Fajr', _todayPrayerTimes!.fajr],
      ['Dhuhr', _todayPrayerTimes!.dhuhr],
      ['Asr', _todayPrayerTimes!.asr],
      ['Maghrib', _todayPrayerTimes!.maghrib],
      ['Isha', _todayPrayerTimes!.isha],
    ];
    for (final bt in beginningTimes) {
      final parts = bt[1].split(':');
      if (parts.length < 2) continue;
      final pt = DateTime(now.year, now.month, now.day, int.parse(parts[0]),
          int.parse(parts[1]));
      if (pt.isAfter(now)) {
        beginningRemaining = _formatCountdown(pt.difference(now));
        break;
      }
    }
    if (beginningRemaining.isEmpty) {
      // wrap to tomorrow fajr beginning
      final fp = _todayPrayerTimes!.fajr.split(':');
      if (fp.length >= 2) {
        final nextFajr = DateTime(now.year, now.month, now.day + 1,
            int.parse(fp[0]), int.parse(fp[1]));
        beginningRemaining = _formatCountdown(nextFajr.difference(now));
      }
    }

    setState(() {
      _nextPrayerName = nextName;
      _timeRemaining = remaining;
      _beginningTimeRemaining = beginningRemaining;
      _now = now;
    });
  }

  /// Format countdown: show hh:mm normally; show mm:ss when ≤ 5 min remaining.
  String _formatCountdown(Duration diff) {
    final totalSecs = diff.inSeconds;
    if (totalSecs <= 900) {
      // switch to MM:SS in last 15 minutes
      // ≤ 5 minutes — show mm:ss
      final m = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$m:$s';
    }
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  // ══════════════════════════════════════════════════════════════════
  // HIJRI DATE  — fetched from Aladhan API (accurate)
  // Falls back to local JDN calculation if offline
  // ══════════════════════════════════════════════════════════════════
  Future<void> _updateHijri() async {
    try {
      final now = DateTime.now();
      final url = Uri.parse(
          'https://api.aladhan.com/v1/gToH/${now.day}-${now.month}-${now.year}');
      final resp = await http.get(url).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final hijri = data['data']['hijri'];
        final day = hijri['day'] as String;
        final month = hijri['month']['en'] as String;
        final year = hijri['year'] as String;
        if (mounted) setState(() => _hijriDate = '$day $month $year AH');
        return;
      }
    } catch (_) {}
    // Fallback: local JDN calculation
    _updateHijriLocal();
  }

  void _updateHijriLocal() {
    final now = DateTime.now();
    final jdn = _gregorianToJdn(now.year, now.month, now.day);
    final hijri = _jdnToHijri(jdn);
    const months = [
      'Muharram',
      'Safar',
      "Rabi' al-Awwal",
      "Rabi' al-Thani",
      'Jumada al-Ula',
      'Jumada al-Akhirah',
      'Rajab',
      "Sha'ban",
      'Ramadan',
      'Shawwal',
      "Dhu al-Qa'dah",
      'Dhu al-Hijjah',
    ];
    if (mounted) {
      setState(() {
        _hijriDate = '${hijri[2]} ${months[hijri[1] - 1]} ${hijri[0]} AH';
      });
    }
  }

  int _gregorianToJdn(int y, int m, int d) {
    return (1461 * (y + 4800 + (m - 14) ~/ 12)) ~/ 4 +
        (367 * (m - 2 - 12 * ((m - 14) ~/ 12))) ~/ 12 -
        (3 * ((y + 4900 + (m - 14) ~/ 12) ~/ 100)) ~/ 4 +
        d -
        32075;
  }

  List<int> _jdnToHijri(int jdn) {
    final l = jdn - 1948440 + 10632;
    final n = (l - 1) ~/ 10631;
    final ll = l - 10631 * n + 354;
    final j = ((10985 - ll) ~/ 5316) * ((50 * ll) ~/ 17719) +
        (ll ~/ 5670) * ((43 * ll) ~/ 15238);
    final lll = ll -
        ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) -
        (j ~/ 16) * ((15238 * j) ~/ 43) +
        29;
    final month = (24 * lll) ~/ 709;
    final day = lll - (709 * month) ~/ 24;
    final year = 30 * n + j - 30;
    return [year, month, day];
  }

  // ══════════════════════════════════════════════════════════════════
  // ADHAN + MAKROOH CHECK  — fires every second from _secondsTimer
  // ══════════════════════════════════════════════════════════════════
  String _lastAdhaanFired = '';

  void _checkAdhan() {
    if (_todayPrayerTimes == null) return;
    final now = DateTime.now();
    final nowStr = DateFormat('HH:mm').format(now);

    // ── Adhan popup — fires within a ±2 min window of prayer beginning ──
    // Using a window rather than exact match so browser timer throttling
    // (common on GitHub Pages / background tabs) can't cause a miss.
    // _lastAdhaanFired stores the prayer name key so it only fires once
    // per prayer per day regardless of how many ticks land in the window.
    final pairs = [
      ['Fajr', _todayPrayerTimes!.fajr],
      ['Dhuhr', _todayPrayerTimes!.dhuhr],
      ['Asr', _todayPrayerTimes!.asr],
      ['Maghrib', _todayPrayerTimes!.maghrib],
      ['Isha', _todayPrayerTimes!.isha],
    ];

    // Helper: parse "HH:mm" → total minutes since midnight
    int toMins(String t) {
      final p = t.split(':');
      if (p.length < 2) return -1;
      return int.tryParse(p[0])! * 60 + int.tryParse(p[1])!;
    }

    final nowMins = now.hour * 60 + now.minute;
    // Key includes the date so it resets every day
    final dayKey = DateFormat('yyyy-MM-dd').format(now);

    for (final p in pairs) {
      final prayerMins = toMins(p[1]);
      if (prayerMins < 0) continue;
      final diff = nowMins - prayerMins; // positive = we've passed it
      // Fire if we're 0–2 minutes past the prayer time, once per prayer per day
      if (diff >= 0 && diff <= 2) {
        final fireKey = '${p[0]}-$dayKey';
        if (_lastAdhaanFired != fireKey) {
          _lastAdhaanFired = fireKey;
          _triggerAdhan(p[0]);
          break;
        }
      }
    }

    // ── Iqamah popup — fires 0–2 min window of jamaat time ──────────
    if (_prayerRows.isNotEmpty) {
      final jamaatPairs = _prayerRows
          .where((r) => r.jamaatTime.isNotEmpty && r.jamaatTime != '--')
          .map((r) => [r.name, r.jamaatTime])
          .toList();
      for (final p in jamaatPairs) {
        final jMins = toMins(p[1]);
        if (jMins < 0) continue;
        final diff = nowMins - jMins;
        if (diff >= 0 && diff <= 2) {
          final fireKey = 'iqamah-${p[0]}-$dayKey';
          if (_lastIqamahFired != fireKey) {
            // For Maghrib: skip iqamah here if the adhan→adhanMasjid→dua
            // sequence is already in progress — it will call _triggerIqamah itself.
            if (p[0] == 'Maghrib' &&
                (_showAdhanMasjid || _showAdhanDua || _showAdhaan)) {
              break;
            }
            _lastIqamahFired = fireKey;
            // For Jumu'ah (1st): fire jamaah adhan (2:30) → khutbah (5 min) → iqamah → blackout
            if (p[0] == "Jumu'ah") {
              _triggerJumuahJamaahSequence(p[0]);
            } else {
              _triggerIqamah(p[0]);
            }
            // Blackout is now scheduled inside _triggerIqamah itself
          }
          break;
        }
      }

      // ── 2nd Jumu'ah — fires adhan (2:30) → khutbah (5 min) → iqamah → blackout ──
      // _jumuahTimes[0] = 1st Jumu'ah (already handled via _prayerRows above on Friday).
      // _jumuahTimes[1] = 2nd Jumu'ah.
      if (_jumuahTimes.length >= 2 &&
          DateTime.now().weekday == DateTime.friday) {
        final j2Time = _jumuahTimes[1];
        final j2Mins = toMins(j2Time);
        if (j2Mins >= 0) {
          final diff = nowMins - j2Mins;
          if (diff >= 0 && diff <= 2) {
            final fireKey = 'jumuah2-$dayKey';
            if (_lastJumuahJamaahFired != fireKey) {
              _lastJumuahJamaahFired = fireKey;
              _triggerJumuahJamaahSequence("Jumu'ah 2nd");
            }
          }
        }
      }

      // ── Adhan Masjid — fires based on gap between beginning and jamaah ──
      // Skip Maghrib — its flow is handled after the beginning adhan fires.
      // Gap > 15 min: fire at 15 min before iqamah (original behaviour).
      // Gap ≤ 15 min: at beginning time, skip the 7-second overlay and go
      //               straight to adhanMasjid (3 min) → dua.
      for (final p in jamaatPairs) {
        if (p[0] == 'Maghrib') continue;
        final jMins = toMins(p[1]);
        if (jMins < 0) continue;

        // Find this prayer's beginning time from _prayerRows
        final row = _prayerRows.firstWhere(
          (r) => r.name == p[0],
          orElse: () => PrayerTime(p[0], '', p[1]),
        );
        final bMins = toMins(row.time);
        final gap = (bMins >= 0) ? (jMins - bMins) : 999;

        if (gap > 15) {
          // Original behaviour: fire at 15 min before iqamah
          final targetMins = jMins - 15;
          final diff = nowMins - targetMins;
          if (diff >= 0 && diff <= 2) {
            final fireKey = 'adhanmasjid-${p[0]}-$dayKey';
            if (_lastAdhanMasjidFired != fireKey) {
              _lastAdhanMasjidFired = fireKey;
              _triggerAdhanMasjid(p[0]);
            }
            break;
          }
        } else {
          // Short gap: at beginning time, cancel the 7-sec adhan and go straight
          // to adhanMasjid (3 min adhan) → dua
          if (bMins >= 0) {
            final diff = nowMins - bMins;
            if (diff >= 0 && diff <= 2) {
              final fireKey = 'adhanmasjid-${p[0]}-$dayKey';
              if (_lastAdhanMasjidFired != fireKey) {
                _lastAdhanMasjidFired = fireKey;
                // Cancel and suppress the 7-second beginning adhan overlay
                _adhaanTimer?.cancel();
                setState(() => _showAdhaan = false);
                // Also consume the beginning adhan fire key so it doesn't re-trigger
                _lastAdhaanFired = '${p[0]}-$dayKey';
                _triggerAdhanMasjid(p[0]);
              }
              break;
            }
          }
        }
      }
    }

    // ── Makrooh time check ─────────────────────────────────────────
    // Makrooh 1: between Sunrise and Ishraq (15 min after sunrise)
    // Makrooh 2: between Zawwal (10 min before Dhuhr) and Dhuhr
    // Makrooh 3: exactly at Dhuhr beginning (zawwal moment) — short flash
    _checkMakrooh(now, nowStr);

    // ── Update remaining countdown (needs seconds precision) ────────
    _updateRemainingTime();
  }

  void _checkMakrooh(DateTime now, String nowStr) {
    DateTime? parse(String t) {
      if (t == '--' || t.isEmpty) return null;
      final p = t.split(':');
      if (p.length < 2) return null;
      try {
        return DateTime(
            now.year, now.month, now.day, int.parse(p[0]), int.parse(p[1]));
      } catch (_) {
        return null;
      }
    }

    String? title;
    String? sub;
    String? endTime;
    String key = '';
    Duration? remaining;

    final sunrise = parse(_todayPrayerTimes!.sunrise);
    final dhuhr = parse(_todayPrayerTimes!.dhuhr);

    // Window 1: Sunrise to Ishraq
    if (sunrise != null && _ishraqTime != '--') {
      final ishraq = parse(_ishraqTime);
      if (ishraq != null && now.isAfter(sunrise) && now.isBefore(ishraq)) {
        title = 'وقت مكروه  ·  Makrūh Time';
        sub = 'Prayer is disliked between Sunrise and Ishrāq';
        endTime = _ishraqTime;
        remaining = ishraq.difference(now);
        key = 'sunrise-ishraq';
      }
    }

    // Window 2: Zawwal to Dhuhr
    if (title == null && dhuhr != null && _zawwalTime != '--') {
      final zawwal = parse(_zawwalTime);
      if (zawwal != null && now.isAfter(zawwal) && now.isBefore(dhuhr)) {
        title = 'وقت مكروه  ·  Zawwāl';
        sub = 'Prayer is disliked from Zawwāl until Dhuhr begins';
        endTime = _todayPrayerTimes!.dhuhr;
        remaining = dhuhr.difference(now);
        key = 'zawwal-dhuhr';
      }
    }

    if (title != null) {
      final timeLeft = remaining != null ? _formatCountdown(remaining!) : '';
      if (_lastMakroohFired != key) {
        // New window — show overlay
        _lastMakroohFired = key;
        setState(() {
          _showMakrooh = true;
          _makroohLabel = title!;
          _makroohSubLabel = sub ?? '';
          _makroohEndTime = endTime ?? '';
          _makroohTimeLeft = timeLeft;
        });
      } else {
        // Same window — update countdown
        setState(() {
          _showMakrooh = true;
          _makroohTimeLeft = timeLeft;
        });
      }
    } else {
      // Outside any makrooh window — clear everything
      if (_showMakrooh || _lastMakroohFired.isNotEmpty) {
        setState(() {
          _showMakrooh = false;
          _lastMakroohFired = '';
        });
      }
    }
  }

  void _triggerAdhan(String prayerName) {
    _adhaanTimer?.cancel();
    // For Maghrib: immediately claim the iqamah fire-key so the minute-timer
    // can never independently call _triggerIqamah (and thus _triggerBlackout)
    // before the full adhan → adhanMasjid → dua sequence has finished.
    if (prayerName == 'Maghrib') {
      final dayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _lastIqamahFired = 'iqamah-Maghrib-$dayKey';
    }
    setState(() {
      _showAdhaan = true;
      _adhaanPrayerName = prayerName;
    });
    _adhaanTimer = Timer(const Duration(seconds: 7), () {
      if (!mounted) return;
      setState(() => _showAdhaan = false);
      // Maghrib special case: 3 min adhanMasjid → dua → iqamah → blackout
      if (prayerName == 'Maghrib') {
        _triggerAdhanMasjid(prayerName, isMaghribPost: true);
      }
    });
  }

  /// Fires the Adhan Masjid overlay (call-to-mosque popup).
  /// For normal salah: triggered 15 min before iqamah.
  /// For Maghrib [isMaghribPost=true]: triggered right after adhan, lasts 3 min.
  void _triggerAdhanMasjid(String prayerName, {bool isMaghribPost = false}) {
    _adhanMasjidTimer?.cancel();
    _adhanMasjidCountdownTimer?.cancel();
    const totalSecs = 60; // 1 minutes
    int secsLeft = totalSecs;
    if (!mounted) return;
    setState(() {
      _showAdhanMasjid = true;
      _adhanMasjidPrayerName = prayerName;
      _adhanMasjidTimeLeft = _fmtMmSs(totalSecs);
      // Dismiss adhan if still showing
      _showAdhaan = false;
    });
    _adhanMasjidCountdownTimer =
        Timer.periodic(const Duration(seconds: 1), (t) {
      secsLeft--;
      if (!mounted || secsLeft <= 0) {
        t.cancel();
        if (mounted) {
          setState(() {
            _showAdhanMasjid = false;
            _adhanMasjidTimeLeft = '';
          });
          _triggerAdhanDua(prayerName, isMaghribPost: isMaghribPost);
        }
        return;
      }
      setState(() => _adhanMasjidTimeLeft = _fmtMmSs(secsLeft));
    });
  }

  /// Fires the Adhan Dua overlay after the Adhan Masjid popup ends.
  /// For Maghrib [isMaghribPost=true]: immediately fires jamaah overlay after dua.
  void _triggerAdhanDua(String prayerName, {bool isMaghribPost = false}) {
    _adhanDuaTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _showAdhanDua = true;
      _adhanDuaPrayerName = prayerName;
    });
    // Show dua for 30 seconds, then for Maghrib immediately fire iqamah/blackout
    _adhanDuaTimer = Timer(const Duration(seconds: 90), () {
      if (!mounted) return;
      setState(() => _showAdhanDua = false);
      if (isMaghribPost) {
        // Mark iqamah as fired for today (already done in _triggerAdhan for
        // Maghrib, but this is a belt-and-braces guard for other callers).
        final dayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
        _lastIqamahFired = 'iqamah-Maghrib-$dayKey';
        // Immediately trigger iqamah (which itself fires blackout after 14s)
        _triggerIqamah(prayerName);
      }
    });
  }

  /// Called at the moment iqamah fires for [prayerName].
  /// Immediately swaps that prayer's displayed beginning + jamaat times to
  /// tomorrow's values from the in-RAM cache so the screen updates at once,
  /// without waiting for the midnight daily refresh.
  void _rolloverPrayerForIqamah(String prayerName) {
    if (_prayerRows.isEmpty) return;
    final tomorrowStr = DateTime.now()
        .add(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);
    final td = _prayerCache[tomorrowStr];
    if (td == null) return; // cache not populated yet — no-op

    // Map from the display name to the Firestore field keys for tomorrow
    const tomorrowKeys = {
      'Fajr': {'b': 'fajrB', 'j': 'fajrJ'},
      "Jumu'ah": {'b': 'dhuhrB', 'j': 'dhuhrJ'},
      'Dhuhr': {'b': 'dhuhrB', 'j': 'dhuhrJ'},
      'Asr': {'b': 'asrB', 'j': 'asrJ'},
      'Maghrib': {'b': 'maghrib', 'j': 'maghrib'},
      'Isha': {'b': 'ishaB', 'j': 'ishaJ'},
    };

    final keys = tomorrowKeys[prayerName];
    if (keys == null) return;

    final newBeginning = (td[keys['b']] ?? '--') as String;
    final newJamaat = (td[keys['j']] ?? '--') as String;

    final updatedRows = _prayerRows.map((row) {
      if (row.name == prayerName) {
        return PrayerTime(row.name, newBeginning, newJamaat);
      }
      return row;
    }).toList();

    setState(() => _prayerRows = updatedRows);
    _updateRemainingTime();
  }

  /// Fires the Jumu'ah jamaah sequence:
  /// Adhan overlay (2:30) → Khutbah overlay (5 min) → Iqamah → Blackout (as normal).
  /// Used for both 1st and 2nd Jumu'ah.
  void _triggerJumuahJamaahSequence(String label) {
    _jumuahJamaahAdhanTimer?.cancel();
    _khutbahTimer?.cancel();
    const adhanSecs = 150; // 2 minutes 30 seconds
    int secsLeft = adhanSecs;
    if (!mounted) return;
    setState(() {
      _showJumuahJamaahAdhan = true;
      _jumuahJamaahAdhanTimeLeft = _fmtMmSs(adhanSecs);
      // Dismiss any other overlays
      _showAdhaan = false;
      _showAdhanMasjid = false;
      _showAdhanDua = false;
    });
    _jumuahJamaahAdhanTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      secsLeft--;
      if (!mounted || secsLeft <= 0) {
        t.cancel();
        if (mounted) {
          setState(() {
            _showJumuahJamaahAdhan = false;
            _jumuahJamaahAdhanTimeLeft = '';
          });
          _triggerKhutbah(label);
        }
        return;
      }
      setState(() => _jumuahJamaahAdhanTimeLeft = _fmtMmSs(secsLeft));
    });
  }

  /// Fires the Khutbah overlay for 5 minutes, then triggers iqamah → blackout.
  void _triggerKhutbah(String label) {
    _khutbahTimer?.cancel();
    const totalSecs = 5 * 60; // 5 minutes
    int secsLeft = totalSecs;
    if (!mounted) return;
    setState(() {
      _showKhutbah = true;
      _khutbahTimeLeft = _fmtMmSs(totalSecs);
    });
    _khutbahTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      secsLeft--;
      if (!mounted || secsLeft <= 0) {
        t.cancel();
        if (mounted) {
          setState(() {
            _showKhutbah = false;
            _khutbahTimeLeft = '';
          });
          _triggerIqamah(label);
        }
        return;
      }
      setState(() => _khutbahTimeLeft = _fmtMmSs(secsLeft));
    });
  }

  void _triggerIqamah(String prayerName) {
    _iqamahTimer?.cancel();
    // Immediately roll the display over to tomorrow's times for this prayer
    _rolloverPrayerForIqamah(prayerName);
    setState(() {
      _showIqamah = true;
      _iqamahPrayerName = prayerName;
      // Dismiss adhan/adhan masjid/dua if still showing
      _showAdhaan = false;
      _showAdhanMasjid = false;
      _showAdhanDua = false;
    });
    _iqamahTimer = Timer(const Duration(seconds: 20), () {
      if (!mounted) return;
      setState(() => _showIqamah = false);
      // Blackout starts immediately after iqamah dismisses — no delay
      _triggerBlackout(prayerName);
    });
  }

  void _triggerBlackout(String prayerName) {
    _blackoutTimer?.cancel();
    _blackoutCountdownTimer?.cancel();
    const totalSecs = 7 * 60; // 7 minutes
    int secsLeft = totalSecs;
    _blackoutTimeLeft = _fmtMmSs(secsLeft);
    setState(() {
      _showBlackout = true;
      _blackoutPrayerName = prayerName;
      _showIqamah = false;
      _showHadith = false;
    });
    // Tick every second for the countdown display
    _blackoutCountdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      secsLeft--;
      if (!mounted || secsLeft <= 0) {
        t.cancel();
        if (mounted) {
          setState(() => _showBlackout = false);
          _startAdhkarSequence(prayerName);
        }
        return;
      }
      setState(() => _blackoutTimeLeft = _fmtMmSs(secsLeft));
    });
  }

  String _fmtMmSs(int totalSecs) {
    final m = (totalSecs ~/ 60).toString().padLeft(2, '0');
    final s = (totalSecs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ══════════════════════════════════════════════════════════════════
  // ADHKAR SEQUENCE — fires after each 7-min blackout
  // Steps: 1(5s) 2(5s) 3(7s) 4(7s) 5(5s) 6(5s) 7(7s) 8(5s) [9(5s) fajr/maghrib only]
  // ══════════════════════════════════════════════════════════════════
  void _startAdhkarSequence(String prayerName) {
    if (!mounted) return;
    _adhkarTimer?.cancel();
    setState(() {
      _showAdhkar = true;
      _adhkarStep = 1;
      _adhkarPrayerName = prayerName;
    });
    _scheduleNextAdhkar();
  }

  void _scheduleNextAdhkar() {
    if (!mounted) return;
    // Determine duration for current step
    final isFajrOrMaghrib =
        _adhkarPrayerName == 'Fajr' || _adhkarPrayerName == 'Maghrib';
    final lastStep = isFajrOrMaghrib ? 9 : 8;

    int secs;
    switch (_adhkarStep) {
      case 1:
        secs = 10;
        break;
      case 2:
        secs = 10;
        break;
      case 3:
        secs = 14;
        break;
      case 4:
        secs = 14;
        break;
      case 5:
        secs = 10;
        break;
      case 6:
        secs = 10;
        break;
      case 7:
        secs = 14;
        break;
      case 8:
        secs = 10;
        break;
      case 9:
        secs = 10;
        break;
      default:
        secs = 10;
    }

    _adhkarTimer = Timer(Duration(seconds: secs), () {
      if (!mounted) return;
      if (_adhkarStep >= lastStep) {
        setState(() => _showAdhkar = false);
        return;
      }
      setState(() => _adhkarStep++);
      _scheduleNextAdhkar();
    });
  }

  // ══════════════════════════════════════════════════════════════════
  // DATA
  // ══════════════════════════════════════════════════════════════════

  /// Returns true only if the device can reach the internet (not just LAN).
  /// Uses a lightweight HEAD request to a reliable endpoint.
  /// Falls back to false on any error so offline path is used safely.
  Future<bool> _hasInternet() async {
    try {
      final resp = await http
          .head(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 4));
      return resp.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  /// Called once at midnight (date change detected by the minute timer).
  /// Online  → re-fetch today's document from Firestore, refresh cache entry.
  /// Offline → read today's data directly from _prayerCache, no network call.
  Future<void> _handleDailyRefresh(String today) async {
    if (_selectedMosque == null) {
      // No mosque selected — only reload if internet is available.
      if (await _hasInternet()) {
        await _loadAllMosques();
      }
      return;
    }

    if (await _hasInternet()) {
      // Internet available: full fresh fetch (also refreshes the cache).
      await _selectMosque(_selectedMosque!);
    } else {
      // No internet (LAN-only or fully offline): serve from in-RAM cache.
      final cached = _prayerCache[today];
      if (cached != null) {
        _applyDayData(cached, today, _selectedMosque!);
      } else {
        // Cache miss for today — try yesterday as a graceful fallback.
        final yesterday = DateFormat('yyyy-MM-dd')
            .format(DateTime.now().subtract(const Duration(days: 1)));
        final fallback = _prayerCache[yesterday];
        if (fallback != null) {
          _applyDayData(fallback, today, _selectedMosque!);
        }
        // If nothing in cache at all, leave current data on screen.
      }
    }
  }

  /// Parses a raw Firestore prayer-times doc [jd] for [today] and updates
  /// all prayer-time state. Shared by both the online and offline refresh paths.
  void _applyDayData(
      Map<String, dynamic> jd, String today, Map<String, dynamic> mosque) {
    final List<String> beginningTimes = [
      (jd['fajrB'] ?? '--') as String,
      (jd['sunrise'] ?? '--') as String,
      (jd['dhuhrB'] ?? '--') as String,
      (jd['asrB'] ?? '--') as String,
      (jd['maghrib'] ?? '--') as String,
      (jd['ishaB'] ?? '--') as String,
    ];
    final jamaatTimes = [
      (jd['fajrJ'] ?? '--') as String,
      (jd['sunrise'] ?? '--') as String,
      (jd['dhuhrJ'] ?? '--') as String,
      (jd['asrJ'] ?? '--') as String,
      (jd['maghrib'] ?? '--') as String,
      (jd['ishaJ'] ?? '--') as String,
    ];
    final todayPt = PrayerTimes(
      date: today,
      fajr: beginningTimes[0],
      sunrise: beginningTimes[1],
      dhuhr: beginningTimes[2],
      asr: beginningTimes[3],
      maghrib: beginningTimes[4],
      isha: beginningTimes[5],
    );

    // Derived times
    String ishraqTime = '--', zawwalTime = '--', suhoorTime = '--';
    try {
      if (beginningTimes[1] != '--' && beginningTimes[1].isNotEmpty) {
        final sp = beginningTimes[1].split(':');
        final m = int.parse(sp[0]) * 60 + int.parse(sp[1]) + 15;
        ishraqTime =
            '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
      }
    } catch (_) {}
    try {
      if (beginningTimes[2] != '--' && beginningTimes[2].isNotEmpty) {
        final dp = beginningTimes[2].split(':');
        final m = int.parse(dp[0]) * 60 + int.parse(dp[1]) - 7;
        zawwalTime =
            '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
      }
    } catch (_) {}
    try {
      if (beginningTimes[0] != '--' && beginningTimes[0].isNotEmpty) {
        final fp = beginningTimes[0].split(':');
        final m = int.parse(fp[0]) * 60 + int.parse(fp[1]) - 10;
        suhoorTime =
            '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
      }
    } catch (_) {}

    // Jumu'ah times from cache
    List<String> jumuahList = [];
    try {
      final nowDt = DateTime.now();
      final daysUntilFriday = (DateTime.friday - nowDt.weekday + 7) % 7;
      final fridayStr = nowDt
          .add(Duration(days: daysUntilFriday))
          .toIso8601String()
          .substring(0, 10);
      final fridayData =
          nowDt.weekday == DateTime.friday ? jd : _prayerCache[fridayStr];
      if (fridayData != null) {
        final raw = fridayData['jummahTimes'];
        if (raw is List) {
          for (final v in raw) {
            final s = v?.toString() ?? '';
            if (s.isNotEmpty && s != '--') jumuahList.add(s);
          }
        }
      }
    } catch (_) {}

    // Tomorrow's Fajr from cache
    String tomorrowFajr = '--';
    try {
      final tStr = DateTime.now()
          .add(const Duration(days: 1))
          .toIso8601String()
          .substring(0, 10);
      tomorrowFajr = (_prayerCache[tStr]?['fajrB'] ?? '--') as String;
    } catch (_) {}

    final isFriday = DateTime.now().weekday == DateTime.friday;

    // Tomorrow's cache data (for rolling over passed prayer times)
    final tomorrowStr = DateTime.now()
        .add(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);
    final tomorrowData = _prayerCache[tomorrowStr];

    // Helper: returns today's time if jamaat hasn't passed yet,
    // otherwise returns tomorrow's time from cache.
    String resolveTime(String todayTime, String tomorrowKey) {
      if (todayTime == '--' || todayTime.isEmpty) return todayTime;
      try {
        final now = DateTime.now();
        final parts = todayTime.split(':');
        final pt = DateTime(now.year, now.month, now.day, int.parse(parts[0]),
            int.parse(parts[1]));
        if (pt.isAfter(now)) return todayTime;
        // Jamaat has passed — use tomorrow's value
        return (tomorrowData?[tomorrowKey] ?? '--') as String;
      } catch (_) {
        return todayTime;
      }
    }

    // For each prayer, resolve beginning and jamaat using the jamaat time
    // as the trigger: if jamaat has passed, show tomorrow's times for that prayer.
    String resolveBeginning(String todayBeginning, String todayJamaat,
        String tomorrowBeginningKey) {
      if (todayJamaat == '--' || todayJamaat.isEmpty) return todayBeginning;
      try {
        final now = DateTime.now();
        final parts = todayJamaat.split(':');
        final pt = DateTime(now.year, now.month, now.day, int.parse(parts[0]),
            int.parse(parts[1]));
        if (pt.isAfter(now)) return todayBeginning;
        return (tomorrowData?[tomorrowBeginningKey] ?? '--') as String;
      } catch (_) {
        return todayBeginning;
      }
    }

    final fajrB = resolveBeginning(beginningTimes[0], jamaatTimes[0], 'fajrB');
    final fajrJ = resolveTime(jamaatTimes[0], 'fajrJ');
    final sunriseB = beginningTimes[1]; // Sunrise has no jamaat — always today
    final dhuhrB =
        resolveBeginning(beginningTimes[2], jamaatTimes[2], 'dhuhrB');
    final dhuhrJ = resolveTime(jamaatTimes[2], 'dhuhrJ');
    final asrB = resolveBeginning(beginningTimes[3], jamaatTimes[3], 'asrB');
    final asrJ = resolveTime(jamaatTimes[3], 'asrJ');
    final maghribB =
        resolveBeginning(beginningTimes[4], jamaatTimes[4], 'maghrib');
    final maghribJ = resolveTime(jamaatTimes[4], 'maghrib');
    final ishaB = resolveBeginning(beginningTimes[5], jamaatTimes[5], 'ishaB');
    final ishaJ = resolveTime(jamaatTimes[5], 'ishaJ');

    final rows = [
      PrayerTime('Fajr', fajrB, fajrJ),
      PrayerTime('Sunrise', sunriseB, '--'),
      PrayerTime(
        isFriday ? "Jumu'ah" : 'Dhuhr',
        dhuhrB,
        dhuhrJ,
      ),
      PrayerTime('Asr', asrB, asrJ),
      PrayerTime('Maghrib', maghribB, maghribJ),
      PrayerTime('Isha', ishaB, ishaJ),
    ];

    if (!mounted) return;
    setState(() {
      _prayerRows = rows;
      _todayPrayerTimes = todayPt;
      _isLoadingTimes = false;
      _ishraqTime = ishraqTime;
      _zawwalTime = zawwalTime;
      _suhoorTime = suhoorTime;
      _jumuahTimes = jumuahList;
      _tomorrowFajr = tomorrowFajr;
    });
    _updateRemainingTime();
    _updateHijri();
    _heroCtrl.forward();
    _tableCtrl.forward();
    _rowCtrl.forward();
  }

  Future<void> _loadAllMosques() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('mosques').get();
      final list = snap.docs
          .map(
            (d) => {
              'id': d.id,
              'name': (d.data()['name'] ?? d.id) as String,
              'city': (d.data()['city'] ?? '') as String,
            },
          )
          .toList();
      list.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      // Fetch which mosques are already claimed by other display accounts
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final takenSnap =
          await FirebaseFirestore.instance.collection('displayMosques').get();
      final taken = <String>{};
      for (final doc in takenSnap.docs) {
        // Skip the current user's own binding — they are allowed to keep theirs
        if (doc.id == currentUid) continue;
        final mosqueId = doc.data()['mosqueId'] as String? ?? '';
        if (mosqueId.isNotEmpty) taken.add(mosqueId);
      }

      setState(() {
        _allMosques = list;
        _filteredMosques = list;
        _isLoadingMosques = false;
        _takenMosqueIds = taken;
      });
    } catch (e) {
      setState(() {
        _errorMsg = 'Failed to load mosques: $e';
        _isLoadingMosques = false;
      });
    }
  }

  Future<void> _selectMosque(Map<String, dynamic> mosque) async {
    setState(() {
      _selectedMosque = mosque;
      _isLoadingTimes = true;
      _noTimetable = false;
      _prayerRows = [];
      _todayPrayerTimes = null;
      _showSuggestions = false;
      _errorMsg = null;
      _searchCtrl.text = mosque['name'];
    });
    _heroCtrl.reset();
    _tableCtrl.reset();
    _rowCtrl.reset();

    final today = DateTime.now().toIso8601String().substring(0, 10);

    try {
      // ── Bulk-fetch ALL prayer time documents for this mosque ─────────────
      // One Firestore read gets every date document and stores them in RAM.
      // This powers offline fallback for all future daily refreshes.
      final allDocs = await FirebaseFirestore.instance
          .collection('mosques')
          .doc(mosque['id'])
          .collection('prayerTimes')
          .get();

      if (allDocs.docs.isEmpty) {
        setState(() {
          _noTimetable = true;
          _isLoadingTimes = false;
        });
        return;
      }

      // Populate in-RAM cache: key = 'yyyy-MM-dd'
      final newCache = <String, Map<String, dynamic>>{};
      for (final doc in allDocs.docs) {
        newCache[doc.id] = doc.data();
      }
      _prayerCache = newCache;
      _cachedMosqueId = mosque['id'] as String;

      // Find today's document from cache
      final jd = _prayerCache[today];
      if (jd == null) {
        setState(() {
          _noTimetable = true;
          _isLoadingTimes = false;
        });
        return;
      }

      // Apply today's data using the shared helper
      _applyDayData(jd, today, mosque);

      FirebaseAnalytics.instance.logEvent(
        name: 'mosque_viewed',
        parameters: {
          'mosque_name': mosque['name'] as String,
          'mosque_id': mosque['id'] as String,
          'city': (mosque['city'] ?? '') as String,
        },
      ).catchError((e) => debugPrint('Analytics logEvent error: $e'));
    } catch (e) {
      setState(() {
        _errorMsg = 'Could not load times: $e';
        _isLoadingTimes = false;
      });
    }

    // ════════════════════════════════════════════════════════════════
    // ALADHAN API — kept for future use, currently unused
    // To re-enable: replace the Firebase beginning times block above
    // with this section and restore imports (http, jsonDecode, etc.)
    // ════════════════════════════════════════════════════════════════
    //
    // final mosqueDoc = await FirebaseFirestore.instance
    //     .collection('mosques')
    //     .doc(mosque['id'])
    //     .get();
    // double lat = 0, lng = 0;
    // if (mosqueDoc.data()?['location'] != null) {
    //   final geo = mosqueDoc.data()!['location'] as GeoPoint;
    //   lat = geo.latitude;
    //   lng = geo.longitude;
    // }
    // List<String> beginningTimes = List.filled(6, '--');
    // PrayerTimes? todayPt;
    // if (lat != 0 && lng != 0) {
    //   final now = DateTime.now();
    //   final url =
    //       'https://api.aladhan.com/v1/calendar?latitude=$lat&longitude=$lng'
    //       '&method=$method&school=$school&year=${now.year}&month=${now.month}';
    //   final resp = await http.get(Uri.parse(url));
    //   if (resp.statusCode == 200) {
    //     final json = jsonDecode(resp.body);
    //     final todayStr = DateFormat('dd-MM-yyyy').format(now);
    //     await loadAdjustments();
    //     for (final day in json['data']) {
    //       final pt = PrayerTimes.fromJson(day);
    //       if (pt.date == todayStr) {
    //         final raw = [
    //           PrayerTimes.removeGMT(pt.fajr),
    //           PrayerTimes.removeGMT(pt.sunrise),
    //           PrayerTimes.removeGMT(pt.dhuhr),
    //           PrayerTimes.removeGMT(pt.asr),
    //           PrayerTimes.removeGMT(pt.maghrib),
    //           PrayerTimes.removeGMT(pt.isha),
    //         ];
    //         beginningTimes = adjustPrayerTimesIndividually(raw, adjustments);
    //         todayPt = PrayerTimes(
    //           date: pt.date,
    //           fajr: beginningTimes[0],
    //           sunrise: beginningTimes[1],
    //           dhuhr: beginningTimes[2],
    //           asr: beginningTimes[3],
    //           maghrib: beginningTimes[4],
    //           isha: beginningTimes[5],
    //         );
    //         break;
    //       }
    //     }
    //   }
    // }
    // ════════════════════════════════════════════════════════════════
  }

  void _filterMosques(String query) {
    final q = query.toLowerCase();
    setState(() {
      _filteredMosques = _allMosques
          .where(
            (m) =>
                (m['name'] as String).toLowerCase().contains(q) ||
                (m['city'] as String).toLowerCase().contains(q),
          )
          .toList();
      _showSuggestions = query.isNotEmpty;
    });
  }

  void _goToLogin() => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WebLoginPage()),
      );

  void _logOut() => FirebaseAuth.instance.signOut();

  // ══════════════════════════════════════════════════════════════════
  // DISPLAYMOSQUE BINDING
  // Collection: displayMosques/{uid}  — completely separate from mosques/
  // ══════════════════════════════════════════════════════════════════
  Future<void> _checkMosqueBinding(String uid) async {
    setState(() => _checkingBinding = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('displayMosques')
          .doc(uid)
          .get();
      if (doc.exists && doc.data()?['mosqueId'] != null) {
        final mosqueId = doc.data()!['mosqueId'] as String? ?? '';
        final mosqueName = doc.data()!['mosqueName'] as String? ?? '';
        final mosqueCity = doc.data()!['mosqueCity'] as String? ?? '';
        final savedTicker =
            (doc.data()!['customTickerMessage'] as String?) ?? '';
        if (mosqueId.isNotEmpty) {
          final bound = {
            'id': mosqueId,
            'name': mosqueName,
            'city': mosqueCity,
          };
          await _selectMosque(bound);
          await _fetchDisplayImages(mosqueId);
          setState(() {
            _checkingBinding = false;
            _showMosqueSetup = false;
            _customTickerMessage = savedTicker;
          });
          return;
        }
      }
      // No binding yet — show setup screen
      setState(() {
        _checkingBinding = false;
        _showMosqueSetup = true;
      });
    } catch (e) {
      setState(() {
        _checkingBinding = false;
        _showMosqueSetup = true;
      });
    }
  }

  Future<void> _saveMosqueBinding(Map<String, dynamic> mosque) async {
    final uid = _currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('displayMosques')
          .doc(uid)
          .set({
        'mosqueId': mosque['id'],
        'mosqueName': mosque['name'],
        'mosqueCity': mosque['city'] ?? '',
        'linkedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _selectMosque(mosque);
      await _fetchDisplayImages(mosque['id'] as String);
      setState(() => _showMosqueSetup = false);
    } catch (e) {
      debugPrint('Error saving mosque binding: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // DISPLAY IMAGES — Storage-only, bytes cached in RAM
  // Path: displayMosques/{mosqueId}/images/{filename}
  // Each mosque has its own isolated folder. Multiple images supported.
  // On load  : listAll() → getData() for each file → store in _displayImageMap
  // On upload: putData() → cache bytes in _displayImageMap
  // On delete: remove from _displayImageMap + delete from Storage
  // No Firestore involved — no sync issues, no rebuild loops.
  // ══════════════════════════════════════════════════════════════════
  Future<void> _fetchDisplayImages(String mosqueId) async {
    if (mosqueId.isEmpty || !mounted) return;
    setState(() => _loadingImages = true);
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('displayMosques/$mosqueId/images');
      final result = await ref.listAll();
      if (!mounted) return;
      // Download all files in parallel
      final entries = await Future.wait(result.items.map((item) async {
        final bytes = await item.getData();
        return MapEntry(item.fullPath, bytes);
      }));
      final newMap = <String, Uint8List>{};
      for (final e in entries) {
        if (e.value != null) newMap[e.key] = e.value!;
      }
      if (!mounted) return;
      setState(() {
        _displayImageMap = newMap;
        if (_displayImageIndex >= _displayImageMap.length) {
          _displayImageIndex =
              _displayImageMap.isEmpty ? 0 : _displayImageMap.length - 1;
        }
        _loadingImages = false;
      });
    } catch (e) {
      debugPrint('fetchDisplayImages error: $e');
      if (mounted) setState(() => _loadingImages = false);
    }
  }

  /// Delete one image: removes from RAM immediately, then deletes from Storage.
  Future<void> _deleteDisplayImage(String storagePath) async {
    // Optimistic removal — UI responds instantly
    setState(() {
      _displayImageMap.remove(storagePath);
      if (_displayImageIndex >= _displayImageMap.length) {
        _displayImageIndex =
            _displayImageMap.isEmpty ? 0 : _displayImageMap.length - 1;
      }
    });
    try {
      await FirebaseStorage.instance.ref(storagePath).delete();
    } catch (e) {
      debugPrint('Storage delete error: $e');
    }
  }

  /// Pick an image from the device, upload to Storage, cache bytes in RAM.
  /// No Firestore involved — bytes are stored in _displayImageMap keyed
  /// by Storage path (displayMosques/{mosqueId}/images/{filename}).
  Future<String?> _uploadImageFromDevice() async {
    final mosqueId = _selectedMosque?['id'] as String?;
    if (mosqueId == null) return null;
    try {
      final picker = ImagePicker();
      final XFile? picked =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return null;
      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.')
          ? picked.name.split('.').last.toLowerCase()
          : 'jpg';

      // ── Confirmation dialog ──────────────────────────────────────
      if (!mounted) return null;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color.fromARGB(255, 8, 18, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Upload image?',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(bytes,
                    height: 160,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image, color: Colors.white38)),
              ),
              const SizedBox(height: 10),
              Text(
                picked.name,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white38)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Upload',
                  style: TextStyle(
                      color: Color.fromARGB(255, 212, 175, 95),
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      if (confirmed != true) return null;

      // ── Upload to Storage ────────────────────────────────────────
      final filename = '\${DateTime.now().millisecondsSinceEpoch}.\$ext';
      final storagePath = 'displayMosques/\$mosqueId/images/\$filename';
      final ref = FirebaseStorage.instance.ref().child(storagePath);
      final metadata = SettableMetadata(contentType: 'image/\$ext');
      await ref.putData(bytes, metadata);

      // Wait for Storage to settle
      await Future.delayed(const Duration(milliseconds: 800));

      // Signal the display screen (other device) to refresh
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('displayMosques')
            .doc(uid)
            .set({'needsRefresh': true}, SetOptions(merge: true));
      }

      // Update this device's map locally
      if (mounted) {
        await _fetchDisplayImages(mosqueId);
      }

      return storagePath;
    } catch (e) {
      debugPrint('Image upload error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // CONTENT SEQUENCE  (8 steps, repeating)
  // 0=wait(20s) 1=hadith(7s) 2=wait(20s) 3=silence(5s)
  // 4=wait(20s) 5=image(7s) 6=wait(20s) 7=promo(7s)
  // ══════════════════════════════════════════════════════════════════
  void _startContentSequence() {
    _sequenceTimer?.cancel();
    _sequenceStep = 0;
    _waitThenAdvance(25);
  }

  // Wait [seconds] then show the next content slot.
  void _waitThenAdvance(int seconds) {
    _sequenceTimer?.cancel();
    _sequenceTimer = Timer(Duration(seconds: seconds), () {
      if (!mounted) return;
      _sequenceStep = (_sequenceStep + 1) % 8;
      _showContentStep();
    });
  }

  // Show content for current step, then schedule next wait.
  void _showContentStep() {
    if (!mounted) return;
    // Priority overlays active — defer by 10 s
    if (_showAdhaan ||
        _showAdhanMasjid ||
        _showAdhanDua ||
        _showJumuahJamaahAdhan ||
        _showKhutbah ||
        _showIqamah ||
        _showBlackout ||
        _showMakrooh ||
        _showAdhkar) {
      _sequenceTimer = Timer(const Duration(seconds: 10), () {
        if (mounted) _showContentStep();
      });
      return;
    }
    switch (_sequenceStep % 8) {
      case 1: // Hadith — 8 seconds
        _pickTodayHadiths();
        setState(() => _showHadith = true);
        _hadithShowTimer?.cancel();
        _hadithShowTimer = Timer(const Duration(seconds: 15), () {
          if (mounted) setState(() => _showHadith = false);
          _waitThenAdvance(25);
        });
        return;
      case 3: // Silence — 5 seconds
        setState(() => _showSilenceOverlayFlag = true);
        _sequenceTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) setState(() => _showSilenceOverlayFlag = false);
          _waitThenAdvance(25);
        });
        return;
      case 5: // Mosque image — 8 seconds (skip if no images)
        if (_displayImageMap.isNotEmpty) {
          setState(() {
            _displayImageIndex =
                (_displayImageIndex + 1) % _displayImageMap.length;
            _showMosqueImageFlag = true;
          });
          _sequenceTimer = Timer(const Duration(seconds: 8), () {
            if (mounted) setState(() => _showMosqueImageFlag = false);
            _waitThenAdvance(25);
          });
          return;
        }
        // No images — skip straight to next wait
        _waitThenAdvance(25);
        return;
      case 7: // App promo — 12 seconds
        setState(() => _showAppPromoFlag = true);
        _sequenceTimer = Timer(const Duration(seconds: 12), () {
          if (mounted) setState(() => _showAppPromoFlag = false);
          _waitThenAdvance(25);
        });
        return;
      default:
        _waitThenAdvance(25);
        return;
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // JAMAAT BATCH WRITE
  // Writes updated jamaat times for all days from today to endDate
  // into displayMosques/{mosqueId}/prayerTimes/{date}
  // ══════════════════════════════════════════════════════════════════
  Future<void> _batchWriteJamaatTimes({
    required String mosqueId,
    required Map<String, String> updatedJamaatTimes,
    // keys: fajrJ, dhuhrJ, asrJ, maghrib, ishaJ
    required DateTime endDate,
  }) async {
    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    final now = DateTime.now();
    DateTime cursor = DateTime(now.year, now.month, now.day);

    while (!cursor.isAfter(endDate)) {
      final dateStr = cursor.toIso8601String().substring(0, 10);
      final ref = db
          .collection('mosques')
          .doc(mosqueId)
          .collection('prayerTimes')
          .doc(dateStr);
      batch.set(ref, updatedJamaatTimes, SetOptions(merge: true));
      cursor = cursor.add(const Duration(days: 1));
    }
    await batch.commit();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance
          .collection('displayMosques')
          .doc(uid)
          .set({'needsRefresh': true}, SetOptions(merge: true));
    }
  }

  void _toggleOrientation() {
    setState(() {
      _forceLandscape = !_forceLandscape;
    });

    // Force actual screen rotation
    if (_forceLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // BUILD ROOT
  // ══════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    // ── Spinner while resolving auth/binding ──────────────────────────
    if (_checkingBinding) {
      return Scaffold(
        backgroundColor: navy,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: gold, strokeWidth: 2),
              const SizedBox(height: 16),
              Text('Loading…',
                  style:
                      TextStyle(color: white.withOpacity(0.4), fontSize: 13)),
            ],
          ),
        ),
      );
    }

    // ── STRICT LOGIN GATE ───────────────────────────────────────────
    if (_currentUser == null) {
      return const WebLoginPage();
    }

    // ── Mosque setup ─────────────────────────────────────────────
    if (_showMosqueSetup) {
      return _buildMosqueSetupScreen();
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: navy,
      resizeToAvoidBottomInset: true,
      // Drawer accessible from both landscape and portrait when logged in
      endDrawer: _buildSettingsDrawer(),
      body: LayoutBuilder(
        builder: (ctx, constraints) {
          final isLandscape = _forceLandscape;
          final screen = isLandscape
              ? _buildLandscape(constraints)
              : _buildPortrait(constraints);
          return Stack(
            children: [
              Positioned.fill(
                child: screen,
              ),

              // Adhan overlay — both portrait and landscape
              if (_showAdhaan)
                Positioned.fill(
                  child: _buildAdhaanOverlay(),
                ),
              // Adhan Masjid overlay — fires 15 min before iqamah (or 3 min after adhan for Maghrib)
              if (_showAdhanMasjid && !_showAdhaan)
                Positioned.fill(child: _buildAdhanMasjidOverlay()),
              // Adhan Dua overlay — fires after Adhan Masjid ends
              if (_showAdhanDua && !_showAdhaan && !_showAdhanMasjid)
                Positioned.fill(child: _buildAdhanDuaOverlay()),
              // Jumu'ah jamaah adhan overlay — fires at jamaah time for 1st & 2nd Jumu'ah
              if (_showJumuahJamaahAdhan)
                Positioned.fill(child: _buildJumuahJamaahAdhanOverlay()),
              // Khutbah overlay — fires after Jumu'ah jamaah adhan ends
              if (_showKhutbah && !_showJumuahJamaahAdhan)
                Positioned.fill(child: _buildKhutbahOverlay()),
              // Iqamah overlay — both portrait and landscape
              if (_showIqamah && !_showAdhaan)
                Positioned.fill(child: _buildIqamahOverlay()),
              // Blackout — 7 min after each jamaat, highest priority
              if (_showBlackout)
                Positioned.fill(child: _buildBlackoutOverlay()),
              // Adhkar sequence — fires after blackout ends
              if (_showAdhkar && !_showBlackout)
                Positioned.fill(child: _buildAdhkarOverlay()),
              // Makrooh overlay — both portrait and landscape
              if (_showMakrooh && !_isJamaahCountdownActive)
                Positioned.fill(child: _buildMakroohOverlay()),
              // Hadith overlay — never over adhan/makrooh/iqamah/blackout
              if (_showHadith &&
                  !_showAdhaan &&
                  !_showMakrooh &&
                  !_showIqamah &&
                  !_showBlackout &&
                  !_isJamaahCountdownActive)
                Positioned.fill(child: _buildHadithOverlay()),
              // Silence overlay — sequence step 3
              if (_showSilenceOverlayFlag &&
                  !_showAdhaan &&
                  !_showMakrooh &&
                  !_showIqamah &&
                  !_showBlackout &&
                  !_isJamaahCountdownActive)
                Positioned.fill(child: _buildSilenceSequenceOverlay()),
              // Mosque image overlay — sequence step 5
              if (_showMosqueImageFlag &&
                  !_showAdhaan &&
                  !_showMakrooh &&
                  !_showIqamah &&
                  !_showBlackout &&
                  !_showHadith &&
                  !_isJamaahCountdownActive)
                Positioned.fill(child: _buildMosqueImageOverlay()),
              // App promo overlay — sequence step 7
              if (_showAppPromoFlag &&
                  !_showAdhaan &&
                  !_showMakrooh &&
                  !_showIqamah &&
                  !_showBlackout &&
                  !_showHadith &&
                  !_showMosqueImageFlag &&
                  !_isJamaahCountdownActive)
                Positioned.fill(child: _buildAppPromoOverlay()),
            ],
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // ══════════════════════════════════════════════════════════════════
  // PORTRAIT — Dark theme matching landscape aesthetic
  // Full-screen dark: centred clock, star field, prayer rows dark cards,
  // Ishraq/Zawwal/Jumu'ah chips, scrolling ticker at bottom
  // Drawer (settings) — only accessible when logged in
  // ══════════════════════════════════════════════════════════════════
  Widget _buildPortrait(BoxConstraints c) {
    final w = c.maxWidth;
    final h = c.maxHeight;
    // Continuous scale: reference width 420px (phone), clamp to avoid extremes
    final scale = (w / 420.0).clamp(0.75, 2.2);
    final timeStr = DateFormat('HH:mm').format(_now);
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(_now);

    return Stack(
      children: [
        // ── Background ────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.0, -0.5),
              radius: 1.6,
              colors: [
                Color.fromARGB(255, 10, 24, 68),
                Color.fromARGB(255, 4, 10, 32),
                Color.fromARGB(255, 2, 5, 16),
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),
        Positioned.fill(child: _StarField()),

        Column(
          children: [
            // ── TOP BAR ────────────────────────────────────────────
            _buildPortraitTopBar(scale: scale),

            // ── CLOCK — FittedBox fills full width, no dead space ──
            Padding(
              padding: EdgeInsets.symmetric(horizontal: w * 0.02),
              child: FittedBox(
                fit: BoxFit.fitWidth,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      timeStr,
                      style: const TextStyle(
                        color: white,
                        fontSize: 200,
                        fontWeight: FontWeight.w200,
                        letterSpacing: 4,
                        height: 1.0,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        ':$_secondsStr',
                        style: TextStyle(
                          color: white.withOpacity(0.45),
                          fontSize: 70,
                          fontWeight: FontWeight.w300,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── DATES (left) + COUNTDOWN (right) in one row ───────
            Padding(
              padding: EdgeInsets.only(
                  top: h * 0.003,
                  bottom: h * 0.006,
                  left: w * 0.03,
                  right: w * 0.03),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left: Gregorian + Hijri
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dateStr,
                          style: TextStyle(
                            color: white.withOpacity(0.75),
                            fontSize: (14.0 * scale).clamp(12.0, 28.0),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                        ),
                        if (_hijriDate.isNotEmpty)
                          Text(
                            _hijriDate,
                            style: TextStyle(
                              color: gold.withOpacity(0.75),
                              fontSize: (13.0 * scale).clamp(11.0, 26.0),
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.3,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Right: compact countdown
                  if (_nextPrayerName.isNotEmpty && _prayerRows.isNotEmpty)
                    _buildPortraitCompactCountdown(scale),
                ],
              ),
            ),

            // ── PRAYER ROWS ────────────────────────────────────────
            Expanded(
              child: _buildPortraitBody(scale: scale, w: w),
            ),

            // ── TICKER ─────────────────────────────────────────────
            _buildPortraitTicker(w, scale),
          ],
        ),
      ],
    );
  }

  Widget _buildPortraitTopBar({required double scale}) {
    final silenceFs = (13.0 * scale).clamp(12.0, 20.0);
    final menuSz = (28.0 * scale).clamp(26.0, 44.0);
    final menuIconSz = (13.0 * scale).clamp(12.0, 20.0);
    final hPad = (14.0 * scale).clamp(10.0, 32.0);
    final logoSz = (32.0 * scale).clamp(28.0, 52.0);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.5), Colors.transparent],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Ihsan logo ────────────────────────────────────────────
          Image.asset(
            'assets/mainAppLogo.png',
            height: logoSz,
            width: logoSz,
            fit: BoxFit.contain,
          ),
          SizedBox(width: (8.0 * scale).clamp(6.0, 14.0)),
          // ── Mosque name + city ────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedMosque?['name'] ?? 'Ihsan Prayer Display',
                  style: TextStyle(
                    color: white,
                    fontSize: (14.0 * scale).clamp(13.0, 24.0),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if ((_selectedMosque?['city'] ?? '').toString().isNotEmpty)
                  Text(
                    _selectedMosque!['city'],
                    style: TextStyle(
                        color: white.withOpacity(0.35),
                        fontSize: (10.0 * scale).clamp(9.0, 15.0)),
                  ),
              ],
            ),
          ),
          // ── Silence chip ──────────────────────────────────────────
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: (12.0 * scale).clamp(10.0, 20.0),
                vertical: (7.0 * scale).clamp(6.0, 12.0)),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: Colors.red.withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.red.withOpacity(0.15), blurRadius: 8),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.vibration,
                    color: Colors.red.shade300,
                    size: (14.0 * scale).clamp(13.0, 20.0)),
                SizedBox(width: (5.0 * scale).clamp(4.0, 8.0)),
                Text(
                  'Silence phones',
                  style: TextStyle(
                      color: Colors.red.shade300,
                      fontSize: silenceFs,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3),
                ),
              ],
            ),
          ),
          SizedBox(width: (8.0 * scale).clamp(6.0, 12.0)),
          // ── Drawer button ─────────────────────────────────────────
          GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
            child: Container(
              width: menuSz,
              height: menuSz,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: white.withOpacity(0.07),
                border: Border.all(color: gold.withOpacity(0.4), width: 1.5),
              ),
              child: Icon(Icons.menu,
                  color: gold.withOpacity(0.85), size: menuIconSz),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortraitTicker(double w, double scale) {
    final mosqueName = _selectedMosque?['name'] ?? 'Ihsan Prayer Display';
    final city = (_selectedMosque?['city'] ?? '') as String;
    // Custom ticker message segment — shown right after mosque name
    final customSegment = _customTickerMessage.trim().isNotEmpty
        ? '   ✦   ${_customTickerMessage.trim()}'
        : '';
    // Jumu'ah block — all times together, repeated 5 times throughout the ticker
    final jumuahBlock = _jumuahTimes.isNotEmpty
        ? '   \u2756   🕌  Jumu\'ah: ${_jumuahTimes.join('  ·  ')}'
        : '';
    // Build message: inject jumuahBlock repeatedly between general content chunks
    final general1 =
        '   \u2756   $mosqueName${city.isNotEmpty ? '  \u00b7  $city' : ''}$customSegment   \u2756   ${DateFormat('EEEE d MMMM yyyy').format(_now)}';
    final general2 =
        '   \u2756   $_hijriDate   \u2756   May Allah accept your prayers  \u00b7  \u0627\u0644\u0644\u0647\u0645 \u062a\u0642\u0628\u0644 \u0645\u0646\u0627';
    final general3 =
        '   \u2756   \u0627\u0644\u0635\u0644\u0627\u0629 \u062e\u064a\u0631 \u0645\u0646 \u0627\u0644\u0646\u0648\u0645';
    final general4 =
        '   \u2756   \ud83d\udcf5  Please switch off or silence your mobile phone  \u00b7  \u0627\u0644\u0631\u062c\u0627\u0621 \u0625\u063a\u0644\u0627\u0642 \u0627\u0644\u0647\u0627\u062a\u0641';
    // Interleave: each general chunk followed by jumuah block (if exists)
    final String msg;
    if (jumuahBlock.isNotEmpty) {
      msg =
          '$general1$jumuahBlock$general2$jumuahBlock$general3$jumuahBlock$general4$jumuahBlock   \u2756   ';
    } else {
      msg = '$general1$general2$general3$general4   \u2756   ';
    }
    final tickerH = (38.0 * scale).clamp(36.0, 54.0);
    final fontSize = (22.0 * scale).clamp(20.0, 30.0);
    final labelFs = (18.0 * scale).clamp(16.0, 26.0);
    final totalW = msg.length * (fontSize * 0.62);
    return Container(
      height: tickerH,
      color: Colors.black.withOpacity(0.75),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: gold.withOpacity(0.1),
            child: Center(
              child: Text('IHSAN',
                  style: TextStyle(
                      color: gold,
                      fontSize: labelFs,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.5)),
            ),
          ),
          Container(width: 1, color: gold.withOpacity(0.2)),
          Expanded(
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                maxWidth: double.infinity,
                child: Transform.translate(
                  offset: Offset(-(_tickerOffset % totalW), 0),
                  child: _buildTickerRichText(
                      msg, jumuahBlock, customSegment, fontSize),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Compact countdown for portrait sub-clock row ─────────────────────────
  // Right-aligned: prayer name + "Jamā'ah" label on top, then HH/MM/SS boxes.
  // Sized to sit comfortably next to the date text without overwhelming it.
  Widget _buildPortraitCompactCountdown(double scale) {
    String hStr = '', mStr = '', sStr = '';
    final raw = _timeRemaining;
    if (raw.contains(':')) {
      final parts = raw.split(':');
      mStr = parts[0].padLeft(2, '0');
      sStr = parts[1].padLeft(2, '0');
    } else if (raw.contains('h')) {
      hStr =
          RegExp(r'(\d+)h').firstMatch(raw)?.group(1)?.padLeft(2, '0') ?? '00';
      mStr =
          RegExp(r'(\d+)m').firstMatch(raw)?.group(1)?.padLeft(2, '0') ?? '00';
    } else if (raw.contains('m')) {
      mStr =
          RegExp(r'(\d+)m').firstMatch(raw)?.group(1)?.padLeft(2, '0') ?? '--';
    } else {
      mStr = raw;
    }

    final numFs = (20.0 * scale).clamp(17.0, 34.0);
    final labelFs = (9.0 * scale).clamp(8.0, 14.0);
    final boxW = (38.0 * scale).clamp(32.0, 58.0);
    final boxH = (44.0 * scale).clamp(36.0, 66.0);
    final headerFs = (12.0 * scale).clamp(10.0, 20.0);

    Widget seg(String val, String lbl, Color accent) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: boxW,
              height: boxH,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accent.withOpacity(0.4), width: 1.2),
              ),
              child: Center(
                child: Text(
                  val.isEmpty ? '--' : val,
                  style: TextStyle(
                    color: white,
                    fontSize: numFs,
                    fontWeight: FontWeight.w200,
                    letterSpacing: 1.5,
                    height: 1.0,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(lbl,
                style: TextStyle(
                    color: accent.withOpacity(0.65),
                    fontSize: labelFs,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
          ],
        );

    Widget colon() => Padding(
          padding: EdgeInsets.only(bottom: boxH * 0.35),
          child: Text(':',
              style: TextStyle(
                  color: gold.withOpacity(0.5),
                  fontSize: numFs * 0.7,
                  fontWeight: FontWeight.w200,
                  height: 1.0)),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Prayer name + label
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _nextPrayerName,
              style: TextStyle(
                  color: gold,
                  fontSize: headerFs,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2),
            ),
            const SizedBox(width: 5),
            Text(
              "Jamā'ah",
              style: TextStyle(
                  color: gold.withOpacity(0.45),
                  fontSize: headerFs * 0.85,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Segment boxes
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (hStr.isNotEmpty) ...[
              seg(hStr, 'HRS', skyBlue),
              const SizedBox(width: 4),
              colon(),
              const SizedBox(width: 4),
            ],
            seg(mStr.isNotEmpty ? mStr : '--', 'MIN', gold),
            if (sStr.isNotEmpty) ...[
              const SizedBox(width: 4),
              colon(),
              const SizedBox(width: 4),
              seg(sStr, 'SEC', mintGreen),
            ],
          ],
        ),
      ],
    );
  }

  /// Renders ticker text with Jumu'ah segment highlighted in vivid gold
  /// and custom message segment highlighted in vivid cyan
  Widget _buildTickerRichText(String fullMsg, String jumuahSegment,
      String customSegment, double fontSize) {
    // Colour for the custom message — vivid cyan-teal, distinct from gold, not red
    const customColor = Color(0xFF00E5CC);

    // Helper: split text into styled spans, applying [highlight] colour to [segment]
    List<TextSpan> _highlight(String text, String segment, Color color) {
      if (segment.isEmpty) {
        return [
          TextSpan(
            text: text,
            style: TextStyle(
                color: white.withOpacity(0.4),
                fontSize: fontSize,
                letterSpacing: 0.3),
          )
        ];
      }
      final parts = text.split(segment);
      final spans = <TextSpan>[];
      for (int i = 0; i < parts.length; i++) {
        spans.add(TextSpan(
          text: parts[i],
          style: TextStyle(
              color: white.withOpacity(0.4),
              fontSize: fontSize,
              letterSpacing: 0.3),
        ));
        if (i < parts.length - 1) {
          spans.add(TextSpan(
            text: segment,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ));
        }
      }
      return spans;
    }

    if (jumuahSegment.isEmpty && customSegment.isEmpty) {
      return Text(
        fullMsg + fullMsg,
        style: TextStyle(
            color: white.withOpacity(0.4),
            fontSize: fontSize,
            letterSpacing: 0.3),
        maxLines: 1,
      );
    }

    // Build spans for doubled message, applying both highlights in passes
    final doubleMsg = fullMsg + fullMsg;

    // First pass: split on jumuahSegment
    final List<TextSpan> spans = [];
    if (jumuahSegment.isNotEmpty) {
      final parts = doubleMsg.split(jumuahSegment);
      for (int i = 0; i < parts.length; i++) {
        // For each non-jumuah piece, apply custom highlight if needed
        if (customSegment.isNotEmpty) {
          spans.addAll(_highlight(parts[i], customSegment, customColor));
        } else {
          spans.add(TextSpan(
            text: parts[i],
            style: TextStyle(
                color: white.withOpacity(0.4),
                fontSize: fontSize,
                letterSpacing: 0.3),
          ));
        }
        if (i < parts.length - 1) {
          spans.add(TextSpan(
            text: jumuahSegment,
            style: TextStyle(
              color: const Color.fromARGB(255, 255, 215, 0),
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ));
        }
      }
    } else {
      // No jumuah — just apply custom highlight
      spans.addAll(_highlight(doubleMsg, customSegment, customColor));
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: 1,
    );
  }

  Widget _buildPortraitBody({double scale = 1.0, double w = 420}) {
    if (_selectedMosque == null) return _buildEmptyState(light: false);
    if (_isLoadingTimes) return _buildLoader(light: false);
    if (_noTimetable) return _buildNoTimetable(light: false);
    if (_errorMsg != null) return _buildError(light: false);
    if (_prayerRows.isEmpty) return _buildLoader(light: false);

    final fardhRows = _prayerRows.where((r) => r.name != 'Sunrise').toList();
    final sunriseRow = _prayerRows.firstWhere((r) => r.name == 'Sunrise',
        orElse: () => PrayerTime('Sunrise', '--', '--'));

    final hPad = (w * 0.015).clamp(4.0, 18.0);
    final headerSize = (10.0 * scale).clamp(9.0, 22.0);

    return FadeTransition(
      opacity: _tableFade,
      child: Padding(
        padding: EdgeInsets.fromLTRB(hPad, 2, hPad, 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Column header row
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: (8.0 * scale).clamp(4.0, 18.0), vertical: 1),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text('Prayer',
                        style: TextStyle(
                            color: white.withOpacity(0.28),
                            fontSize: headerSize,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('Begining',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: white.withOpacity(0.28),
                            fontSize: headerSize,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text("Jamā'ah",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: white.withOpacity(0.28),
                            fontSize: headerSize,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2)),
                  ),
                ],
              ),
            ),

            // Prayer rows — each takes equal flex share
            ...fardhRows.asMap().entries.map((e) {
              final i = e.key;
              final prayer = e.value;
              final isNext = prayer.name == _nextPrayerName ||
                  (prayer.name == "Jumu'ah" && _nextPrayerName == 'Dhuhr') ||
                  (prayer.name == 'Dhuhr' && _nextPrayerName == "Jumu'ah");
              return Expanded(
                flex: 8,
                child: AnimatedBuilder(
                  animation: _rowCtrl,
                  builder: (_, child) {
                    final t = (_rowCtrl.value - i * 0.1).clamp(0.0, 1.0);
                    final curve = Curves.easeOutCubic.transform(t);
                    return Opacity(
                      opacity: curve,
                      child: Transform.translate(
                          offset: Offset(0, 14 * (1 - curve)), child: child),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _buildPortraitPrayerRow(prayer,
                        isNext: isNext, scale: scale, fillHeight: true),
                  ),
                ),
              );
            }),

            // Info strip (Sunrise / Ishraq / Zawwal / Suhoor + Makrooh)
            Expanded(
              flex: 7,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _buildPortraitInfoStrip(sunriseRow, scale: scale),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortraitPrayerRow(PrayerTime prayer,
      {required bool isNext, double scale = 1.0, bool fillHeight = false}) {
    final Map<String, Color> accents = {
      'Fajr': const Color.fromARGB(255, 110, 155, 235),
      "Jumu'ah": const Color.fromARGB(255, 72, 200, 155),
      'Dhuhr': const Color.fromARGB(255, 255, 210, 80),
      'Asr': const Color.fromARGB(255, 80, 195, 225),
      'Maghrib': const Color.fromARGB(255, 255, 130, 85),
      'Isha': const Color.fromARGB(255, 165, 130, 230),
    };
    // Only use per-prayer accent for the active (next) prayer; all others neutral
    final accent = isNext ? (accents[prayer.name] ?? gold) : white;
    final hasJamaat = prayer.jamaatTime.isNotEmpty && prayer.jamaatTime != '--';

    // Continuous scale — jamaah time is always biggest
    final nameSize = (23.0 * scale).clamp(19.0, 44.0);
    final adhanSize = (28.0 * scale).clamp(24.0, 52.0);
    final jamaatSize = (36.0 * scale).clamp(30.0, 64.0);
    final vPad = (8.0 * scale).clamp(4.0, 18.0);
    final barH = (36.0 * scale).clamp(28.0, 50.0);

    // Uniform very dark background — active prayer gets a subtle accent tint
    const darkBg = Color.fromARGB(255, 8, 12, 28);
    const darkBgActive = Color.fromARGB(255, 12, 18, 42);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      margin: fillHeight ? EdgeInsets.zero : const EdgeInsets.only(bottom: 6),
      padding:
          EdgeInsets.symmetric(horizontal: 8, vertical: fillHeight ? 0 : vPad),
      constraints:
          fillHeight ? const BoxConstraints.expand() : const BoxConstraints(),
      decoration: BoxDecoration(
        color: isNext ? darkBgActive : darkBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNext ? accent : white.withOpacity(0.20),
          width: isNext ? 2.5 : 1.8,
        ),
        boxShadow: isNext
            ? [
                BoxShadow(
                    color: accent.withOpacity(0.20),
                    blurRadius: 20,
                    spreadRadius: 1),
              ]
            : [],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Active accent bar
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            width: isNext ? 5 : 3,
            height: barH,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [accent, accent.withOpacity(isNext ? 0.4 : 0.15)],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Prayer name + arabic
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  prayer.name,
                  style: TextStyle(
                    color: white,
                    fontSize: nameSize,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  _arabicPrayerName(prayer.name),
                  style: TextStyle(
                    color: accent.withOpacity(0.65),
                    fontSize: nameSize * 0.72,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          // Adhān time
          Expanded(
            flex: 2,
            child: Text(
              prayer.time.isEmpty || prayer.time == '--' ? '--' : prayer.time,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: white.withOpacity(0.80),
                fontSize: adhanSize,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.8,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),

          // Jamā'ah time — white regardless of selected state
          Expanded(
            flex: 2,
            child: Text(
              hasJamaat ? prayer.jamaatTime : '--',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: white,
                fontSize: jamaatSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _arabicPrayerName(String name) {
    const map = {
      'Fajr': 'الفجر',
      'Dhuhr': 'الظهر',
      "Jumu'ah": 'الجمعة',
      'Asr': 'العصر',
      'Maghrib': 'المغرب',
      'Isha': 'العشاء',
      'Sunrise': 'الشروق',
    };
    return map[name] ?? '';
  }

  Widget _buildPortraitInfoStrip(PrayerTime sunriseRow, {double scale = 1.0}) {
    final chips = <_InfoChip>[
      _InfoChip(
          label: 'Sunrise',
          time: sunriseRow.time,
          color: const Color.fromARGB(255, 255, 200, 80)),
      _InfoChip(
          label: 'Ishraq',
          time: _ishraqTime,
          color: const Color.fromARGB(255, 255, 155, 60)),
      _InfoChip(
          label: 'Zawwal',
          time: _zawwalTime,
          color: const Color.fromARGB(255, 170, 130, 220)),
      _InfoChip(
          label: 'Suhoor',
          time: _suhoorTime,
          color: const Color.fromARGB(255, 255, 110, 70)),
    ];
    final labelSz = (15.0 * scale).clamp(13.0, 24.0);
    final timeSz = (28.0 * scale).clamp(24.0, 40.0);
    return Column(
      children: [
        Expanded(
          flex: 6,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: chips.asMap().entries.map((e) {
              final chip = e.value;
              return Expanded(
                child: Container(
                  margin:
                      EdgeInsets.only(right: e.key < chips.length - 1 ? 6 : 0),
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 8, 12, 28),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: chip.color.withOpacity(0.35), width: 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(chip.label,
                          style: TextStyle(
                              color: chip.color.withOpacity(0.85),
                              fontSize: labelSz,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.7)),
                      const SizedBox(height: 3),
                      Text(
                        chip.time.isEmpty || chip.time == '--'
                            ? '--'
                            : chip.time,
                        style: TextStyle(
                          color: white,
                          fontSize: timeSz,
                          fontWeight: FontWeight.w500,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitJumuahCard({bool isWide = false}) {
    const color = Color.fromARGB(255, 72, 200, 155);
    final timeSz = isWide ? 28.0 : 22.0;
    final labelSz = isWide ? 16.0 : 13.0;
    final ordinals = ['1st', '2nd', '3rd', '4th', '5th'];
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isWide ? 30 : 14, vertical: isWide ? 12 : 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.08), blurRadius: 16),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Top row: icon + label (+ inline chips when ≤2 times) ─
          Row(
            children: [
              Icon(Icons.people, color: color, size: isWide ? 28 : 22),
              const SizedBox(width: 8),
              Text("JUMU'AH",
                  style: TextStyle(
                      color: color,
                      fontSize: labelSz,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5)),
              const SizedBox(width: 6),
              Text('Friday prayer times',
                  style: TextStyle(
                      color: white.withOpacity(0.35),
                      fontSize: isWide ? 18 : 13)),
              if (_jumuahTimes.length <= 2) ...[
                const SizedBox(width: 10),
                ..._jumuahTimes.asMap().entries.map((e) {
                  final ordinal = e.key < ordinals.length
                      ? ordinals[e.key]
                      : '${e.key + 1}th';
                  return Padding(
                    padding: EdgeInsets.only(
                        right: e.key < _jumuahTimes.length - 1
                            ? (isWide ? 10 : 6)
                            : 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$ordinal ',
                            style: TextStyle(
                                color: white.withOpacity(0.3),
                                fontSize: isWide ? 14 : 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3)),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: isWide ? 14 : 7,
                              vertical: isWide ? 8 : 3),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: color.withOpacity(0.35), width: 1),
                          ),
                          child: Text(e.value,
                              style: TextStyle(
                                color: white,
                                fontSize: timeSz,
                                fontWeight: FontWeight.w600,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              )),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
          // ── Time chips below — only when more than 2 times ──────
          if (_jumuahTimes.length > 2) ...[
            SizedBox(height: isWide ? 12 : 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: _jumuahTimes.asMap().entries.map((e) {
                final ordinal = e.key < ordinals.length
                    ? ordinals[e.key]
                    : '${e.key + 1}th';
                return Padding(
                  padding: EdgeInsets.only(
                      right: e.key < _jumuahTimes.length - 1
                          ? (isWide ? 12 : 8)
                          : 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(ordinal,
                          style: TextStyle(
                              color: white.withOpacity(0.3),
                              fontSize: isWide ? 16 : 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3)),
                      const SizedBox(height: 2),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: isWide ? 20 : 8,
                            vertical: isWide ? 14 : 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: color.withOpacity(0.35), width: 1),
                        ),
                        child: Text(e.value,
                            style: TextStyle(
                              color: white,
                              fontSize: timeSz,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            )),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNextPrayerPill({required bool isSmall}) =>
      const SizedBox.shrink(); // kept for compat

  Widget _buildPortraitPrayerCard(PrayerTime prayer,
          {required bool isNext, required bool isSunrise}) =>
      const SizedBox.shrink(); // replaced by _buildPortraitPrayerRow

  Widget _buildPortraitInfoRow() => const SizedBox.shrink(); // replaced

  // ══════════════════════════════════════════════════════════════════
  // LANDSCAPE — Mawaqit-style full screen display
  // Centre: giant clock + countdown + search
  // Flanks: Sunrise (left) | Jumu'ah (right)
  // Bottom row: 5 prayer bubble cards (Fajr/Dhuhr/Asr/Maghrib/Isha)
  // Ticker at very bottom
  // ══════════════════════════════════════════════════════════════════
  Widget _buildLandscape(BoxConstraints c) {
    final w = c.maxWidth;
    final h = c.maxHeight;
    // Continuous scale: reference 1000px wide landscape display
    final scale = (w / 1000.0).clamp(0.6, 1.8);

    // Filter to 5 main prayers (no Sunrise)
    final mainPrayers = _prayerRows.where((r) => r.name != 'Sunrise').toList();
    final sunriseRow = _prayerRows.isNotEmpty
        ? _prayerRows.firstWhere((r) => r.name == 'Sunrise',
            orElse: () => PrayerTime('Sunrise', '--', '--'))
        : null;

    return Stack(
      children: [
        // ── Deep night-sky background ──────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.0, -0.4),
              radius: 1.4,
              colors: [
                Color.fromARGB(255, 12, 28, 78),
                Color.fromARGB(255, 5, 12, 40),
                Color.fromARGB(255, 2, 5, 18),
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),
        Positioned.fill(child: _StarField()),

        // ── Mosque silhouette ──────────────────────────────────────
        Positioned(
          bottom: 58,
          left: 0,
          right: 0,
          child: CustomPaint(
            painter: _MosqueSilhouettePainter(),
            size: Size(w, h * 0.2),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: h * 0.45,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  const Color.fromARGB(255, 2, 6, 22),
                  const Color.fromARGB(185, 2, 6, 22),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),

        // ── Main layout ────────────────────────────────────────────
        Column(
          children: [
            // Top bar
            _buildLsTopBar(w, scale),

            // Body: flanks + centre
            Expanded(
              child: Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: w * 0.018, vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ── LEFT FLANK: Sunrise + Ishraq ────────────────
                    SizedBox(
                      width: w * 0.15,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildFlankCard(
                            label: 'Sunrise',
                            arabicLabel: 'الشروق',
                            time: sunriseRow?.time ?? '--',
                            icon: Icons.wb_twilight,
                            color: const Color.fromARGB(255, 255, 195, 70),
                            scale: scale,
                          ),
                          SizedBox(height: h * 0.025),
                          _buildFlankCard(
                            label: 'Ishrāq',
                            arabicLabel: 'الإشراق',
                            time: _ishraqTime,
                            icon: Icons.wb_sunny,
                            color: const Color.fromARGB(255, 255, 145, 55),
                            scale: scale,
                          ),
                        ],
                      ),
                    ),

                    // ── CENTRE: clock + dates + countdown + search ───
                    Expanded(
                      child: _buildLsCentre(w, h, scale),
                    ),

                    // ── RIGHT FLANK: Zawwal + Jumu'ah ───────────────
                    SizedBox(
                      width: w * 0.15,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildFlankCard(
                            label: 'Zawwāl',
                            arabicLabel: 'الزوال',
                            time: _zawwalTime,
                            icon: Icons.schedule,
                            color: const Color.fromARGB(255, 170, 130, 220),
                            scale: scale,
                          ),
                          SizedBox(height: h * 0.025),
                          _buildFlankCard(
                            label: 'Suhoor',
                            arabicLabel: 'السحور',
                            time: _suhoorTime,
                            icon: Icons.wb_twilight,
                            color: const Color.fromARGB(255, 255, 110, 70),
                            scale: scale,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Prayer bubble cards row
            _buildLsPrayerBubbles(mainPrayers, w, h, scale),

            // Ticker
            _buildLsTicker(w, scale),
          ],
        ),

        // Search suggestions
      ],
    );
  }

  Widget _buildLsTopBar(double w, double scale) {
    final chipV = (8.0 * scale).clamp(6.0, 12.0);
    final chipFs = (20.0 * scale).clamp(14.0, 26.0);
    final chipH = (12.0 * scale).clamp(9.0, 18.0);
    final menuSz = (40.0 * scale).clamp(32.0, 54.0);
    final logoSz = (22.0 * scale).clamp(18.0, 46.0);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: w * 0.02, vertical: (5.0 * scale).clamp(4.0, 9.0)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.55), Colors.transparent],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Ihsan logo ────────────────────────────────────────────
          Image.asset(
            'assets/mainAppLogo.png',
            height: logoSz,
            width: logoSz,
            fit: BoxFit.contain,
          ),
          SizedBox(width: (8.0 * scale).clamp(6.0, 14.0)),
          // ── Mosque name + city ────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedMosque?['name'] ?? 'Ihsan Prayer Display',
                  style: TextStyle(
                    color: white,
                    fontSize: (15.0 * scale).clamp(12.0, 28.0),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if ((_selectedMosque?['city'] ?? '').toString().isNotEmpty)
                  Text(
                    _selectedMosque!['city'],
                    style: TextStyle(
                        color: white.withOpacity(0.35),
                        fontSize: (11.0 * scale).clamp(9.0, 20.0)),
                  ),
              ],
            ),
          ),
          // ── Date ──────────────────────────────────────────────────
          Text(
            DateFormat('EEE, d MMM yyyy').format(_now),
            style: TextStyle(
                color: white.withOpacity(0.40),
                fontSize: (12.0 * scale).clamp(10.0, 36.0),
                letterSpacing: 0.3),
          ),
          SizedBox(width: (8.0 * scale).clamp(6.0, 16.0)),
          // ── Silence chip ──────────────────────────────────────────
          Container(
            padding: EdgeInsets.symmetric(horizontal: chipH, vertical: chipV),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.withOpacity(0.3), width: 1),
            ),
            child: Text(
              'Silence phones',
              style: TextStyle(
                color: Colors.red.shade300,
                fontSize: chipFs,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          SizedBox(width: (6.0 * scale).clamp(4.0, 12.0)),
          // ── Drawer button — same height as silence chip ───────────
          GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
            child: Container(
              width: menuSz,
              height: menuSz,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: white.withOpacity(0.07),
                border: Border.all(color: gold.withOpacity(0.4), width: 1.5),
              ),
              child: Icon(Icons.menu,
                  color: gold.withOpacity(0.85),
                  size: (17.0 * scale).clamp(14.0, 28.0)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLsCentre(double w, double h, double scale) {
    final timeStr = DateFormat('HH:mm').format(_now);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Giant clock — proportional to centre column width
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              timeStr,
              style: TextStyle(
                color: white,
                fontSize: (w * 0.20).clamp(60.0, 150.0),
                fontWeight: FontWeight.w200,
                letterSpacing: 4,
                height: 1.0,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                ':$_secondsStr',
                style: TextStyle(
                  color: white.withOpacity(0.65),
                  fontSize: (w * 0.044).clamp(24.0, 72.0),
                  fontWeight: FontWeight.w300,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),

        // ── Date row: Gregorian left · Hijri right ─────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              DateFormat('EEEE, d MMMM yyyy').format(_now),
              style: TextStyle(
                color: white.withOpacity(0.72),
                fontSize: (19.0 * scale).clamp(15.0, 38.0),
                fontWeight: FontWeight.w400,
                letterSpacing: 0.3,
              ),
            ),
            if (_hijriDate.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '·',
                  style: TextStyle(
                    color: gold.withOpacity(0.35),
                    fontSize: (18.0 * scale).clamp(14.0, 34.0),
                  ),
                ),
              ),
              Text(
                _hijriDate,
                style: TextStyle(
                  color: gold.withOpacity(0.62),
                  fontSize: (17.0 * scale).clamp(13.0, 34.0),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ],
        ),

        SizedBox(height: h * 0.01),

        // ── Segmented countdown to next prayer ────────────────────
        if (_nextPrayerName.isNotEmpty && _prayerRows.isNotEmpty)
          _buildSegmentedCountdown(isBig: scale >= 1.0),

        SizedBox(height: h * 0.01),
      ],
    );
  }

  // ── Flank card: sunrise, ishraq, zawwal ─────────────────────────────────
  Widget _buildFlankCard({
    required String label,
    required String arabicLabel,
    required String time,
    required IconData icon,
    required Color color,
    required double scale,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          vertical: (10.0 * scale).clamp(7.0, 16.0),
          horizontal: (8.0 * scale).clamp(6.0, 14.0)),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.12), blurRadius: 20, spreadRadius: 2),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            arabicLabel,
            style: TextStyle(
              color: color.withOpacity(0.6),
              fontSize: (11.0 * scale).clamp(9.0, 22.0),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.9),
              fontSize: (12.0 * scale).clamp(10.0, 22.0),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            time,
            style: TextStyle(
              color: white,
              fontSize: (30.0 * scale).clamp(20.0, 46.0),
              fontWeight: FontWeight.w300,
              letterSpacing: 1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  // ── Jumu'ah flank card ───────────────────────────────────────────────────
  Widget _buildFlankJumuah({required double scale}) {
    const color = Color.fromARGB(255, 72, 200, 155);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.10), blurRadius: 20),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people,
              color: color, size: (14.0 * scale).clamp(12.0, 20.0)),
          const SizedBox(height: 4),
          Text(
            "الجمعة",
            style: TextStyle(
              color: color.withOpacity(0.6),
              fontSize: (8.0 * scale).clamp(7.0, 16.0),
            ),
          ),
          Text(
            "Jumu'ah",
            style: TextStyle(
              color: color.withOpacity(0.9),
              fontSize: (9.0 * scale).clamp(8.0, 17.0),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          if (_jumuahTimes.isEmpty)
            Text('--',
                style: TextStyle(
                    color: white.withOpacity(0.3),
                    fontSize: (16.0 * scale).clamp(13.0, 22.0),
                    fontWeight: FontWeight.w300))
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: _jumuahTimes
                  .asMap()
                  .entries
                  .map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${e.key + 1}. ',
                              style: TextStyle(
                                color: color.withOpacity(0.45),
                                fontSize: (7.0 * scale).clamp(6.0, 11.0),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              e.value,
                              style: TextStyle(
                                color: white,
                                fontSize: (14.0 * scale).clamp(12.0, 20.0),
                                fontWeight: FontWeight.w400,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  // ── Prayer bubble cards ──────────────────────────────────────────────────
  Widget _buildLsPrayerBubbles(
      List<PrayerTime> prayers, double w, double h, double scale) {
    return Container(
      height: h * 0.27,
      padding: EdgeInsets.fromLTRB(w * 0.015, 0, w * 0.015, 6),
      child: Row(
        children: prayers.asMap().entries.map((entry) {
          final i = entry.key;
          final prayer = entry.value;
          // Highlight based on next jamaat (or dhuhr↔jumu'ah alias)
          final isNext = prayer.name == _nextPrayerName ||
              (prayer.name == "Jumu'ah" && _nextPrayerName == 'Dhuhr') ||
              (prayer.name == 'Dhuhr' && _nextPrayerName == "Jumu'ah");
          return Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: (4.0 * scale).clamp(2.0, 7.0)),
              child: AnimatedBuilder(
                animation: _rowCtrl,
                builder: (_, child) {
                  final t = (_rowCtrl.value - i * 0.1).clamp(0.0, 1.0);
                  final curve = Curves.easeOutCubic.transform(t);
                  return Opacity(
                    opacity: curve,
                    child: Transform.translate(
                        offset: Offset(0, 20 * (1 - curve)), child: child),
                  );
                },
                child:
                    _buildLsPrayerBubble(prayer, isNext: isNext, scale: scale),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLsPrayerBubble(PrayerTime prayer,
      {required bool isNext, required double scale}) {
    final offset = _jamaatOffset(prayer);
    final hasJamaat = !prayer.name.contains('Sunrise') &&
        prayer.jamaatTime.isNotEmpty &&
        prayer.jamaatTime != '--';

    // Prayer accent colours
    final Map<String, Color> accents = {
      'Fajr': const Color.fromARGB(255, 110, 155, 235),
      "Jumu'ah": const Color.fromARGB(255, 72, 200, 155),
      'Dhuhr': const Color.fromARGB(255, 255, 210, 80),
      'Asr': const Color.fromARGB(255, 80, 195, 225),
      'Maghrib': const Color.fromARGB(255, 255, 130, 85),
      'Isha': const Color.fromARGB(255, 165, 130, 230),
    };
    final accent = isNext ? (accents[prayer.name] ?? gold) : white;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        gradient: isNext
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withOpacity(0.22),
                  accent.withOpacity(0.08),
                ],
              )
            : null,
        color: isNext ? null : Colors.black.withOpacity(0.38),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isNext ? accent : white.withOpacity(0.22),
          width: isNext ? 2.5 : 1.8,
        ),
        boxShadow: isNext
            ? [
                BoxShadow(
                    color: accent.withOpacity(0.35),
                    blurRadius: 28,
                    spreadRadius: 3),
              ]
            : [],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
            vertical: (4.0 * scale).clamp(3.0, 7.0),
            horizontal: (5.0 * scale).clamp(4.0, 10.0)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Prayer name — always per-prayer accent colour
            Text(
              prayer.name,
              style: TextStyle(
                color: accent,
                fontSize: (16.0 * scale).clamp(13.0, 26.0),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
              textAlign: TextAlign.center,
            ),

            // Active accent line
            if (isNext)
              Container(
                height: 2,
                width: (20.0 * scale).clamp(16.0, 28.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    accent.withOpacity(0.0),
                    accent,
                    accent.withOpacity(0.0)
                  ]),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),

            // JAMAA'H — big number (primary)
            if (hasJamaat) ...[
              Text(
                "Jamā'ah",
                style: TextStyle(
                  color:
                      isNext ? accent.withOpacity(0.7) : white.withOpacity(0.3),
                  fontSize: (10.0 * scale).clamp(9.0, 19.0),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                prayer.jamaatTime,
                style: TextStyle(
                  color: white.withOpacity(0.9),
                  fontSize: (36.0 * scale).clamp(26.0, 48.0),
                  fontWeight: isNext ? FontWeight.w400 : FontWeight.w300,
                  letterSpacing: 1.5,
                  height: 1.05,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              // No jamaat — show beginning as big
              Text(
                prayer.time.isEmpty || prayer.time == '--' ? '--' : prayer.time,
                style: TextStyle(
                  color: isNext
                      ? const Color.fromARGB(255, 255, 215, 0)
                      : white.withOpacity(0.85),
                  fontSize: (36.0 * scale).clamp(26.0, 48.0),
                  fontWeight: FontWeight.w200,
                  letterSpacing: 1.5,
                  height: 1.05,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                textAlign: TextAlign.center,
              ),
            ],

            // BEGINNING — smaller below jamaat
            if (hasJamaat)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Adhān',
                    style: TextStyle(
                      color: white.withOpacity(0.45),
                      fontSize: (9.0 * scale).clamp(7.0, 17.0),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    prayer.time.isEmpty || prayer.time == '--'
                        ? '--'
                        : prayer.time,
                    style: TextStyle(
                      color: isNext
                          ? white.withOpacity(0.55)
                          : white.withOpacity(0.35),
                      fontSize: (19.0 * scale).clamp(15.0, 32.0),
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Returns "+N'" offset string between beginning and jamaat
  String _jamaatOffset(PrayerTime prayer) {
    if (prayer.jamaatTime == '--' || prayer.jamaatTime.isEmpty) return '';
    if (prayer.time == '--' || prayer.time.isEmpty) return '';
    try {
      final bp = prayer.time.split(':');
      final jp = prayer.jamaatTime.split(':');
      if (bp.length < 2 || jp.length < 2) return '';
      final bm = int.parse(bp[0]) * 60 + int.parse(bp[1]);
      final jm = int.parse(jp[0]) * 60 + int.parse(jp[1]);
      final diff = jm - bm;
      if (diff <= 0) return '';
      return "+$diff'";
    } catch (_) {
      return '';
    }
  }

  Widget _buildLsTicker(double w, double scale) {
    final mosqueName = _selectedMosque?['name'] ?? 'Ihsan Prayer Display';
    final city = (_selectedMosque?['city'] ?? '') as String;
    // Custom ticker message segment — shown right after mosque name
    final customSegment = _customTickerMessage.trim().isNotEmpty
        ? '   ✦   ${_customTickerMessage.trim()}'
        : '';
    // Jumu'ah block — all times together, repeated between every content chunk
    final jumuahBlock = _jumuahTimes.isNotEmpty
        ? '   \u2756   🕌  Jumu\'ah: ${_jumuahTimes.join('  ·  ')}'
        : '';
    final general1 =
        '   \u2756   $mosqueName${city.isNotEmpty ? '  \u00b7  $city' : ''}$customSegment   \u2756   ${DateFormat('EEEE d MMMM yyyy').format(_now)}';
    final general2 =
        '   \u2756   $_hijriDate   \u2756   May Allah accept your prayers  \u00b7  \u0627\u0644\u0644\u0647\u0645 \u062a\u0642\u0628\u0644 \u0645\u0646\u0627';
    final general3 =
        '   \u2756   \u0627\u0644\u0635\u0644\u0627\u0629 \u062e\u064a\u0631 \u0645\u0646 \u0627\u0644\u0646\u0648\u0645';
    final general4 =
        '   \u2756   \ud83d\udcf5  Please switch off or silence your mobile phone  \u00b7  \u0627\u0644\u0631\u062c\u0627\u0621 \u0625\u063a\u0644\u0627\u0642 \u0627\u0644\u0647\u0627\u062a\u0641';
    final String msg;
    if (jumuahBlock.isNotEmpty) {
      msg =
          '$general1$jumuahBlock$general2$jumuahBlock$general3$jumuahBlock$general4$jumuahBlock   \u2756   ';
    } else {
      msg = '$general1$general2$general3$general4   \u2756   ';
    }
    final tickerH = (50.0 * scale).clamp(42.0, 64.0);
    final fontSize = (28.0 * scale).clamp(22.0, 38.0);
    final labelFs = (17.0 * scale).clamp(14.0, 24.0);
    final totalW = msg.length * (fontSize * 0.62);

    return Container(
      height: tickerH,
      color: Colors.black.withOpacity(0.8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            color: gold.withOpacity(0.1),
            child: Center(
              child: Text(
                'IHSAN',
                style: TextStyle(
                  color: gold,
                  fontSize: labelFs,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.5,
                ),
              ),
            ),
          ),
          Container(width: 1, color: gold.withOpacity(0.2)),
          Expanded(
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                maxWidth: double.infinity,
                child: Transform.translate(
                  offset: Offset(-(_tickerOffset % totalW), 0),
                  child: _buildTickerRichText(
                      msg, jumuahBlock, customSegment, fontSize),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLsEmptyPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mosque_outlined, color: white.withOpacity(0.08), size: 36),
          const SizedBox(height: 10),
          Text(
            'Search for your mosque to display prayer times',
            style: TextStyle(color: white.withOpacity(0.18), fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // SETTINGS DRAWER — opens from right, login required
  // Content to be added in future sessions
  // ══════════════════════════════════════════════════════════════════
  // ══════════════════════════════════════════════════════════════════
  // SETTINGS DRAWER — full implementation
  // Three tabs: Images | Jamaat Times | Settings
  // ══════════════════════════════════════════════════════════════════
  Widget _buildSettingsDrawer() {
    final firstName = _displayName.isNotEmpty
        ? _displayName.split(' ').first
        : (_currentUser?.email ?? 'User');
    return Drawer(
      width: 380,
      backgroundColor: const Color.fromARGB(255, 8, 18, 48),
      child: _DrawerBody(
        firstName: firstName,
        email: _currentUser?.email ?? '',
        mosqueId: _selectedMosque?['id'] as String? ?? '',
        mosqueName: _selectedMosque?['name'] as String? ?? '',
        displayImageMap: _displayImageMap,
        onDeleteImage: _deleteDisplayImage,
        onUploadImageFromDevice: _uploadImageFromDevice,
        onRefreshImages: () =>
            _fetchDisplayImages(_selectedMosque?['id'] as String? ?? ''),
        onBatchWriteJamaat: _batchWriteJamaatTimes,
        onChangeMosque: () {
          Navigator.of(context).pop();
          setState(() => _showMosqueSetup = true);
        },
        onLogOut: _logOut,
        onCloseDrawer: () => Navigator.of(context).pop(),
        onToggleOrientation: () {
          Navigator.of(context).pop();
          _toggleOrientation();
        },
        isLandscape: _forceLandscape,
        customTickerMessage: _customTickerMessage,
        onUpdateTickerMessage: (msg) async {
          setState(() => _customTickerMessage = msg);
          // Persist to Firebase so it survives a screen rebuild/reload
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid != null) {
            try {
              await FirebaseFirestore.instance
                  .collection('displayMosques')
                  .doc(uid)
                  .set({'customTickerMessage': msg, 'needsRefresh': true},
                      SetOptions(merge: true));
            } catch (e) {
              debugPrint('Error saving ticker message: $e');
            }
          }
          // Rebuild the screen so the ticker immediately picks up the new message
          if (mounted) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                transitionDuration: Duration.zero,
                pageBuilder: (_, __, ___) => const MosqueDisplayScreen(),
              ),
            );
          }
        },
        // pass palette
        navy: navy,
        navyMid: navyMid,
        navyLight: navyLight,
        gold: gold,
        goldLight: goldLight,
        white: white,
        offWhite: offWhite,
        textDark: textDark,
        textMid: textMid,
        borderCol: borderCol,
        mintGreen: mintGreen,
        skyBlue: skyBlue,
        skyLight: skyLight,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // MOSQUE SETUP SCREEN — one-time, shown after first login
  // ══════════════════════════════════════════════════════════════════
  Widget _buildMosqueSetupScreen() {
    return Scaffold(
      backgroundColor: navy,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.4),
                radius: 1.5,
                colors: [
                  Color.fromARGB(255, 12, 28, 75),
                  Color.fromARGB(255, 3, 8, 28),
                ],
              ),
            ),
          ),
          Positioned.fill(child: _StarField()),
          Center(
            child: Container(
              width: 520,
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 10, 22, 58),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: gold.withOpacity(0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: gold.withOpacity(0.08),
                      blurRadius: 40,
                      spreadRadius: 4),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: gold.withOpacity(0.1),
                      border:
                          Border.all(color: gold.withOpacity(0.5), width: 2),
                    ),
                    child: const Icon(Icons.mosque_outlined,
                        color: gold, size: 26),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Which mosque is this display for?',
                    style: TextStyle(
                      color: white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Search and select your mosque. This will be saved to your account and loaded automatically on every login.',
                    style: TextStyle(
                        color: white.withOpacity(0.45),
                        fontSize: 13,
                        height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _buildSearchBar(dark: true),
                  if (_showSuggestions && _filteredMosques.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      constraints: const BoxConstraints(maxHeight: 220),
                      decoration: BoxDecoration(
                        color: navyLight,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: gold.withOpacity(0.2), width: 1),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _filteredMosques.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: white.withOpacity(0.06)),
                        itemBuilder: (ctx, i) {
                          final m = _filteredMosques[i];
                          final isSel = _selectedMosque?['id'] == m['id'];
                          final isTaken =
                              _takenMosqueIds.contains(m['id'] as String);
                          return ListTile(
                            dense: true,
                            enabled: !isTaken,
                            leading: Icon(
                              isTaken
                                  ? Icons.lock_outline
                                  : Icons.mosque_outlined,
                              size: 15,
                              color: isTaken
                                  ? white.withOpacity(0.18)
                                  : isSel
                                      ? gold
                                      : white.withOpacity(0.35),
                            ),
                            title: Text(m['name'],
                                style: TextStyle(
                                    color: isTaken
                                        ? white.withOpacity(0.25)
                                        : isSel
                                            ? gold
                                            : white,
                                    fontSize: 13,
                                    fontWeight: isSel
                                        ? FontWeight.w600
                                        : FontWeight.w400)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if ((m['city'] as String).isNotEmpty)
                                  Text(m['city'],
                                      style: TextStyle(
                                          color: isTaken
                                              ? white.withOpacity(0.15)
                                              : white.withOpacity(0.3),
                                          fontSize: 11)),
                                if (isTaken)
                                  Text('Already in use',
                                      style: TextStyle(
                                          color: Colors.orange.withOpacity(0.6),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600)),
                              ],
                            ),
                            trailing: isSel
                                ? const Icon(Icons.check, color: gold, size: 14)
                                : isTaken
                                    ? Icon(Icons.lock,
                                        color: white.withOpacity(0.18),
                                        size: 13)
                                    : null,
                            onTap: isTaken
                                ? null
                                : () {
                                    setState(() {
                                      _selectedMosque = m;
                                      _showSuggestions = false;
                                      _searchCtrl.text = m['name'];
                                    });
                                  },
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (_selectedMosque != null)
                    GestureDetector(
                      onTap: () => _saveMosqueBinding(_selectedMosque!),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color.fromARGB(255, 222, 185, 105),
                              Color.fromARGB(255, 195, 155, 72),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                                color: gold.withOpacity(0.25),
                                blurRadius: 16,
                                offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline,
                                color: navy, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Set as display: ${_selectedMosque!['name']}',
                              style: const TextStyle(
                                color: navy,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _logOut,
                    child: Text('Log out',
                        style: TextStyle(
                            color: white.withOpacity(0.25), fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // SEGMENTED COUNTDOWN — airport-style number segments
  // ══════════════════════════════════════════════════════════════════
  Widget _buildSegmentedCountdown({required bool isBig}) {
    // isBig still passed as bool from callers; map it to a local scale factor
    final s = isBig ? 1.5 : 1.2;
    // Parse _timeRemaining into h/m/s segments
    String hStr = '', mStr = '', sStr = '';
    final raw = _timeRemaining;

    if (raw.contains(':')) {
      // MM:SS format (under 15 min)
      final parts = raw.split(':');
      mStr = parts[0].padLeft(2, '0');
      sStr = parts[1].padLeft(2, '0');
    } else if (raw.contains('h')) {
      // "Xh Ym" format
      final hMatch = RegExp(r'(\d+)h').firstMatch(raw);
      final mMatch = RegExp(r'(\d+)m').firstMatch(raw);
      hStr = (hMatch?.group(1) ?? '0').padLeft(2, '0');
      mStr = (mMatch?.group(1) ?? '0').padLeft(2, '0');
    } else if (raw.contains('m')) {
      mStr =
          RegExp(r'(\d+)m').firstMatch(raw)?.group(1)?.padLeft(2, '0') ?? '--';
    } else {
      mStr = raw;
    }

    final numSize = (30.0 * s).clamp(32.0, 56.0);
    final labelSize = (12.0 * s).clamp(12.0, 20.0);
    final boxW = (50.0 * s).clamp(54.0, 90.0);
    final boxH = (60.0 * s).clamp(64.0, 104.0);

    Widget seg(String val, String label, Color accent) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: boxW,
            height: boxH,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withOpacity(0.35), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: accent.withOpacity(0.12),
                    blurRadius: 12,
                    spreadRadius: 1),
              ],
            ),
            child: Center(
              child: Text(
                val.isEmpty ? '--' : val,
                style: TextStyle(
                  color: white,
                  fontSize: numSize,
                  fontWeight: FontWeight.w200,
                  letterSpacing: 2,
                  height: 1.0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: accent.withOpacity(0.65),
              fontSize: labelSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ],
      );
    }

    Widget colon() => Padding(
          padding: const EdgeInsets.only(bottom: 22),
          child: Text(':',
              style: TextStyle(
                  color: gold.withOpacity(0.6),
                  fontSize: numSize * 0.6,
                  fontWeight: FontWeight.w200,
                  height: 1.0)),
        );

    final prayerNameFs = (18.0 * s).clamp(20.0, 36.0);
    final jamaahLabelFs = (12.0 * s).clamp(13.0, 26.0);
    final adhanFs = (18.0 * s).clamp(16.0, 30.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              _nextPrayerName,
              style: TextStyle(
                color: gold,
                fontSize: prayerNameFs,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              "Jamā'ah",
              style: TextStyle(
                color: gold.withOpacity(0.45),
                fontSize: jamaahLabelFs,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (hStr.isNotEmpty) ...[
              seg(hStr, 'HRS', skyBlue),
              const SizedBox(width: 6),
              colon(),
              const SizedBox(width: 6),
            ],
            seg(mStr.isNotEmpty ? mStr : '--',
                hStr.isEmpty && sStr.isEmpty ? 'MIN' : 'MIN', gold),
            if (sStr.isNotEmpty) ...[
              const SizedBox(width: 6),
              colon(),
              const SizedBox(width: 6),
              seg(sStr, 'SEC', mintGreen),
            ],
          ],
        ),
        if (_beginningTimeRemaining.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_beginningTimeRemaining,
                  style: TextStyle(
                    color: white.withOpacity(0.3),
                    fontSize: adhanFs,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 1.2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
              const SizedBox(width: 5),
              Text('until Adhān',
                  style: TextStyle(
                    color: white.withOpacity(0.2),
                    fontSize: (adhanFs * 0.85).clamp(10.0, 22.0),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  )),
            ],
          ),
        ],
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // SILENCE SEQUENCE OVERLAY
  // ══════════════════════════════════════════════════════════════════
  Widget _buildSilenceSequenceOverlay() {
    final isLandscape = _forceLandscape;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.red.shade900.withOpacity(0.97),
            const Color.fromARGB(255, 45, 5, 5),
            Colors.black,
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: isLandscape ? 80 : 28, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: isLandscape ? 180 : 150,
                height: isLandscape ? 180 : 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withOpacity(0.12),
                  border: Border.all(
                      color: Colors.red.shade300.withOpacity(0.6),
                      width: isLandscape ? 10 : 8),
                ),
                child: Icon(Icons.phone_android,
                    color: Colors.red.shade300, size: isLandscape ? 120 : 100),
              ),
              SizedBox(height: isLandscape ? 36 : 28),
              Text(
                'Please Silence Your Phone',
                style: TextStyle(
                  color: Colors.red.shade200,
                  fontSize: isLandscape ? 56 : 42,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isLandscape ? 20 : 16),
              Text(
                'الرجاء إغلاق الهاتف أو كتم الصوت',
                style: TextStyle(
                  color: Colors.red.shade300.withOpacity(0.85),
                  fontSize: isLandscape ? 42 : 32,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isLandscape ? 28 : 22),
              Text(
                'Out of respect for those in prayer',
                style: TextStyle(
                    color: white.withOpacity(0.45),
                    fontSize: isLandscape ? 26 : 20,
                    fontWeight: FontWeight.w300,
                    height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // MOSQUE IMAGE OVERLAY
  // Uses Image.memory from bytes cached in _displayImageMap.
  // No network calls, no CORS issues, no loading spinners.
  // ══════════════════════════════════════════════════════════════════
  Widget _buildMosqueImageOverlay() {
    if (_displayImageMap.isEmpty) return const SizedBox.shrink();
    final paths = _displayImageMap.keys.toList();
    final path = paths[_displayImageIndex % paths.length];
    final bytes = _displayImageMap[path];
    if (bytes == null) return const SizedBox.shrink();
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            bytes,
            key: ValueKey(path),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.black,
              child: Center(
                child: Icon(Icons.image_outlined,
                    color: white.withOpacity(0.15), size: 48),
              ),
            ),
          ),
          // Subtle mosque name watermark bottom-left
          Positioned(
            bottom: 32,
            left: 32,
            child: Text(
              _selectedMosque?['name'] ?? '',
              style: TextStyle(
                color: white.withOpacity(0.18),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // APP PROMO OVERLAY  —  sequence step 7, 7 seconds
  // Shows Ihsan logo, tagline, QR code linking to Google Play Store.
  // ══════════════════════════════════════════════════════════════════
  Widget _buildAppPromoOverlay() {
    final isLandscape = _forceLandscape;
    return GestureDetector(
      onTap: () => setState(() => _showAppPromoFlag = false),
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.2),
            radius: 1.3,
            colors: [
              const Color.fromARGB(255, 8, 22, 60),
              const Color.fromARGB(255, 3, 8, 28),
            ],
          ),
        ),
        child: Center(
          child: isLandscape
              ? _buildAppPromoLandscape()
              : _buildAppPromoPortrait(),
        ),
      ),
    );
  }

  Widget _buildAppPromoLandscape() {
    return Image.asset(
      'assets/app_promo_landscape.png',
      fit: BoxFit.contain,
    );
  }

  Widget _buildAppPromoPortrait() {
    return Image.asset(
      'assets/app_promo_portrait.png',
      fit: BoxFit.contain,
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // HADITH — sunnah.com API, sahih only, show every 20 min for 45 sec
  // Fetches Bukhari + Muslim books; caches locally; never interrupts adhan
  // ══════════════════════════════════════════════════════════════════

  /// Fetch a batch of ahadith from sunnah.com API (requires no key for basic)
  /// We pull from Sahih al-Bukhari (collection: bukhari) random chapters
  // ══════════════════════════════════════════════════════════════════
  // HADITH SYSTEM
  // Topic-targeted books from sunnah.com API:
  //   bukhari/2   = Belief (Iman) — foundational virtues
  //   bukhari/10  = Times of Prayer — virtues of Salah
  //   bukhari/24  = Zakat — virtues of Sadaqah/charity
  //   bukhari/31  = Fasting — virtues of Sawm
  //   bukhari/56  = Jihaad — khurooj fi sabilillah / going out in Allah's path
  //   bukhari/66  = Virtues of Quran
  //   bukhari/75  = Invocations (Du'a & Dhikr)
  //   bukhari/78  = Good Manners / Good Deeds
  //   muslim/4    = Prayer (Salah virtues)
  //   muslim/12   = Zakat (Sadaqah virtues)
  //   muslim/32   = Jihaad and Expeditions (khurooj/going out)
  //   muslim/48   = Remembrance and Supplication (Dhikr)
  // ══════════════════════════════════════════════════════════════════

  // ══════════════════════════════════════════════════════════════════
  // HARDCODED HADITH / AYAH ENTRIES
  // Each entry: arabic, english, urdu, reference, type ('hadith'|'ayah')
  // ══════════════════════════════════════════════════════════════════
  static const List<Map<String, String>> _kHadiths = [
    // 1 — Virtues of Quran (Bukhari 5027)
    {
      'arabic': 'خَيْرُكُمْ مَنْ تَعَلَّمَ الْقُرْآنَ وَعَلَّمَهُ',
      'english':
          'The best among you are those who learn the Qur\'an and teach it.',
      'urdu': 'تم میں سب سے بہتر وہ ہے جو قرآن مجید پڑھے اور پڑھائے۔',
      'reference': 'Ṣaḥīḥ al-Bukhārī 5027',
      'narrator': 'Narrated \'Uthmān (RA)',
      'type': 'hadith',
    },
    // 2 — Virtues of Ṣalāh (Bukhari 528)
    {
      'arabic':
          'أَرَأَيْتُمْ لَوْ أَنَّ نَهَرًا بِبَابِ أَحَدِكُمْ يَغْتَسِلُ فِيهِ كُلَّ يَوْمٍ خَمْسًا مَا تَقُولُ ذَلِكَ يُبْقِي مِنْ دَرَنِهِ؟ قَالُوا: لَا يُبْقِي مِنْ دَرَنِهِ شَيْئًا. قَالَ: فَذَلِكَ مِثْلُ الصَّلَوَاتِ الْخَمْسِ يَمْحُو اللَّهُ بِهِ الْخَطَايَا.',
      'english':
          'If there was a river at the door of anyone of you and he took a bath in it five times a day, would any dirt remain on him? They said: No. The Prophet ﷺ said: That is the example of the five prayers — with them Allah blots out evil deeds.',
      'urdu':
          'اگر کسی کے دروازے پر نہر جاری ہو اور وہ روزانہ پانچ بار نہائے تو کیا کوئی میل باقی رہے گی؟ صحابہ نے کہا: نہیں۔ آپ ﷺ نے فرمایا: یہی حال پانچ نمازوں کا ہے — اللہ ان سے گناہ مٹا دیتا ہے۔',
      'reference': 'Ṣaḥīḥ al-Bukhārī 528',
      'narrator': 'Narrated Abū Hurairah (RA)',
      'type': 'hadith',
    },
    // 3 — Virtues of Da'wah / Khuruj (Fussilat 41:33)
    {
      'arabic':
          'وَمَنْ أَحْسَنُ قَوْلًا مِّمَّن دَعَآ إِلَى ٱللَّهِ وَعَمِلَ صَـٰلِحًا وَقَالَ إِنَّنِى مِنَ ٱلْمُسْلِمِينَ',
      'english':
          'And whose words are better than someone who calls others to Allah, does good, and says: "I am truly one of those who submit"?',
      'urdu':
          'اور اس سے زیادہ اچھی بات والا کون ہے جو اللہ کی طرف بلائے اور نیک کام کرے اور کہے کہ میں یقیناً مسلمانوں میں سے ہوں۔',
      'reference': 'Sūrah Fuṣṣilat 41:33',
      'narrator': '',
      'type': 'ayah',
    },
    // 4 — Enjoining Good (Aal Imran 3:104)
    {
      'arabic':
          'وَلْتَكُن مِّنكُمْ أُمَّةٌ يَدْعُونَ إِلَى ٱلْخَيْرِ وَيَأْمُرُونَ بِٱلْمَعْرُوفِ وَيَنْهَوْنَ عَنِ ٱلْمُنكَرِ ۚ وَأُو۟لَـٰٓئِكَ هُمُ ٱلْمُفْلِحُونَ',
      'english':
          'Let there be a group among you who call others to goodness, encourage what is good, and forbid what is evil — it is they who will be successful.',
      'urdu':
          'اور تم میں ایک جماعت ایسی ہونی چاہیے جو لوگوں کو نیکی کی طرف بلائے، اچھے کام کرنے کا حکم دے اور برے کاموں سے منع کرے — یہی لوگ نجات پانے والے ہیں۔',
      'reference': 'Sūrah Āl \'Imrān 3:104',
      'narrator': '',
      'type': 'ayah',
    },
    // 5 — Virtues of Dhikr / Mufarradun (Muslim 2676)
    {
      'arabic':
          'سَبَقَ الْمُفَرِّدُونَ. قَالُوا: وَمَا الْمُفَرِّدُونَ يَا رَسُولَ اللَّهِ؟ قَالَ: الذَّاكِرُونَ اللَّهَ كَثِيرًا وَالذَّاكِرَاتُ.',
      'english':
          'The Messenger of Allah ﷺ said: "The Mufarradun have gone ahead." They asked: Who are the Mufarradun, O Messenger of Allah? He said: "Those men and women who remember Allah much."',
      'urdu':
          'رسول اللہ ﷺ نے فرمایا: مفردون بازی لے گئے۔ لوگوں نے پوچھا: مفردون کون ہیں؟ فرمایا: کثرت سے اللہ کو یاد کرنے والے مرد اور عورتیں۔',
      'reference': 'Ṣaḥīḥ Muslim 2676',
      'narrator': 'Narrated Abū Hurairah (RA)',
      'type': 'hadith',
    },
  ];

  /// One entry per day — cycles through all 5 in order.
  /// Uses the day-of-year so day 1 → entry 0, day 2 → entry 1, etc.
  void _pickTodayHadiths() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (_hadithDayKey == today) return;
    _hadithDayKey = today;
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    _todayHadithIndices = [dayOfYear % _kHadiths.length];
  }

  void _maybeShowHadith() {
    if (!mounted) return;
    if (_showAdhaan || _showMakrooh) return;
    _pickTodayHadiths();
    _hadithShowTimer?.cancel();
    setState(() => _showHadith = true);
    _hadithShowTimer = Timer(const Duration(seconds: 20), () {
      if (mounted) setState(() => _showHadith = false);
    });
  }

  Widget _buildHadithOverlay() {
    _pickTodayHadiths();
    final h = _kHadiths[_todayHadithIndices[0]];
    final isAyah = h['type'] == 'ayah';
    final isLandscape = _forceLandscape;

    // Colour palette — consistent with rest of screen
    const bgDeep = Color.fromARGB(255, 5, 12, 40);
    const bgMid = Color.fromARGB(255, 10, 25, 70);

    return GestureDetector(
      onTap: () => setState(() => _showHadith = false),
      child: Container(
        // Fully opaque — takes over the whole screen
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.4,
            colors: [bgMid, bgDeep],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isLandscape ? 60 : 24,
              vertical: isLandscape ? 32 : 28,
            ),
            child: Column(
              children: [
                // ── Top badge row ──────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: gold.withOpacity(0.12),
                        border:
                            Border.all(color: gold.withOpacity(0.45), width: 1),
                      ),
                      child: Icon(
                        isAyah ? Icons.menu_book : Icons.menu_book,
                        color: gold,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isAyah ? 'آيةٌ كريمة' : 'حديث شريف',
                      style: TextStyle(
                        color: gold,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                // Gold divider line
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 60),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.transparent,
                      gold.withOpacity(0.4),
                      Colors.transparent,
                    ]),
                  ),
                ),

                // ── Content ───────────────────────────────────────
                Expanded(
                  child: isLandscape
                      ? _hadithLandscapeContent(h, context)
                      : _hadithPortraitContent(h, context),
                ),

                // ── Reference + dismiss hint ───────────────────────
                const SizedBox(height: 8),
                Text(
                  h['reference'] ?? '',
                  style: TextStyle(
                    color: gold.withOpacity(0.55),
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                if ((h['narrator'] ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      h['narrator']!,
                      style: TextStyle(
                        color: white.withOpacity(0.3),
                        fontSize: 15,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  'Tap anywhere to dismiss',
                  style: TextStyle(
                    color: white.withOpacity(0.15),
                    fontSize: 9,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Landscape: three columns Arabic | English | Urdu
  Widget _hadithLandscapeContent(Map<String, String> h, BuildContext ctx) {
    // Scale to screen width — works on phone landscape and desktop monitor
    final w = MediaQuery.of(ctx).size.width;
    final ar = (w * 0.038).clamp(22.0, 36.0); // Arabic
    final en = (w * 0.028).clamp(18.0, 28.0); // English
    final ur = (w * 0.032).clamp(20.0, 32.0); // Urdu
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _langBlock(
            label: 'عربي',
            text: h['arabic'] ?? '',
            isRtl: true,
            fontSize: ar,
            textColor: white.withOpacity(0.97),
            fontStyle: FontStyle.normal,
          ),
        ),
        _vDivider(),
        Expanded(
          child: _langBlock(
            label: 'English',
            text: h['english'] ?? '',
            isRtl: false,
            fontSize: en,
            textColor: white.withOpacity(0.88),
            fontStyle: FontStyle.italic,
          ),
        ),
        _vDivider(),
        Expanded(
          child: _langBlock(
            label: 'اردو',
            text: h['urdu'] ?? '',
            isRtl: true,
            fontSize: ur,
            textColor: white.withOpacity(0.88),
            fontStyle: FontStyle.normal,
          ),
        ),
      ],
    );
  }

  // Portrait: Arabic top, English middle, Urdu bottom
  Widget _hadithPortraitContent(Map<String, String> h, BuildContext ctx) {
    // Scale to screen height — works on phone portrait and desktop browser
    final sh = MediaQuery.of(ctx).size.height;
    final ar = (sh * 0.062).clamp(32.0, 48.0); // Arabic
    final en = (sh * 0.048).clamp(26.0, 36.0); // English
    final ur = (sh * 0.054).clamp(28.0, 42.0); // Urdu
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _langBlock(
          label: 'عربي',
          text: h['arabic'] ?? '',
          isRtl: true,
          fontSize: ar,
          textColor: white.withOpacity(0.97),
          fontStyle: FontStyle.normal,
        ),
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 30),
          color: gold.withOpacity(0.15),
        ),
        _langBlock(
          label: 'English',
          text: h['english'] ?? '',
          isRtl: false,
          fontSize: en,
          textColor: white.withOpacity(0.85),
          fontStyle: FontStyle.italic,
        ),
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 30),
          color: gold.withOpacity(0.15),
        ),
        _langBlock(
          label: 'اردو',
          text: h['urdu'] ?? '',
          isRtl: true,
          fontSize: ur,
          textColor: white.withOpacity(0.85),
          fontStyle: FontStyle.normal,
        ),
      ],
    );
  }

  Widget _langBlock({
    required String label,
    required String text,
    required bool isRtl,
    required double fontSize,
    required Color textColor,
    required FontStyle fontStyle,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            color: gold.withOpacity(0.45),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          text,
          textAlign: TextAlign.center,
          textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w400,
            height: 1.65,
            fontStyle: fontStyle,
          ),
        ),
      ],
    );
  }

  Widget _vDivider() => Container(
        width: 1,
        height: 120,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              gold.withOpacity(0.25),
              Colors.transparent,
            ],
          ),
        ),
      );

  // ══════════════════════════════════════════════════════════════════
  // IQAMAH OVERLAY — full screen
  // ══════════════════════════════════════════════════════════════════
  Widget _buildJumuahJamaahAdhanOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color.fromARGB(255, 20, 10, 50),
            const Color.fromARGB(255, 36, 18, 80),
            const Color.fromARGB(255, 14, 8, 40),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: gold.withOpacity(0.1),
                border: Border.all(color: gold.withOpacity(0.5), width: 2.5),
              ),
              child: Icon(Icons.mosque_outlined, color: gold, size: 56),
            ),
            const SizedBox(height: 32),
            Text(
              'الأذان',
              style: TextStyle(
                color: gold,
                fontSize: 54,
                fontWeight: FontWeight.w600,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Adhān — Jumu\'ah',
              style: TextStyle(
                color: white,
                fontSize: 52,
                fontWeight: FontWeight.w200,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Please stand by for Jumu\'ah',
              style: TextStyle(
                color: white.withOpacity(0.5),
                fontSize: 24,
                fontWeight: FontWeight.w300,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 36),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                color: gold.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: gold.withOpacity(0.35), width: 1.5),
              ),
              child: Text(
                _jumuahJamaahAdhanTimeLeft,
                style: TextStyle(
                  color: gold,
                  fontSize: 38,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 4,
                  fontFeatures: const [ui.FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKhutbahOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color.fromARGB(255, 8, 20, 52),
            const Color.fromARGB(255, 15, 36, 85),
            const Color.fromARGB(255, 6, 14, 40),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: skyBlue.withOpacity(0.1),
                border: Border.all(color: skyBlue.withOpacity(0.5), width: 2.5),
              ),
              child: Icon(Icons.record_voice_over_outlined,
                  color: skyBlue, size: 56),
            ),
            const SizedBox(height: 32),
            Text(
              'الخطبة',
              style: TextStyle(
                color: skyBlue,
                fontSize: 54,
                fontWeight: FontWeight.w600,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Khutbah — Jumu\'ah',
              style: TextStyle(
                color: white,
                fontSize: 52,
                fontWeight: FontWeight.w200,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Please silence your phones and listen attentively',
              style: TextStyle(
                color: white.withOpacity(0.5),
                fontSize: 24,
                fontWeight: FontWeight.w300,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 36),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                color: skyBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: skyBlue.withOpacity(0.35), width: 1.5),
              ),
              child: Text(
                _khutbahTimeLeft,
                style: TextStyle(
                  color: skyBlue,
                  fontSize: 38,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 4,
                  fontFeatures: const [ui.FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIqamahOverlay() {
    return GestureDetector(
      onTap: () {
        setState(() => _showIqamah = false);
        _triggerBlackout(_iqamahPrayerName);
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color.fromARGB(255, 6, 28, 14),
              const Color.fromARGB(255, 10, 48, 22),
              const Color.fromARGB(255, 4, 20, 10),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: mintGreen.withOpacity(0.1),
                  border:
                      Border.all(color: mintGreen.withOpacity(0.5), width: 2.5),
                ),
                child: Icon(Icons.mosque_outlined, color: mintGreen, size: 56),
              ),
              const SizedBox(height: 32),
              // Arabic
              Text(
                'إقامة الصلاة',
                style: TextStyle(
                  color: mintGreen,
                  fontSize: 54,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 14),
              // Prayer name
              Text(
                _iqamahPrayerName,
                style: TextStyle(
                  color: white,
                  fontSize: 72,
                  fontWeight: FontWeight.w200,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Jamā\'ah is beginning now',
                style: TextStyle(
                  color: white.withOpacity(0.5),
                  fontSize: 26,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 48),
              // Silence phones — prominent
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: Colors.red.withOpacity(0.5), width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.phone_android,
                            color: Colors.red.shade300, size: 28),
                        const SizedBox(width: 14),
                        Text(
                          'Please silence all mobile phones',
                          style: TextStyle(
                            color: Colors.red.shade200,
                            fontSize: 26,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Icon(Icons.phone_android,
                            color: Colors.red.shade300, size: 28),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'الرجاء إغلاق جميع الهواتف المحمولة',
                      style: TextStyle(
                        color: Colors.red.shade300.withOpacity(0.65),
                        fontSize: 20,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Text(
                'Tap to dismiss',
                style: TextStyle(color: white.withOpacity(0.12), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // ADHKAR OVERLAY — post-salah remembrances, fires after blackout ends
  // ══════════════════════════════════════════════════════════════════
  Widget _buildAdhkarOverlay() {
    final isLandscape = _forceLandscape;

    // ── shared decoration ──────────────────────────────────────────
    const bgDeep = Color.fromARGB(255, 4, 10, 32);
    const bgMid = Color.fromARGB(255, 9, 22, 62);

    Widget screen = _buildAdhkarStep(isLandscape);

    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.3),
          radius: 1.5,
          colors: [bgMid, bgDeep],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Heading ─────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.only(
                  top: isLandscape ? 14 : 18, bottom: isLandscape ? 6 : 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'أَذْكَارٌ بَعْدَ الصَّلَاة',
                    style: TextStyle(
                      color: gold,
                      fontSize: isLandscape ? 60 : 36,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ADHKĀR AFTER ṢALĀH',
                    style: TextStyle(
                      color: gold.withOpacity(0.55),
                      fontSize: isLandscape ? 40 : 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 1,
                    width: 200,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.transparent,
                        gold.withOpacity(0.45),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                ],
              ),
            ),
            // ── Step content ────────────────────────────────────────
            Expanded(child: screen),
          ],
        ),
      ),
    );
  }

  Widget _buildAdhkarStep(bool isLandscape) {
    switch (_adhkarStep) {
      case 1:
        return _adhkarStep1(isLandscape);
      case 2:
        return _adhkarStep2(isLandscape);
      case 3:
        return _adhkarStep3(isLandscape);
      case 4:
        return _adhkarStep4(isLandscape);
      case 5:
        return _adhkarStep5(isLandscape);
      case 6:
        return _adhkarStep6(isLandscape);
      case 7:
        return _adhkarStep7(isLandscape);
      case 8:
        return _adhkarStep8(isLandscape);
      case 9:
        return _adhkarStep9(isLandscape);
      default:
        return const SizedBox.shrink();
    }
  }

  // ── helpers ───────────────────────────────────────────────────────
  Widget _adhkarArabic(String text, {double? fs, bool rtl = true}) {
    return Text(
      text,
      textAlign: TextAlign.center,
      textDirection: rtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      style: TextStyle(
        color: white.withOpacity(0.95),
        fontSize: fs ?? 30,
        fontWeight: FontWeight.w400,
        height: 1.85,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _adhkarEng(String text, {double? fs}) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: white.withOpacity(0.52),
        fontSize: fs ?? 18,
        fontWeight: FontWeight.w300,
        fontStyle: FontStyle.italic,
        height: 1.6,
      ),
    );
  }

  Widget _adhkarDivider() => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 60),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Colors.transparent,
            gold.withOpacity(0.3),
            Colors.transparent,
          ]),
        ),
      );

  Widget _adhkarCenter(List<Widget> children) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: children,
          ),
        ),
      );

  // ── Step 1: Astaghfirullah ×3 ─────────────────────────────────────
  Widget _adhkarStep1(bool ls) {
    const ar = 'أَسْتَغْفِرُ اللَّهَ';
    const en = 'I seek the forgiveness of Allah';
    if (ls) {
      // landscape: all 3 on one line
      return _adhkarCenter([
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _adhkarArabic(ar, fs: 46),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('·',
                  style: TextStyle(color: gold.withOpacity(0.4), fontSize: 40)),
            ),
            _adhkarArabic(ar, fs: 46),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('·',
                  style: TextStyle(color: gold.withOpacity(0.4), fontSize: 40)),
            ),
            _adhkarArabic(ar, fs: 46),
          ],
        ),
        const SizedBox(height: 16),
        _adhkarEng(en, fs: 22),
        const SizedBox(height: 6),
        Text('×3',
            style: TextStyle(
                color: gold.withOpacity(0.5),
                fontSize: 20,
                fontWeight: FontWeight.w600)),
      ]);
    } else {
      // portrait: stacked
      return _adhkarCenter([
        _adhkarArabic(ar, fs: 70),
        _adhkarArabic(ar, fs: 70),
        _adhkarArabic(ar, fs: 70),
        const SizedBox(height: 14),
        _adhkarEng(en, fs: 20),
        const SizedBox(height: 4),
        Text('×3',
            style: TextStyle(
                color: gold.withOpacity(0.5),
                fontSize: 18,
                fontWeight: FontWeight.w600)),
      ]);
    }
  }

  // ── Step 2: Allahumma anta al-salaam ─────────────────────────────
  Widget _adhkarStep2(bool ls) {
    return _adhkarCenter([
      _adhkarArabic(
        'اللَّهُمَّ أَنْتَ السَّلَامُ وَمِنْكَ السَّلَامُ،\nتَبَارَكْتَ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ',
        fs: ls ? 40 : 50,
      ),
      _adhkarDivider(),
      _adhkarEng(
        'O Allah, You are The Flawless and The Source of Peace,\nand from You comes peace.\nBlessed are You, full of Majesty and Honour.',
        fs: ls ? 22 : 25,
      ),
      const SizedBox(height: 6),
      Text('(Muslim)',
          style:
              TextStyle(color: gold.withOpacity(0.4), fontSize: ls ? 15 : 13)),
    ]);
  }

  // ── Step 3: La ilaha illallah wahdahu + Allahumma la mani'a ──────
  Widget _adhkarStep3(bool ls) {
    return _adhkarCenter([
      _adhkarArabic(
        'لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ،\nلَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَىٰ كُلِّ شَيْءٍ قَدِيرٌ',
        fs: ls ? 36 : 40,
      ),
      const SizedBox(height: 8),
      _adhkarArabic(
        'اللَّهُمَّ لَا مَانِعَ لِمَا أَعْطَيْتَ،\nوَلَا مُعْطِيَ لِمَا مَنَعْتَ،\nوَلَا يَنْفَعُ ذَا الْجَدِّ مِنْكَ الْجَدُّ',
        fs: ls ? 34 : 40,
      ),
      _adhkarDivider(),
      _adhkarEng(
        'There is no god but Allah, Alone, with no partner.\nTo Him belongs all sovereignty and praise, over all things All-Powerful.\nO Allah, none can withhold what You give, none can give what You withhold,\nand no fortune avails its owner against You.',
        fs: ls ? 19 : 25,
      ),
      const SizedBox(height: 4),
      Text('(Muslim)',
          style:
              TextStyle(color: gold.withOpacity(0.4), fontSize: ls ? 14 : 12)),
    ]);
  }

  // ── Step 4: La ilaha illallah + la hawla ─────────────────────────
  Widget _adhkarStep4(bool ls) {
    return _adhkarCenter([
      _adhkarArabic(
        'لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ،\nلَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَىٰ كُلِّ شَيْءٍ قَدِيرٌ',
        fs: ls ? 34 : 40,
      ),
      const SizedBox(height: 6),
      _adhkarArabic(
        'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ، لَا إِلَٰهَ إِلَّا اللَّهُ وَلَا نَعْبُدُ إِلَّا إِيَّاهُ',
        fs: ls ? 32 : 40,
      ),
      const SizedBox(height: 6),
      _adhkarArabic(
        'لَهُ النِّعْمَةُ وَلَهُ الْفَضْلُ وَلَهُ الثَّنَاءُ الْحَسَنُ،\nلَا إِلَٰهَ إِلَّا اللَّهُ مُخْلِصِينَ لَهُ الدِّينَ وَلَوْ كَرِهَ الْكَافِرُونَ',
        fs: ls ? 30 : 40,
      ),
      _adhkarDivider(),
      _adhkarEng(
        'There is no god but Allah, Alone, with no partner.\nTo Him belongs sovereignty and praise, over all things All-Powerful.\nThere is no might except through Allah. We worship none but Him.\nTo Him belong all blessings, bounty and beautiful praise.\nThere is no god but Allah — sincere in faith, even if the disbelievers dislike it.',
        fs: ls ? 17 : 20,
      ),
      const SizedBox(height: 4),
      Text('(Muslim)',
          style:
              TextStyle(color: gold.withOpacity(0.4), fontSize: ls ? 13 : 11)),
    ]);
  }

  // ── Step 5: Tasbih ×33 each + Kalimah ────────────────────────────
  Widget _adhkarStep5(bool ls) {
    Widget tasbihBlock(String ar, String label, String count) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ar,
                textAlign: TextAlign.center,
                textDirection: ui.TextDirection.rtl,
                style: TextStyle(
                    color: white.withOpacity(0.95),
                    fontSize: ls ? 42 : 50,
                    fontWeight: FontWeight.w400,
                    height: 1.4)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: gold.withOpacity(0.55),
                    fontSize: ls ? 15 : 20,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600)),
            Text(count,
                style: TextStyle(
                    color: gold,
                    fontSize: ls ? 22 : 25,
                    fontWeight: FontWeight.w700)),
          ],
        );

    const kalimah =
        'لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ،\nلَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَىٰ كُلِّ شَيْءٍ قَدِيرٌ';

    if (ls) {
      return _adhkarCenter([
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: tasbihBlock('سُبْحَانَ اللَّهِ', 'SUBHĀNALLĀH', '×33')),
            Container(width: 1, height: 100, color: gold.withOpacity(0.15)),
            Expanded(
                child:
                    tasbihBlock('الْحَمْدُ لِلَّهِ', 'ALHAMDULILLĀH', '×33')),
            Container(width: 1, height: 100, color: gold.withOpacity(0.15)),
            Expanded(
                child: tasbihBlock('اللَّهُ أَكْبَرُ', 'ALLĀHU AKBAR', '×33')),
          ],
        ),
        _adhkarDivider(),
        _adhkarArabic(kalimah, fs: 50),
      ]);
    } else {
      return _adhkarCenter([
        tasbihBlock('سُبْحَانَ اللَّهِ', 'SUBHĀNALLĀH', '×33'),
        const SizedBox(height: 10),
        tasbihBlock('الْحَمْدُ لِلَّهِ', 'ALHAMDULILLĀH', '×33'),
        const SizedBox(height: 10),
        tasbihBlock('اللَّهُ أَكْبَرُ', 'ALLĀHU AKBAR', '×33'),
        _adhkarDivider(),
        _adhkarArabic(kalimah, fs: 40),
      ]);
    }
  }

  // ── Step 6: Allahumma a'inni ─────────────────────────────────────
  Widget _adhkarStep6(bool ls) {
    return _adhkarCenter([
      _adhkarArabic(
        'اللَّهُمَّ أَعِنِّي عَلَىٰ ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ',
        fs: ls ? 44 : 50,
      ),
      _adhkarDivider(),
      _adhkarEng(
        'O Allah, help us to remember You,\nto be grateful to You,\nand to worship You in an excellent manner.',
        fs: ls ? 24 : 30,
      ),
      const SizedBox(height: 6),
      Text('(Abū Dāwūd)',
          style:
              TextStyle(color: gold.withOpacity(0.4), fontSize: ls ? 15 : 13)),
    ]);
  }

  // ── Step 7: Āyat al-Kursī ────────────────────────────────────────
  Widget _adhkarStep7(bool ls) {
    return _adhkarCenter([
      Text(
        'آيَةُ الْكُرْسِيّ',
        style: TextStyle(
            color: gold.withOpacity(0.7),
            fontSize: ls ? 20 : 30,
            fontWeight: FontWeight.w600,
            letterSpacing: 2),
      ),
      const SizedBox(height: 10),
      _adhkarArabic(
        'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَن ذَا الَّذِي يَشْفَعُ عِندَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ',
        fs: ls ? 40 : 50,
      ),
      _adhkarDivider(),
      Text(
        'Sūrah al-Baqarah 2:255',
        style: TextStyle(
            color: gold.withOpacity(0.4),
            fontSize: ls ? 14 : 30,
            letterSpacing: 1),
      ),
    ]);
  }

  // ── Step 8: Allahumma inni as'aluka ─────────────────────────────
  Widget _adhkarStep8(bool ls) {
    return _adhkarCenter([
      _adhkarArabic(
        'اللَّهُمَّ إِنِّي أَسْأَلُكَ عِلْمًا نَافِعًا،\nوَرِزْقًا طَيِّبًا،\nوَعَمَلًا مُتَقَبَّلًا',
        fs: ls ? 46 : 60,
      ),
      _adhkarDivider(),
      _adhkarEng(
        'O Allah, I ask You for beneficial knowledge,\ngood provision,\nand acceptable deeds.',
        fs: ls ? 26 : 40,
      ),
      const SizedBox(height: 6),
      Text('(Ibn Mājah)',
          style:
              TextStyle(color: gold.withOpacity(0.4), fontSize: ls ? 15 : 13)),
    ]);
  }

  // ── Step 9: Allahumma ajirni min an-Nar ×7 (Fajr & Maghrib only) ─
  Widget _adhkarStep9(bool ls) {
    return _adhkarCenter([
      _adhkarArabic(
        'اللَّهُمَّ أَجِرْنِي مِنَ النَّارِ',
        fs: ls ? 52 : 60,
      ),
      const SizedBox(height: 10),
      Text(
        '×7',
        style: TextStyle(
            color: gold, fontSize: ls ? 36 : 28, fontWeight: FontWeight.w700),
      ),
      _adhkarDivider(),
      _adhkarEng(
        'O Allah, save me from the Hellfire.',
        fs: ls ? 26 : 50,
      ),
      const SizedBox(height: 6),
      Text(
        'Recite 7 times after Fajr & Maghrib  ·  (Abū Dāwūd)',
        style: TextStyle(color: gold.withOpacity(0.4), fontSize: ls ? 14 : 30),
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════
  // BLACKOUT OVERLAY — 7 minutes after each Jamaat
  // ══════════════════════════════════════════════════════════════════
  Widget _buildBlackoutOverlay() {
    return AnimatedBuilder(
      animation: _clockPulse,
      builder: (_, __) {
        final pulse = _clockPulse.value * 0.3 + 0.7;
        return Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mosque icon — softly pulsing
                Icon(Icons.mosque_outlined,
                    color: gold.withOpacity(0.12 * pulse), size: 100),
                const SizedBox(height: 24),

                // ── Which salah is taking place ─────────────────────
                Text(
                  _blackoutPrayerName,
                  style: TextStyle(
                    color: gold.withOpacity(0.75),
                    fontSize: 70,
                    fontWeight: FontWeight.w200,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ṣalāh in progress',
                  style: TextStyle(
                    color: white.withOpacity(0.35),
                    fontSize: 30,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 36),

                // ── Silence phones — prominent ──────────────────────
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08 * pulse),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.red.withOpacity(0.45 * pulse),
                        width: 1.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.phone_android,
                              color:
                                  Colors.red.shade300.withOpacity(0.8 * pulse),
                              size: 22),
                          const SizedBox(width: 12),
                          Text(
                            'Please silence all mobile phones',
                            style: TextStyle(
                              color:
                                  Colors.red.shade200.withOpacity(0.85 * pulse),
                              fontSize: 40,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.phone_android,
                              color:
                                  Colors.red.shade300.withOpacity(0.8 * pulse),
                              size: 30),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'الرجاء إغلاق جميع الهواتف المحمولة',
                        style: TextStyle(
                          color: Colors.red.shade300.withOpacity(0.6 * pulse),
                          fontSize: 20,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),
                // Countdown
                Text(
                  _blackoutTimeLeft,
                  style: TextStyle(
                    color: white.withOpacity(0.8),
                    fontSize: 45,
                    fontWeight: FontWeight.w100,
                    letterSpacing: 6,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Screen will restore automatically',
                  style: TextStyle(
                    color: white.withOpacity(0.07),
                    fontSize: 20,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // ADHAN MASJID OVERLAY — fires 15 min before iqamah (3 min duration)
  // For Maghrib: fires 3 min after adhan beginning
  // ══════════════════════════════════════════════════════════════════
  Widget _buildAdhanMasjidOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.82),
      child: Center(
        child: Container(
          width: 580,
          padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 48),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color.fromARGB(255, 8, 30, 18),
                const Color.fromARGB(255, 14, 52, 28),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: mintGreen.withOpacity(0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: mintGreen.withOpacity(0.2),
                blurRadius: 70,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: mintGreen.withOpacity(0.1),
                  border:
                      Border.all(color: mintGreen.withOpacity(0.5), width: 2.5),
                ),
                child: Icon(Icons.mosque_outlined, color: mintGreen, size: 48),
              ),
              const SizedBox(height: 24),
              Text(
                'أَذَانُ الْمَسْجِد',
                style: TextStyle(
                  color: mintGreen.withOpacity(0.9),
                  fontSize: 38,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _adhanMasjidPrayerName,
                style: TextStyle(
                  color: white,
                  fontSize: 60,
                  fontWeight: FontWeight.w200,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                height: 1,
                width: 140,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.transparent,
                    mintGreen.withOpacity(0.5),
                    Colors.transparent,
                  ]),
                ),
              ),
              const SizedBox(height: 24),
              // Adhan words
              Text(
                'اللَّهُ أَكْبَرُ  ·  اللَّهُ أَكْبَرُ',
                style: TextStyle(
                  color: white.withOpacity(0.65),
                  fontSize: 26,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'حَيَّ عَلَى الصَّلَاةِ  ·  حَيَّ عَلَى الْفَلَاحِ',
                style: TextStyle(
                  color: white.withOpacity(0.5),
                  fontSize: 22,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 28),
              // Countdown
              if (_adhanMasjidTimeLeft.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: mintGreen.withOpacity(0.25), width: 1),
                  ),
                  child: Text(
                    _adhanMasjidTimeLeft,
                    style: TextStyle(
                      color: mintGreen.withOpacity(0.7),
                      fontSize: 38,
                      fontWeight: FontWeight.w200,
                      letterSpacing: 5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // ADHAN DUA OVERLAY — shown after adhan masjid popup ends (15 sec)
  // For Maghrib: fires jamaah overlay automatically after dua
  // ══════════════════════════════════════════════════════════════════
  Widget _buildAdhanDuaOverlay() {
    final isLandscape = _forceLandscape;
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    // Font sizes scale to the shorter dimension so nothing overflows
    final arabicFs = isLandscape
        ? (sh * 0.055).clamp(22.0, 44.0)
        : (sw * 0.07).clamp(20.0, 38.0);
    final engFs = isLandscape
        ? (sh * 0.038).clamp(14.0, 28.0)
        : (sw * 0.048).clamp(13.0, 24.0);
    final titleArabicFs = isLandscape
        ? (sh * 0.048).clamp(18.0, 36.0)
        : (sw * 0.065).clamp(18.0, 32.0);
    final titleEngFs = isLandscape
        ? (sh * 0.032).clamp(12.0, 22.0)
        : (sw * 0.044).clamp(12.0, 20.0);
    final refFs = isLandscape
        ? (sh * 0.028).clamp(11.0, 20.0)
        : (sw * 0.038).clamp(11.0, 18.0);

    return Container(
      color: Colors.black.withOpacity(0.85),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isLandscape ? 32 : 20,
              vertical: isLandscape ? 16 : 24,
            ),
            child: Container(
              width: isLandscape
                  ? (sw * 0.72).clamp(420.0, 820.0)
                  : (sw * 0.92).clamp(280.0, 500.0),
              padding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 44 : 28,
                vertical: isLandscape ? 32 : 36,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color.fromARGB(255, 12, 28, 65),
                    const Color.fromARGB(255, 22, 48, 100),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: gold.withOpacity(0.55), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: gold.withOpacity(0.18),
                    blurRadius: 70,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: gold.withOpacity(0.1),
                      border:
                          Border.all(color: gold.withOpacity(0.5), width: 2),
                    ),
                    child:
                        const Icon(Icons.auto_awesome, color: gold, size: 36),
                  ),
                  SizedBox(height: isLandscape ? 14 : 18),
                  Text(
                    'دُعَاءُ بَعْدَ الْأَذَان',
                    style: TextStyle(
                      color: gold.withOpacity(0.9),
                      fontSize: titleArabicFs,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 4,
                    ),
                  ),
                  SizedBox(height: isLandscape ? 4 : 6),
                  Text(
                    'Du\'ā After the Adhān',
                    style: TextStyle(
                      color: white.withOpacity(0.4),
                      fontSize: titleEngFs,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: isLandscape ? 16 : 20),
                  Container(
                    height: 1,
                    width: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.transparent,
                        gold.withOpacity(0.45),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                  SizedBox(height: isLandscape ? 16 : 22),
                  // Arabic dua text
                  Text(
                    'اللَّهُمَّ رَبَّ هَٰذِهِ الدَّعْوَةِ التَّامَّةِ\nوَالصَّلَاةِ الْقَائِمَةِ\nآتِ مُحَمَّدًا الْوَسِيلَةَ وَالْفَضِيلَةَ\nوَابْعَثْهُ مَقَامًا مَحْمُودًا الَّذِي وَعَدْتَهُ',
                    textAlign: TextAlign.center,
                    textDirection: ui.TextDirection.rtl,
                    style: TextStyle(
                      color: white.withOpacity(0.92),
                      fontSize: arabicFs,
                      fontWeight: FontWeight.w400,
                      height: 1.9,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: isLandscape ? 16 : 22),
                  Container(
                    height: 1,
                    width: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.transparent,
                        gold.withOpacity(0.3),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                  SizedBox(height: isLandscape ? 12 : 16),
                  // English translation
                  Text(
                    '"O Allah, Lord of this perfect call\nand the prayer to be offered,\ngrant Muhammad the privilege and honour\nand raise him to the praised position You promised."',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: white.withOpacity(0.5),
                      fontSize: engFs,
                      fontWeight: FontWeight.w300,
                      fontStyle: FontStyle.italic,
                      height: 1.65,
                    ),
                  ),
                  SizedBox(height: isLandscape ? 10 : 14),
                  Text(
                    'Ṣaḥīḥ al-Bukhārī 614',
                    style: TextStyle(
                      color: gold.withOpacity(0.35),
                      fontSize: refFs,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdhaanOverlay() {
    return GestureDetector(
      onTap: () => setState(() => _showAdhaan = false),
      child: Container(
        color: Colors.black.withOpacity(0.78),
        child: Center(
          child: Container(
            width: 520,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 44),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.fromARGB(255, 12, 30, 72),
                  Color.fromARGB(255, 20, 50, 110),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: gold.withOpacity(0.6), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: gold.withOpacity(0.18),
                  blurRadius: 60,
                  spreadRadius: 6,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: gold.withOpacity(0.1),
                    border: Border.all(color: gold.withOpacity(0.5), width: 2),
                  ),
                  child:
                      const Icon(Icons.mosque_outlined, color: gold, size: 42),
                ),
                const SizedBox(height: 22),
                Text(
                  'أَذَان',
                  style: TextStyle(
                    color: gold.withOpacity(0.8),
                    fontSize: 32,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Time for',
                  style:
                      TextStyle(color: white.withOpacity(0.45), fontSize: 18),
                ),
                const SizedBox(height: 10),
                Text(
                  _adhaanPrayerName,
                  style: const TextStyle(
                    color: white,
                    fontSize: 64,
                    fontWeight: FontWeight.w200,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  height: 1,
                  width: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.transparent,
                      gold.withOpacity(0.5),
                      Colors.transparent,
                    ]),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'الله أكبر  ·  الله أكبر',
                  style: TextStyle(
                    color: white.withOpacity(0.55),
                    fontSize: 22,
                    letterSpacing: 2.5,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Tap to dismiss',
                  style: TextStyle(
                    color: white.withOpacity(0.18),
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMakroohOverlay() {
    return AnimatedBuilder(
      animation: _clockPulse,
      builder: (_, __) {
        final pulse = _clockPulse.value * 0.45 + 0.55;
        return Stack(
          children: [
            // Pulsing red edge vignette over the whole screen
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      Colors.transparent,
                      Colors.red.withOpacity(0.12 * pulse),
                    ],
                  ),
                  border: Border.all(
                      color: Colors.red.withOpacity(0.6 * pulse), width: 3),
                ),
              ),
            ),

            // Centre modal card
            Center(
              child: GestureDetector(
                onTap: () {}, // block tap-through
                child: Container(
                  width: MediaQuery.of(context).size.width > 520
                      ? 500
                      : MediaQuery.of(context).size.width * 0.9,
                  padding: const EdgeInsets.fromLTRB(40, 30, 40, 24),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(248, 18, 0, 0),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                        color: Colors.red.withOpacity(0.65 * pulse),
                        width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.red.withOpacity(0.3 * pulse),
                          blurRadius: 70,
                          spreadRadius: 8),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Arabic + warning icon row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.warning_amber,
                              color: Colors.red.shade400, size: 28),
                          const SizedBox(width: 10),
                          Text(
                            'وقت مكروه',
                            style: TextStyle(
                              color: Colors.red.shade300,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(Icons.warning_amber,
                              color: Colors.red.shade400, size: 28),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Main title (e.g. "Makrūh Time" or "Zawwāl")
                      Text(
                        _makroohLabel,
                        style: TextStyle(
                          color: Colors.red.shade200,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 8),

                      // Sub label
                      Text(
                        _makroohSubLabel,
                        style: TextStyle(
                          color: white.withOpacity(0.52),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 20),

                      // Countdown + end time row
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.red.withOpacity(0.2), width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Time remaining
                            Column(
                              children: [
                                Text(
                                  'Ends in',
                                  style: TextStyle(
                                    color: white.withOpacity(0.35),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _makroohTimeLeft.isNotEmpty
                                      ? _makroohTimeLeft
                                      : '--:--',
                                  style: TextStyle(
                                    color: Colors.red.shade200,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w200,
                                    letterSpacing: 2,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            Container(
                                width: 1,
                                height: 40,
                                color: Colors.red.withOpacity(0.2)),

                            // End time
                            Column(
                              children: [
                                Text(
                                  'Ends at',
                                  style: TextStyle(
                                    color: white.withOpacity(0.35),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _makroohEndTime.isNotEmpty
                                      ? _makroohEndTime
                                      : '--:--',
                                  style: TextStyle(
                                    color: white.withOpacity(0.75),
                                    fontSize: 28,
                                    fontWeight: FontWeight.w200,
                                    letterSpacing: 2,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Hadith reminder
                      Text(
                        '"Three times at which the Prophet صلى الله عليه وسلم forbade us to pray..."',
                        style: TextStyle(
                          color: white.withOpacity(0.22),
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // AUTH ROW — login is required so always show name + logout
  // ══════════════════════════════════════════════════════════════════
  Widget _buildAuthRow({required bool compact}) {
    final firstName = _displayName.isNotEmpty
        ? _displayName.split(' ').first
        : (_currentUser?.email?.split('@').first ?? '');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: mintGreen,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          firstName,
          style: TextStyle(
            color: white.withOpacity(0.7),
            fontSize: compact ? 12 : 13,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _pillBtn({
    required String label,
    required IconData icon,
    required bool isGold,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          gradient: isGold
              ? const LinearGradient(
                  colors: [
                    Color.fromARGB(255, 222, 185, 105),
                    Color.fromARGB(255, 200, 160, 78),
                  ],
                )
              : null,
          color: isGold ? null : navyLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isGold ? Colors.transparent : gold.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: isGold
              ? [
                  BoxShadow(
                    color: gold.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: isGold ? navy : gold,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isGold ? navy : gold,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // SHARED WIDGETS
  // ══════════════════════════════════════════════════════════════════

  Widget _buildSearchBar({required bool dark}) {
    return Container(
      decoration: BoxDecoration(
        color: dark ? navyLight.withOpacity(0.9) : white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dark ? gold.withOpacity(0.25) : borderCol,
          width: 1,
        ),
        boxShadow: dark
            ? []
            : [
                BoxShadow(
                  color: navy.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: TextField(
        controller: _searchCtrl,
        style: TextStyle(color: dark ? white : textDark, fontSize: 13),
        cursorColor: gold,
        decoration: InputDecoration(
          hintText:
              _isLoadingMosques ? 'Loading mosques…' : 'Search mosque or city…',
          hintStyle: TextStyle(
            color: dark ? white.withOpacity(0.28) : textMid.withOpacity(0.5),
            fontSize: 12,
          ),
          prefixIcon: _isLoadingMosques
              ? const Padding(
                  padding: EdgeInsets.all(11),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: gold,
                    ),
                  ),
                )
              : Icon(
                  Icons.search,
                  color: gold.withOpacity(0.65),
                  size: 16,
                ),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close,
                    color: dark
                        ? white.withOpacity(0.35)
                        : textMid.withOpacity(0.4),
                    size: 14,
                  ),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {
                      _showSuggestions = false;
                      _filteredMosques = _allMosques;
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 11,
            horizontal: 4,
          ),
        ),
        onChanged: _filterMosques,
        onTap: () {
          if (_searchCtrl.text.isNotEmpty)
            setState(() => _showSuggestions = true);
        },
      ),
    );
  }

  Widget _buildSuggestionList({required double maxH}) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: navyLight,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: gold.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _filteredMosques.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: white.withOpacity(0.06)),
        itemBuilder: (context, i) {
          final m = _filteredMosques[i];
          final isSelected = _selectedMosque?['id'] == m['id'];
          return ListTile(
            dense: true,
            leading: Icon(
              Icons.mosque_outlined,
              size: 15,
              color: isSelected ? gold : white.withOpacity(0.35),
            ),
            title: Text(
              m['name'],
              style: TextStyle(
                color: isSelected ? gold : white,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            subtitle: (m['city'] as String).isNotEmpty
                ? Text(
                    m['city'],
                    style: TextStyle(
                      color: white.withOpacity(0.3),
                      fontSize: 10,
                    ),
                  )
                : null,
            trailing: isSelected
                ? const Icon(Icons.check, color: gold, size: 13)
                : null,
            onTap: () {
              FirebaseAnalytics.instance.logEvent(
                name: 'mosque_selected',
                parameters: {
                  'mosque_name': m['name'] as String,
                  'mosque_id': m['id'] as String,
                  'city': (m['city'] ?? '') as String,
                },
              ).catchError((e) => debugPrint('Analytics logEvent error: $e'));
              _selectMosque(m);
            },
          );
        },
      ),
    );
  }

  Widget _headerCell(String text, TextAlign align, double size) => Expanded(
        child: Text(
          text,
          textAlign: align,
          style: TextStyle(
            color: gold,
            fontSize: size,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      );

  Widget _timeChip(
    String time, {
    required bool isNext,
    required bool isSunrise,
    required bool isPrimary,
  }) {
    final displayTime = time.isEmpty || time == '--' ? '--' : time;
    Color textColor;
    Color bgColor;
    Color borderColor;

    if (isSunrise) {
      textColor = textMid.withOpacity(0.5);
      bgColor = offWhite;
      borderColor = borderCol.withOpacity(0.5);
    } else if (isNext && isPrimary) {
      textColor = const Color.fromARGB(255, 20, 75, 160);
      bgColor = skyLight;
      borderColor = skyBlue.withOpacity(0.4);
    } else if (isNext && !isPrimary) {
      textColor = const Color.fromARGB(255, 15, 110, 75);
      bgColor = mintLight;
      borderColor = mintGreen.withOpacity(0.4);
    } else {
      textColor = textMid;
      bgColor = offWhite;
      borderColor = borderCol;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: isNext
            ? [
                BoxShadow(
                  color: (isPrimary ? skyBlue : mintGreen).withOpacity(0.15),
                  blurRadius: 6,
                ),
              ]
            : [],
      ),
      child: Text(
        displayTime,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
          color: textColor,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  // ── Empty / loading / error states ─────────────────────────────
  Widget _buildEmptyState({required bool light}) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [navyLight.withOpacity(0.5), Colors.transparent],
                ),
                border: Border.all(color: gold.withOpacity(0.15), width: 1),
              ),
              child: Icon(
                Icons.mosque_outlined,
                size: 28,
                color:
                    light ? textMid.withOpacity(0.25) : white.withOpacity(0.08),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Select a mosque to view times',
              style: TextStyle(
                color:
                    light ? textMid.withOpacity(0.5) : white.withOpacity(0.2),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Search by name or city above',
              style: TextStyle(
                color:
                    light ? textMid.withOpacity(0.3) : white.withOpacity(0.1),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );

  Widget _buildNoTimetable({required bool light}) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [navyMid.withOpacity(0.8), Colors.transparent],
                  ),
                  border: Border.all(color: gold.withOpacity(0.3), width: 1.5),
                ),
                child: Icon(
                  Icons.schedule,
                  color: gold.withOpacity(0.5),
                  size: 26,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No Timetable Available',
                style: TextStyle(
                  color: light ? textDark : white.withOpacity(0.85),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'No prayer times have been uploaded for\n${_selectedMosque?['name'] ?? 'this mosque'} yet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: light ? textMid : white.withOpacity(0.35),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildLoader({required bool light}) => Center(
        child: CircularProgressIndicator(
          color: light ? gold.withOpacity(0.6) : gold.withOpacity(0.4),
          strokeWidth: 2,
        ),
      );

  Widget _buildError({required bool light}) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _errorMsg ?? 'An error occurred',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: light ? textMid : white.withOpacity(0.4),
              fontSize: 13,
            ),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════
// DRAWER BODY — stateful 3-tab panel
// Tabs: Images | Jamaat Times | Settings
// ══════════════════════════════════════════════════════════════════
class _DrawerBody extends StatefulWidget {
  final String firstName, email, mosqueId, mosqueName;
  final Map<String, Uint8List> displayImageMap;
  final Future<void> Function(String) onDeleteImage;
  final Future<String?> Function() onUploadImageFromDevice;
  final VoidCallback onRefreshImages;
  final Future<void> Function({
    required String mosqueId,
    required Map<String, String> updatedJamaatTimes,
    required DateTime endDate,
  }) onBatchWriteJamaat;
  final VoidCallback onChangeMosque;
  final VoidCallback onLogOut;
  final VoidCallback onCloseDrawer;
  final VoidCallback onToggleOrientation;
  final bool isLandscape;
  final String customTickerMessage;
  final void Function(String) onUpdateTickerMessage;
  // Palette
  final Color navy,
      navyMid,
      navyLight,
      gold,
      goldLight,
      white,
      offWhite,
      textDark,
      textMid,
      borderCol,
      mintGreen,
      skyBlue,
      skyLight;

  const _DrawerBody({
    required this.firstName,
    required this.email,
    required this.mosqueId,
    required this.mosqueName,
    required this.displayImageMap,
    required this.onDeleteImage,
    required this.onUploadImageFromDevice,
    required this.onRefreshImages,
    required this.onBatchWriteJamaat,
    required this.onChangeMosque,
    required this.onLogOut,
    required this.onCloseDrawer,
    required this.onToggleOrientation,
    required this.isLandscape,
    required this.customTickerMessage,
    required this.onUpdateTickerMessage,
    required this.navy,
    required this.navyMid,
    required this.navyLight,
    required this.gold,
    required this.goldLight,
    required this.white,
    required this.offWhite,
    required this.textDark,
    required this.textMid,
    required this.borderCol,
    required this.mintGreen,
    required this.skyBlue,
    required this.skyLight,
  });

  @override
  State<_DrawerBody> createState() => _DrawerBodyState();
}

class _DrawerBodyState extends State<_DrawerBody>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _savingUrl = false;

  // Jamaat editor state
  final Map<String, TextEditingController> _jamaatCtrls = {
    'fajrJ': TextEditingController(),
    'dhuhrJ': TextEditingController(),
    'asrJ': TextEditingController(),
    'maghrib': TextEditingController(),
    'ishaJ': TextEditingController(),
  };
  DateTime _endDate = DateTime.now().add(const Duration(days: 6));
  bool _savingJamaat = false;
  String _jamaatSaveMsg = '';

  // Custom ticker message editor
  late TextEditingController _tickerMsgCtrl;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tickerMsgCtrl = TextEditingController(text: widget.customTickerMessage);
  }

  @override
  void dispose() {
    _tab.dispose();
    for (final c in _jamaatCtrls.values) c.dispose();
    _tickerMsgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Header ─────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 52, 20, 0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color.fromARGB(255, 12, 30, 78),
                widget.navy,
              ],
            ),
            border: Border(
              bottom: BorderSide(color: widget.gold.withOpacity(0.2), width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.gold.withOpacity(0.1),
                      border: Border.all(
                          color: widget.gold.withOpacity(0.4), width: 1.5),
                    ),
                    child: Icon(Icons.person, color: widget.gold, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.firstName,
                            style: TextStyle(
                                color: widget.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                        Text(widget.email,
                            style: TextStyle(
                                color: widget.white.withOpacity(0.35),
                                fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onCloseDrawer,
                    child: Icon(Icons.close,
                        color: widget.white.withOpacity(0.4), size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.mosqueName.isNotEmpty
                    ? widget.mosqueName
                    : 'No mosque selected',
                style: TextStyle(
                    color: widget.gold.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              // Tabs
              TabBar(
                controller: _tab,
                labelColor: widget.gold,
                unselectedLabelColor: widget.white.withOpacity(0.35),
                indicatorColor: widget.gold,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5),
                tabs: const [
                  Tab(text: 'IMAGES'),
                  Tab(text: "JAMĀ'AH"),
                  Tab(text: 'SETTINGS'),
                ],
              ),
            ],
          ),
        ),

        // ── Tab content ────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildImagesTab(),
              _buildJamaatTab(),
              _buildSettingsTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ── IMAGES TAB ──────────────────────────────────────────────────
  // Uses bytes from widget.displayImageMap (Storage-only, no Firestore).
  // Thumbnail rendered with Image.memory — no network calls, no CORS issues.
  Widget _buildImagesTab() {
    final imageMap = widget.displayImageMap;
    final paths = imageMap.keys.toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('DISPLAY IMAGES', Icons.image_outlined),
          const SizedBox(height: 6),
          Text(
            'Images shown in the display cycle. '
            'Each mosque has its own folder — only this mosque can see these.',
            style: TextStyle(
                color: widget.white.withOpacity(0.35),
                fontSize: 11,
                height: 1.5),
          ),
          const SizedBox(height: 16),

          // ── Upload button ─────────────────────────────────────
          GestureDetector(
            onTap: _savingUrl
                ? null
                : () async {
                    setState(() => _savingUrl = true);
                    await widget.onUploadImageFromDevice();
                    if (mounted) setState(() => _savingUrl = false);
                  },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: widget.gold.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: widget.gold.withOpacity(_savingUrl ? 0.2 : 0.45),
                    width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_savingUrl)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: widget.gold, strokeWidth: 2),
                    )
                  else
                    Icon(Icons.upload_rounded, color: widget.gold, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    _savingUrl ? 'Uploading…' : 'Pick image from device',
                    style: TextStyle(
                      color: _savingUrl
                          ? widget.white.withOpacity(0.35)
                          : widget.gold,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Count ────────────────────────────────────────────
          Text(
            '${paths.length} image(s) stored',
            style:
                TextStyle(color: widget.white.withOpacity(0.4), fontSize: 11),
          ),
          const SizedBox(height: 10),

          // ── Image list ────────────────────────────────────────
          if (paths.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No images added yet',
                  style: TextStyle(
                      color: widget.white.withOpacity(0.2), fontSize: 12),
                ),
              ),
            )
          else
            ...paths.asMap().entries.map((e) {
              final path = e.value;
              final idx = e.key;
              final bytes = imageMap[path]!;
              // Extract filename for display
              final filename = path.split('/').last;
              return Container(
                height: 64,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: widget.navyLight.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: widget.gold.withOpacity(0.15), width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Thumbnail (Image.memory — no network) ──
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(11)),
                      child: SizedBox(
                        width: 80,
                        child: Image.memory(
                          bytes,
                          key: ValueKey(path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: widget.navyLight,
                            child: Icon(Icons.image_outlined,
                                color: widget.white.withOpacity(0.25),
                                size: 22),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // ── Label ──────────────────────────────────
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Image ${idx + 1}',
                          style: TextStyle(
                              color: widget.white.withOpacity(0.7),
                              fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    // ── Delete button ──────────────────────────
                    GestureDetector(
                      onTap: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: widget.navyLight,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            title: Text('Delete Image',
                                style: TextStyle(
                                    color: widget.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                            content: Text(
                              'Remove "Image ${idx + 1}" from the display cycle?',
                              style: TextStyle(
                                  color: widget.white.withOpacity(0.55),
                                  fontSize: 13),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: Text('Cancel',
                                    style: TextStyle(
                                        color: widget.white.withOpacity(0.4))),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Delete',
                                    style: TextStyle(
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await widget.onDeleteImage(path);
                        }
                      },
                      child: Container(
                        width: 52,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(11)),
                        ),
                        child: Center(
                          child: Icon(Icons.delete_outline_rounded,
                              color: Colors.red.shade400, size: 22),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── JAMAAT TIMES TAB ────────────────────────────────────────────
  Widget _buildJamaatTab() {
    final prayers = [
      {'key': 'fajrJ', 'label': 'Fajr', 'arabic': 'الفجر'},
      {'key': 'dhuhrJ', 'label': 'Dhuhr / Jumu\'ah', 'arabic': 'الظهر'},
      {'key': 'asrJ', 'label': 'Asr', 'arabic': 'العصر'},
      {'key': 'maghrib', 'label': 'Maghrib', 'arabic': 'المغرب'},
      {'key': 'ishaJ', 'label': 'Isha', 'arabic': 'العشاء'},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel("JAMĀ'AH TIMES", Icons.schedule),
          const SizedBox(height: 6),
          Text(
            'Set new Jamā\'ah times. Choose an end date — all days from today to that date will be updated.',
            style: TextStyle(
                color: widget.white.withOpacity(0.35),
                fontSize: 11,
                height: 1.5),
          ),
          const SizedBox(height: 16),

          ...prayers.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p['label']!,
                              style: TextStyle(
                                  color: widget.white.withOpacity(0.85),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          Text(p['arabic']!,
                              style: TextStyle(
                                  color: widget.gold.withOpacity(0.5),
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _jamaatCtrls[p['key']],
                        style: TextStyle(
                            color: widget.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 1,
                            fontFeatures: const [FontFeature.tabularFigures()]),
                        keyboardType: TextInputType.datetime,
                        decoration: InputDecoration(
                          hintText: 'HH:MM',
                          hintStyle: TextStyle(
                              color: widget.white.withOpacity(0.2),
                              fontSize: 13),
                          filled: true,
                          fillColor: widget.navyLight,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                                color: widget.gold.withOpacity(0.2), width: 1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                                color: widget.gold.withOpacity(0.2), width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                BorderSide(color: widget.gold, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )),

          const SizedBox(height: 4),
          Divider(color: widget.white.withOpacity(0.08)),
          const SizedBox(height: 10),

          // End date picker
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _endDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 90)),
                builder: (ctx, child) => Theme(
                  data: ThemeData.dark().copyWith(
                    colorScheme: ColorScheme.dark(
                      primary: widget.gold,
                      surface: widget.navyMid,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => _endDate = picked);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: widget.navyLight,
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: widget.gold.withOpacity(0.25), width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today,
                      color: widget.gold.withOpacity(0.7), size: 16),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Apply until',
                          style: TextStyle(
                              color: widget.white.withOpacity(0.4),
                              fontSize: 10,
                              letterSpacing: 0.5)),
                      Text(
                        DateFormat('EEEE, d MMMM yyyy').format(_endDate),
                        style: TextStyle(
                            color: widget.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right,
                      color: widget.white.withOpacity(0.3), size: 16),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),
          Text(
            'This will update ${_endDate.difference(DateTime.now()).inDays + 1} day(s)',
            style: TextStyle(color: widget.gold.withOpacity(0.5), fontSize: 11),
          ),

          const SizedBox(height: 16),

          if (_jamaatSaveMsg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(_jamaatSaveMsg,
                  style: TextStyle(color: widget.mintGreen, fontSize: 12)),
            ),

          GestureDetector(
            onTap: _savingJamaat ? null : _saveJamaatTimes,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.gold.withOpacity(_savingJamaat ? 0.3 : 1),
                    widget.gold.withOpacity(_savingJamaat ? 0.2 : 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: _savingJamaat
                    ? []
                    : [
                        BoxShadow(
                            color: widget.gold.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 3)),
                      ],
              ),
              child: _savingJamaat
                  ? Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: widget.navy, strokeWidth: 2),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save, color: widget.navy, size: 16),
                        const SizedBox(width: 8),
                        Text('Save & Apply',
                            style: TextStyle(
                                color: widget.navy,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveJamaatTimes() async {
    setState(() {
      _savingJamaat = true;
      _jamaatSaveMsg = '';
    });
    final times = <String, String>{};
    for (final entry in _jamaatCtrls.entries) {
      final raw = entry.value.text.trim();
      if (raw.isEmpty) continue;
      // Normalise and validate: accept H:MM or HH:MM, reject anything else
      final parts = raw.split(':');
      if (parts.length != 2) {
        setState(() {
          _savingJamaat = false;
          _jamaatSaveMsg =
              'Invalid time "$raw" — use HH:MM format (e.g. 05:45).';
        });
        return;
      }
      final hPart = parts[0].trim();
      final mPart = parts[1].trim();
      final h = int.tryParse(hPart);
      final m = int.tryParse(mPart);
      if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
        setState(() {
          _savingJamaat = false;
          _jamaatSaveMsg =
              'Invalid time "$raw" — use HH:MM format (e.g. 05:45).';
        });
        return;
      }
      // Normalise to zero-padded HH:MM
      times[entry.key] =
          '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }
    if (times.isEmpty) {
      setState(() {
        _savingJamaat = false;
        _jamaatSaveMsg = 'No times entered.';
      });
      return;
    }
    try {
      await widget.onBatchWriteJamaat(
        mosqueId: widget.mosqueId,
        updatedJamaatTimes: times,
        endDate: _endDate,
      );
      setState(() {
        _savingJamaat = false;
        _jamaatSaveMsg =
            '✓ Saved for ${_endDate.difference(DateTime.now()).inDays + 1} day(s)';
      });
      // Reload the page after a short delay so the user sees the confirmation
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: Duration.zero,
            pageBuilder: (_, __, ___) => const MosqueDisplayScreen(),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _savingJamaat = false;
        _jamaatSaveMsg = 'Error: $e';
      });
    }
  }

  // ── SETTINGS TAB ────────────────────────────────────────────────
  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('DISPLAY SETTINGS', Icons.settings),
          const SizedBox(height: 16),

          // Rotate orientation
          _settingsTile(
            icon: widget.isLandscape
                ? Icons.stay_current_portrait
                : Icons.stay_current_landscape,
            label: widget.isLandscape
                ? 'Switch to Portrait'
                : 'Switch to Landscape',
            sub: widget.isLandscape
                ? 'Currently: Landscape'
                : 'Currently: Portrait',
            color: widget.skyBlue,
            onTap: widget.onToggleOrientation,
          ),

          const SizedBox(height: 12),

          // Custom ticker message
          _sectionLabel('TICKER MESSAGE', Icons.edit_note),
          const SizedBox(height: 8),
          Text(
            'Add a custom announcement shown in the ticker right after the mosque name.',
            style: TextStyle(
                color: widget.white.withOpacity(0.35),
                fontSize: 11,
                height: 1.5),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _tickerMsgCtrl,
            style: TextStyle(
                color: widget.white, fontSize: 14, fontWeight: FontWeight.w400),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'e.g. Sisters class after Asr today',
              hintStyle:
                  TextStyle(color: widget.white.withOpacity(0.2), fontSize: 12),
              filled: true,
              fillColor: widget.navyLight,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: const Color(0xFF00E5CC).withOpacity(0.3), width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: const Color(0xFF00E5CC).withOpacity(0.3), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: Color(0xFF00E5CC), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    widget.onUpdateTickerMessage(_tickerMsgCtrl.text.trim());
                    FocusScope.of(context).unfocus();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5CC).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF00E5CC).withOpacity(0.5),
                          width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check,
                            color: Color(0xFF00E5CC), size: 16),
                        const SizedBox(width: 6),
                        Text('Apply',
                            style: TextStyle(
                                color: const Color(0xFF00E5CC),
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  _tickerMsgCtrl.clear();
                  widget.onUpdateTickerMessage('');
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: widget.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: widget.white.withOpacity(0.12), width: 1),
                  ),
                  child: Text('Clear',
                      style: TextStyle(
                          color: widget.white.withOpacity(0.4),
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          Divider(color: widget.white.withOpacity(0.07)),
          const SizedBox(height: 8),

          _sectionLabel('ACCOUNT', Icons.person_outline),
          const SizedBox(height: 10),
          _settingsTile(
            icon: Icons.logout,
            label: 'Log Out',
            sub: widget.email,
            color: Colors.red.shade400,
            onTap: () {
              widget.onCloseDrawer();
              widget.onLogOut();
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, IconData icon) => Row(
        children: [
          Icon(icon, color: widget.gold.withOpacity(0.7), size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: widget.gold.withOpacity(0.7),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ],
      );

  Widget _settingsTile({
    required IconData icon,
    required String label,
    required String sub,
    required Color color,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2), width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            color: widget.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Text(sub,
                        style: TextStyle(
                            color: widget.white.withOpacity(0.35),
                            fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: widget.white.withOpacity(0.25), size: 16),
            ],
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════
// STAR FIELD  — static decorative background stars
// ══════════════════════════════════════════════════════════════════
class _StarField extends StatelessWidget {
  const _StarField({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _StarPainter());
  }
}

class _StarPainter extends CustomPainter {
  // Fixed pseudo-random star positions (deterministic)
  static final List<Offset> _stars = List.generate(80, (i) {
    final x = ((i * 137.508 + 23) % 100) / 100;
    final y = ((i * 97.312 + 11) % 100) / 100;
    return Offset(x, y);
  });
  static final List<double> _sizes = List.generate(80, (i) {
    return 0.5 + ((i * 31.7) % 10) / 10 * 1.5;
  });
  static final List<double> _opacities = List.generate(80, (i) {
    return 0.2 + ((i * 17.3) % 10) / 10 * 0.5;
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < _stars.length; i++) {
      final paint = Paint()
        ..color = Colors.white.withOpacity(_opacities[i])
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(_stars[i].dx * size.width, _stars[i].dy * size.height),
        _sizes[i],
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ══════════════════════════════════════════════════════════════════
// MOSQUE SILHOUETTE  — decorative bottom-of-screen silhouette
// ══════════════════════════════════════════════════════════════════
class _MosqueSilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.045)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    final path = Path();
    path.moveTo(0, h);
    path.lineTo(0, h * 0.75);
    path.lineTo(w * 0.03, h * 0.75);
    path.lineTo(w * 0.03, h * 0.65);
    path.lineTo(w * 0.06, h * 0.65);
    path.lineTo(w * 0.06, h * 0.75);
    path.lineTo(w * 0.10, h * 0.75);
    path.lineTo(w * 0.10, h * 0.60);
    path.lineTo(w * 0.13, h * 0.60);
    path.lineTo(w * 0.13, h * 0.75);
    // Left minaret
    path.lineTo(w * 0.17, h * 0.75);
    path.lineTo(w * 0.17, h * 0.20);
    path.quadraticBezierTo(w * 0.19, h * 0.05, w * 0.21, h * 0.20);
    path.lineTo(w * 0.21, h * 0.75);
    // Left wing dome
    path.lineTo(w * 0.25, h * 0.75);
    path.lineTo(w * 0.25, h * 0.55);
    path.quadraticBezierTo(w * 0.30, h * 0.38, w * 0.35, h * 0.55);
    path.lineTo(w * 0.35, h * 0.75);
    // Central large dome
    path.lineTo(w * 0.38, h * 0.75);
    path.lineTo(w * 0.38, h * 0.45);
    path.quadraticBezierTo(w * 0.50, h * -0.12, w * 0.62, h * 0.45);
    path.lineTo(w * 0.62, h * 0.75);
    // Right wing dome
    path.lineTo(w * 0.65, h * 0.75);
    path.lineTo(w * 0.65, h * 0.55);
    path.quadraticBezierTo(w * 0.70, h * 0.38, w * 0.75, h * 0.55);
    path.lineTo(w * 0.75, h * 0.75);
    // Right minaret
    path.lineTo(w * 0.79, h * 0.75);
    path.lineTo(w * 0.79, h * 0.20);
    path.quadraticBezierTo(w * 0.81, h * 0.05, w * 0.83, h * 0.20);
    path.lineTo(w * 0.83, h * 0.75);
    path.lineTo(w * 0.87, h * 0.75);
    path.lineTo(w * 0.87, h * 0.60);
    path.lineTo(w * 0.90, h * 0.60);
    path.lineTo(w * 0.90, h * 0.75);
    path.lineTo(w * 0.94, h * 0.75);
    path.lineTo(w * 0.94, h * 0.65);
    path.lineTo(w * 0.97, h * 0.65);
    path.lineTo(w * 0.97, h * 0.75);
    path.lineTo(w, h * 0.75);
    path.lineTo(w, h);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ══════════════════════════════════════════════════════════════════
// DATA MODELS
// ══════════════════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════════
// BOTTOM STRIP CELL MODEL
// ══════════════════════════════════════════════════════════════════
class _BottomCell {
  final String label;
  final String time;
  final Color color;
  const _BottomCell(
      {required this.label, required this.time, required this.color});
}

class _InfoChip {
  final String label;
  final String time;
  final Color color;
  const _InfoChip(
      {required this.label, required this.time, required this.color});
}

class PrayerTime {
  final String name;
  final String time;
  final String jamaatTime;
  PrayerTime(this.name, this.time, this.jamaatTime);
}
