import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

String townName = "";
double latitude = 0;
double longitude = 0;
int method = 2;
int school = 1;

String mosqueIdFind = '';

String? tempMosqueId;

DateTime DateForCalc = DateTime.now();
int month = DateForCalc.month;
int year = DateForCalc.year;

int fajrAdj = 0;
int sunriseAdj = 0;
int dhuhrAdj = 0;
int asrAdj = 0;
int maghribAdj = 0;
int ishaAdj = 0;

// ==================== MOSQUE PREFERENCE HELPERS ====================

Future<void> saveLocalMosqueId(String mosqueId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('localMosqueId', mosqueId);
}

Future<String> getLocalMosqueId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('localMosqueId') ?? '';
}

Future<void> clearLocalMosqueId() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('localMosqueId');
}

// Helper to get mosque name from ID
Future<String> getMosqueNameFromId(String mosqueId) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('mosques')
        .doc(mosqueId)
        .get();
    return doc.data()?['name'] ?? 'Unknown Mosque';
  } catch (e) {
    return 'Unknown Mosque';
  }
}

// Add this to prayerTimesClass.dart
// Helper to fetch mosque prayer times and convert to PrayerTimes format
Future<List<PrayerTimes>> fetchMosquePrayerTimes(String mosqueId) async {
  final firestore = FirebaseFirestore.instance;
  final snapshot = await firestore
      .collection('mosques')
      .doc(mosqueId)
      .collection('prayerTimes')
      .get();

  List<PrayerTimes> mosqueTimes = [];

  // IMPORTANT: Load latest adjustments before applying
  await loadAdjustments();

  for (var doc in snapshot.docs) {
    final data = doc.data();

    // Convert Firestore date (yyyy-MM-dd) to display format (dd-MM-yyyy)
    final dateParts = doc.id.split('-');
    final displayDate = '${dateParts[2]}-${dateParts[1]}-${dateParts[0]}';

    // Get raw times from mosque
    String fajrTime = data['fajrB'] ?? '';
    String sunriseTime = data['sunrise'] ?? '';
    String dhuhrTime = data['dhuhrB'] ?? '';
    String asrTime = data['asrB'] ?? '';
    String maghribTime = data['maghrib'] ?? '';
    String ishaTime = data['ishaB'] ?? '';

    // Apply user adjustments from SharedPreferences
    List<String> rawTimes = [
      fajrTime,
      sunriseTime,
      dhuhrTime,
      asrTime,
      maghribTime,
      ishaTime
    ];

    // This function uses the global 'adjustments' list
    List<String> adjustedTimes =
        adjustPrayerTimesIndividually(rawTimes, adjustments);

    mosqueTimes.add(PrayerTimes(
      date: displayDate,
      fajr: adjustedTimes[0],
      sunrise: adjustedTimes[1],
      dhuhr: adjustedTimes[2],
      asr: adjustedTimes[3],
      maghrib: adjustedTimes[4],
      isha: adjustedTimes[5],
    ));
  }

  // Sort by date
  mosqueTimes.sort((a, b) {
    final aDate = DateFormat('dd-MM-yyyy').parse(a.date);
    final bDate = DateFormat('dd-MM-yyyy').parse(b.date);
    return aDate.compareTo(bDate);
  });

  return mosqueTimes;
}

Future<void> saveMonthlyPrayerTimes(List<PrayerTimes> prayerTimesList) async {
  final prefs = await SharedPreferences.getInstance();

  if (prayerTimesList.isEmpty) return;

  final DateTime firstDate =
      DateFormat('dd-MM-yyyy').parse(prayerTimesList.first.date);
  final String yearKey = 'prayerTimes_${firstDate.year}';

  List<Map<String, dynamic>> jsonList =
      prayerTimesList.map((prayer) => prayer.toJson()).toList();

  String jsonString = jsonEncode(jsonList);
  await prefs.setString(yearKey, jsonString);
}

Future<List<PrayerTimes>> loadMonthlyPrayerTimes() async {
  final prefs = await SharedPreferences.getInstance();

  final int currentYear = DateTime.now().year;
  final String yearKey = 'prayerTimes_$currentYear';

  String? jsonString = prefs.getString(yearKey);

  if (jsonString == null) return [];

  List<dynamic> jsonList = jsonDecode(jsonString);
  return jsonList.map((json) => PrayerTimes.fromJson(json)).toList();
}

