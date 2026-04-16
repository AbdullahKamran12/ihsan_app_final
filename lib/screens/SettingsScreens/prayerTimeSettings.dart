import 'package:flutter/material.dart';
import 'package:ihsan_app_final/screens/homeScreen.dart';
import 'package:ihsan_app_final/screens/moreoptionsScreen.dart';
import 'package:ihsan_app_final/screens/settings.dart';
import 'package:ihsan_app_final/sharedWidgets.dart';
import 'package:ihsan_app_final/screens/prayerTimesClass.dart';
import 'package:ihsan_app_final/screens/prayerScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _navy = Color.fromARGB(255, 10, 25, 60);
const Color _navyMid = Color.fromARGB(255, 18, 42, 95);
const Color _gold = Color.fromARGB(255, 212, 175, 95);
const Color _goldLight = Color.fromARGB(255, 252, 243, 210);
const Color _skyLight = Color.fromARGB(255, 220, 240, 255);
const Color _skyBlue = Color.fromARGB(255, 100, 180, 240);
const Color _mintGreen = Color.fromARGB(255, 72, 200, 155);
const Color _mintLight = Color.fromARGB(255, 210, 245, 232);
const Color _white = Color.fromARGB(255, 255, 255, 255);
const Color _offWhite = Color.fromARGB(255, 247, 249, 255);
const Color _textDark = Color.fromARGB(255, 15, 30, 65);
const Color _textMid = Color.fromARGB(255, 90, 115, 160);
const Color _border = Color.fromARGB(255, 210, 220, 240);

// ── Shared save helper ────────────────────────────────────────────────────────
Future<void> saveAllSettings() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('method', method);
  await prefs.setInt('school', school);
  await saveAdjustments();
}

// ══════════════════════════════════════════════════════════════════════════════
// Prayer Time Settings  (top-level hub)
// ══════════════════════════════════════════════════════════════════════════════
class prayerTimeSettingsScreen extends StatefulWidget {
  const prayerTimeSettingsScreen({super.key});
  @override
  prayerTimeSettingsScreenState createState() =>
      prayerTimeSettingsScreenState();
}

class prayerTimeSettingsScreenState extends State<prayerTimeSettingsScreen> {
  String? _activeMosqueId;
  String? _activeMosqueName;
  bool _isLoadingMosque = true;

  // Method name map for display
  static const Map<int, String> _methodNames = {
    0: 'Jafari / Shia Ithna-Ashari',
    1: 'University of Islamic Sciences, Karachi',
    2: 'Islamic Society of North America',
    3: 'Muslim World League',
    4: 'Umm Al-Qura University, Makkah',
    5: 'Egyptian General Authority of Survey',
    7: 'Institute of Geophysics, Tehran',
    8: 'Gulf Region',
    9: 'Kuwait',
    10: 'Qatar',
    11: 'Majlis Ugama Islam Singapura',
    12: 'Union des organisations islamiques de France',
    13: 'Diyanet İşleri Başkanlığı, Turkey',
    14: 'Spiritual Administration of Muslims of Russia',
    15: 'Moonsighting Committee Worldwide',
    16: 'Dubai (experimental)',
    17: 'JAKIM, Malaysia',
    18: 'Tunisia',
    19: 'Algeria',
    20: 'KEMENAG, Indonesia',
    21: 'Morocco',
    22: 'Comunidade Islamica de Lisboa',
    23: 'Ministry of Awqaf, Jordan',
    99: 'Custom',
  };

  @override
  void initState() {
    super.initState();
    _loadMosqueStatus();
  }

  Future<void> _loadMosqueStatus() async {
    final mosqueId = await getLocalMosqueId();
    if (mosqueId.isNotEmpty) {
      final name = await getMosqueNameFromId(mosqueId);
      setState(() {
        _activeMosqueId = mosqueId;
        _activeMosqueName = name;
        _isLoadingMosque = false;
      });
    } else {
      setState(() {
        _activeMosqueId = null;
        _activeMosqueName = null;
        _isLoadingMosque = false;
      });
    }
  }

