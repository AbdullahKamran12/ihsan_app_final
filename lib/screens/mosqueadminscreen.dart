import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MosqueAdminScreen
// Mobile screen that gives mosque admins the same controls as the web drawer:
//   • IMAGES tab  — upload / delete display images for the TV screen
//   • JAMĀ'AH tab — batch-update jamaat times for a date range
//   • SETTINGS tab — custom ticker message, change mosque, log out
//
// Access: push this screen from HomeScreen for users who are admins and have
// a displayMosques/{uid} binding.  No orientation change needed (portrait only).
// ─────────────────────────────────────────────────────────────────────────────

// ── Palette (matches mosqueDisplayScreen) ────────────────────────────────────
const _navy = Color.fromARGB(255, 8, 20, 52);
const _navyMid = Color.fromARGB(255, 15, 36, 85);
const _navyLight = Color.fromARGB(255, 24, 52, 110);
const _gold = Color.fromARGB(255, 212, 175, 95);
const _mintGreen = Color.fromARGB(255, 72, 200, 155);
const _skyBlue = Color.fromARGB(255, 100, 180, 240);
const _white = Colors.white;
const _teal = Color(0xFF00E5CC);

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

  // ── Images ────────────────────────────────────────────────────────
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
  DateTime _endDate = DateTime.now().add(const Duration(days: 6));
  bool _savingJamaat = false;
  String _jamaatSaveMsg = '';

  // ── Ticker message ────────────────────────────────────────────────
  late TextEditingController _tickerCtrl;
  bool _savingTicker = false;
  String _tickerSaveMsg = '';

  // ── All mosques (for change mosque) ──────────────────────────────
  List<Map<String, dynamic>> _allMosques = [];
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _filteredMosques = [];
  bool _changingMosque = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tickerCtrl = TextEditingController();
    _user = FirebaseAuth.instance.currentUser;
    _loadBinding();
  }

  @override
  void dispose() {
    _tab.dispose();
    for (final c in _jamaatCtrls.values) c.dispose();
    _tickerCtrl.dispose();
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

      // Load user display name
      final userDoc = await FirebaseFirestore.instance
          .collection('UserData')
          .doc(uid)
          .get();
      final displayName =
          (userDoc.data()?['displayName'] as String?) ?? _user?.email ?? '';
      _firstName = displayName.split(' ').first;
      _email = _user?.email ?? '';

      // Load mosque binding
      final bindingDoc = await FirebaseFirestore.instance
          .collection('displayMosques')
          .doc(uid)
          .get();

      if (!bindingDoc.exists || bindingDoc.data()?['mosqueId'] == null) {
        setState(() {
          _loading = false;
          _error = 'No mosque linked to this account.\n'
              'Please set up your display screen first.';
        });
        return;
      }

      _mosqueId = bindingDoc.data()!['mosqueId'] as String? ?? '';
      _mosqueName = bindingDoc.data()!['mosqueName'] as String? ?? '';
      final savedTicker =
          (bindingDoc.data()!['customTickerMessage'] as String?) ?? '';
      _tickerCtrl.text = savedTicker;

      await _fetchImages();
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // IMAGES
  // ══════════════════════════════════════════════════════════════════
  Future<void> _fetchImages() async {
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
      debugPrint('fetchImages error: $e');
    } finally {
      if (mounted) setState(() => _loadingImages = false);
    }
  }

  Future<void> _uploadImage() async {
    if (_mosqueId.isEmpty) return;
    setState(() => _uploadingImage = true);
    try {
      final picker = ImagePicker();
      final XFile? picked =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) {
        setState(() => _uploadingImage = false);
        return;
      }
      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.')
          ? picked.name.split('.').last.toLowerCase()
          : 'jpg';

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _navyMid,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Upload image?',
              style: TextStyle(
                  color: _white, fontSize: 16, fontWeight: FontWeight.w700)),
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
              Text(picked.name,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
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
                  style: TextStyle(color: _gold, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        setState(() => _uploadingImage = false);
        return;
      }

      final filename = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storagePath = 'displayMosques/$_mosqueId/images/$filename';
      final ref = FirebaseStorage.instance.ref().child(storagePath);
      await ref.putData(bytes, SettableMetadata(contentType: 'image/$ext'));

      // Signal TV display to refresh
      final uid = _user?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('displayMosques')
            .doc(uid)
            .set({'needsRefresh': true}, SetOptions(merge: true));
      }

      await _fetchImages();
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

  Future<void> _deleteImage(String storagePath) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _navyMid,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Image',
            style: TextStyle(
                color: _white, fontSize: 15, fontWeight: FontWeight.w600)),
        content: const Text('Remove this image from the display cycle?',
            style: TextStyle(color: Colors.white54, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white38))),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete',
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _imageMap.remove(storagePath));
    try {
      await FirebaseStorage.instance.ref(storagePath).delete();
      // Signal TV display to refresh
      final uid = _user?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('displayMosques')
            .doc(uid)
            .set({'needsRefresh': true}, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Delete error: $e');
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
          _jamaatSaveMsg = 'Invalid time "$raw" — use HH:MM format.';
        });
        return;
      }
      final h = int.tryParse(parts[0].trim());
      final m = int.tryParse(parts[1].trim());
      if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
        setState(() {
          _savingJamaat = false;
          _jamaatSaveMsg = 'Invalid time "$raw" — use HH:MM format.';
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
      final now = DateTime.now();
      DateTime cursor = DateTime(now.year, now.month, now.day);

      while (!cursor.isAfter(_endDate)) {
        final dateStr = cursor.toIso8601String().substring(0, 10);
        final ref = db
            .collection('mosques')
            .doc(_mosqueId)
            .collection('prayerTimes')
            .doc(dateStr);
        batch.set(ref, times, SetOptions(merge: true));
        cursor = cursor.add(const Duration(days: 1));
      }
      await batch.commit();

      // Signal TV display to refresh
      final uid = _user?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('displayMosques')
            .doc(uid)
            .set({'needsRefresh': true}, SetOptions(merge: true));
      }

      setState(() {
        _savingJamaat = false;
        _jamaatSaveMsg =
            '✓ Saved for ${_endDate.difference(DateTime.now()).inDays + 1} day(s)';
      });
    } catch (e) {
      setState(() {
        _savingJamaat = false;
        _jamaatSaveMsg = 'Error: $e';
      });
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // TICKER MESSAGE
  // ══════════════════════════════════════════════════════════════════
  Future<void> _saveTicker() async {
    final uid = _user?.uid;
    if (uid == null) return;
    setState(() {
      _savingTicker = true;
      _tickerSaveMsg = '';
    });
    try {
      await FirebaseFirestore.instance
          .collection('displayMosques')
          .doc(uid)
          .set({'customTickerMessage': _tickerCtrl.text.trim()},
              SetOptions(merge: true));
      // Signal TV to refresh
      await FirebaseFirestore.instance
          .collection('displayMosques')
          .doc(uid)
          .set({'needsRefresh': true}, SetOptions(merge: true));
      setState(() => _tickerSaveMsg = '✓ Ticker updated');
    } catch (e) {
      setState(() => _tickerSaveMsg = 'Error: $e');
    } finally {
      setState(() => _savingTicker = false);
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

  void _filterMosques(String query) {
    final q = query.toLowerCase();
    setState(() {
      _filteredMosques = q.isEmpty
          ? List.from(_allMosques)
          : _allMosques
              .where((m) =>
                  (m['name'] as String? ?? '').toLowerCase().contains(q) ||
                  (m['city'] as String? ?? '').toLowerCase().contains(q))
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
        _mosqueName = mosque['name'] as String? ?? '';
        _changingMosque = false;
      });
      await _fetchImages();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Mosque updated'), backgroundColor: Colors.green));
      }
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
        appBar: _appBar('Mosque Admin'),
        body: const Center(
            child: CircularProgressIndicator(color: _gold, strokeWidth: 2)),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: _navy,
        appBar: _appBar('Mosque Admin'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!,
                style: const TextStyle(color: Colors.white60, fontSize: 14),
                textAlign: TextAlign.center),
          ),
        ),
      );
    }

    if (_changingMosque) {
      return _buildChangeMosqueScreen();
    }

    return Scaffold(
      backgroundColor: _navy,
      appBar: AppBar(
        backgroundColor: _navyMid,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
          ],
        ),
        bottom: TabBar(
          controller: _tab,
          labelColor: _gold,
          unselectedLabelColor: Colors.white38,
          indicatorColor: _gold,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          tabs: const [
            Tab(text: 'IMAGES'),
            Tab(text: "JAMĀ'AH"),
            Tab(text: 'SETTINGS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildImagesTab(),
          _buildJamaatTab(),
          _buildSettingsTab(),
        ],
      ),
    );
  }

  AppBar _appBar(String title) => AppBar(
        backgroundColor: _navyMid,
        elevation: 0,
        title: Text(title,
            style: const TextStyle(
                color: _white, fontSize: 16, fontWeight: FontWeight.w700)),
      );

  // ══════════════════════════════════════════════════════════════════
  // IMAGES TAB
  // ══════════════════════════════════════════════════════════════════
  Widget _buildImagesTab() {
    return RefreshIndicator(
      color: _gold,
      backgroundColor: _navyMid,
      onRefresh: _fetchImages,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('DISPLAY IMAGES', Icons.image_outlined),
            const SizedBox(height: 6),
            Text(
              'Images shown on the mosque TV display cycle. '
              'Pull to refresh.',
              style: TextStyle(
                  color: _white.withOpacity(0.35), fontSize: 11, height: 1.5),
            ),
            const SizedBox(height: 16),

            // Upload button
            GestureDetector(
              onTap: _uploadingImage ? null : _uploadImage,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: _gold.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _gold.withOpacity(_uploadingImage ? 0.2 : 0.45),
                      width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_uploadingImage)
                      const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: _gold, strokeWidth: 2))
                    else
                      const Icon(Icons.upload_rounded, color: _gold, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      _uploadingImage ? 'Uploading…' : 'Pick image from device',
                      style: TextStyle(
                        color:
                            _uploadingImage ? _white.withOpacity(0.35) : _gold,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
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
                            color: _white.withOpacity(0.2), fontSize: 12)),
                  ),
                )
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
                                        size: 22))),
                          ),
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
                                overflow: TextOverflow.ellipsis),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _deleteImage(path),
                          child: Container(
                            width: 52,
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
          ],
        ),
      ),
    );
  }

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel("JAMĀ'AH TIMES", Icons.schedule),
          const SizedBox(height: 6),
          Text(
            "Set new Jamā'ah times. Choose an end date — all days from today to that date will be updated.",
            style: TextStyle(
                color: _white.withOpacity(0.35), fontSize: 11, height: 1.5),
          ),
          const SizedBox(height: 16),

          ...prayers.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
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
                        ],
                      ),
                    ),
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
                        decoration: InputDecoration(
                          hintText: 'HH:MM',
                          hintStyle: TextStyle(
                              color: _white.withOpacity(0.2), fontSize: 13),
                          filled: true,
                          fillColor: _navyLight,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                                color: _gold.withOpacity(0.2), width: 1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                                color: _gold.withOpacity(0.2), width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: _gold, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )),

          const SizedBox(height: 4),
          Divider(color: _white.withOpacity(0.08)),
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
                    colorScheme: const ColorScheme.dark(
                      primary: _gold,
                      surface: _navyMid,
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
                color: _navyLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _gold.withOpacity(0.25), width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today,
                      color: _gold.withOpacity(0.7), size: 16),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Apply until',
                          style: TextStyle(
                              color: _white.withOpacity(0.4),
                              fontSize: 10,
                              letterSpacing: 0.5)),
                      Text(
                        DateFormat('EEEE, d MMMM yyyy').format(_endDate),
                        style: const TextStyle(
                            color: _white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right,
                      color: _white.withOpacity(0.3), size: 16),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),
          Text(
            'This will update ${_endDate.difference(DateTime.now()).inDays + 1} day(s)',
            style: TextStyle(color: _gold.withOpacity(0.5), fontSize: 11),
          ),
          const SizedBox(height: 16),

          if (_jamaatSaveMsg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(_jamaatSaveMsg,
                  style: const TextStyle(color: _mintGreen, fontSize: 12)),
            ),

          GestureDetector(
            onTap: _savingJamaat ? null : _saveJamaatTimes,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _gold.withOpacity(_savingJamaat ? 0.3 : 1),
                    _gold.withOpacity(_savingJamaat ? 0.2 : 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: _savingJamaat
                    ? []
                    : [
                        BoxShadow(
                            color: _gold.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 3)),
                      ],
              ),
              child: _savingJamaat
                  ? const Center(
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: _navy, strokeWidth: 2)))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save, color: _navy, size: 16),
                        SizedBox(width: 8),
                        Text('Save & Apply',
                            style: TextStyle(
                                color: _navy,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // SETTINGS TAB
  // ══════════════════════════════════════════════════════════════════
  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('TICKER MESSAGE', Icons.edit_note),
          const SizedBox(height: 8),
          Text(
            'Add a custom announcement shown in the ticker on the TV display.',
            style: TextStyle(
                color: _white.withOpacity(0.35), fontSize: 11, height: 1.5),
          ),
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
                borderSide: BorderSide(color: _teal.withOpacity(0.3), width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _teal.withOpacity(0.3), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _teal, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_tickerSaveMsg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_tickerSaveMsg,
                  style: const TextStyle(color: _mintGreen, fontSize: 12)),
            ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _savingTicker ? null : _saveTicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: _teal.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: _teal.withOpacity(0.5), width: 1.5),
                    ),
                    child: _savingTicker
                        ? const Center(
                            child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    color: _teal, strokeWidth: 2)))
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check, color: _teal, size: 16),
                              SizedBox(width: 6),
                              Text('Apply',
                                  style: TextStyle(
                                      color: _teal,
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
                  _tickerCtrl.clear();
                  _saveTicker();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: _white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: _white.withOpacity(0.12), width: 1),
                  ),
                  child: Text('Clear',
                      style: TextStyle(
                          color: _white.withOpacity(0.4),
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Divider(color: _white.withOpacity(0.07)),
          const SizedBox(height: 16),
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
            },
          ),
          const SizedBox(height: 24),
          Divider(color: _white.withOpacity(0.07)),
          const SizedBox(height: 16),
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
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // CHANGE MOSQUE SCREEN
  // ══════════════════════════════════════════════════════════════════
  Widget _buildChangeMosqueScreen() {
    return Scaffold(
      backgroundColor: _navy,
      appBar: AppBar(
        backgroundColor: _navyMid,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _white),
          onPressed: () => setState(() => _changingMosque = false),
        ),
        title: const Text('Change Mosque',
            style: TextStyle(
                color: _white, fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
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
                      BorderSide(color: _gold.withOpacity(0.2), width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: _gold.withOpacity(0.2), width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _gold, width: 1.5),
                ),
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
                      final isSelected = m['id'] == _mosqueId;
                      return GestureDetector(
                        onTap: () => _bindMosque(m),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _gold.withOpacity(0.1)
                                : _navyLight.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? _gold.withOpacity(0.5)
                                  : _white.withOpacity(0.07),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.mosque_outlined,
                                  color: isSelected
                                      ? _gold
                                      : _white.withOpacity(0.4),
                                  size: 18),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        style: TextStyle(
                                            color: isSelected ? _gold : _white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                    if (city.isNotEmpty)
                                      Text(city,
                                          style: TextStyle(
                                              color: _white.withOpacity(0.4),
                                              fontSize: 11)),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle,
                                    color: _gold, size: 18),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // SHARED WIDGETS
  // ══════════════════════════════════════════════════════════════════
  Widget _sectionLabel(String label, IconData icon) => Row(
        children: [
          Icon(icon, color: _gold.withOpacity(0.7), size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: _gold.withOpacity(0.7),
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
                        style: const TextStyle(
                            color: _white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Text(sub,
                        style: TextStyle(
                            color: _white.withOpacity(0.35), fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: _white.withOpacity(0.25), size: 16),
            ],
          ),
        ),
      );
}
