import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

// AccentColour removed — theme colour is no longer user-configurable.

enum BackgroundStyle {
  navy,
  deepBlack,
  darkGreen,
  darkMaroon,
  warmGold,
  darkBrown,
  deepPurple,
  slateGrey,
}

enum ColourTemperature { warm, neutral, cool }

enum BackgroundPattern {
  none,
  geometric,
  starField,
  gradientMesh,
  wood,
  arabesque,
  circuitLines,
  hexGrid,
  dots,
  waves,
  customImage
}

enum BlackoutDuration { five, seven, ten, fifteen }

extension BackgroundStyleX on BackgroundStyle {
  String get label {
    switch (this) {
      case BackgroundStyle.navy:
        return 'Navy (Default)';
      case BackgroundStyle.deepBlack:
        return 'Deep Black';
      case BackgroundStyle.darkGreen:
        return 'Dark Green';
      case BackgroundStyle.darkMaroon:
        return 'Dark Maroon';
      case BackgroundStyle.warmGold:
        return 'Warm Gold';
      case BackgroundStyle.darkBrown:
        return 'Dark Brown';
      case BackgroundStyle.deepPurple:
        return 'Deep Purple';
      case BackgroundStyle.slateGrey:
        return 'Slate Grey';
    }
  }

  List<Color> get gradientColors {
    switch (this) {
      case BackgroundStyle.navy:
        return [
          const Color.fromARGB(255, 8, 20, 52),
          const Color.fromARGB(255, 15, 36, 85),
          const Color.fromARGB(255, 8, 20, 52),
        ];
      case BackgroundStyle.deepBlack:
        return [
          const Color.fromARGB(255, 4, 4, 8),
          const Color.fromARGB(255, 10, 10, 18),
          const Color.fromARGB(255, 2, 2, 6),
        ];
      case BackgroundStyle.darkGreen:
        return [
          const Color.fromARGB(255, 5, 28, 16),
          const Color.fromARGB(255, 10, 48, 26),
          const Color.fromARGB(255, 4, 18, 10),
        ];
      case BackgroundStyle.darkMaroon:
        return [
          const Color.fromARGB(255, 32, 8, 12),
          const Color.fromARGB(255, 52, 14, 20),
          const Color.fromARGB(255, 22, 5, 8),
        ];
      case BackgroundStyle.warmGold:
        return [
          const Color.fromARGB(255, 42, 28, 4),
          const Color.fromARGB(255, 68, 46, 8),
          const Color.fromARGB(255, 32, 20, 2),
        ];
      case BackgroundStyle.darkBrown:
        return [
          const Color.fromARGB(255, 28, 16, 8),
          const Color.fromARGB(255, 48, 28, 12),
          const Color.fromARGB(255, 18, 10, 4),
        ];
      case BackgroundStyle.deepPurple:
        return [
          const Color.fromARGB(255, 18, 8, 40),
          const Color.fromARGB(255, 34, 14, 68),
          const Color.fromARGB(255, 12, 4, 28),
        ];
      case BackgroundStyle.slateGrey:
        return [
          const Color.fromARGB(255, 18, 22, 30),
          const Color.fromARGB(255, 30, 36, 48),
          const Color.fromARGB(255, 12, 15, 22),
        ];
    }
  }

  /// The characteristic hue used by wood/gradientMesh pattern overlays —
  /// always a tone of this background's own colour family.
  Color get patternColor {
    switch (this) {
      case BackgroundStyle.navy:
        return const Color.fromARGB(255, 60, 110, 210);
      case BackgroundStyle.deepBlack:
        return const Color.fromARGB(255, 80, 80, 100);
      case BackgroundStyle.darkGreen:
        return const Color.fromARGB(255, 50, 160, 90);
      case BackgroundStyle.darkMaroon:
        return const Color.fromARGB(255, 180, 60, 80);
      case BackgroundStyle.warmGold:
        return const Color.fromARGB(255, 210, 165, 60);
      case BackgroundStyle.darkBrown:
        return const Color.fromARGB(255, 160, 100, 50);
      case BackgroundStyle.deepPurple:
        return const Color.fromARGB(255, 140, 80, 200);
      case BackgroundStyle.slateGrey:
        return const Color.fromARGB(255, 100, 120, 155);
    }
  }

  Color get swatch => gradientColors[1];
}

