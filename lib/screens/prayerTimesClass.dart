import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

String townName = "";
double latitude = 0;
double longitude = 0;
int method = 2;
int school = 1;

DateTime DateForCalc = DateTime.now();
int month = DateForCalc.month;
int year = DateForCalc.year;

int fajrAdj = 0;
int sunriseAdj = 0;
int dhuhrAdj = 0;
int asrAdj = 0;
int maghribAdj = 0;
int ishaAdj = 0;

Future<void> saveAdjustments() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('fajrAdj', fajrAdj);
  await prefs.setInt('sunriseAdj', sunriseAdj);
  await prefs.setInt('dhuhrAdj', dhuhrAdj);
  await prefs.setInt('asrAdj', asrAdj);
  await prefs.setInt('maghribAdj', maghribAdj);
  await prefs.setInt('ishaAdj', ishaAdj);
}

Future<void> loadAdjustments() async {
  final prefs = await SharedPreferences.getInstance();
  fajrAdj = prefs.getInt('fajrAdj') ?? 0;
  sunriseAdj = prefs.getInt('sunriseAdj') ?? 0;
  dhuhrAdj = prefs.getInt('dhuhrAdj') ?? 0;
  asrAdj = prefs.getInt('asrAdj') ?? 0;
  maghribAdj = prefs.getInt('maghribAdj') ?? 0;
  ishaAdj = prefs.getInt('ishaAdj') ?? 0;

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
    return {'latitude': latitude, 'longitude': longitude};
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

  PrayerTimesJamaat({
    required this.date,
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
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
  final String url =
      'https://nominatim.openstreetmap.org/search?q=$cityName&format=json&limit=1';

  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);

    if (data.isNotEmpty) {
      final double latitude = double.parse(data[0]['lat']);
      final double longitude = double.parse(data[0]['lon']);

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
  loadAdjustments();

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
      loadAdjustments();

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
