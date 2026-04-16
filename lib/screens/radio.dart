import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:ihsan_app_final/screens/moreoptionsScreen.dart';
import 'package:ihsan_app_final/sharedWidgets.dart';
import 'dart:async';
import 'package:http/http.dart' as http;

// ── Full eMasjid station data ─────────────────────────────────────────
// Stream URLs follow: https://relay.emasjidlive.uk/{slug}
// Slugs taken directly from emasjidlive.co.uk/listen

class _Station {
  final String name;
  final String slug;
  final String city;
  final String type; // 'Masjid' | 'Madrasah' | 'Radio' | 'Quraan'
  const _Station({
    required this.name,
    required this.slug,
    required this.city,
    this.type = 'Masjid',
  });
  String get streamUrl => 'https://relay.emasjidlive.uk/$slug';
}

const List<_Station> _allStations = [
  // ── Bolton ──────────────────────────────────────────────────────────
  _Station(name: 'Masjid Al-Rahman', slug: 'alrahman', city: 'Bolton'),
  _Station(name: 'Masjid Ali', slug: 'masjidalibolton', city: 'Bolton'),
  _Station(name: 'Taiyabah Masjid', slug: 'taiyabahmasjid', city: 'Bolton'),
  _Station(name: 'Zakariyya Jaam\'e Masjid', slug: 'zjmbolton', city: 'Bolton'),
  _Station(name: 'Adam Masjid', slug: 'adammasjid', city: 'Bolton'),
  _Station(name: 'Al Falah Masjid', slug: 'alfalahbolton', city: 'Bolton'),
  _Station(name: 'Ashrafia Masjid', slug: 'ashrafiamasjid', city: 'Bolton'),
  _Station(name: 'Makki Masjid', slug: 'makkimasjidbolton', city: 'Bolton'),
  _Station(
      name: 'Bolton Darul Uloom',
      slug: 'boltondarululoom',
      city: 'Bolton',
      type: 'Madrasah'),
  _Station(
      name: 'Azhar Academy',
      slug: 'azharacademybolton',
      city: 'Bolton',
      type: 'Madrasah'),
  _Station(
      name: 'Tafseer-Raheemi (HLCE)',
      slug: 'tafseerraheemi_hlce',
      city: 'Bolton',
      type: 'Madrasah'),

  // ── Birmingham ──────────────────────────────────────────────────────
  _Station(
      name: 'Birmingham Jame Masjid',
      slug: 'birminghamjamemasjid',
      city: 'Birmingham'),
  _Station(
      name: 'Jami Mosque & Islamic Centre',
      slug: 'jamimosque',
      city: 'Birmingham'),
  _Station(
      name: 'Kings Heath Masjid', slug: 'kingsheathmasjid', city: 'Birmingham'),
  _Station(
      name: 'Masjid Esa Ibn Maryam',
      slug: 'masjidesaibnmaryam',
      city: 'Birmingham'),
  _Station(
      name: 'Masjid Naqeebul Islam',
      slug: 'masjidnaqeebulislam',
      city: 'Birmingham'),
  _Station(
      name: 'Masjid Al Falaah', slug: 'masjidalfalaah', city: 'Birmingham'),
  _Station(
      name: 'Masjid Sulayman bin Dawud',
      slug: 'masjidsulayman',
      city: 'Birmingham'),
  _Station(
      name: 'Masjid Taqwa Sparkbrook', slug: 'masjidtaqwa', city: 'Birmingham'),
  _Station(name: 'Masjid Ul Madni', slug: 'masjidulmadni', city: 'Birmingham'),
  _Station(
      name: 'Masjid Yousuf Sheldon',
      slug: 'masjidyousufsheldon',
      city: 'Birmingham'),
  _Station(name: 'Al-Habib Trust', slug: 'alhabib', city: 'Birmingham'),
  _Station(
      name: 'Great Barr Muslim Foundation', slug: 'gbmf', city: 'Birmingham'),

  // ── Bradford ────────────────────────────────────────────────────────
  _Station(
      name: 'Jamia Masjid Howard Street',
      slug: 'jamiamasjidbradford',
      city: 'Bradford'),
  _Station(name: 'Masjid at-Taqwa BD7', slug: 'attaqwa', city: 'Bradford'),
  _Station(
      name: 'Masjid Noor Toller Lane',
      slug: 'masjidnoorbradford',
      city: 'Bradford'),
  _Station(name: 'Masjid Quba', slug: 'masjidquba', city: 'Bradford'),
  _Station(name: 'Masjid Bilal BD8', slug: 'masjidbilal', city: 'Bradford'),
  _Station(
      name: 'Masjid-e-Usman', slug: 'masjideusmanbradford', city: 'Bradford'),
  _Station(
      name: 'Tawakkulia Jami Masjid',
      slug: 'tawakkuliaislamicsociety',
      city: 'Bradford'),
  _Station(name: 'Masjid Nimrah', slug: 'nimrah', city: 'Bradford'),
  _Station(
      name: 'Al Hidaya Academy',
      slug: 'alhidayaacademy',
      city: 'Bradford',
      type: 'Madrasah'),
  _Station(
      name: 'Al Mahad ul Islami',
      slug: 'almahadulislami',
      city: 'Bradford',
      type: 'Madrasah'),
  _Station(
      name: 'Masjid Noorul Islam BD7',
      slug: 'masjidnoorulislambradford',
      city: 'Bradford'),

  // ── Manchester ──────────────────────────────────────────────────────
  _Station(
      name: 'Masjid E Hidayah',
      slug: 'masjidehidayah_manchester',
      city: 'Manchester'),
  _Station(
      name: 'As-Salaam Centre', slug: 'assalaamcentre', city: 'Manchester'),
  _Station(
      name: 'Masjid E Noor Old Trafford',
      slug: 'masjidenoor_manchester',
      city: 'Manchester'),

  // ── Blackburn ───────────────────────────────────────────────────────
  _Station(name: 'Al Masjid Al Aqsa', slug: 'masjidalaqsa', city: 'Blackburn'),
  _Station(
      name: 'Masjid al-Momineen', slug: 'masjidalmomineen', city: 'Blackburn'),
  _Station(
      name: 'Masjid E Sajedeen', slug: 'masjidesajedeen', city: 'Blackburn'),
  _Station(
      name: 'Masjid-e-Quwwatul Islam',
      slug: 'masjidquwwatulislam',
      city: 'Blackburn'),
  _Station(name: 'Masjid-E-Rizwan', slug: 'masjiderizwan', city: 'Blackburn'),
  _Station(
      name: 'Masjid-e-Saliheen', slug: 'masjid_saliheen', city: 'Blackburn'),
  _Station(
      name: 'Masjide Noorul Islam',
      slug: 'masjidenoorulislam',
      city: 'Blackburn'),
  _Station(
      name: 'Masjid E Anisul Islam',
      slug: 'masjideanisulislam',
      city: 'Blackburn'),
  _Station(
      name: 'Jaame Masjid Blackburn',
      slug: 'jaamemasjidblackburn',
      city: 'Blackburn'),
  _Station(
      name: 'Markazul Uloom',
      slug: 'markazululoom',
      city: 'Blackburn',
      type: 'Madrasah'),

  // ── Dewsbury ────────────────────────────────────────────────────────
  _Station(
      name: 'Darul Ilm Thornhill Lees',
      slug: 'darulilmdewsbury',
      city: 'Dewsbury',
      type: 'Madrasah'),
  _Station(name: 'Ilaahi Masjid Hope Street', slug: 'ilaahi', city: 'Dewsbury'),
  _Station(
      name: 'Masjid Heera Thornhill', slug: 'masjidheera', city: 'Dewsbury'),
  _Station(name: 'Masjid Talha', slug: 'talha', city: 'Dewsbury'),
  _Station(name: 'Zakaria Masjid', slug: 'zakariamasjid', city: 'Dewsbury'),
  _Station(
      name: 'Masjid-E-Bilal', slug: 'masjidbilaldewsbury', city: 'Dewsbury'),
  _Station(name: 'Masjid-e-Umar', slug: 'meudewsbury', city: 'Dewsbury'),
  _Station(name: 'Masjid Ur Rahman', slug: 'masjidurrahman', city: 'Dewsbury'),

  // ── Leeds ───────────────────────────────────────────────────────────
  _Station(
      name: 'Shahjalal Jamia Masjid', slug: 'shahjalalleeds', city: 'Leeds'),
  _Station(name: 'Makki Masjid Leeds', slug: 'makkimasjidleeds', city: 'Leeds'),
  _Station(
      name: 'Masjid Ibraheem Beeston', slug: 'masjidibraheem', city: 'Leeds'),
  _Station(name: 'Masjid-E-Yusuf Gipton', slug: 'gkwa', city: 'Leeds'),

  // ── Sheffield ───────────────────────────────────────────────────────
  _Station(name: 'Makki Mosque', slug: 'makkimosque', city: 'Sheffield'),
  _Station(name: 'Markazi Jamia Masjid', slug: 'mjm', city: 'Sheffield'),
  _Station(name: 'Masjid Umar', slug: 'masjidumar', city: 'Sheffield'),
  _Station(
      name: 'Al-Huda Academy',
      slug: 'alhudaacademy',
      city: 'Sheffield',
      type: 'Madrasah'),
  _Station(
      name: 'Masjid Abu Bakr Tinsley',
      slug: 'masjidabubakr',
      city: 'Sheffield'),

  // ── Leicester ───────────────────────────────────────────────────────
  _Station(
      name: 'As-Salaam Trust (Peace Centre)',
      slug: 'peacecentre',
      city: 'Leicester'),
  _Station(
      name: 'Darul Arqam Educational Trust',
      slug: 'darularqameducationaltrust',
      city: 'Leicester'),
  _Station(name: 'Darul Ihsaan', slug: 'darulihsaan', city: 'Leicester'),
  _Station(name: 'Jame Masjid', slug: 'jamemasjid', city: 'Leicester'),
  _Station(name: 'Madani Masjid', slug: 'madanimasjid', city: 'Leicester'),
  _Station(
      name: 'Masjid Adam Oadby', slug: 'masjidadamoadby', city: 'Leicester'),
  _Station(name: 'Masjid Al Furqan', slug: 'masjidalfurqan', city: 'Leicester'),
  _Station(
      name: 'Masjid e Abdullah Ibn Mas\'ud',
      slug: 'abdullahibnmasud',
      city: 'Leicester'),
  _Station(
      name: 'Masjid Muadh Ibn Jabal', slug: 'muadhibnjabal', city: 'Leicester'),
  _Station(
      name: 'Masjid-ul-Imam-il-Bukhari', slug: 'bukhari', city: 'Leicester'),
  _Station(name: 'Masjid Aisha', slug: 'masjidaisha', city: 'Leicester'),

  // ── London East ─────────────────────────────────────────────────────
  _Station(
      name: 'Esha\'atul Islam Ford Sq',
      slug: 'eshaatulislam',
      city: 'London - East'),
  _Station(
      name: 'Hasanah Centre Stratford',
      slug: 'hasanahaid',
      city: 'London - East'),
  _Station(
      name: 'Leytonstone Masjid',
      slug: 'leytonstonemasjid',
      city: 'London - East'),
  _Station(
      name: 'Masjid Adam Ilford', slug: 'masjidadam', city: 'London - East'),
  _Station(
      name: 'Masjid Al-Hikmah Selwyn',
      slug: 'masjidalhikmah',
      city: 'London - East'),
  _Station(
      name: 'Masjid ul Hidayah Manor Park',
      slug: 'masjidulhidayah',
      city: 'London - East'),
  _Station(
      name: 'Masjid Yousuf Forest Gate',
      slug: 'masjidyousuf',
      city: 'London - East'),
  _Station(
      name: 'Masjid-E-Tauheed Manor Park',
      slug: 'masjidetauheed',
      city: 'London - East'),
  _Station(name: 'Seven Kings Masjid', slug: 'skmet', city: 'London - East'),
  _Station(
      name: 'Shah Jalal Mosque',
      slug: 'shahjalalmasjid',
      city: 'London - East'),
  _Station(
      name: 'Quwwat-ul-Islam Forest Gate',
      slug: 'qislondon',
      city: 'London - East'),
  _Station(
      name: 'Newbury Park Masjid',
      slug: 'newburyparkmasjid',
      city: 'London - East'),
  _Station(
      name: 'Masjid-e-Da\'watul Islam Ilford',
      slug: 'balfourroadmasjid',
      city: 'London - East'),
  _Station(
      name: 'Markaz ud Dawat Wal Irshad',
      slug: 'plashetgrovemasjid',
      city: 'London - East'),

  // ── London NW ───────────────────────────────────────────────────────
  _Station(
      name: 'Islamic Cultural Centre Wembley',
      slug: 'iccwembley',
      city: 'London - North West'),

  // ── Glasgow ─────────────────────────────────────────────────────────
  _Station(
      name: 'Glasgow Central Mosque', slug: 'glasgowmosque', city: 'Glasgow'),
  _Station(
      name: 'Islamic Education Trust Cumbernauld',
      slug: 'cumbernauldmasjid',
      city: 'Glasgow'),
  _Station(
      name: 'Newton Mearns Islamic Centre',
      slug: 'nmislamiccentre',
      city: 'Glasgow'),
  _Station(
      name: 'Zakariyya Masjid Motherwell',
      slug: 'zmmasjidmotherwell',
      city: 'Glasgow'),

  // ── Batley ──────────────────────────────────────────────────────────
  _Station(
      name: 'Al Mubarak Radio',
      slug: 'almubarakradio',
      city: 'Batley',
      type: 'Radio'),
  _Station(
      name: 'Al Mubarak Radio Live Shows',
      slug: 'almubarakradiolive',
      city: 'Batley',
      type: 'Radio'),
  _Station(name: 'ICWA - Jame Masjid', slug: 'icwa', city: 'Batley'),
  _Station(name: 'Snowdon St. Masjid', slug: 'snowdonmasjid', city: 'Batley'),

  // ── Huddersfield ────────────────────────────────────────────────────
  _Station(
      name: 'Jamia Masjid Noor', slug: 'jamiamasjidnoor', city: 'Huddersfield'),
  _Station(name: 'Masjid Usman', slug: 'masjidusman', city: 'Huddersfield'),

  // ── Luton ───────────────────────────────────────────────────────────
  _Station(name: 'Masjid As Sunnah', slug: 'masjidassunnah', city: 'Luton'),
  _Station(name: 'Masjid Noor', slug: 'masjidnoorluton', city: 'Luton'),
  _Station(name: 'Zakariya Masjid', slug: 'zakariyamasjid', city: 'Luton'),

  // ── Derby ───────────────────────────────────────────────────────────
  _Station(
      name: 'Masjid Al-Farooq', slug: 'masjidalfarooqderby', city: 'Derby'),

  // ── Walsall ─────────────────────────────────────────────────────────
  _Station(
      name: 'Al Hidayah Foundation',
      slug: 'alhidayahfoundation',
      city: 'Walsall'),
  _Station(
      name: 'Bilal Academy',
      slug: 'bilalacademy',
      city: 'Walsall',
      type: 'Madrasah'),
  _Station(
      name: 'Masjid Al Farouq', slug: 'masjidalfarouqwalsall', city: 'Walsall'),

  // ── Oldham ──────────────────────────────────────────────────────────
  _Station(
      name: 'Nusratul Islam Masjid', slug: 'nusratulislam', city: 'Oldham'),
  _Station(
      name: 'Madinatul Ilm',
      slug: 'madinatulilm',
      city: 'Oldham',
      type: 'Madrasah'),

  // ── Rotherham ───────────────────────────────────────────────────────
  _Station(
      name: 'Masjid Ibrahim Ferham',
      slug: 'masjidibrahimrotherham',
      city: 'Rotherham'),

  // ── Nottingham ──────────────────────────────────────────────────────
  _Station(name: 'Masjid Al Khazra', slug: 'al_khazra', city: 'Nottingham'),

  // ── Peterborough ────────────────────────────────────────────────────
  _Station(name: 'Darassalaam', slug: 'darassalaam', city: 'Peterborough'),

  // ── Scunthorpe ──────────────────────────────────────────────────────
  _Station(
      name: 'Scunthorpe Central Mosque',
      slug: 'scunthorpecentralmosque',
      city: 'Scunthorpe'),

  // ── Tunbridge Wells ─────────────────────────────────────────────────
  _Station(
      name: 'Tunbridge Wells Mosque',
      slug: 'tunbridgewellsmosque',
      city: 'Tunbridge Wells'),

  // ── Special / Quraan ────────────────────────────────────────────────
  _Station(
      name: 'Qur\'aan Recitation',
      slug: 'quraan',
      city: 'Qur\'aan',
      type: 'Quraan'),
];