extension ColourTemperatureX on ColourTemperature {
  String get label {
    switch (this) {
      case ColourTemperature.warm:
        return 'Warm';
      case ColourTemperature.neutral:
        return 'Neutral';
      case ColourTemperature.cool:
        return 'Cool';
    }
  }

  ColorFilter? get filter {
    switch (this) {
      case ColourTemperature.warm:
        return const ColorFilter.matrix([
          1.04,
          0.01,
          -0.01,
          0,
          5,
          0.01,
          1.01,
          0.00,
          0,
          2,
          -0.01,
          0.00,
          0.96,
          0,
          -2,
          0,
          0,
          0,
          1,
          0,
        ]);
      case ColourTemperature.cool:
        return const ColorFilter.matrix([
          0.96,
          0.00,
          0.01,
          0,
          -2,
          0.00,
          1.00,
          0.01,
          0,
          1,
          0.01,
          0.01,
          1.05,
          0,
          4,
          0,
          0,
          0,
          1,
          0,
        ]);
      case ColourTemperature.neutral:
        return null;
    }
  }
}

extension BackgroundPatternX on BackgroundPattern {
  String get label {
    switch (this) {
      case BackgroundPattern.none:
        return 'None';
      case BackgroundPattern.geometric:
        return 'Geometric';
      case BackgroundPattern.starField:
        return 'Star Field';
      case BackgroundPattern.gradientMesh:
        return 'Gradient Mesh';
      case BackgroundPattern.wood:
        return 'Wood';
      case BackgroundPattern.arabesque:
        return 'Arabesque';
      case BackgroundPattern.circuitLines:
        return 'Circuit Lines';
      case BackgroundPattern.hexGrid:
        return 'Hex Grid';
      case BackgroundPattern.dots:
        return 'Dots';
      case BackgroundPattern.waves:
        return 'Waves';
      case BackgroundPattern.customImage:
        return 'Custom Image';
    }
  }
}

extension BlackoutDurationX on BlackoutDuration {
  String get label {
    switch (this) {
      case BlackoutDuration.five:
        return '5 minutes';
      case BlackoutDuration.seven:
        return '7 minutes (Default)';
      case BlackoutDuration.ten:
        return '10 minutes';
      case BlackoutDuration.fifteen:
        return '15 minutes';
    }
  }

  int get minutes {
    switch (this) {
      case BlackoutDuration.five:
        return 5;
      case BlackoutDuration.seven:
        return 7;
      case BlackoutDuration.ten:
        return 10;
      case BlackoutDuration.fifteen:
        return 15;
    }
  }
}

/// All display settings that are persisted to Firestore (primary) and
/// SharedPreferences (offline fallback). AccentColour has been removed —
/// the app always uses the gold palette.
class DisplaySettings {
  BackgroundStyle backgroundStyle;
  ColourTemperature colourTemperature;
  BackgroundPattern backgroundPattern;
  bool showTicker;
  bool jumuahEnabled;
  BlackoutDuration blackoutDuration;

  DisplaySettings({
    this.backgroundStyle = BackgroundStyle.navy,
    this.colourTemperature = ColourTemperature.neutral,
    this.backgroundPattern = BackgroundPattern.none,
    this.showTicker = true,
    this.jumuahEnabled = true,
    this.blackoutDuration = BlackoutDuration.seven,
  });

  List<Color> get bgColors => backgroundStyle.gradientColors;
  int get blackoutMinutes => blackoutDuration.minutes;

  // ── SharedPreferences keys (offline fallback only) ──────────────
  static const _kBgStyle = 'ds_bg_style';
  static const _kTemp = 'ds_colour_temp';
  static const _kPattern = 'ds_bg_pattern';
  static const _kTicker = 'ds_show_ticker';
  static const _kJumuah = 'ds_jumuah_enabled';
  static const _kBlackout = 'ds_blackout_duration';

  // ── Firestore field names (stored in displayMosques/{uid}) ───────
  static const _fBgStyle = 'setting_bgStyle';
  static const _fTemp = 'setting_colourTemp';
  static const _fPattern = 'setting_bgPattern';
  static const _fTicker = 'setting_showTicker';
  static const _fJumuah = 'setting_jumuahEnabled';
  static const _fBlackout = 'setting_blackoutDuration';

