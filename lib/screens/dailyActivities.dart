import 'package:flutter/material.dart';
import 'package:ihsan_app_final/screens/calender.dart';
import 'package:ihsan_app_final/sharedWidgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:intl/intl.dart';

class dailyActivitiesScreen extends StatefulWidget {
  final DateTime selectedDate;
  final DailyActivity? dailyActivity;
  const dailyActivitiesScreen(
      {super.key, required this.selectedDate, this.dailyActivity});

  @override
  _dailyActivitiesScreenState createState() => _dailyActivitiesScreenState();
}

class _dailyActivitiesScreenState extends State<dailyActivitiesScreen> {
  late DailyActivity _activity;

  @override
  void initState() {
    super.initState();
    _activity = widget.dailyActivity!;
  }

  void _saveActivity() async {
    setState(() {
      dailyActivities[widget.selectedDate] = _activity;
    });

    final prefs = await SharedPreferences.getInstance();
    await saveDailyActivitiesToSharedPreferences(prefs);
    print(dailyActivities);

    Navigator.pop(context, _activity);
  }

  Widget _sectionLabel(String text, IconData icon, Color color) => Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    // ── Palette ────────────────────────────────────────────────────────
    const Color navy = Color.fromARGB(255, 10, 25, 60);
    const Color navyMid = Color.fromARGB(255, 18, 42, 95);
    const Color navyLight = Color.fromARGB(255, 28, 58, 120);
    const Color gold = Color.fromARGB(255, 212, 175, 95);
    const Color goldLight = Color.fromARGB(255, 252, 243, 210);
    const Color skyBlue = Color.fromARGB(255, 100, 180, 240);
    const Color skyLight = Color.fromARGB(255, 220, 240, 255);
    const Color mintGreen = Color.fromARGB(255, 72, 200, 155);
    const Color mintLight = Color.fromARGB(255, 210, 245, 232);
    const Color white = Color.fromARGB(255, 255, 255, 255);
    const Color offWhite = Color.fromARGB(255, 247, 249, 255);
    const Color textDark = Color.fromARGB(255, 15, 30, 65);
    const Color textMid = Color.fromARGB(255, 90, 115, 160);
    const Color border = Color.fromARGB(255, 210, 220, 240);

    // How many prayers are ticked
    final int prayersDone =
        _activity.prayers.values.where((v) => v == true).length;
    final double prayerProgress = prayersDone / 5.0;

