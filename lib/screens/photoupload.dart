import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_functions/cloud_functions.dart';

// ─── API KEY ──────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

const _navy = Color.fromARGB(255, 10, 25, 60);
const _navyMid = Color.fromARGB(255, 18, 42, 95);
const _navyLight = Color.fromARGB(255, 28, 58, 120);
const _gold = Color.fromARGB(255, 212, 175, 95);
const _mintGreen = Color.fromARGB(255, 72, 200, 155);
const _skyBlue = Color.fromARGB(255, 100, 180, 240);
const _fridayPurple = Color.fromARGB(255, 156, 39, 176);
const _errorRed = Color.fromARGB(255, 200, 60, 60);

const _columnLabels = [
  'Fajr Begin',
  'Fajr Jamaat',
  'Sunrise',
  'Dhuhr Begin',
  'Dhuhr Jamaat',
  'Asr Begin',
  'Asr Jamaat',
  'Maghrib',
  'Isha Begin',
  'Isha Jamaat',
];

// Row layout: [0]=date(DD/MM/YYYY), [1]=dayname,
//             [2]=fajrB, [3]=fajrJ, [4]=sunrise,
//             [5]=dhuhrB, [6]=dhuhrJ,
//             [7]=asrB, [8]=asrJ,
//             [9]=maghrib,
//             [10]=ishaB, [11]=ishaJ
const Set<int> _jamaatRowIndices = {3, 6, 8, 11};

class _ColumnInfo {
  final String label;
  final bool isJamaatColumn;
  _ColumnInfo(this.label, this.isJamaatColumn);
}

/// One Friday entry: the date string + up to 4 jummah slots.
class _FridayJummah {
  final String date; // DD/MM/YYYY display string
  List<TextEditingController> controllers;

  _FridayJummah({required this.date, required List<String> times})
      : controllers = times.map((t) => TextEditingController(text: t)).toList();

  List<String> get times => controllers.map((c) => c.text.trim()).toList();