  /// Convert to a map for Firestore (only settings fields).
  Map<String, dynamic> toFirestore() => {
        _fBgStyle: backgroundStyle.index,
        _fTemp: colourTemperature.index,
        _fPattern: backgroundPattern.index,
        _fTicker: showTicker,
        _fJumuah: jumuahEnabled,
        _fBlackout: blackoutDuration.index,
      };

  /// Parse from a Firestore doc data map. Any missing field falls back to default.
  factory DisplaySettings.fromFirestore(Map<String, dynamic> data) {
    T safeEnum<T>(List<T> values, String key, T fallback) {
      final i = data[key];
      if (i is! int || i < 0 || i >= values.length) return fallback;
      return values[i];
    }

    return DisplaySettings(
      backgroundStyle:
          safeEnum(BackgroundStyle.values, _fBgStyle, BackgroundStyle.navy),
      colourTemperature:
          safeEnum(ColourTemperature.values, _fTemp, ColourTemperature.neutral),
      backgroundPattern:
          safeEnum(BackgroundPattern.values, _fPattern, BackgroundPattern.none),
      showTicker: (data[_fTicker] as bool?) ?? true,
      jumuahEnabled: (data[_fJumuah] as bool?) ?? true,
      blackoutDuration:
          safeEnum(BlackoutDuration.values, _fBlackout, BlackoutDuration.seven),
    );
  }

  /// Save to Firestore (primary) and SharedPreferences (offline fallback).
  /// [uid] is the current user's uid — the Firestore doc is displayMosques/{uid}.
  Future<void> save({String? uid}) async {
    // Always write to SharedPreferences for offline resilience
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kBgStyle, backgroundStyle.index);
    await p.setInt(_kTemp, colourTemperature.index);
    await p.setInt(_kPattern, backgroundPattern.index);
    await p.setBool(_kTicker, showTicker);
    await p.setBool(_kJumuah, jumuahEnabled);
    await p.setInt(_kBlackout, blackoutDuration.index);

    // Write to Firestore if uid provided
    if (uid != null && uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('displayMosques')
            .doc(uid)
            .set(toFirestore(), SetOptions(merge: true));
      } catch (e) {
        debugPrint('DisplaySettings.save Firestore error: $e');
      }
    }
  }

  /// Load from Firestore if [uid] and [firestoreData] supplied, otherwise
  /// from SharedPreferences. Firestore takes precedence.
  static DisplaySettings loadFromMap(Map<String, dynamic>? firestoreData) {
    if (firestoreData != null && firestoreData.containsKey(_fBgStyle)) {
      return DisplaySettings.fromFirestore(firestoreData);
    }
    return DisplaySettings(); // all defaults
  }

  /// Load purely from SharedPreferences (used during initState before auth).
  static Future<DisplaySettings> loadLocal() async {
    final p = await SharedPreferences.getInstance();
    T safeEnum<T>(List<T> values, String key, T fallback) {
      final i = p.getInt(key);
      if (i == null || i < 0 || i >= values.length) return fallback;
      return values[i];
    }

    return DisplaySettings(
      backgroundStyle:
          safeEnum(BackgroundStyle.values, _kBgStyle, BackgroundStyle.navy),
      colourTemperature:
          safeEnum(ColourTemperature.values, _kTemp, ColourTemperature.neutral),
      backgroundPattern:
          safeEnum(BackgroundPattern.values, _kPattern, BackgroundPattern.none),
      showTicker: p.getBool(_kTicker) ?? true,
      jumuahEnabled: p.getBool(_kJumuah) ?? true,
      blackoutDuration:
          safeEnum(BlackoutDuration.values, _kBlackout, BlackoutDuration.seven),
    );
  }

  /// Legacy alias kept so existing callers compile without changes.
  static Future<DisplaySettings> load() => loadLocal();

  DisplaySettings copyWith({
    BackgroundStyle? backgroundStyle,
    ColourTemperature? colourTemperature,
    BackgroundPattern? backgroundPattern,
    bool? showTicker,
    bool? jumuahEnabled,
    BlackoutDuration? blackoutDuration,
  }) =>
      DisplaySettings(
        backgroundStyle: backgroundStyle ?? this.backgroundStyle,
        colourTemperature: colourTemperature ?? this.colourTemperature,
        backgroundPattern: backgroundPattern ?? this.backgroundPattern,
        showTicker: showTicker ?? this.showTicker,
        jumuahEnabled: jumuahEnabled ?? this.jumuahEnabled,
        blackoutDuration: blackoutDuration ?? this.blackoutDuration,
      );
}