Future<void> saveTownName(String townName) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('townName', townName);
}

Future<String> getTownName() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('townName') ?? "";
}

Future<void> saveAdjustments() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('fajrAdjs', fajrAdj);
  await prefs.setInt('sunriseAdjs', sunriseAdj);
  await prefs.setInt('dhuhrAdjs', dhuhrAdj);
  await prefs.setInt('asrAdjs', asrAdj);
  await prefs.setInt('maghribAdjs', maghribAdj);
  await prefs.setInt('ishaAdjs', ishaAdj);
}

Future<void> loadAdjustments() async {
  final prefs = await SharedPreferences.getInstance();
  fajrAdj = prefs.getInt('fajrAdjs') ?? 0;
  sunriseAdj = prefs.getInt('sunriseAdjs') ?? 0;
  dhuhrAdj = prefs.getInt('dhuhrAdjs') ?? 0;
  asrAdj = prefs.getInt('asrAdjs') ?? 0;
  maghribAdj = prefs.getInt('maghribAdjs') ?? 0;
  ishaAdj = prefs.getInt('ishaAdjs') ?? 0;

  adjustments = [
    Duration(minutes: fajrAdj),
    Duration(minutes: sunriseAdj),
    Duration(minutes: dhuhrAdj),
    Duration(minutes: asrAdj),
    Duration(minutes: maghribAdj),
    Duration(minutes: ishaAdj),
  ];
}

List<Duration> adjustments = [
  Duration(minutes: fajrAdj),
  Duration(minutes: sunriseAdj),
  Duration(minutes: dhuhrAdj),
  Duration(minutes: asrAdj),
  Duration(minutes: maghribAdj),
  Duration(minutes: ishaAdj)
];

Future<void> updateTownNameFromCoordinates(
    double latitude, double longitude) async {
  try {
    final String apiKey = 'AIzaSyBgsjMh_ojTBOMxLkSk5NSNYO7qSogbjdw';
    final url = 'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=$latitude,$longitude&key=$apiKey';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      townName = 'Unknown Location';
      return;
    }

    final data = jsonDecode(response.body);

    final compound = data['plus_code']?['compound_code'];
    if (compound != null) {
      final parts = compound.split(' ');
      if (parts.length >= 2) {
        final area = parts.sublist(1).join(' ').replaceAll(', UK', '').trim();

        townName = area;
        await saveTownName(townName);
        return;
      }
    }

    for (var result in data['results'] ?? []) {
      for (var component in result['address_components']) {
        final types = List<String>.from(component['types']);

        if (types.contains('postal_town') ||
            types.contains('locality') ||
            types.contains('administrative_area_level_2')) {
          townName = component['long_name'];
          await saveTownName(townName);
          return;
        }
      }
    }

    townName = 'Unknown Location';
    await saveTownName(townName);
  } catch (e) {
    townName = 'Unknown Location';
  }
}

Future<void> saveLocation(double latitude, double longitude) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble('latitude', latitude);
  await prefs.setDouble('longitude', longitude);
}