// All unique cities in sorted order (Qur'aan pinned first)
List<String> get _allCities {
  final cities = _allStations.map((s) => s.city).toSet().toList();
  cities.remove("Qur'aan");
  cities.sort();
  return ["All Cities", "Qur'aan", ...cities];
}

// ══════════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════════
class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key});
  @override
  _RadioScreenState createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen>
    with TickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();
  int _activeIndex = -1; // index within _filteredStations
  bool _isLoading = false;
  String _selectedCity = 'All Cities';
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // ── Live status ──────────────────────────────────────────────────────
  // null = still checking, true = live, false = offline
  final Map<String, bool?> _liveStatus = {};
  bool _isCheckingLive = false;
  int _checkedCount = 0;

  // ── Favourites ───────────────────────────────────────────────────────
  final Set<String> _favourites = {};

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // ── Palette ──────────────────────────────────────────────────────────
  static const Color navy = Color.fromARGB(255, 10, 25, 60);
  static const Color navyMid = Color.fromARGB(255, 18, 42, 95);
  static const Color gold = Color.fromARGB(255, 212, 175, 95);
  static const Color goldLight = Color.fromARGB(255, 252, 243, 210);
  static const Color skyBlue = Color.fromARGB(255, 100, 180, 240);
  static const Color skyLight = Color.fromARGB(255, 220, 240, 255);
  static const Color mintGreen = Color.fromARGB(255, 72, 200, 155);
  static const Color mintLight = Color.fromARGB(255, 210, 245, 232);
  static const Color white = Color.fromARGB(255, 255, 255, 255);
  static const Color offWhite = Color.fromARGB(255, 247, 249, 255);
  static const Color textDark = Color.fromARGB(255, 15, 30, 65);
  static const Color textMid = Color.fromARGB(255, 90, 115, 160);
  static const Color border = Color.fromARGB(255, 210, 220, 240);
  static const Color liveGreen = Color.fromARGB(255, 34, 197, 94);
  static const Color liveGreenBg = Color.fromARGB(255, 220, 252, 231);
  static const Color offlineRed = Color.fromARGB(255, 239, 68, 68);
  static const Color offlineRedBg = Color.fromARGB(255, 254, 226, 226);

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Start checking live status after first frame (keep startup fast)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAllLive();
    });
  }

  @override
  void dispose() {
    _player.dispose();
    _pulseCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Sends a HEAD request to each stream URL. Concurrency-limited to 10 at a time.
  Future<void> _checkAllLive() async {
    if (!mounted) return;
    setState(() {
      _isCheckingLive = true;
      _checkedCount = 0;
      for (final s in _allStations) {
        _liveStatus[s.slug] = null; // reset to "checking"
      }
    });

    const concurrency = 10;
    final client = http.Client();
    try {
      final stations = List<_Station>.from(_allStations);
      int i = 0;

      while (i < stations.length) {
        final batch = stations.skip(i).take(concurrency).toList();
        await Future.wait(batch.map((station) async {
          bool isLive = false;
          try {
            final response = await http
                .head(Uri.parse(station.streamUrl))
                .timeout(const Duration(seconds: 6));
            // 200 or any 2xx/3xx typically means stream is up
            isLive = response.statusCode >= 200 && response.statusCode < 400;
          } catch (_) {
            isLive = false;
          }
          if (mounted) {
            setState(() {
              _liveStatus[station.slug] = isLive;
              _checkedCount++;
            });
          }
        }));
        i += concurrency;
      }
    } finally {
      client.close();
      if (mounted) {
        setState(() => _isCheckingLive = false);
      }
    }
  }

  List<_Station> get _filteredStations {
    var list = _allStations.where((s) {
      final matchCity =
          _selectedCity == 'All Cities' || s.city == _selectedCity;
      final matchSearch = _searchQuery.isEmpty ||
          s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.city.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchCity && matchSearch;
    }).toList();

    // Sort: favourites first, then live, then by type, then alphabetical
    list.sort((a, b) {
      final aFav = _favourites.contains(a.slug);
      final bFav = _favourites.contains(b.slug);
      if (aFav != bFav) return aFav ? -1 : 1;
      final aLive = _liveStatus[a.slug] == true;
      final bLive = _liveStatus[b.slug] == true;
      if (aLive != bLive) return aLive ? -1 : 1;
      const order = ['Masjid', 'Radio', 'Quraan', 'Madrasah'];
      if (a.type != b.type) {
        return order.indexOf(a.type).compareTo(order.indexOf(b.type));
      }
      return a.name.compareTo(b.name);
    });
    return list;
  }

  _Station? get _activeStation =>
      _activeIndex >= 0 && _activeIndex < _filteredStations.length
          ? _filteredStations[_activeIndex]
          : null;

  Future<void> _tap(int index) async {
    HapticFeedback.lightImpact();
    final stations = _filteredStations;

    if (_activeIndex == index) {
      await _player.stop();
      setState(() => _activeIndex = -1);
      return;
    }

    if (_activeIndex != -1) await _player.stop();
    setState(() {
      _activeIndex = index;
      _isLoading = true;
    });

    try {
      await _player.setUrl(stations[index].streamUrl);
      await _player.play();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: gold, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text('Could not connect to ${stations[index].name}',
                  style: const TextStyle(color: white))),
        ]),
        backgroundColor: navyMid,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ));
      setState(() => _activeIndex = -1);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _typeColor(_Station s) {
    switch (s.type) {
      case 'Radio':
        return skyBlue;
      case 'Quraan':
        return gold;
      case 'Madrasah':
        return mintGreen;
      default:
        return const Color.fromARGB(255, 140, 160, 210);
    }
  }

  Color _typeBg(_Station s) {
    switch (s.type) {
      case 'Radio':
        return skyLight;
      case 'Quraan':
        return goldLight;
      case 'Madrasah':
        return mintLight;
      default:
        return offWhite;
    }
  }

  IconData _typeIcon(_Station s) {
    switch (s.type) {
      case 'Radio':
        return Icons.radio_outlined;
      case 'Quraan':
        return Icons.menu_book_rounded;
      case 'Madrasah':
        return Icons.school_outlined;
      default:
        return Icons.mosque_outlined;
    }
  }

  /// Builds the live status pill shown on the far right of each card.
  Widget _livePill(String slug) {
    final status = _liveStatus[slug];

    if (status == null) {
      // Still checking — small pulsing dot
      return AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, __) => Opacity(
          opacity: _pulseAnim.value,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: textMid.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }

    final isLive = status == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isLive ? liveGreenBg : offlineRedBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color:
              isLive ? liveGreen.withOpacity(0.5) : offlineRed.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive)
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: liveGreen.withOpacity(_pulseAnim.value),
                  shape: BoxShape.circle,
                ),
              ),
            )
          else
            Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.only(right: 4),
              decoration: const BoxDecoration(
                color: offlineRed,
                shape: BoxShape.circle,
              ),
            ),
          Text(
            isLive ? 'LIVE' : 'OFF',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: isLive ? liveGreen : offlineRed,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stations = _filteredStations;
    final liveCount = _liveStatus.values.where((v) => v == true).length;

    return Scaffold(
      backgroundColor: navy,
      appBar: buildAppBar(
          context, 'Mosque Radio', const MoreOptionsScreen(), screenFrom),
      body: Column(
        children: [
          const QurbaniBanner(),

          // ── LIVE CHECK BANNER ─────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: _isCheckingLive
                ? Container(
                    key: const ValueKey('checking'),
                    color: navyMid,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                color: gold,
                                strokeWidth: 1.5,
                                value: _allStations.isEmpty
                                    ? null
                                    : _checkedCount / _allStations.length,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Checking for live masjids… ($_checkedCount/${_allStations.length})',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: gold.withOpacity(0.9),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: _allStations.isEmpty
                                ? null
                                : _checkedCount / _allStations.length,
                            backgroundColor: navy.withOpacity(0.5),
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(gold),
                            minHeight: 3,
                          ),
                        ),
                      ],
                    ),
                  )
                : liveCount > 0
                    ? Container(
                        key: const ValueKey('done'),
                        color: navyMid,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 7),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: liveGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$liveCount masjid${liveCount == 1 ? '' : 's'} live now',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: liveGreen,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('empty')),
          ),

          // ── HERO — now-playing card ─────────────────────────────────
          Container(
            width: double.infinity,
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
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
            child: Column(
              children: [
                // Now-playing card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: navyMid,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _activeStation != null
                          ? gold.withOpacity(0.6)
                          : gold.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Play/stop button
                      GestureDetector(
                        onTap: _activeStation == null || _isLoading
                            ? null
                            : () => _tap(_activeIndex),
                        child: AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (_, __) => Transform.scale(
                            scale: _activeStation != null && !_isLoading
                                ? _pulseAnim.value
                                : 1.0,
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _activeStation != null
                                    ? gold.withOpacity(0.15)
                                    : white.withOpacity(0.06),
                                border: Border.all(
                                  color: _activeStation != null
                                      ? gold
                                      : white.withOpacity(0.2),
                                  width: 2,
                                ),
                                boxShadow: _activeStation != null
                                    ? [
                                        BoxShadow(
                                          color: gold.withOpacity(0.25),
                                          blurRadius: 16,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                            color: gold, strokeWidth: 2.5),
                                      )
                                    : Icon(
                                        _activeStation != null
                                            ? Icons.stop_rounded
                                            : Icons.radio_rounded,
                                        color: _activeStation != null
                                            ? gold
                                            : white.withOpacity(0.3),
                                        size: 30,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 14),

                      // Station info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (_activeStation != null)
                                  Container(
                                    width: 7,
                                    height: 7,
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: const BoxDecoration(
                                      color: mintGreen,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                Text(
                                  _activeStation != null
                                      ? 'NOW PLAYING'
                                      : 'RADIO',
                                  style: TextStyle(
                                    fontSize: 9,
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.w700,
                                    color: _activeStation != null
                                        ? mintGreen
                                        : white.withOpacity(0.4),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _activeStation?.name ?? 'No station selected',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _activeStation != null
                                    ? white
                                    : white.withOpacity(0.35),
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_activeStation != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                _activeStation!.city,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: gold.withOpacity(0.75),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Type badge
                      if (_activeStation != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color:
                                _typeColor(_activeStation!).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  _typeColor(_activeStation!).withOpacity(0.4),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _activeStation!.type,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _typeColor(_activeStation!),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── CITY + SEARCH CONTROLS ──────────────────────────────────
          Container(
            color: offWhite,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Column(
              children: [
                // City dropdown
                Container(
                  decoration: BoxDecoration(
                    color: white,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: border, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: navy.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: ButtonTheme(
                      alignedDropdown: true,
                      child: DropdownButton<String>(
                        value: _selectedCity,
                        isExpanded: true,
                        borderRadius: BorderRadius.circular(13),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: navy, size: 22),
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textDark),
                        dropdownColor: white,
                        items: _allCities.map((city) {
                          final bool isSelected = city == _selectedCity;
                          final bool isSpecial =
                              city == 'All Cities' || city == "Qur'aan";
                          return DropdownMenuItem(
                            value: city,
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? navy
                                        : isSpecial
                                            ? goldLight
                                            : offWhite,
                                    borderRadius: BorderRadius.circular(7),
                                    border: Border.all(
                                      color: isSelected
                                          ? gold.withOpacity(0.5)
                                          : border,
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    city == "Qur'aan"
                                        ? Icons.menu_book_rounded
                                        : city == 'All Cities'
                                            ? Icons.public_rounded
                                            : Icons.location_city_rounded,
                                    size: 14,
                                    color: isSelected
                                        ? gold
                                        : isSpecial
                                            ? const Color.fromARGB(
                                                255, 140, 105, 30)
                                            : textMid,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    city,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected ? navy : textDark,
                                    ),
                                  ),
                                ),
                                // Station count badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected ? gold : offWhite,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    city == 'All Cities'
                                        ? '${_allStations.length}'
                                        : '${_allStations.where((s) => s.city == city).length}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected ? navy : textMid,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedCity = val;
                              _activeIndex = -1;
                            });
                          }
                        },
                        selectedItemBuilder: (context) =>
                            _allCities.map((city) {
                          return Row(
                            children: [
                              Icon(
                                city == "Qur'aan"
                                    ? Icons.menu_book_rounded
                                    : city == 'All Cities'
                                        ? Icons.public_rounded
                                        : Icons.location_city_rounded,
                                size: 16,
                                color: navy,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                city,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: navy),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                city == 'All Cities'
                                    ? '(${_allStations.length} stations)'
                                    : '(${_allStations.where((s) => s.city == city).length} stations)',
                                style: const TextStyle(
                                    fontSize: 12, color: textMid),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Search bar
                Container(
                  decoration: BoxDecoration(
                    color: white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _searchQuery.isNotEmpty
                          ? gold.withOpacity(0.6)
                          : border,
                      width: _searchQuery.isNotEmpty ? 1.5 : 1,
                    ),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(fontSize: 14, color: textDark),
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search mosques…',
                      hintStyle: const TextStyle(color: textMid, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: textMid, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                              child: const Icon(Icons.close_rounded,
                                  color: textMid, size: 18),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Results count + type legend
                Row(
                  children: [
                    Text(
                      '${stations.length} station${stations.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: textMid,
                          letterSpacing: 0.5),
                    ),
                    const Spacer(),
                    _legend('Masjid', const Color.fromARGB(255, 140, 160, 210),
                        offWhite),
                    const SizedBox(width: 6),
                    _legend('Radio', skyBlue, skyLight),
                    const SizedBox(width: 6),
                    _legend('Madrasah', mintGreen, mintLight),
                    const SizedBox(width: 6),
                    _legend('Qur\'aan', gold, goldLight),
                  ],
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),

          // ── STATION LIST ────────────────────────────────────────────
          Expanded(
            child: Container(
              color: offWhite,
              child: stations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded,
                              size: 48, color: textMid.withOpacity(0.3)),
                          const SizedBox(height: 12),
                          const Text('No stations found',
                              style: TextStyle(
                                  color: textMid,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          const Text('Try a different city or search term',
                              style: TextStyle(color: textMid, fontSize: 12)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                      itemCount: stations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final station = stations[index];
                        final bool isActive = _activeIndex == index;
                        final bool isLive = _liveStatus[station.slug] == true;
                        final bool isFav = _favourites.contains(station.slug);

                        return GestureDetector(
                          onTap: () => _tap(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? navy
                                  : isFav
                                      ? goldLight.withOpacity(0.7)
                                      : isLive
                                          ? liveGreenBg.withOpacity(0.5)
                                          : white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isActive
                                    ? gold.withOpacity(0.6)
                                    : isFav
                                        ? gold.withOpacity(0.4)
                                        : isLive
                                            ? liveGreen.withOpacity(0.3)
                                            : border,
                                width: isActive || isFav ? 1.5 : 1,
                              ),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: navy.withOpacity(0.2),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [
                                      BoxShadow(
                                        color: navy.withOpacity(0.05),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 11),
                              child: Row(
                                children: [
                                  // Icon badge
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? _typeColor(station)
                                              .withOpacity(0.15)
                                          : _typeBg(station),
                                      borderRadius: BorderRadius.circular(11),
                                      border: Border.all(
                                        color: isActive
                                            ? _typeColor(station)
                                                .withOpacity(0.5)
                                            : _typeColor(station)
                                                .withOpacity(0.25),
                                        width: 1,
                                      ),
                                    ),
                                    child: isActive && _isLoading
                                        ? Center(
                                            child: SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                color: _typeColor(station),
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          )
                                        : Icon(
                                            isActive
                                                ? Icons.stop_rounded
                                                : _typeIcon(station),
                                            size: 20,
                                            color: _typeColor(station),
                                          ),
                                  ),

                                  const SizedBox(width: 12),

                                  // Name + city
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          station.name,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: isActive ? white : textDark,
                                            height: 1.2,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          station.city,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isActive
                                                ? gold.withOpacity(0.7)
                                                : textMid,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  // Favourite button
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        if (isFav) {
                                          _favourites.remove(station.slug);
                                        } else {
                                          _favourites.add(station.slug);
                                        }
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: isFav
                                            ? gold.withOpacity(
                                                isActive ? 0.25 : 0.12)
                                            : Colors.transparent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isFav
                                            ? Icons.star_rounded
                                            : Icons.star_outline_rounded,
                                        size: 20,
                                        color: isFav
                                            ? gold
                                            : isActive
                                                ? white.withOpacity(0.3)
                                                : textMid.withOpacity(0.35),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 4),

                                  // Right: type badge + LIVE pill + play indicator
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      // Type badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? _typeColor(station)
                                                  .withOpacity(0.2)
                                              : _typeBg(station),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                            color: _typeColor(station)
                                                .withOpacity(
                                                    isActive ? 0.5 : 0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          station.type,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                            color: _typeColor(station),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 4),

                                      // LIVE / OFFLINE pill
                                      _livePill(station.slug),

                                      // Playing wave bars
                                      if (isActive && !_isLoading)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: List.generate(
                                              3,
                                              (i) => AnimatedBuilder(
                                                animation: _pulseAnim,
                                                builder: (_, __) => Container(
                                                  width: 3,
                                                  height: 3 +
                                                      (i * 2) *
                                                          (_pulseAnim.value -
                                                              0.85) /
                                                          0.15,
                                                  margin: const EdgeInsets
                                                      .symmetric(horizontal: 1),
                                                  decoration: BoxDecoration(
                                                    color: mintGreen,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            1.5),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
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

  Widget _legend(String label, Color color, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
      );
}