  void dispose() {
    for (final c in controllers) c.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class PhotoUploadPage extends StatefulWidget {
  final String mosqueName;
  final String mosqueId;
  final String city;

  const PhotoUploadPage({
    super.key,
    required this.mosqueName,
    required this.mosqueId,
    required this.city,
  });

  @override
  State<PhotoUploadPage> createState() => _PhotoUploadPageState();
}

class _PhotoUploadPageState extends State<PhotoUploadPage> {
  File? _imageFile;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;

  List<List<String>> _filledRows = [];
  List<_ColumnInfo> _columnInfo = [];
  bool _isScanning = false;
  bool _dataReady = false;
  String? _errorMsg;

  // Jummah data — one entry per Friday in the scanned month
  List<_FridayJummah> _fridayJummahs = [];

  bool _isRamadanTimetable = false;

  @override
  void initState() {
    super.initState();
    _columnInfo = List.generate(
      _columnLabels.length,
      (i) => _ColumnInfo(_columnLabels[i], _jamaatRowIndices.contains(i + 2)),
    );
  }

  @override
  void dispose() {
    for (final f in _fridayJummahs) f.dispose();
    super.dispose();
  }

  // ── Back guard ──────────────────────────────────────────────────────────────
  Future<bool> _onWillPop() async {
    if (_isScanning) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: _navyMid,
          title:
              const Text('⚠️ Scan in Progress', style: TextStyle(color: _gold)),
          content: const Text(
            'AI is currently analysing the timetable.\n\n'
            'Leaving now will waste the API call and you will be charged for it. '
            'Please wait for the scan to finish.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _gold),
              onPressed: () => Navigator.pop(context),
              child: const Text('Stay',
                  style: TextStyle(color: _navy, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return false;
    }
    return true;
  }

  // ── Permission + image pick ─────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Camera permission required.'),
          action: status.isPermanentlyDenied
              ? SnackBarAction(label: 'Settings', onPressed: openAppSettings)
              : null,
          backgroundColor: _navyMid,
        ));
        return;
      }
    } else if (Platform.isIOS) {
      final status = await Permission.photos.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Photo library access required.'),
          action: status.isPermanentlyDenied
              ? SnackBarAction(label: 'Settings', onPressed: openAppSettings)
              : null,
          backgroundColor: _navyMid,
        ));
        return;
      }
    }

    final picked =
        await ImagePicker().pickImage(source: source, imageQuality: 90);
    if (picked == null) return;
    setState(() {
      _imageFile = File(picked.path);
      _filledRows = [];
      _dataReady = false;
      _errorMsg = null;
      for (final f in _fridayJummahs) f.dispose();
      _fridayJummahs = [];
    });
  }

  String getPrompt() {
    String basePrompt =
        'This is a printed mosque prayer timetable. Extract every data row as a JSON array. '
        'CRITICAL: Convert ALL times to 24-hour format (e.g., 1:00 PM → 13:00, 12:00 AM → 00:00). '
        'Especially any time at Dhuhr, Asr, Maghrib, Isha. make sure they are in 24h format and assume all times for asr, maghrib, isha are PM while converting. '
        'If there is a sunset column, ignore sunset and take ONLY maghrib. '
        'Each object must have these exact keys:\n'
        '  day (integer 1-31),\n'
        '  fajr_begin   — use the "Fajr Start" or "Fajr Begin" or "Fajr column. '
        'IGNORE any column labelled "Sehri" or "Seheri" or "Suhoor" or any of the like completely (strictly ONLY except if fajr or fajr begin dosent exist at all),\n'
        '  fajr_jamaat, sunrise,\n'
        '  dhuhr_begin, dhuhr_jamaat,\n'
        '  asr_begin, asr_jamaat,\n'
        '  maghrib,\n'
        '  isha_begin, isha_jamaat,\n'
        '  jummah_times — ONLY for Friday rows: an array of up to 4 time '
        'strings for 1st, 2nd, 3rd, 4th Jummah as they appear on the '
        'timetable (e.g. ["13:15","14:30"]). For non-Friday rows use an '
        'empty array [].\n'
        'If no separate Jummah times are visible on the timetable for that Friday, '
        'use the dhuhr_jamaat time of that row as the single Jummah time '
        '(e.g. ["13:15"]). Never return an empty array for a Friday row. '
        'Check the whole page for a 2nd Jummah or 3rd Jummah. '
        'Use empty string for any blank cell. And do not guess ANY times, use EXACT times as in timetable'
        'Return only the JSON array, no other text.';

    if (_isRamadanTimetable) {
      basePrompt +=
          '\n\nIMPORTANT: This is a RAMADAN timetable that may span TWO MONTHS. '
          'Look at the timetable carefully - it might show dates like 18/02, 19/02, etc. for the first part, '
          'and then 01/03, 02/03, etc. for the second part.\n'
          'For EACH ROW, you MUST include the correct "month" field based on what you see in the date column. '
          'Example: If the row says "18 Feb" or "18/02", then month should be 2 (February). '
          'If it says "01 Mar" or "01/03", then month should be 3 (March).\n'
          'If it is not clear only then, check the whole document for any gregorian months at the top.\n'
          'The "day" field should be the day number from that date (18, 19, etc.).\n'
          'DO NOT assume all rows are in the same month - check each row\'s date carefully.';
    }
    return basePrompt;
  }

  // ── Gemini scan ─────────────────────────────────────────────────────────────
  Future<void> _scanWithGemini() async {
    if (_imageFile == null) return;
    setState(() {
      _isScanning = true;
      _errorMsg = null;
    });

    try {
      final bytes = await _imageFile!.readAsBytes();
      final b64 = base64Encode(bytes);
      final ext = _imageFile!.path.split('.').last.toLowerCase();
      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';

      final callable = FirebaseFunctions.instance.httpsCallable(
        'askGemini',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 280)),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'image': b64,
        'mime': mime,
        'prompt': getPrompt(),
      });

      final rawText = result.data['text'] as String;
      final cleaned = rawText
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      _buildRows(jsonDecode(cleaned) as List<dynamic>);
    } on FirebaseFunctionsException catch (e) {
      setState(() => _errorMsg = 'Function error [${e.code}]: ${e.message}');
    } catch (e) {
      setState(() => _errorMsg = e.toString());
    } finally {
      setState(() => _isScanning = false);
    }
  }

  // ── Build rows + auto intelligent fill + jummah ─────────────────────────────
  void _buildRows(List<dynamic> jsonRows) {
    final raw = <List<String>>[];

    for (final entry in jsonRows) {
      final map = entry as Map<String, dynamic>;
      final day = (map['day'] as num).toInt();
      int rowMonth = _month; // Start with dropdown value
      if (_isRamadanTimetable && map.containsKey('month')) {
        rowMonth =
            (map['month'] as num).toInt(); // Use month from this specific row
      }
      final date = DateTime(_year, rowMonth, day);
      final ds =
          '${day.toString().padLeft(2, '0')}/${rowMonth.toString().padLeft(2, '0')}/$_year';

      raw.add([
        ds,
        _weekday(date.weekday),
        _s(map['fajr_begin']), // [2]
        _s(map['fajr_jamaat']), // [3]
        _s(map['sunrise']), // [4]
        _s(map['dhuhr_begin']), // [5]
        _s(map['dhuhr_jamaat']), // [6]
        _s(map['asr_begin']), // [7]
        _s(map['asr_jamaat']), // [8]
        _s(map['maghrib']), // [9]
        _s(map['isha_begin']), // [10]
        _s(map['isha_jamaat']), // [11]
      ]);
    }

    // Intelligent fill — carry jamaat times forward
    final carry = <int, String>{};
    final filled = raw.map((rawRow) {
      final row = List<String>.from(rawRow);
      for (final ji in _jamaatRowIndices) {
        if (ji >= row.length) continue;
        if (row[ji].isEmpty) {
          row[ji] = carry[ji] ?? '';
        } else {
          carry[ji] = row[ji];
        }
      }
      return row;
    }).toList();

    // Build Friday jummah list
    final List<_FridayJummah> jummahs = [];
    for (final entry in jsonRows) {
      final map = entry as Map<String, dynamic>;
      final day = (map['day'] as num).toInt();
      int rowMonth = _month; // Start with dropdown value
      if (_isRamadanTimetable && map.containsKey('month')) {
        rowMonth =
            (map['month'] as num).toInt(); // Use month from this specific row
      }
      final date = DateTime(_year, rowMonth, day);
      if (date.weekday != DateTime.friday) continue;

      final ds =
          '${day.toString().padLeft(2, '0')}/${rowMonth.toString().padLeft(2, '0')}/$_year';

      final rawTimes = map['jummah_times'];
      final List<String> times = rawTimes is List
          ? rawTimes
              .map((t) => t.toString().trim())
              .where((t) => t.isNotEmpty)
              .toList()
          : [];

      // Always give at least one empty slot so admin can type it in
      if (times.isEmpty) times.add('');

      jummahs.add(_FridayJummah(date: ds, times: times));
    }

    // Dispose old controllers before replacing
    for (final f in _fridayJummahs) f.dispose();

    setState(() {
      _filledRows = filled;
      _fridayJummahs = jummahs;
      _dataReady = true;
    });
  }

  String _s(dynamic v) => v == null ? '' : v.toString().trim();

  String _weekday(int w) {
    const n = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return n[w];
  }

  // ── Edit a single prayer-time cell ──────────────────────────────────────────
  // Begin columns (colIdx): 2=FajrB, 4=Sunrise, 5=DhuhrB, 7=AsrB, 9=Maghrib, 10=IshaB
  // Jamaat columns (colIdx): 3=FajrJ, 6=DhuhrJ, 8=AsrJ, 11=IshaJ
  static const Set<int> _beginColIndices = {2, 4, 5, 7, 9, 10};

  Future<void> _editCell(int rowIdx, int colIdx) async {
    if (colIdx <= 1) return;
    final headers = ['Date', 'Day', ..._columnLabels];

    // Parse existing time or default to 00:00
    String currentTime = _filledRows[rowIdx][colIdx].isNotEmpty
        ? _filledRows[rowIdx][colIdx]
        : '00:00';

    List<String> parts = currentTime.split(':');
    String selectedHour = parts[0].padLeft(2, '0');
    String selectedMinute = parts.length > 1 ? parts[1].padLeft(2, '0') : '00';

    // Begin columns get every minute (0–59); Jamaat columns get every 5 min
    final bool isBeginCol = _beginColIndices.contains(colIdx);
    final hourOptions = List.generate(24, (i) => i.toString().padLeft(2, '0'));
    final minuteOptions = isBeginCol
        ? List.generate(60, (i) => i.toString().padLeft(2, '0'))
        : List.generate(12, (i) => (i * 5).toString().padLeft(2, '0'));

    // If current minute not in list (e.g. scanned value like "37" on a jamaat col), clamp to nearest
    if (!minuteOptions.contains(selectedMinute)) {
      selectedMinute = minuteOptions.first;
    }

    final String? newVal = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _navyMid,
        title: Text(
          'Edit ${headers[colIdx]}  •  ${_filledRows[rowIdx][0]}',
          style: const TextStyle(color: _gold, fontSize: 14),
        ),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Hour dropdown
                  Expanded(
                    child: DropdownButton<String>(
                      value: selectedHour,
                      dropdownColor: _navyLight,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold),
                      icon: const Icon(Icons.arrow_drop_down, color: _gold),
                      isExpanded: true,
                      items: hourOptions.map((hour) {
                        return DropdownMenuItem(
                          value: hour,
                          child: Center(child: Text(hour)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedHour = value!;
                        });
                      },
                    ),
                  ),
                  const Text(' : ',
                      style: TextStyle(
                          color: _gold,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  // Minute dropdown
                  Expanded(
                    child: DropdownButton<String>(
                      value: selectedMinute,
                      dropdownColor: _navyLight,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold),
                      icon: const Icon(Icons.arrow_drop_down, color: _gold),
                      isExpanded: true,
                      items: minuteOptions.map((minute) {
                        return DropdownMenuItem(
                          value: minute,
                          child: Center(child: Text(minute)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedMinute = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Select hour and minute (24-hour format)',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _gold),
            onPressed: () =>
                Navigator.pop(ctx, '$selectedHour:$selectedMinute'),
            child: const Text('Save',
                style: TextStyle(color: _navy, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (newVal != null) {
      setState(() => _filledRows[rowIdx][colIdx] = newVal);
    }
  }

  // ── Return to UploadMosque ───────────────────────────────────────────────────
  /// Packages jummah times into each Friday row as extra fields.
  /// UploadMosque will read indices [12..15] as jummah1..jummah4.
  void _useThisData() {
    // Attach jummah times to the matching Friday rows
    final result = _filledRows.map((r) => List<String>.from(r)).toList();

    for (final fj in _fridayJummahs) {
      final idx = result.indexWhere((r) => r[0] == fj.date);
      if (idx == -1) continue;
      // Pad/trim to exactly 4 slots
      final times = List<String>.from(fj.times);
      while (times.length < 4) times.add('');
      // Append as [12]=j1, [13]=j2, [14]=j3, [15]=j4
      result[idx].addAll(times.take(4));
    }

    Navigator.pop(context, result);
  }

  // ── CSV copy helper ─────────────────────────────────────────────────────────
  String _buildCsv(List<List<String>> rows) {
    final header = ['Date', 'Day', ..._columnLabels].join(',');
    return [header, ...rows.map((r) => r.map(_csvCell).join(','))].join('\n');
  }

  String _csvCell(String v) =>
      v.contains(',') || v.contains('"') || v.contains('\n')
          ? '"${v.replaceAll('"', '""')}"'
          : v;

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Copied to clipboard'), duration: Duration(seconds: 2)));
  }

  // ── BUILD ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          backgroundColor: _navy,
          appBar: AppBar(
            backgroundColor: _navyMid,
            leading: BackButton(
              color: _gold,
              onPressed: () async {
                if (await _onWillPop()) Navigator.pop(context);
              },
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Timetable Scanner',
                    style: TextStyle(color: _gold, fontSize: 16)),
                Text(widget.mosqueName,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Scanning warning banner ───────────────────────────
                if (_isScanning)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _gold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _gold.withOpacity(0.6)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.warning_amber_rounded, color: _gold, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Scan in progress — do not leave this screen. '
                          'Closing now will waste the API call.',
                          style: TextStyle(
                              color: _gold,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                  ),

                _monthYearPicker(),
                const SizedBox(height: 12),
                _card(
                  child: Row(
                    children: [
                      const Icon(Icons.ramen_dining, color: _gold, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Ramadan Timetable',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      const Spacer(),
                      Switch(
                        value: _isRamadanTimetable,
                        onChanged: (value) {
                          setState(() {
                            _isRamadanTimetable = value;
                          });
                        },
                        activeColor: _fridayPurple,
                        activeTrackColor: _fridayPurple.withOpacity(0.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _imageSection(),

                if (_errorMsg != null) ...[
                  const SizedBox(height: 12),
                  _errorWidget(),
                ],

                if (_dataReady) ...[
                  const SizedBox(height: 16),

                  // Edit hint
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _mintGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _mintGreen.withOpacity(0.4)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.touch_app_rounded,
                          color: _mintGreen, size: 16),
                      SizedBox(width: 8),
                      Text('Tap any time cell to edit it.',
                          style: TextStyle(color: _mintGreen, fontSize: 12)),
                    ]),
                  ),
                  const SizedBox(height: 8),

                  // Copy CSV button
                  _outlineBtn(Icons.copy, 'Copy CSV', _skyBlue,
                      () => _copy(_buildCsv(_filledRows))),
                  const SizedBox(height: 12),

                  // ── Main prayer times table ───────────────────────
                  _dataTable(),

                  // ── Friday Jummah section ─────────────────────────
                  if (_fridayJummahs.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _jummahSection(),
                  ],

                  const SizedBox(height: 20),

                  // ── Use This Data button ──────────────────────────
                  ElevatedButton.icon(
                    onPressed: _useThisData,
                    icon: const Icon(Icons.upload_rounded, color: _navy),
                    label: const Text('Use This Data',
                        style: TextStyle(
                            color: _navy,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gold,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_filledRows.length} days ready — ${widget.mosqueName}.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),
        ),
      );

  // ── Prayer times table ───────────────────────────────────────────────────────
  Widget _dataTable() {
    final headers = ['Date', 'Day', ..._columnLabels];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(_navyLight),
        dataRowColor: WidgetStateProperty.resolveWith((_) => _navyMid),
        headingTextStyle: const TextStyle(
            color: _gold, fontWeight: FontWeight.bold, fontSize: 11),
        dataTextStyle: const TextStyle(color: Colors.white70, fontSize: 11),
        columnSpacing: 10,
        columns: headers.map((h) => DataColumn(label: Text(h))).toList(),
        rows: _filledRows.asMap().entries.map((entry) {
          final rowIdx = entry.key;
          final row = entry.value;
          final isFriday = row.length > 1 && row[1] == 'Friday';

          return DataRow(
            color: WidgetStateProperty.all(
                isFriday ? _fridayPurple.withOpacity(0.25) : _navyMid),
            cells: row.asMap().entries.map((e) {
              final colIdx = e.key;
              final val = e.value;
              final canEdit = colIdx > 1;

              return DataCell(
                GestureDetector(
                  onTap: canEdit ? () => _editCell(rowIdx, colIdx) : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(val,
                          style: TextStyle(
                            color: isFriday ? _fridayPurple : null,
                            fontWeight: isFriday ? FontWeight.bold : null,
                          )),
                      if (canEdit) ...[
                        const SizedBox(width: 3),
                        const Icon(Icons.edit, size: 9, color: Colors.white24),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  // ── Friday Jummah section ────────────────────────────────────────────────────
  Widget _jummahSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            const Icon(Icons.mosque_outlined, color: _fridayPurple, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Friday Jummah Times',
                  style: TextStyle(
                      color: _fridayPurple,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
            const Text('Tap to edit  •  + to add slot',
                style: TextStyle(color: Colors.white38, fontSize: 10)),
          ]),
          const SizedBox(height: 4),
          const Text(
            'Up to 4 Jummah times per Friday. '
            'Leave unused slots blank — they will be ignored.',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 12),

          // One row per Friday
          ..._fridayJummahs.map((fj) => _fridayRow(fj)),
        ],
      ),
    );
  }

  Widget _fridayRow(_FridayJummah fj) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date label
          Text(
            '${fj.date}  (Friday)',
            style: const TextStyle(
                color: _fridayPurple,
                fontWeight: FontWeight.w600,
                fontSize: 12),
          ),
          const SizedBox(height: 6),

          // Jummah time chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...fj.controllers.asMap().entries.map((e) {
                final i = e.key;
                final ctrl = e.value;
                return GestureDetector(
                  onTap: () => _editJummahSlot(fj, i),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _navyLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _fridayPurple.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ctrl.text.isEmpty
                              ? '${_ordinal(i + 1)} Jummah'
                              : ctrl.text,
                          style: TextStyle(
                            color: ctrl.text.isEmpty
                                ? Colors.white38
                                : Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit, size: 10, color: Colors.white30),
                      ],
                    ),
                  ),
                );
              }),

              // Add slot button (max 4)
              if (fj.controllers.length < 4)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      fj.controllers.add(TextEditingController(text: ''));
                    });
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _fridayPurple.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _fridayPurple.withOpacity(0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 14, color: _fridayPurple),
                        SizedBox(width: 4),
                        Text('Add Jummah',
                            style:
                                TextStyle(color: _fridayPurple, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editJummahSlot(_FridayJummah fj, int slotIdx) async {
    // Parse existing time or default to 00:00
    String currentTime = fj.controllers[slotIdx].text.isNotEmpty
        ? fj.controllers[slotIdx].text
        : '00:00';

    List<String> parts = currentTime.split(':');
    String selectedHour = parts[0].padLeft(2, '0');
    String selectedMinute = parts.length > 1 ? parts[1].padLeft(2, '0') : '00';

    // Jummah is always a Jamaat-style time — every 5 minutes
    final hourOptions = List.generate(24, (i) => i.toString().padLeft(2, '0'));
    final minuteOptions =
        List.generate(12, (i) => (i * 5).toString().padLeft(2, '0'));

    // Clamp in case scanned minute isn't a multiple of 5
    if (!minuteOptions.contains(selectedMinute)) {
      selectedMinute = minuteOptions.first;
    }

    final String? newVal = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _navyMid,
        title: Text(
          'Edit ${_ordinal(slotIdx + 1)} Jummah  •  ${fj.date}',
          style: const TextStyle(color: _fridayPurple, fontSize: 14),
        ),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Hour dropdown
                  Expanded(
                    child: DropdownButton<String>(
                      value: selectedHour,
                      dropdownColor: _navyLight,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold),
                      icon: const Icon(Icons.arrow_drop_down,
                          color: _fridayPurple),
                      isExpanded: true,
                      items: hourOptions.map((hour) {
                        return DropdownMenuItem(
                          value: hour,
                          child: Center(child: Text(hour)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedHour = value!;
                        });
                      },
                    ),
                  ),
                  const Text(' : ',
                      style: TextStyle(
                          color: _fridayPurple,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  // Minute dropdown
                  Expanded(
                    child: DropdownButton<String>(
                      value: selectedMinute,
                      dropdownColor: _navyLight,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold),
                      icon: const Icon(Icons.arrow_drop_down,
                          color: _fridayPurple),
                      isExpanded: true,
                      items: minuteOptions.map((minute) {
                        return DropdownMenuItem(
                          value: minute,
                          child: Center(child: Text(minute)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedMinute = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Select hour and minute (24-hour format)',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          if (fj.controllers.length > 1)
            TextButton(
              onPressed: () => Navigator.pop(ctx, '__remove__'),
              child: const Text('Remove', style: TextStyle(color: _errorRed)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _gold),
            onPressed: () =>
                Navigator.pop(ctx, '$selectedHour:$selectedMinute'),
            child: const Text('Save',
                style: TextStyle(color: _navy, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (newVal == '__remove__') {
      setState(() {
        fj.controllers[slotIdx].dispose();
        fj.controllers.removeAt(slotIdx);
      });
    } else if (newVal != null) {
      setState(() => fj.controllers[slotIdx].text = newVal);
    }
  }

  String _ordinal(int n) {
    const suffixes = ['', '1st', '2nd', '3rd', '4th'];
    return n < suffixes.length ? suffixes[n] : '${n}th';
  }

  // ── Widgets ──────────────────────────────────────────────────────────────────
  Widget _monthYearPicker() {
    const monthNames = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    final years = List.generate(6, (i) => DateTime.now().year - 1 + i);
    return _card(
        child: Row(children: [
      const Icon(Icons.calendar_month, color: _gold),
      const SizedBox(width: 12),
      Expanded(
          child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
        value: _month,
        dropdownColor: _navyMid,
        style: const TextStyle(color: Colors.white),
        items: List.generate(12, (i) => i + 1)
            .map((m) => DropdownMenuItem(value: m, child: Text(monthNames[m])))
            .toList(),
        onChanged: (v) => setState(() => _month = v!),
      ))),
      const SizedBox(width: 12),
      Expanded(
          child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
        value: _year,
        dropdownColor: _navyMid,
        style: const TextStyle(color: Colors.white),
        items: years
            .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
            .toList(),
        onChanged: (v) => setState(() => _year = v!),
      ))),
    ]));
  }

  Widget _imageSection() => Column(children: [
        if (_imageFile != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(_imageFile!,
                height: 200, width: double.infinity, fit: BoxFit.cover),
          ),
          const SizedBox(height: 12),
        ],
        Row(children: [
          Expanded(
              child: _outlineBtn(Icons.photo_library, 'Gallery', _skyBlue,
                  () => _pickImage(ImageSource.gallery))),
        ]),
        if (_imageFile != null) ...[
          const SizedBox(height: 8),
          // ── Fixed scan button with working spinner ──────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isScanning ? null : _scanWithGemini,
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                disabledBackgroundColor: _gold.withOpacity(0.6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _isScanning
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(_navy),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Scanning…',
                            style: TextStyle(
                                color: _navy, fontWeight: FontWeight.bold)),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.document_scanner, color: _navy),
                        SizedBox(width: 8),
                        Text('Scan with AI',
                            style: TextStyle(
                                color: _navy, fontWeight: FontWeight.bold)),
                      ],
                    ),
            ),
          ),
        ],
      ]);

  Widget _errorWidget() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _errorRed.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _errorRed),
        ),
        child: Text(_errorMsg!, style: const TextStyle(color: _errorRed)),
      );

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _navyMid,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _navyLight),
        ),
        child: child,
      );

  Widget _outlineBtn(
          IconData icon, String label, Color color, VoidCallback onTap) =>
      OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: color, size: 16),
        label: Text(label, style: TextStyle(color: color, fontSize: 12)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
}