  Future<void> _removeMosque() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _offWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Mosque Timetable',
            style: TextStyle(
                color: _textDark, fontWeight: FontWeight.w700, fontSize: 16)),
        content: const Text(
            'This will switch back to standard calculation. Continue?',
            style: TextStyle(color: _textMid, fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: _textMid))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: _white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await clearLocalMosqueId();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('prayerTimes_${DateTime.now().year}');
    change = true;
    setState(() {
      _activeMosqueId = null;
      _activeMosqueName = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Mosque timetable removed — using standard calculation'),
        backgroundColor: _gold,
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  String _getAdjustmentSummary() {
    final List<String> parts = [];
    if (fajrAdj != 0)
      parts.add('Fajr ${fajrAdj > 0 ? "+$fajrAdj" : "$fajrAdj"}m');
    if (sunriseAdj != 0)
      parts.add('Sunrise ${sunriseAdj > 0 ? "+$sunriseAdj" : "$sunriseAdj"}m');
    if (dhuhrAdj != 0)
      parts.add('Dhuhr ${dhuhrAdj > 0 ? "+$dhuhrAdj" : "$dhuhrAdj"}m');
    if (asrAdj != 0) parts.add('Asr ${asrAdj > 0 ? "+$asrAdj" : "$asrAdj"}m');
    if (maghribAdj != 0)
      parts.add('Maghrib ${maghribAdj > 0 ? "+$maghribAdj" : "$maghribAdj"}m');
    if (ishaAdj != 0)
      parts.add('Isha ${ishaAdj > 0 ? "+$ishaAdj" : "$ishaAdj"}m');
    return parts.isEmpty ? 'No adjustments' : parts.join('  ·  ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      appBar: buildAppBar(
          context, 'Prayer Time Settings', const SettingScreen(), null),
      body: Container(
        color: _offWhite,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Mosque status card ──────────────────────────────────────────
            if (!_isLoadingMosque) ...[
              _sectionLabel('PRAYER SOURCE'),
              Container(
                decoration: BoxDecoration(
                  color: _activeMosqueId != null ? _mintLight : _offWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: _activeMosqueId != null
                          ? _mintGreen.withOpacity(0.5)
                          : _border,
                      width: 1.2),
                  boxShadow: [
                    BoxShadow(
                        color: _navy.withOpacity(0.07),
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: _activeMosqueId != null
                            ? _mintGreen.withOpacity(0.15)
                            : _skyLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _activeMosqueId != null
                            ? Icons.mosque_rounded
                            : Icons.calculate_outlined,
                        size: 20,
                        color: _activeMosqueId != null ? _mintGreen : _navy,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _activeMosqueId != null
                                ? 'Mosque Timetable'
                                : 'Standard Calculation',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _activeMosqueId != null
                                  ? const Color.fromARGB(255, 30, 140, 105)
                                  : _textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _activeMosqueId != null
                                ? (_activeMosqueName ?? 'Unknown Mosque')
                                : 'Method ${_methodNames[method] ?? method.toString()}',
                            style:
                                const TextStyle(fontSize: 12, color: _textMid),
                          ),
                          if (_activeMosqueId != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _getAdjustmentSummary(),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: _textMid.withOpacity(0.8)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_activeMosqueId != null)
                      GestureDetector(
                        onTap: _removeMosque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: const Text('Remove',
                              style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Options ─────────────────────────────────────────────────────
            _sectionLabel('ADJUSTMENTS'),
            _settingsTile(
              icon: Icons.tune_rounded,
              iconBg: _goldLight,
              iconColor: const Color.fromARGB(255, 140, 105, 30),
              title: 'Adjust Prayer Times',
              subtitle: _getAdjustmentSummary(),
              trailing: _activeMosqueId != null
                  ? const Icon(Icons.check_circle_rounded,
                      size: 16, color: _mintGreen)
                  : null,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const adjustTimeSettingsScreen()),
              ),
            ),
            const SizedBox(height: 20),
            _sectionLabel('CALCULATION'),
            _settingsTile(
              icon: Icons.menu_book_rounded,
              iconBg: _skyLight,
              iconColor: _navy,
              title: 'Calculation Method',
              subtitle: _methodNames[method] ?? 'Method $method',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const adjustMethodSettingsScreen()),
              ),
            ),
            const SizedBox(height: 8),
            _settingsTile(
              icon: Icons.school_rounded,
              iconBg: _mintLight,
              iconColor: const Color.fromARGB(255, 30, 140, 105),
              title: 'School of Fiqh (Asr)',
              subtitle: school == 0 ? 'Shafi' : 'Hanafi (Standard)',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const adjustSchoolSettingsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(label,
            style: const TextStyle(
                fontSize: 11,
                letterSpacing: 1.3,
                fontWeight: FontWeight.w700,
                color: _textMid)),
      );

  Widget _settingsTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border, width: 1),
          boxShadow: [
            BoxShadow(
                color: _navy.withOpacity(0.07),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _textDark)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 12, color: _textMid),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 6),
              trailing,
            ],
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 18, color: _textMid),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Adjust Time Settings
// ══════════════════════════════════════════════════════════════════════════════
class adjustTimeSettingsScreen extends StatefulWidget {
  const adjustTimeSettingsScreen({super.key});
  @override
  _adjustTimeSettingsScreenState createState() =>
      _adjustTimeSettingsScreenState();
}

class _adjustTimeSettingsScreenState extends State<adjustTimeSettingsScreen> {
  Future<void> _save() async {
    setState(() {
      adjustments[0] = Duration(minutes: fajrAdj);
      adjustments[1] = Duration(minutes: sunriseAdj);
      adjustments[2] = Duration(minutes: dhuhrAdj);
      adjustments[3] = Duration(minutes: asrAdj);
      adjustments[4] = Duration(minutes: maghribAdj);
      adjustments[5] = Duration(minutes: ishaAdj);
    });
    await saveAdjustments();
    change = true;
    if (mounted) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const PrayerTimesScreen()));
    }
  }

  void _reset() {
    setState(() {
      fajrAdj = 0;
      sunriseAdj = 0;
      dhuhrAdj = 0;
      asrAdj = 0;
      maghribAdj = 0;
      ishaAdj = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final prayers = [
      {
        'label': 'Fajr',
        'icon': Icons.brightness_3_rounded,
        'color': const Color.fromARGB(255, 80, 120, 200),
        'bg': _skyLight,
        'val': fajrAdj,
        'dec': () => setState(() => fajrAdj--),
        'inc': () => setState(() => fajrAdj++)
      },
      {
        'label': 'Sunrise',
        'icon': Icons.wb_sunny_rounded,
        'color': const Color.fromARGB(255, 200, 140, 30),
        'bg': _goldLight,
        'val': sunriseAdj,
        'dec': () => setState(() => sunriseAdj--),
        'inc': () => setState(() => sunriseAdj++)
      },
      {
        'label': 'Dhuhr',
        'icon': Icons.wb_sunny_outlined,
        'color': const Color.fromARGB(255, 200, 140, 30),
        'bg': _goldLight,
        'val': dhuhrAdj,
        'dec': () => setState(() => dhuhrAdj--),
        'inc': () => setState(() => dhuhrAdj++)
      },
      {
        'label': 'Asr',
        'icon': Icons.wb_twilight_rounded,
        'color': const Color.fromARGB(255, 180, 100, 40),
        'bg': const Color.fromARGB(255, 255, 235, 210),
        'val': asrAdj,
        'dec': () => setState(() => asrAdj--),
        'inc': () => setState(() => asrAdj++)
      },
      {
        'label': 'Maghrib',
        'icon': Icons.nights_stay_outlined,
        'color': const Color.fromARGB(255, 140, 80, 200),
        'bg': const Color.fromARGB(255, 235, 220, 255),
        'val': maghribAdj,
        'dec': () => setState(() => maghribAdj--),
        'inc': () => setState(() => maghribAdj++)
      },
      {
        'label': 'Isha',
        'icon': Icons.nightlight_round,
        'color': _navy,
        'bg': _skyLight,
        'val': ishaAdj,
        'dec': () => setState(() => ishaAdj--),
        'inc': () => setState(() => ishaAdj++)
      },
    ];

    return Scaffold(
      backgroundColor: _navy,
      appBar: buildAppBar(context, 'Adjust Prayer Times',
          const prayerTimeSettingsScreen(), null),
      body: Container(
        color: _offWhite,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _skyLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _skyBlue.withOpacity(0.4), width: 1),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: _navy),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Add or subtract minutes from each calculated prayer time.',
                            style: TextStyle(fontSize: 12, color: _textDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...prayers.map((p) => _adjustRow(
                        label: p['label'] as String,
                        icon: p['icon'] as IconData,
                        iconColor: p['color'] as Color,
                        iconBg: p['bg'] as Color,
                        value: p['val'] as int,
                        onDec: p['dec'] as VoidCallback,
                        onInc: p['inc'] as VoidCallback,
                      )),
                ],
              ),
            ),
            // Bottom action bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: const BoxDecoration(
                color: _white,
                border: Border(top: BorderSide(color: _border, width: 1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _reset,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: _border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Reset All',
                          style: TextStyle(
                              color: _textMid, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: _navy,
                        foregroundColor: _gold,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save Adjustments',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _adjustRow({
    required String label,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required int value,
    required VoidCallback onDec,
    required VoidCallback onInc,
  }) {
    final bool hasAdj = value != 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: hasAdj ? _gold.withOpacity(0.5) : _border, width: 1),
        boxShadow: [
          BoxShadow(
              color: _navy.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _textDark))),
          // Decrement
          _adjBtn(Icons.remove_rounded, onDec),
          const SizedBox(width: 8),
          // Value chip
          Container(
            width: 60,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: hasAdj ? _navyMid : _offWhite,
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: hasAdj ? _gold.withOpacity(0.5) : _border),
            ),
            child: Text(
              value == 0 ? '0 min' : '${value > 0 ? "+" : ""}$value min',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: hasAdj ? _gold : _textMid),
            ),
          ),
          const SizedBox(width: 8),
          // Increment
          _adjBtn(Icons.add_rounded, onInc),
        ],
      ),
    );
  }

  Widget _adjBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _skyLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _border),
          ),
          child: Icon(icon, size: 16, color: _navy),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// Calculation Method