Future<Map<String, double>?> getLastKnownLocation() async {
  final prefs = await SharedPreferences.getInstance();

  final latitude = prefs.getDouble('latitude');
  final longitude = prefs.getDouble('longitude');

  if (latitude != null && longitude != null) {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  return null;
}

class PrayerTimesJamaat {
  String date;
  String fajr;
  String sunrise;
  String dhuhr;
  String asr;
  String maghrib;
  String isha;
  List<String>? jummahTimes;

  PrayerTimesJamaat({
    required this.date,
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    this.jummahTimes,
  });
}

class PrayerTimes {
  String date;
  String fajr;
  String sunrise;
  String dhuhr;
  String asr;
  String maghrib;
  String isha;

  PrayerTimes({
    required this.date,
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  static String removeGMT(String time) {
    return time.replaceAll(" (GMT)", "").trim();
  }

  Map<String, dynamic> toJson() {
    return {
      'date': {
        'gregorian': {
          'date': date,
        }
      },
      'timings': {
        'Fajr': fajr,
        'Sunrise': sunrise,
        'Dhuhr': dhuhr,
        'Asr': asr,
        'Maghrib': maghrib,
        'Isha': isha,
      }
    };
  }

  factory PrayerTimes.fromJson(Map<String, dynamic> json) {
    return PrayerTimes(
      date: json['date']['gregorian']['date'],
      fajr: json['timings']['Fajr'],
      sunrise: json['timings']['Sunrise'],
      dhuhr: json['timings']['Dhuhr'],
      asr: json['timings']['Asr'],
      maghrib: json['timings']['Maghrib'],
      isha: json['timings']['Isha'],
    );
  }
}

DateTime stringToDateTime(String time) {
  return DateFormat.Hm().parse(time);
}

String dateTimeToString(DateTime time) {
  return DateFormat.Hm().format(time);
}

List<String> adjustPrayerTimesIndividually(
    List<String> prayerTimes, List<Duration> adjustments) {
  if (prayerTimes.length != adjustments.length) {
    throw Exception(
        'Prayer times and adjustments lists must have the same length.');
  }

  return List.generate(prayerTimes.length, (index) {
    DateTime dateTime = stringToDateTime(prayerTimes[index]);
    DateTime adjustedTime = dateTime.add(adjustments[index]);
    return dateTimeToString(adjustedTime);
  });
}

Future<List<double>> getLatLngFromCity(String cityName) async {
  final String apiKey = 'AIzaSyBgsjMh_ojTBOMxLkSk5NSNYO7qSogbjdw';
  final String url =
      'https://maps.googleapis.com/maps/api/geocode/json?address=$cityName&key=$apiKey';

  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);

    if (data['results'] != null && (data['results'] as List).isNotEmpty) {
      final location = data['results'][0]['geometry']['location'];
      final double latitude = location['lat'];
      final double longitude = location['lng'];

      return [latitude, longitude];
    } else {
      throw Exception('No results found for the provided city.');
    }
  } else {
    throw Exception('Failed to fetch location data.');
  }
}

class PrayerTime {
  final String name;
  String time;
  String jamaatTime;

  PrayerTime(this.name, this.time, this.jamaatTime);
}

Future<List<PrayerTimes>> fetchMonthlyPrayerTimes(double latitude,
    double longitude, int method, int school, int year, int month) async {
  final String url =
      'https://api.aladhan.com/v1/calendar?latitude=$latitude&longitude=$longitude&method=$method&school=$school&year=$year&month=$month';
  final response = await http.get(Uri.parse(url));
  await loadAdjustments();

  if (response.statusCode == 200) {
    final json = jsonDecode(response.body);
    List<PrayerTimes> monthlyPrayerTimes = [];
    for (var day in json['data']) {
      PrayerTimes prayerTimes = PrayerTimes.fromJson(day);

      prayerTimes.fajr = PrayerTimes.removeGMT(prayerTimes.fajr);
      prayerTimes.sunrise = PrayerTimes.removeGMT(prayerTimes.sunrise);
      prayerTimes.dhuhr = PrayerTimes.removeGMT(prayerTimes.dhuhr);
      prayerTimes.asr = PrayerTimes.removeGMT(prayerTimes.asr);
      prayerTimes.maghrib = PrayerTimes.removeGMT(prayerTimes.maghrib);
      prayerTimes.isha = PrayerTimes.removeGMT(prayerTimes.isha);

      List<String> prayerTimesList = [
        prayerTimes.fajr,
        prayerTimes.sunrise,
        prayerTimes.dhuhr,
        prayerTimes.asr,
        prayerTimes.maghrib,
        prayerTimes.isha
      ];

      List<String> adjustedTimes =
          adjustPrayerTimesIndividually(prayerTimesList, adjustments);

      prayerTimes.fajr = adjustedTimes[0];
      prayerTimes.sunrise = adjustedTimes[1];
      prayerTimes.dhuhr = adjustedTimes[2];
      prayerTimes.asr = adjustedTimes[3];
      prayerTimes.maghrib = adjustedTimes[4];
      prayerTimes.isha = adjustedTimes[5];

      monthlyPrayerTimes.add(prayerTimes);
    }
    return monthlyPrayerTimes;
  } else {
    throw Exception('Failed to load prayer times');
  }
}
