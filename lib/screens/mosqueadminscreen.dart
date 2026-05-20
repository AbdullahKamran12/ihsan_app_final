import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

// Import the real DisplaySettings so enums are shared — no duplication.
import 'package:ihsan_app_final/screens/display_settings.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MosqueAdminScreen
// Mobile screen that gives mosque admins remote control of the TV display.
//
//   Access gate: only shown when displayAccounts/{uid}.status == 'approved'.
//
//   IMAGES tab   — upload / delete display images for the TV slideshow
//   JAMĀ'AH tab  — batch-update jamaat times for a date range
//   DISPLAY tab  — all DisplaySettings (mirrors the TV drawer) + background
//                  image upload straight from this phone
//   SETTINGS tab — ticker message, donation link, change mosque, log out
//
// Every write merges into displayMosques/{uid} and sets needsRefresh: true.
// The TV display screen picks this up via its Firestore stream and reloads.
// ─────────────────────────────────────────────────────────────────────────────

// ── Palette (matches mosqueDisplayScreen) ─────────────────────────────────────
const _navy = Color.fromARGB(255, 8, 20, 52);
const _navyMid = Color.fromARGB(255, 15, 36, 85);
const _navyLight = Color.fromARGB(255, 24, 52, 110);
const _gold = Color.fromARGB(255, 212, 175, 95);
const _mintGreen = Color.fromARGB(255, 72, 200, 155);
const _skyBlue = Color.fromARGB(255, 100, 180, 240);
const _white = Colors.white;
const _teal = Color(0xFF00E5CC);

// ── Firestore field names — MUST match DisplaySettings constants ───────────────
// (copied from display_settings.dart to avoid needing to import private consts)
const _fBgStyle = 'setting_bgStyle';
const _fTemp = 'setting_colourTemp';
const _fPattern = 'setting_bgPattern';
const _fTicker = 'setting_showTicker';
const _fJumuah = 'setting_jumuahEnabled';
const _fBlackout = 'setting_blackoutDuration';
// Background image: stored as the Storage path in displayMosques/{uid}
const _fBgImagePath = 'setting_bgImagePath';

// ─────────────────────────────────────────────────────────────────────────────

class MosqueAdminScreen extends StatefulWidget {
  const MosqueAdminScreen({super.key});

  @override
  State<MosqueAdminScreen> createState() => _MosqueAdminScreenState();
}