// ══════════════════════════════════════════════════════════════════════════════
class adjustMethodSettingsScreen extends StatefulWidget {
  const adjustMethodSettingsScreen({super.key});
  @override
  _adjustMethodSettingsScreenState createState() =>
      _adjustMethodSettingsScreenState();
}

class _adjustMethodSettingsScreenState
    extends State<adjustMethodSettingsScreen> {
  int _selected = method;

  static const List<Map<String, dynamic>> _methods = [
    {'value': 0, 'name': 'Jafari / Shia Ithna-Ashari'},
    {'value': 1, 'name': 'University of Islamic Sciences, Karachi'},
    {'value': 2, 'name': 'Islamic Society of North America (ISNA)'},
    {'value': 3, 'name': 'Muslim World League'},
    {'value': 4, 'name': 'Umm Al-Qura University, Makkah'},
    {'value': 5, 'name': 'Egyptian General Authority of Survey'},
    {'value': 7, 'name': 'Institute of Geophysics, University of Tehran'},
    {'value': 8, 'name': 'Gulf Region'},
    {'value': 9, 'name': 'Kuwait'},
    {'value': 10, 'name': 'Qatar'},
    {'value': 11, 'name': 'Majlis Ugama Islam Singapura'},
    {'value': 12, 'name': 'Union des organisations islamiques de France'},
    {'value': 13, 'name': 'Diyanet İşleri Başkanlığı, Turkey'},
    {'value': 14, 'name': 'Spiritual Administration of Muslims of Russia'},
    {'value': 15, 'name': 'Moonsighting Committee Worldwide'},
    {'value': 16, 'name': 'Dubai (experimental)'},
    {'value': 17, 'name': 'JAKIM, Malaysia'},
    {'value': 18, 'name': 'Tunisia'},
    {'value': 19, 'name': 'Algeria'},
    {'value': 20, 'name': 'KEMENAG, Indonesia'},
    {'value': 21, 'name': 'Morocco'},
    {'value': 22, 'name': 'Comunidade Islamica de Lisboa'},
    {'value': 23, 'name': 'Ministry of Awqaf, Jordan'},
    {'value': 99, 'name': 'Custom'},
  ];

  @override
  void initState() {
    super.initState();
    _selected = method;
  }

  Future<void> _apply() async {
    method = _selected;
    fajrAdj = 0;
    sunriseAdj = 0;
    dhuhrAdj = 0;
    asrAdj = 0;
    maghribAdj = 0;
    ishaAdj = 0;
    for (int i = 0; i < adjustments.length; i++) {
      adjustments[i] = Duration.zero;
    }
    await saveAdjustments();
    change = true;
    await saveAllSettings();
    if (mounted) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const PrayerTimesScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      appBar: buildAppBar(context, 'Calculation Method',
          const prayerTimeSettingsScreen(), null),
      body: Container(
        color: _offWhite,
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                itemCount: _methods.length,
                itemBuilder: (ctx, i) {
                  final m = _methods[i];
                  final bool isSelected = _selected == m['value'];
                  return GestureDetector(
                    onTap: () => setState(() => _selected = m['value']),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? _navyMid : _white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                isSelected ? _gold.withOpacity(0.6) : _border,
                            width: isSelected ? 1.5 : 1),
                        boxShadow: [
                          BoxShadow(
                              color: _navy.withOpacity(0.06),
                              blurRadius: 5,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? _gold : _offWhite,
                              border: Border.all(
                                  color: isSelected ? _gold : _border,
                                  width: 1.5),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check_rounded,
                                    size: 13, color: _navy)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              m['name'],
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected ? _white : _textDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: const BoxDecoration(
                  color: _white,
                  border: Border(top: BorderSide(color: _border, width: 1))),
              child: ElevatedButton(
                onPressed: _apply,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: _navy,
                  foregroundColor: _gold,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Apply Method',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// School of Fiqh
// ══════════════════════════════════════════════════════════════════════════════
class adjustSchoolSettingsScreen extends StatefulWidget {
  const adjustSchoolSettingsScreen({super.key});
  @override
  _adjustSchoolSettingsScreenState createState() =>
      _adjustSchoolSettingsScreenState();
}

class _adjustSchoolSettingsScreenState
    extends State<adjustSchoolSettingsScreen> {
  int _selected = school;

  static const List<Map<String, dynamic>> _schools = [
    {
      'value': 0,
      'name': 'Shafi',
      'desc': 'Asr begins when shadow length equals object height',
    },
    {
      'value': 1,
      'name': 'Hanafi (Standard)',
      'desc': 'Asr begins when shadow length is twice the object height',
    },
  ];

  Future<void> _apply() async {
    school = _selected;
    fajrAdj = 0;
    sunriseAdj = 0;
    dhuhrAdj = 0;
    asrAdj = 0;
    maghribAdj = 0;
    ishaAdj = 0;
    for (int i = 0; i < adjustments.length; i++) {
      adjustments[i] = Duration.zero;
    }
    await saveAdjustments();
    change = true;
    await saveAllSettings();
    if (mounted) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const PrayerTimesScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      appBar: buildAppBar(
          context, 'School of Fiqh', const prayerTimeSettingsScreen(), null),
      body: Container(
        color: _offWhite,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _mintLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _mintGreen.withOpacity(0.4), width: 1),
                    ),
                    child: const Row(children: [
                      Icon(Icons.info_outline, size: 16, color: _navy),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This only affects the Asr prayer calculation.',
                          style: TextStyle(fontSize: 12, color: _textDark),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  ..._schools.map((s) {
                    final bool isSelected = _selected == s['value'];
                    return GestureDetector(
                      onTap: () => setState(() => _selected = s['value']),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected ? _navyMid : _white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color:
                                  isSelected ? _gold.withOpacity(0.6) : _border,
                              width: isSelected ? 1.5 : 1),
                          boxShadow: [
                            BoxShadow(
                                color: _navy.withOpacity(0.06),
                                blurRadius: 6,
                                offset: const Offset(0, 2))
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              margin: const EdgeInsets.only(top: 1),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? _gold : _offWhite,
                                border: Border.all(
                                    color: isSelected ? _gold : _border,
                                    width: 1.5),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check_rounded,
                                      size: 13, color: _navy)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s['name'],
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected ? _white : _textDark),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    s['desc'],
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: isSelected
                                            ? _white.withOpacity(0.6)
                                            : _textMid),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: const BoxDecoration(
                  color: _white,
                  border: Border(top: BorderSide(color: _border, width: 1))),
              child: ElevatedButton(
                onPressed: _apply,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: _navy,
                  foregroundColor: _gold,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Apply School',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
