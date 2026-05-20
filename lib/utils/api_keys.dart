import 'package:cloud_functions/cloud_functions.dart';

class ApiKeys {
  ApiKeys._(); // prevent instantiation

  static String? _mapsKey;

  /// Call this once (e.g. in main() or HomeScreen.initState).
  /// Subsequent calls return instantly from cache.
  static Future<String> getMapsKey() async {
    if (_mapsKey != null) return _mapsKey!;

    final result = await FirebaseFunctions.instance
        .httpsCallable('getMapsKeys')
        .call({'platform': 'overall'}); // uses MAP_OVERALL_WORKING_KEY

    _mapsKey = result.data['key'] as String;
    return _mapsKey!;
  }
}