class _MosqueAdminScreenState extends State<MosqueAdminScreen>
    with SingleTickerProviderStateMixin {
  // ── Tab controller ────────────────────────────────────────────────
  late TabController _tab;

  // ── Auth / mosque binding ─────────────────────────────────────────
  User? _user;
  String _firstName = '';
  String _email = '';
  String _mosqueId = '';
  String _mosqueName = '';
  bool _loading = true;
  String? _error;

  // ── Account status ────────────────────────────────────────────────
  String _accountStatus = ''; // 'pending' | 'approved' | 'rejected'

  // ── Slideshow images ──────────────────────────────────────────────
  Map<String, Uint8List> _imageMap = {};
  bool _loadingImages = false;
  bool _uploadingImage = false;

  // ── Jamaat editor ─────────────────────────────────────────────────
  final Map<String, TextEditingController> _jamaatCtrls = {
    'fajrJ': TextEditingController(),
    'dhuhrJ': TextEditingController(),
    'asrJ': TextEditingController(),
    'maghrib': TextEditingController(),
    'ishaJ': TextEditingController(),
  };
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 6));
  bool _savingJamaat = false;
  String _jamaatSaveMsg = '';

  // ── Display settings (loaded from Firestore, saved back on Apply) ─
  // Uses .index for Firestore (same as DisplaySettings.toFirestore())
  BackgroundStyle _backgroundStyle = BackgroundStyle.navy;
  ColourTemperature _colourTemperature = ColourTemperature.neutral;
  BackgroundPattern _backgroundPattern = BackgroundPattern.none;
  bool _showTicker = true;
  bool _jumuahEnabled = true;
  BlackoutDuration _blackoutDuration = BlackoutDuration.seven;

  // ── Background image ──────────────────────────────────────────────
  // Current bg image shown as preview; null = none set / not loaded yet
  Uint8List? _bgImageBytes;
  String _bgImageStoragePath = ''; // e.g. displayMosques/{uid}/bg/bg.jpg
  bool _uploadingBg = false;
  bool _clearingBg = false;
  bool _savingDisplay = false;
  String _displaySaveMsg = '';

  // ── Ticker / Donation ─────────────────────────────────────────────
  late TextEditingController _tickerCtrl;
  late TextEditingController _donationCtrl;
  bool _savingTicker = false;
  String _tickerSaveMsg = '';
  bool _savingDonation = false;
  String _donationSaveMsg = '';

  // ── Change mosque ─────────────────────────────────────────────────
  List<Map<String, dynamic>> _allMosques = [];
  List<Map<String, dynamic>> _filteredMosques = [];
  final TextEditingController _searchCtrl = TextEditingController();
  bool _changingMosque = false;

  // ─────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _tickerCtrl = TextEditingController();
    _donationCtrl = TextEditingController();
    _user = FirebaseAuth.instance.currentUser;
    _loadBinding();
  }

  @override
  void dispose() {
    _tab.dispose();
    for (final c in _jamaatCtrls.values) c.dispose();
    _tickerCtrl.dispose();
    _donationCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════
  // LOAD BINDING
  // ══════════════════════════════════════════════════════════════════
  Future<void> _loadBinding() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = _user?.uid;
      if (uid == null) throw Exception('Not logged in');

      // 1. User display name
      final userDoc = await FirebaseFirestore.instance
          .collection('UserData')
          .doc(uid)
          .get();
      final displayName =
          (userDoc.data()?['displayName'] as String?) ?? _user?.email ?? '';
      _firstName = displayName.split(' ').first;
      _email = _user?.email ?? '';

      // 2. Approval status
      final accountDoc = await FirebaseFirestore.instance
          .collection('displayAccounts')
          .doc(uid)
          .get();
      final status = (accountDoc.data()?['status'] as String?) ?? 'pending';

      if (status != 'approved') {
        setState(() {
          _accountStatus = status;
          _loading = false;
        });
        return;
      }
      _accountStatus = 'approved';

      // 3. Mosque binding + settings
      final bindingDoc = await FirebaseFirestore.instance
          .collection('displayMosques')
          .doc(uid)
          .get();

      if (!bindingDoc.exists ||
          ((bindingDoc.data()?['mosqueId'] as String?) ?? '').isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No mosque linked to this account.\n'
              'Please ask the administrator to assign your mosque.';
        });
        return;
      }

      final data = bindingDoc.data()!;
      _mosqueId = (data['mosqueId'] as String?) ?? '';
      _mosqueName = (data['mosqueName'] as String?) ?? '';
      _tickerCtrl.text = (data['customTickerMessage'] as String?) ?? '';
      _donationCtrl.text = (data['donationLink'] as String?) ?? '';

      _loadDisplaySettingsFromMap(data);

      // 4. Load bg image preview if one was previously set
      final storedBgPath = (data[_fBgImagePath] as String?) ?? '';
      if (storedBgPath.isNotEmpty) {
        _bgImageStoragePath = storedBgPath;
        _bgImageBytes = await _fetchBytesFromStorage(storedBgPath);
      }

      await _fetchSlideshowImages();
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  // ── Parse DisplaySettings from Firestore doc ──────────────────────
  // DisplaySettings stores each enum as its .index (int).
  void _loadDisplaySettingsFromMap(Map<String, dynamic> data) {
    T safe<T>(List<T> vals, String key, T def) {
      final i = data[key];
      if (i is! int || i < 0 || i >= vals.length) return def;
      return vals[i];
    }

    _backgroundStyle =
        safe(BackgroundStyle.values, _fBgStyle, BackgroundStyle.navy);
    _colourTemperature =
        safe(ColourTemperature.values, _fTemp, ColourTemperature.neutral);
    _backgroundPattern =
        safe(BackgroundPattern.values, _fPattern, BackgroundPattern.none);
    _showTicker = (data[_fTicker] as bool?) ?? true;
    _jumuahEnabled = (data[_fJumuah] as bool?) ?? true;
    _blackoutDuration =
        safe(BlackoutDuration.values, _fBlackout, BlackoutDuration.seven);
  }

  // ══════════════════════════════════════════════════════════════════
  // SHARED HELPERS
  // ══════════════════════════════════════════════════════════════════
  Future<void> _signalRefresh() async {
    final uid = _user?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('displayMosques')
        .doc(uid)
        .set({'needsRefresh': true}, SetOptions(merge: true));
  }

  Future<void> _mergeToFirestore(Map<String, dynamic> data) async {
    final uid = _user?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('displayMosques')
        .doc(uid)
        .set({...data, 'needsRefresh': true}, SetOptions(merge: true));
  }

  Future<Uint8List?> _fetchBytesFromStorage(String path) async {
    try {
      return await FirebaseStorage.instance.ref(path).getData();
    } catch (e) {
      debugPrint('fetchBytesFromStorage error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // SLIDESHOW IMAGES (cycle displayed on TV)
  // ══════════════════════════════════════════════════════════════════
  Future<void> _fetchSlideshowImages() async {
    if (_mosqueId.isEmpty) return;
    setState(() => _loadingImages = true);
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('displayMosques/$_mosqueId/images');
      final result = await ref.listAll();
      final entries = await Future.wait(result.items.map((item) async {
        final bytes = await item.getData();
        return MapEntry(item.fullPath, bytes);
      }));
      final newMap = <String, Uint8List>{};
      for (final e in entries) {
        if (e.value != null) newMap[e.key] = e.value!;
      }
      if (mounted) setState(() => _imageMap = newMap);
    } catch (e) {
      debugPrint('fetchSlideshowImages error: $e');
    } finally {
      if (mounted) setState(() => _loadingImages = false);
    }
  }

  Future<void> _uploadSlideshowImage() async {
    if (_mosqueId.isEmpty) return;
    setState(() => _uploadingImage = true);
    try {
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) {
        setState(() => _uploadingImage = false);
        return;
      }
      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.')
          ? picked.name.split('.').last.toLowerCase()
          : 'jpg';

      if (!mounted) return;
      final confirmed = await _showConfirmImageDialog(bytes, picked.name);
      if (confirmed != true) {
        setState(() => _uploadingImage = false);
        return;
      }

      final filename = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storagePath = 'displayMosques/$_mosqueId/images/$filename';
      await FirebaseStorage.instance
          .ref(storagePath)
          .putData(bytes, SettableMetadata(contentType: 'image/$ext'));
      await _signalRefresh();
      await _fetchSlideshowImages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red.shade700));
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _deleteSlideshowImage(String storagePath) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _confirmDialog(
        ctx,
        title: 'Delete Image',
        body: 'Remove this image from the display cycle?',
        confirmLabel: 'Delete',
        confirmColor: Colors.redAccent,
      ),
    );
    if (ok != true) return;
    setState(() => _imageMap.remove(storagePath));
    try {
      await FirebaseStorage.instance.ref(storagePath).delete();
      await _signalRefresh();
    } catch (e) {
      debugPrint('Delete slideshow image error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // BACKGROUND IMAGE (full-screen TV backdrop, set from this phone)
  // ══════════════════════════════════════════════════════════════════
  Future<void> _pickBackgroundImage() async {
    setState(() => _uploadingBg = true);
    try {
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (picked == null) {
        setState(() => _uploadingBg = false);
        return;
      }
      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.')
          ? picked.name.split('.').last.toLowerCase()
          : 'jpg';

      if (!mounted) return;
      final confirmed = await _showConfirmImageDialog(bytes, picked.name,
          confirmLabel: 'Set as TV Background');
      if (confirmed != true) {
        setState(() => _uploadingBg = false);
        return;
      }

      final uid = _user?.uid;
      if (uid == null) return;

      // Delete old bg image if one exists
      if (_bgImageStoragePath.isNotEmpty) {
        try {
          await FirebaseStorage.instance.ref(_bgImageStoragePath).delete();
        } catch (_) {}
      }

      final storagePath = 'displayMosques/$uid/bg/bg.$ext';
      await FirebaseStorage.instance
          .ref(storagePath)
          .putData(bytes, SettableMetadata(contentType: 'image/$ext'));

      // Write path + set pattern to customImage so the TV uses it
      await _mergeToFirestore({
        _fBgImagePath: storagePath,
        _fPattern: BackgroundPattern.customImage.index,
      });

      setState(() {
        _bgImageBytes = bytes;
        _bgImageStoragePath = storagePath;
        _backgroundPattern = BackgroundPattern.customImage;
        _displaySaveMsg = '✓ Background image applied to TV';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red.shade700));
      }
    } finally {
      if (mounted) setState(() => _uploadingBg = false);
    }
  }

  Future<void> _clearBackgroundImage() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _confirmDialog(
        ctx,
        title: 'Remove Background Image',
        body: 'The TV will revert to the selected background pattern/style.',
        confirmLabel: 'Remove',
        confirmColor: Colors.redAccent,
      ),
    );
    if (ok != true) return;
    setState(() => _clearingBg = true);
    try {
      if (_bgImageStoragePath.isNotEmpty) {
        try {
          await FirebaseStorage.instance.ref(_bgImageStoragePath).delete();
        } catch (_) {}
      }
      await _mergeToFirestore({
        _fBgImagePath: '',
        _fPattern: BackgroundPattern.none.index,
      });
      setState(() {
        _bgImageBytes = null;
        _bgImageStoragePath = '';
        _backgroundPattern = BackgroundPattern.none;
        _displaySaveMsg = '✓ Background image removed';
      });
    } finally {
      if (mounted) setState(() => _clearingBg = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // JAMAAT BATCH WRITE
  // ══════════════════════════════════════════════════════════════════
  Future<void> _saveJamaatTimes() async {
    setState(() {
      _savingJamaat = true;
      _jamaatSaveMsg = '';
    });

    final times = <String, String>{};
    for (final entry in _jamaatCtrls.entries) {
      final raw = entry.value.text.trim();
      if (raw.isEmpty) continue;
      final parts = raw.split(':');
      if (parts.length != 2) {
        setState(() {
          _savingJamaat = false;
          _jamaatSaveMsg = 'Invalid time "$raw" — use HH:MM.';
        });
        return;
      }
      final h = int.tryParse(parts[0].trim());
      final m = int.tryParse(parts[1].trim());
      if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
        setState(() {
          _savingJamaat = false;
          _jamaatSaveMsg = 'Invalid time "$raw" — use HH:MM.';
        });
        return;
      }
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
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      var cursor = DateTime(_startDate.year, _startDate.month, _startDate.day);
      while (!cursor.isAfter(_endDate)) {
        final dateStr = cursor.toIso8601String().substring(0, 10);
        batch.set(
          db
              .collection('mosques')
              .doc(_mosqueId)
              .collection('prayerTimes')
              .doc(dateStr),
          times,
          SetOptions(merge: true),
        );
        cursor = cursor.add(const Duration(days: 1));
      }
      await batch.commit();
      await _signalRefresh();
      setState(() {
        _savingJamaat = false;
        _jamaatSaveMsg = '✓ Saved '
            '${DateFormat('d MMM').format(_startDate)} – '
            '${DateFormat('d MMM yyyy').format(_endDate)} (both included)';
      });
    } catch (e) {
      setState(() {
        _savingJamaat = false;
        _jamaatSaveMsg = 'Error: $e';
      });
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // DISPLAY SETTINGS SAVE
  // Writes the same integer-indexed fields that DisplaySettings.toFirestore()
  // produces, so the TV's DisplaySettings.fromFirestore() reads them correctly.
  // ══════════════════════════════════════════════════════════════════
  Future<void> _saveDisplaySettings() async {
    setState(() {
      _savingDisplay = true;
      _displaySaveMsg = '';
    });
    try {
      final Map<String, dynamic> payload = {
        _fBgStyle: _backgroundStyle.index,
        _fTemp: _colourTemperature.index,
        _fTicker: _showTicker,
        _fJumuah: _jumuahEnabled,
        _fBlackout: _blackoutDuration.index,
      };

      // Pattern: if the user has a bg image, keep customImage selected;
      // otherwise write whatever chip they picked.
      if (_bgImageBytes != null) {
        payload[_fPattern] = BackgroundPattern.customImage.index;
      } else {
        payload[_fPattern] = _backgroundPattern.index;
        // Clear any stale path if the user explicitly chose a non-image pattern
        payload[_fBgImagePath] = '';
      }

      await _mergeToFirestore(payload);
      setState(() => _displaySaveMsg = '✓ Display settings applied to TV');
    } catch (e) {
      setState(() => _displaySaveMsg = 'Error: $e');
    } finally {
      setState(() => _savingDisplay = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // TICKER MESSAGE
  // ══════════════════════════════════════════════════════════════════
  Future<void> _saveTicker() async {
    setState(() {
      _savingTicker = true;
      _tickerSaveMsg = '';
    });
    try {
      await _mergeToFirestore({'customTickerMessage': _tickerCtrl.text.trim()});
      setState(() => _tickerSaveMsg = '✓ Ticker updated');
    } catch (e) {
      setState(() => _tickerSaveMsg = 'Error: $e');
    } finally {
      setState(() => _savingTicker = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // DONATION LINK
  // ══════════════════════════════════════════════════════════════════
  Future<void> _saveDonation() async {
    setState(() {
      _savingDonation = true;
      _donationSaveMsg = '';
    });
    try {
      await _mergeToFirestore({'donationLink': _donationCtrl.text.trim()});
      setState(() => _donationSaveMsg = '✓ Donation link updated');
    } catch (e) {
      setState(() => _donationSaveMsg = 'Error: $e');
    } finally {
      setState(() => _savingDonation = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // CHANGE MOSQUE
  // ══════════════════════════════════════════════════════════════════
  Future<void> _loadAllMosques() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('mosques').get();
      _allMosques = snap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .cast<Map<String, dynamic>>()
          .toList();
      _filteredMosques = List.from(_allMosques);
    } catch (e) {
      debugPrint('loadAllMosques error: $e');
    }
  }

  void _filterMosques(String q) {
    final ql = q.toLowerCase();
    setState(() {
      _filteredMosques = ql.isEmpty
          ? List.from(_allMosques)
          : _allMosques
              .where((m) =>
                  (m['name'] as String? ?? '').toLowerCase().contains(ql) ||
                  (m['city'] as String? ?? '').toLowerCase().contains(ql))
              .toList();
    });
  }

  Future<void> _bindMosque(Map<String, dynamic> mosque) async {
    final uid = _user?.uid;
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
        'needsRefresh': true,
      }, SetOptions(merge: true));
      setState(() {
        _mosqueId = mosque['id'] as String;
        _mosqueName = (mosque['name'] as String?) ?? '';
        _changingMosque = false;
      });
      await _fetchSlideshowImages();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Mosque updated'), backgroundColor: Colors.green));
    } catch (e) {
      debugPrint('bindMosque error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
          backgroundColor: _navy,
          appBar: _simpleAppBar('Mosque Admin'),
          body: const Center(
              child: CircularProgressIndicator(color: _gold, strokeWidth: 2)));
    }
    if (_accountStatus == 'pending') {
      return _buildStatusScreen(
        icon: Icons.hourglass_top_rounded,
        iconColor: _gold,
        title: 'Awaiting Approval',
        body: 'Your display screen account is waiting for admin approval.\n\n'
            'You will be able to manage your mosque\'s TV display once approved.',
      );
    }
    if (_accountStatus == 'rejected') {
      return _buildStatusScreen(
        icon: Icons.cancel_outlined,
        iconColor: Colors.redAccent,
        title: 'Account Not Approved',
        body: 'Your display screen account was not approved.\n\n'
            'Please contact the administrator if you believe this is a mistake.',
      );
    }
    if (_error != null) {
      return Scaffold(
          backgroundColor: _navy,
          appBar: _simpleAppBar('Mosque Admin'),
          body: Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!,
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 14),
                      textAlign: TextAlign.center))));
    }
    if (_changingMosque) return _buildChangeMosqueScreen();

    return Scaffold(
      backgroundColor: _navy,
      appBar: AppBar(
        backgroundColor: _navyMid,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Mosque Admin',
              style: TextStyle(
                  color: _white, fontSize: 16, fontWeight: FontWeight.w700)),
          Text(_mosqueName,
              style: TextStyle(
                  color: _gold.withOpacity(0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
        bottom: TabBar(
          controller: _tab,
          labelColor: _gold,
          unselectedLabelColor: Colors.white38,
          indicatorColor: _gold,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          tabs: const [
            Tab(text: 'IMAGES'),
            Tab(text: "JAMĀ'AH"),
            Tab(text: 'DISPLAY'),
            Tab(text: 'SETTINGS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildImagesTab(),
          _buildJamaatTab(),
          _buildDisplayTab(),
          _buildSettingsTab(),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // STATUS SCREENS
  // ══════════════════════════════════════════════════════════════════
  Widget _buildStatusScreen({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
  }) =>
      Scaffold(
        backgroundColor: _navy,
        appBar: _simpleAppBar('Mosque Admin'),
        body: Center(
            child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: iconColor, size: 56),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                    color: _white, fontSize: 18, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
            const SizedBox(height: 14),
            Text(body,
                style: TextStyle(
                    color: _white.withOpacity(0.5), fontSize: 13, height: 1.6),
                textAlign: TextAlign.center),
          ]),
        )),
      );

  AppBar _simpleAppBar(String title) => AppBar(
        backgroundColor: _navyMid,
        elevation: 0,
        title: Text(title,
            style: const TextStyle(
                color: _white, fontSize: 16, fontWeight: FontWeight.w700)),
      );

  // ══════════════════════════════════════════════════════════════════
  // IMAGES TAB — slideshow images
  // ══════════════════════════════════════════════════════════════════
  Widget _buildImagesTab() => RefreshIndicator(
        color: _gold,
        backgroundColor: _navyMid,
        onRefresh: _fetchSlideshowImages,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionLabel('SLIDESHOW IMAGES', Icons.image_outlined),
            const SizedBox(height: 6),
            Text(
                'Images shown in the mosque TV display cycle. Pull to refresh.',
                style: TextStyle(
                    color: _white.withOpacity(0.35),
                    fontSize: 11,
                    height: 1.5)),
            const SizedBox(height: 16),
            _actionButton(
              label: _uploadingImage ? 'Uploading…' : 'Add image from phone',
              icon: Icons.upload_rounded,
              color: _gold,
              loading: _uploadingImage,
              onTap: _uploadingImage ? null : _uploadSlideshowImage,
            ),
            const SizedBox(height: 16),
            if (_loadingImages)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(
                          color: _gold, strokeWidth: 2)))
            else ...[
              Text('${_imageMap.length} image(s) stored',
                  style:
                      TextStyle(color: _white.withOpacity(0.4), fontSize: 11)),
              const SizedBox(height: 10),
              if (_imageMap.isEmpty)
                Center(
                    child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text('No images added yet',
                            style: TextStyle(
                                color: _white.withOpacity(0.2), fontSize: 12))))
              else
                ..._imageMap.entries.toList().asMap().entries.map((e) {
                  final idx = e.key;
                  final path = e.value.key;
                  final bytes = e.value.value;
                  return Container(
                    height: 64,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: _navyLight.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: _gold.withOpacity(0.15), width: 1),
                    ),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(11)),
                            child: SizedBox(
                                width: 80,
                                child: Image.memory(bytes,
                                    key: ValueKey(path),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                        color: _navyLight,
                                        child: Icon(Icons.image_outlined,
                                            color: _white.withOpacity(0.25),
                                            size: 22)))),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('Image ${idx + 1}',
                                      style: TextStyle(
                                          color: _white.withOpacity(0.7),
                                          fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis))),
                          GestureDetector(
                              onTap: () => _deleteSlideshowImage(path),
                              child: Container(
                                  width: 52,
                                  decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.08),
                                      borderRadius:
                                          const BorderRadius.horizontal(
                                              right: Radius.circular(11))),
                                  child: Center(
                                      child: Icon(Icons.delete_outline_rounded,
                                          color: Colors.red.shade400,
                                          size: 22)))),
                        ]),
                  );
                }),
            ],
          ]),
        ),
      );

  // ══════════════════════════════════════════════════════════════════
  // JAMAAT TAB
  // ══════════════════════════════════════════════════════════════════
  Widget _buildJamaatTab() {
    final prayers = [
      {'key': 'fajrJ', 'label': 'Fajr', 'arabic': 'الفجر'},
      {'key': 'dhuhrJ', 'label': "Dhuhr / Jumu'ah", 'arabic': 'الظهر'},
      {'key': 'asrJ', 'label': 'Asr', 'arabic': 'العصر'},
      {'key': 'maghrib', 'label': 'Maghrib', 'arabic': 'المغرب'},
      {'key': 'ishaJ', 'label': 'Isha', 'arabic': 'العشاء'},
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel("JAMĀ'AH TIMES", Icons.schedule),
        const SizedBox(height: 6),
        Text(
            "Set new Jamā'ah times. Choose a date range — all days will be updated (both dates included).",
            style: TextStyle(
                color: _white.withOpacity(0.35), fontSize: 11, height: 1.5)),
        const SizedBox(height: 16),
        ...prayers.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                SizedBox(
                    width: 100,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p['label']!,
                              style: TextStyle(
                                  color: _white.withOpacity(0.85),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          Text(p['arabic']!,
                              style: TextStyle(
                                  color: _gold.withOpacity(0.5), fontSize: 12)),
                        ])),
                const SizedBox(width: 10),
                Expanded(
                    child: TextField(
                  controller: _jamaatCtrls[p['key']],
                  style: const TextStyle(
                      color: _white,
                      fontSize: 16,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 1),
                  keyboardType: TextInputType.datetime,
                  decoration: _timeInputDecoration('HH:MM'),
                )),
              ]),
            )),
        const SizedBox(height: 4),
        Divider(color: _white.withOpacity(0.08)),
        const SizedBox(height: 10),
        _datePicker(
            label: 'Apply from',
            date: _startDate,
            onTap: () async {
              final p = await _showDatePickerDialog(_startDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 30)));
              if (p != null)
                setState(() {
                  _startDate = p;
                  if (_endDate.isBefore(_startDate)) _endDate = _startDate;
                });
            }),
        const SizedBox(height: 8),
        _datePicker(
            label: 'Apply until',
            date: _endDate,
            onTap: () async {
              final p =
                  await _showDatePickerDialog(_endDate, firstDate: _startDate);
              if (p != null) setState(() => _endDate = p);
            }),
        const SizedBox(height: 8),
        Text(
          '${_endDate.difference(_startDate).inDays + 1} day(s) — '
          '${DateFormat('d MMM').format(_startDate)} to '
          '${DateFormat('d MMM yyyy').format(_endDate)}, both included',
          style: TextStyle(color: _gold.withOpacity(0.5), fontSize: 11),
        ),
        const SizedBox(height: 16),
        if (_jamaatSaveMsg.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(_jamaatSaveMsg,
                  style: const TextStyle(color: _mintGreen, fontSize: 12))),
        _primaryButton(
            label: 'Save & Apply',
            icon: Icons.save,
            loading: _savingJamaat,
            onTap: _savingJamaat ? null : _saveJamaatTimes),
        const SizedBox(height: 40),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // DISPLAY TAB
  // ══════════════════════════════════════════════════════════════════
  Widget _buildDisplayTab() => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── TOGGLES ───────────────────────────────────────────────────
          _sectionLabel('DISPLAY OPTIONS', Icons.tv_outlined),
          const SizedBox(height: 12),
          _toggleTile(
            label: 'Scrolling Ticker',
            icon: Icons.text_fields,
            color: _gold,
            sub: 'Show mosque name and announcement at the bottom',
            value: _showTicker,
            onChanged: (v) => setState(() => _showTicker = v),
          ),
          const SizedBox(height: 8),
          _toggleTile(
            label: "Jumu'ah Display",
            icon: Icons.mosque_outlined,
            color: _mintGreen,
            sub:
                "Enable the Jumu'ah adhan, khutbah overlay and iqamah sequence on Fridays",
            value: _jumuahEnabled,
            onChanged: (v) => setState(() => _jumuahEnabled = v),
          ),

          _divider(),

          // ── BLACKOUT DURATION ─────────────────────────────────────────
          _sectionLabel("BLACKOUT AFTER JAMĀ'AH", Icons.nightlight_outlined),
          const SizedBox(height: 6),
          Text('How long the screen goes dark after each prayer congregation.',
              style: TextStyle(
                  color: _white.withOpacity(0.35), fontSize: 11, height: 1.5)),
          const SizedBox(height: 10),
          _chipRow<BlackoutDuration>(
            values: BlackoutDuration.values,
            selected: _blackoutDuration,
            label: (v) => v.label,
            onTap: (v) => setState(() => _blackoutDuration = v),
          ),

          _divider(),

          // ── BACKGROUND STYLE ──────────────────────────────────────────
          _sectionLabel('BACKGROUND STYLE', Icons.gradient_outlined),
          const SizedBox(height: 6),
          Text('Overall background tone of the display screen.',
              style: TextStyle(
                  color: _white.withOpacity(0.35), fontSize: 11, height: 1.5)),
          const SizedBox(height: 10),
          _chipRow<BackgroundStyle>(
            values: BackgroundStyle.values,
            selected: _backgroundStyle,
            label: (v) => v.label,
            onTap: (v) => setState(() {
              _backgroundStyle = v;
            }),
          ),

          _divider(),

          // ── COLOUR TEMPERATURE ────────────────────────────────────────
          _sectionLabel('COLOUR TEMPERATURE', Icons.wb_sunny_outlined),
          const SizedBox(height: 6),
          Text('Adjusts warm/cool tone for different room lighting.',
              style: TextStyle(
                  color: _white.withOpacity(0.35), fontSize: 11, height: 1.5)),
          const SizedBox(height: 10),
          _chipRow<ColourTemperature>(
            values: ColourTemperature.values,
            selected: _colourTemperature,
            label: (v) => v.label,
            onTap: (v) => setState(() => _colourTemperature = v),
          ),

          _divider(),

          // ── BACKGROUND PATTERN ────────────────────────────────────────
          _sectionLabel('BACKGROUND PATTERN', Icons.auto_awesome_outlined),
          const SizedBox(height: 6),
          Text(
              'Subtle overlay pattern. Selecting one will clear the background image.',
              style: TextStyle(
                  color: _white.withOpacity(0.35), fontSize: 11, height: 1.5)),
          const SizedBox(height: 10),
          // Exclude customImage — that is set via the image picker below
          _chipRow<BackgroundPattern>(
            values: BackgroundPattern.values
                .where((v) => v != BackgroundPattern.customImage)
                .toList(),
            selected: _backgroundPattern == BackgroundPattern.customImage
                ? BackgroundPattern.none
                : _backgroundPattern,
            label: (v) => v.label,
            onTap: (v) {
              setState(() {
                _backgroundPattern = v;
                // Choosing a pattern overrides the bg image
                if (v != BackgroundPattern.none) {
                  _bgImageBytes = null;
                  _bgImageStoragePath = '';
                }
              });
            },
          ),

          _divider(),

          // ── BACKGROUND IMAGE ──────────────────────────────────────────
          _sectionLabel('BACKGROUND IMAGE', Icons.wallpaper_outlined),
          const SizedBox(height: 6),
          Text(
            'Pick a photo from this phone to use as the full-screen TV background. '
            'Overrides the pattern above.',
            style: TextStyle(
                color: _white.withOpacity(0.35), fontSize: 11, height: 1.5),
          ),
          const SizedBox(height: 12),

          // Preview (if image already set)
          if (_bgImageBytes != null) ...[
            Stack(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(_bgImageBytes!,
                    height: 130, width: double.infinity, fit: BoxFit.cover),
              ),
              Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: _clearingBg ? null : _clearBackgroundImage,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          shape: BoxShape.circle),
                      child: _clearingBg
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  color: Colors.redAccent, strokeWidth: 2))
                          : const Icon(Icons.delete_outline,
                              color: Colors.redAccent, size: 18),
                    ),
                  )),
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20)),
                  child: const Row(children: [
                    Icon(Icons.tv, color: _gold, size: 12),
                    SizedBox(width: 4),
                    Text('Active TV background',
                        style: TextStyle(
                            color: _gold,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            // Change button
            _outlineButton(
              label: 'Change image',
              icon: Icons.swap_horiz,
              color: _white.withOpacity(0.5),
              loading: _uploadingBg,
              onTap: _uploadingBg ? null : _pickBackgroundImage,
            ),
          ] else ...[
            // No bg image — big pick button
            _actionButton(
              label: _uploadingBg ? 'Uploading…' : 'Pick photo from phone',
              icon: Icons.wallpaper,
              color: _skyBlue,
              loading: _uploadingBg,
              onTap: _uploadingBg ? null : _pickBackgroundImage,
            ),
          ],

          const SizedBox(height: 24),
          if (_displaySaveMsg.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(_displaySaveMsg,
                    style: const TextStyle(color: _mintGreen, fontSize: 12))),
          _primaryButton(
              label: 'Apply to TV',
              icon: Icons.cast,
              loading: _savingDisplay,
              onTap: _savingDisplay ? null : _saveDisplaySettings),
          const SizedBox(height: 40),
        ]),
      );

  // ══════════════════════════════════════════════════════════════════
  // SETTINGS TAB
  // ══════════════════════════════════════════════════════════════════
  Widget _buildSettingsTab() => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── TICKER MESSAGE ────────────────────────────────────────────
          _sectionLabel('TICKER MESSAGE', Icons.edit_note),
          const SizedBox(height: 8),
          Text(
              'Custom announcement shown in the ticker strip on the TV display.',
              style: TextStyle(
                  color: _white.withOpacity(0.35), fontSize: 11, height: 1.5)),
          const SizedBox(height: 10),
          TextField(
            controller: _tickerCtrl,
            style: const TextStyle(
                color: _white, fontSize: 14, fontWeight: FontWeight.w400),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'e.g. Sisters class after Asr today',
              hintStyle:
                  TextStyle(color: _white.withOpacity(0.2), fontSize: 12),
              filled: true,
              fillColor: _navyLight,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: _teal.withOpacity(0.3), width: 1)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: _teal.withOpacity(0.3), width: 1)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _teal, width: 1.5)),
            ),
          ),
          const SizedBox(height: 8),
          if (_tickerSaveMsg.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_tickerSaveMsg,
                    style: const TextStyle(color: _mintGreen, fontSize: 12))),
          Row(children: [
            Expanded(
                child: _outlineButton(
                    label: 'Apply',
                    icon: Icons.check,
                    color: _teal,
                    loading: _savingTicker,
                    onTap: _savingTicker ? null : _saveTicker)),
            const SizedBox(width: 8),
            GestureDetector(
                onTap: () {
                  _tickerCtrl.clear();
                  _saveTicker();
                },
                child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                        color: _white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _white.withOpacity(0.12), width: 1)),
                    child: Text('Clear',
                        style: TextStyle(
                            color: _white.withOpacity(0.4),
                            fontSize: 13,
                            fontWeight: FontWeight.w500)))),
          ]),

          _divider(),

          // ── DONATION QR ───────────────────────────────────────────────
          _sectionLabel('DONATION QR', Icons.qr_code_2_outlined),
          const SizedBox(height: 8),
          Text(
              "Enter your mosque's donation link. A QR code will appear on the TV display overlay.",
              style: TextStyle(
                  color: _white.withOpacity(0.35), fontSize: 11, height: 1.5)),
          const SizedBox(height: 10),
          TextField(
            controller: _donationCtrl,
            style: const TextStyle(color: _white, fontSize: 13),
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              hintText: 'https://donate.example.com/mosque',
              hintStyle:
                  TextStyle(color: _white.withOpacity(0.2), fontSize: 12),
              filled: true,
              fillColor: _navyLight,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: _gold.withOpacity(0.2), width: 1)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: _gold.withOpacity(0.2), width: 1)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _gold, width: 1.5)),
            ),
          ),
          const SizedBox(height: 8),
          if (_donationSaveMsg.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_donationSaveMsg,
                    style: const TextStyle(color: _mintGreen, fontSize: 12))),
          _outlineButton(
              label: 'Save Donation Link',
              icon: Icons.save_outlined,
              color: _gold,
              loading: _savingDonation,
              onTap: _savingDonation ? null : _saveDonation),

          _divider(),

          // ── MOSQUE ────────────────────────────────────────────────────
          _sectionLabel('MOSQUE', Icons.mosque_outlined),
          const SizedBox(height: 10),
          _settingsTile(
              icon: Icons.swap_horiz,
              label: 'Change Mosque',
              sub: _mosqueName,
              color: _skyBlue,
              onTap: () async {
                await _loadAllMosques();
                setState(() => _changingMosque = true);
              }),

          _divider(),

          // ── ACCOUNT ───────────────────────────────────────────────────
          _sectionLabel('ACCOUNT', Icons.person_outline),
          const SizedBox(height: 10),
          _settingsTile(
              icon: Icons.logout,
              label: 'Log Out',
              sub: _email,
              color: Colors.red.shade400,
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) Navigator.of(context).pop();
              }),
          const SizedBox(height: 40),
        ]),
      );

  // ══════════════════════════════════════════════════════════════════
  // CHANGE MOSQUE SCREEN
  // ══════════════════════════════════════════════════════════════════
  Widget _buildChangeMosqueScreen() => Scaffold(
        backgroundColor: _navy,
        appBar: AppBar(
          backgroundColor: _navyMid,
          elevation: 0,
          leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: _white),
              onPressed: () => setState(() => _changingMosque = false)),
          title: const Text('Change Mosque',
              style: TextStyle(
                  color: _white, fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _filterMosques,
              style: const TextStyle(color: _white),
              decoration: InputDecoration(
                hintText: 'Search mosque or city…',
                hintStyle:
                    TextStyle(color: _white.withOpacity(0.3), fontSize: 13),
                prefixIcon: Icon(Icons.search, color: _white.withOpacity(0.4)),
                filled: true,
                fillColor: _navyLight,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: _gold.withOpacity(0.2), width: 1)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: _gold.withOpacity(0.2), width: 1)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _gold, width: 1.5)),
              ),
            ),
          ),
          Expanded(
            child: _filteredMosques.isEmpty
                ? Center(
                    child: Text('No mosques found',
                        style: TextStyle(
                            color: _white.withOpacity(0.3), fontSize: 13)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredMosques.length,
                    itemBuilder: (_, i) {
                      final m = _filteredMosques[i];
                      final name = m['name'] as String? ?? '';
                      final city = m['city'] as String? ?? '';
                      final isSel = m['id'] == _mosqueId;
                      return GestureDetector(
                        onTap: () => _bindMosque(m),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                              color: isSel
                                  ? _gold.withOpacity(0.1)
                                  : _navyLight.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: isSel
                                      ? _gold.withOpacity(0.5)
                                      : _white.withOpacity(0.07),
                                  width: 1)),
                          child: Row(children: [
                            Icon(Icons.mosque_outlined,
                                color: isSel ? _gold : _white.withOpacity(0.4),
                                size: 18),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(name,
                                      style: TextStyle(
                                          color: isSel ? _gold : _white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                  if (city.isNotEmpty)
                                    Text(city,
                                        style: TextStyle(
                                            color: _white.withOpacity(0.4),
                                            fontSize: 11)),
                                ])),
                            if (isSel)
                              const Icon(Icons.check_circle,
                                  color: _gold, size: 18),
                          ]),
                        ),
                      );
                    }),
          ),
        ]),
      );

  // ══════════════════════════════════════════════════════════════════
  // DIALOGS
  // ══════════════════════════════════════════════════════════════════
  Future<bool?> _showConfirmImageDialog(Uint8List bytes, String name,
      {String confirmLabel = 'Upload'}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _navyMid,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(confirmLabel,
            style: const TextStyle(
                color: _white, fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(bytes,
                  height: 160,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image, color: Colors.white38))),
          const SizedBox(height: 10),
          Text(name,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white38))),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(confirmLabel,
                  style: const TextStyle(
                      color: _gold, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _confirmDialog(BuildContext ctx,
          {required String title,
          required String body,
          required String confirmLabel,
          required Color confirmColor}) =>
      AlertDialog(
        backgroundColor: _navyMid,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: const TextStyle(
                color: _white, fontSize: 15, fontWeight: FontWeight.w600)),
        content: Text(body,
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white38))),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(confirmLabel,
                  style: TextStyle(
                      color: confirmColor, fontWeight: FontWeight.w700))),
        ],
      );

  // ══════════════════════════════════════════════════════════════════
  // SHARED UI HELPERS
  // ══════════════════════════════════════════════════════════════════
  Future<DateTime?> _showDatePickerDialog(DateTime initial,
          {DateTime? firstDate}) =>
      showDatePicker(
        context: context,
        initialDate: initial,
        firstDate:
            firstDate ?? DateTime.now().subtract(const Duration(days: 30)),
        lastDate: DateTime.now().add(const Duration(days: 90)),
        builder: (ctx, child) => Theme(
            data: ThemeData.dark().copyWith(
                colorScheme:
                    const ColorScheme.dark(primary: _gold, surface: _navyMid)),
            child: child!),
      );

  Widget _datePicker(
          {required String label,
          required DateTime date,
          required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
              color: _navyLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _gold.withOpacity(0.25), width: 1)),
          child: Row(children: [
            Icon(Icons.calendar_today, color: _gold.withOpacity(0.7), size: 16),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(
                      color: _white.withOpacity(0.4),
                      fontSize: 10,
                      letterSpacing: 0.5)),
              Text(DateFormat('EEEE, d MMMM yyyy').format(date),
                  style: const TextStyle(
                      color: _white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ]),
            const Spacer(),
            Icon(Icons.chevron_right, color: _white.withOpacity(0.3), size: 16),
          ]),
        ),
      );

  InputDecoration _timeInputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _white.withOpacity(0.2), fontSize: 13),
        filled: true,
        fillColor: _navyLight,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _gold.withOpacity(0.2), width: 1)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _gold.withOpacity(0.2), width: 1)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _gold, width: 1.5)),
      );

  Widget _chipRow<T>({
    required List<T> values,
    required T selected,
    required String Function(T) label,
    required void Function(T) onTap,
  }) =>
      Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values.map((v) {
            final isSel = v == selected;
            return GestureDetector(
              onTap: () => onTap(v),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                    color: isSel ? _gold.withOpacity(0.15) : _navyLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: isSel ? _gold : _white.withOpacity(0.15),
                        width: isSel ? 1.5 : 1)),
                child: Text(label(v),
                    style: TextStyle(
                        color: isSel ? _gold : _white.withOpacity(0.55),
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w400)),
              ),
            );
          }).toList());

  Widget _toggleTile({
    required String label,
    required String sub,
    required IconData icon,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.18), width: 1)),
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: const TextStyle(
                        color: _white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(sub,
                    style: TextStyle(
                        color: _white.withOpacity(0.35),
                        fontSize: 11,
                        height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ])),
          const SizedBox(width: 8),
          Switch(
              value: value,
              onChanged: onChanged,
              activeColor: color,
              activeTrackColor: color.withOpacity(0.3),
              inactiveThumbColor: Colors.white38,
              inactiveTrackColor: _navyLight),
        ]),
      );

  Widget _actionButton({
    required String label,
    required IconData icon,
    required bool loading,
    required Color color,
    required VoidCallback? onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: color.withOpacity(loading ? 0.2 : 0.45), width: 1.5)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            loading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child:
                        CircularProgressIndicator(color: color, strokeWidth: 2))
                : Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    color: loading ? _white.withOpacity(0.35) : color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required bool loading,
    required VoidCallback? onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                _gold.withOpacity(loading ? 0.3 : 1),
                _gold.withOpacity(loading ? 0.2 : 0.8),
              ]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: loading
                  ? []
                  : [
                      BoxShadow(
                          color: _gold.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 3))
                    ]),
          child: loading
              ? const Center(
                  child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: _navy, strokeWidth: 2)))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icon, color: _navy, size: 16),
                  const SizedBox(width: 8),
                  Text(label,
                      style: const TextStyle(
                          color: _navy,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ]),
        ),
      );

  Widget _outlineButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool loading,
    required VoidCallback? onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.5), width: 1.5)),
          child: loading
              ? Center(
                  child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          color: color, strokeWidth: 2)))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icon, color: color, size: 16),
                  const SizedBox(width: 6),
                  Text(label,
                      style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ]),
        ),
      );

  Widget _sectionLabel(String label, IconData icon) => Row(children: [
        Icon(icon, color: _gold.withOpacity(0.7), size: 14),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: _gold.withOpacity(0.7),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5)),
      ]);

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
              border: Border.all(color: color.withOpacity(0.2), width: 1)),
          child: Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(label,
                      style: const TextStyle(
                          color: _white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  Text(sub,
                      style: TextStyle(
                          color: _white.withOpacity(0.35), fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ])),
            Icon(Icons.chevron_right,
                color: _white.withOpacity(0.25), size: 16),
          ]),
        ),
      );

  Widget _divider() => Column(children: [
        const SizedBox(height: 20),
        Divider(color: _white.withOpacity(0.07)),
        const SizedBox(height: 16),
      ]);
}