    // ── Reusable styled toggle card ───────────────────────────────────
    Widget toggleCard({
      required String title,
      required String subtitle,
      required bool value,
      required ValueChanged<bool> onChanged,
      required IconData icon,
      required Color activeColor,
      required Color activeBg,
      required Color activeBorder,
    }) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: value ? activeBg : white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value ? activeBorder : border,
            width: value ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: navy.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: value ? activeColor.withOpacity(0.15) : offWhite,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: value ? activeColor.withOpacity(0.4) : border,
                width: 1,
              ),
            ),
            child: Icon(icon, size: 19, color: value ? activeColor : textMid),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: value ? FontWeight.w700 : FontWeight.w500,
              color: value ? textDark : textMid,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: value ? activeColor : textMid.withOpacity(0.7),
            ),
          ),
          trailing: Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: activeColor,
            activeTrackColor: activeColor.withOpacity(0.25),
            inactiveThumbColor: textMid.withOpacity(0.5),
            inactiveTrackColor: border,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: navy,
      appBar: buildAppBar(
          context, 'Daily Activity Tracker', const CalendarScreen(), null),
      body: Column(
        children: [
          // ── HERO HEADER ─────────────────────────────────────────────
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
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            child: Column(
              children: [
                // Date display
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(
                    color: navyMid,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: gold.withOpacity(0.45), width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 15, color: gold),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat.yMMMMEEEEd()
                            .format(widget.selectedDate.toLocal()),
                        style: const TextStyle(
                          color: gold,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Prayer progress card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: navyMid,
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: gold.withOpacity(0.4), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                    color: mintGreen, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'PRAYERS TODAY',
                                style: TextStyle(
                                  fontSize: 9,
                                  letterSpacing: 1.4,
                                  fontWeight: FontWeight.w700,
                                  color: mintGreen,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            '$prayersDone / 5',
                            style: const TextStyle(
                              color: white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: prayerProgress,
                          backgroundColor: white.withOpacity(0.1),
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(mintGreen),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Prayer dot indicators
                      Row(
                        children: _activity.prayers.keys.map((prayer) {
                          final bool done = _activity.prayers[prayer] ?? false;
                          return Expanded(
                            child: Column(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: done
                                        ? mintGreen
                                        : white.withOpacity(0.15),
                                    border: Border.all(
                                      color: done
                                          ? mintGreen
                                          : white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  prayer.substring(0, 1),
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: done
                                        ? mintGreen
                                        : white.withOpacity(0.3),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── SCROLLABLE CONTENT ──────────────────────────────────────
          Expanded(
            child: Container(
              color: offWhite,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── PRAYERS SECTION ────────────────────────────────
                    _sectionLabel('PRAYERS', Icons.mosque_outlined, navy),
                    const SizedBox(height: 8),

                    ..._activity.prayers.keys.map((prayer) {
                      final bool done = _activity.prayers[prayer] ?? false;
                      return toggleCard(
                        title: prayer,
                        subtitle: done ? 'Completed ✓' : 'Not yet marked',
                        value: done,
                        onChanged: (val) =>
                            setState(() => _activity.prayers[prayer] = val),
                        icon: Icons.mosque_outlined,
                        activeColor: mintGreen,
                        activeBg: mintLight,
                        activeBorder: mintGreen.withOpacity(0.4),
                      );
                    }).toList(),

                    const SizedBox(height: 6),

                    // ── IBADAH SECTION ─────────────────────────────────
                    _sectionLabel(
                        'IBADAH', Icons.favorite_outline_rounded, navy),
                    const SizedBox(height: 8),

                    // Zikr
                    toggleCard(
                      title: 'Zikr / Dhikr',
                      subtitle:
                          _activity.zikrCount ? 'Completed ✓' : 'Not yet done',
                      value: _activity.zikrCount,
                      onChanged: (val) =>
                          setState(() => _activity.zikrCount = val),
                      icon: Icons.radio_button_checked_outlined,
                      activeColor: skyBlue,
                      activeBg: skyLight,
                      activeBorder: skyBlue.withOpacity(0.4),
                    ),

                    // Fasting
                    toggleCard(
                      title: 'Fasting',
                      subtitle: _activity.isFasting
                          ? 'Fasting today ✓'
                          : 'Not fasting today',
                      value: _activity.isFasting,
                      onChanged: (val) =>
                          setState(() => _activity.isFasting = val),
                      icon: Icons.no_food_outlined,
                      activeColor: gold,
                      activeBg: goldLight,
                      activeBorder: gold.withOpacity(0.4),
                    ),

                    const SizedBox(height: 6),

                    // ── QURAN SECTION ──────────────────────────────────
                    _sectionLabel('QURAN', Icons.menu_book_rounded, navy),
                    const SizedBox(height: 8),

                    Container(
                      decoration: BoxDecoration(
                        color: white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _activity.quranPagesRead > 0
                              ? gold.withOpacity(0.45)
                              : border,
                          width: _activity.quranPagesRead > 0 ? 1.5 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: navy.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: _activity.quranPagesRead > 0
                                  ? goldLight
                                  : offWhite,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _activity.quranPagesRead > 0
                                    ? gold.withOpacity(0.4)
                                    : border,
                                width: 1,
                              ),
                            ),
                            child: Icon(Icons.menu_book_rounded,
                                size: 19,
                                color: _activity.quranPagesRead > 0
                                    ? const Color.fromARGB(255, 140, 105, 30)
                                    : textMid),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Pages Read Today',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: textDark,
                                  ),
                                ),
                                Text(
                                  _activity.quranPagesRead > 0
                                      ? '${_activity.quranPagesRead} page${_activity.quranPagesRead == 1 ? '' : 's'} read'
                                      : 'Enter number of pages',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _activity.quranPagesRead > 0
                                        ? const Color.fromARGB(
                                            255, 140, 105, 30)
                                        : textMid.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Compact number input
                          SizedBox(
                            width: 64,
                            child: TextFormField(
                              initialValue: _activity.quranPagesRead.toString(),
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textDark,
                              ),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 8),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: border, width: 1),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      const BorderSide(color: gold, width: 1.5),
                                ),
                                filled: true,
                                fillColor: offWhite,
                              ),
                              onChanged: (val) => setState(() => _activity
                                  .quranPagesRead = int.tryParse(val) ?? 0),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── SAVE BUTTON ────────────────────────────────────
                    GestureDetector(
                      onTap: _saveActivity,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          color: navy,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: gold.withOpacity(0.55), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: navy.withOpacity(0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline_rounded,
                                color: gold, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Save Activity',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: gold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
