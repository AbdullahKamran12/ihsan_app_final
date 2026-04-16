import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ihsan_app_final/screens/moreoptionsScreen.dart';
import 'package:ihsan_app_final/sharedWidgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TasbeehItem {
  final String phrase;
  final String arabicPhrase;
  final int count;
  TasbeehItem(
      {required this.phrase, this.arabicPhrase = '', required this.count});
}

class TasbeehCollection {
  final String name;
  final String arabicName;
  final List<TasbeehItem> items;
  final bool isBlank;
  final bool isCustom;
  const TasbeehCollection({
    required this.name,
    this.arabicName = '',
    required this.items,
    this.isBlank = false,
    this.isCustom = false,
  });
}

final TasbeehCollection blankTasbih = TasbeehCollection(
  name: 'Blank Tasbih',
  arabicName: 'تسبيح حر',
  isBlank: true,
  items: [TasbeehItem(phrase: '', arabicPhrase: '', count: 0)],
);

TasbeehCollection buildCustomTasbih(int target) => TasbeehCollection(
      name: 'Custom Tasbih',
      arabicName: 'تسبيح مخصص',
      isCustom: true,
      items: [TasbeehItem(phrase: 'Custom', arabicPhrase: '', count: target)],
    );

final List<TasbeehCollection> tasbeehCollections = [
  // ─────────────────────────────────────────────
  // TASBEEH FATIMA (AUTHENTIC)
  // ─────────────────────────────────────────────
  TasbeehCollection(
    name: 'Tasbeeh Fatima',
    arabicName: 'تسبيح فاطمة',
    items: [
      TasbeehItem(
          phrase: 'SubhanAllah', arabicPhrase: 'سُبْحَانَ اللَّهِ', count: 33),
      TasbeehItem(
          phrase: 'Alhamdulillah',
          arabicPhrase: 'الْحَمْدُ لِلَّهِ',
          count: 33),
      TasbeehItem(
          phrase: 'Allahu Akbar', arabicPhrase: 'اللَّهُ أَكْبَرُ', count: 34),
    ],
  ),

  // ─────────────────────────────────────────────
  // KALIMATAN KHAFIFATAN
  // ─────────────────────────────────────────────
  TasbeehCollection(
    name: 'Kalimatan Khafifatan',
    arabicName: 'كلمتان خفيفتان',
    items: [
      TasbeehItem(
        phrase: 'SubhanAllahi wa bihamdihi',
        arabicPhrase: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
        count: 100,
      ),
    ],
  ),

  // ─────────────────────────────────────────────
  // TASBEEH / TAHMEED / TAKBEER
  // ─────────────────────────────────────────────
  TasbeehCollection(
    name: 'Tasbeeh, Tahmeed & Takbeer',
    arabicName: 'التسبيح والتحميد والتكبير',
    items: [
      TasbeehItem(
        phrase: 'SubhanAllah',
        arabicPhrase: 'سُبْحَانَ اللَّهِ',
        count: 33,
      ),
      TasbeehItem(
        phrase: 'Alhamdulillah',
        arabicPhrase: 'الْحَمْدُ لِلَّهِ',
        count: 33,
      ),
      TasbeehItem(
        phrase: 'Allahu Akbar',
        arabicPhrase: 'اللَّهُ أَكْبَرُ',
        count: 34,
      ),
    ],
  ),

  // ─────────────────────────────────────────────
  // DUROOD IBRAHIM (FULL)
  // ─────────────────────────────────────────────
  TasbeehCollection(
    name: 'Durood Ibrahim',
    arabicName: 'الصلاة الإبراهيمية',
    items: [
      TasbeehItem(
        phrase:
            'Allahumma salli \'ala Muhammad wa \'ala aali Muhammad kama sallayta \'ala Ibrahim wa \'ala aali Ibrahim, innaka hameedum majeed',
        arabicPhrase:
            'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ كَمَا صَلَّيْتَ عَلَى إِبْرَاهِيمَ وَعَلَى آلِ إِبْرَاهِيمَ إِنَّكَ حَمِيدٌ مَجِيدٌ',
        count: 10,
      ),
    ],
  ),

  // ─────────────────────────────────────────────
  // SALAWAT (SHORT)
  // ─────────────────────────────────────────────
  TasbeehCollection(
    name: 'Salawat',
    arabicName: 'الصلوات',
    items: [
      TasbeehItem(
        phrase: 'Allahumma salli wa sallim \'ala Nabiyyina Muhammad',
        arabicPhrase: 'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ',
        count: 100,
      ),
    ],
  ),

  // ─────────────────────────────────────────────
  // SAYYID AL-ISTIGHFAR (BEST)
  // ─────────────────────────────────────────────
  TasbeehCollection(
    name: 'Sayyid al-Istighfar',
    arabicName: 'سيد الاستغفار',
    items: [
      TasbeehItem(
        phrase:
            'Allahumma anta Rabbi la ilaha illa anta, khalaqtani wa ana abduka wa ana \'ala ahdika wa wa\'dika mastata\'tu, a\'udhu bika min sharri ma sana\'tu, abu\'u laka bini\'matika \'alayya wa abu\'u bidhanbi faghfir li fa innahu la yaghfiru adh-dhunuba illa anta',
        arabicPhrase:
            'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ خَلَقْتَنِي وَأَنَا عَبْدُكَ وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ',
        count: 1,
      ),
    ],
  ),

  // ─────────────────────────────────────────────
  // SIMPLE ISTIGHFAR
  // ─────────────────────────────────────────────
  TasbeehCollection(
    name: 'Istighfar',
    arabicName: 'الاستغفار',
    items: [
      TasbeehItem(
        phrase: 'Astaghfirullah',
        arabicPhrase: 'أَسْتَغْفِرُ اللَّهَ',
        count: 100,
      ),
    ],
  ),

  // ─────────────────────────────────────────────
  // TAHLIL
  // ─────────────────────────────────────────────
  TasbeehCollection(
    name: 'Tahleel',
    arabicName: 'التهليل',
    items: [
      TasbeehItem(
        phrase:
            'La ilaha illAllahu wahdahu la sharika lah, lahul mulku wa lahul hamdu wa huwa \'ala kulli shay\'in qadeer',
        arabicPhrase:
            'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
        count: 100,
      ),
    ],
  ),

  // ─────────────────────────────────────────────
  // HASBUNALLAH
  // ─────────────────────────────────────────────
  TasbeehCollection(
    name: 'Hasbunallah',
    arabicName: 'حسبنا الله',
    items: [
      TasbeehItem(
        phrase: 'HasbunAllahu wa ni\'mal wakeel',
        arabicPhrase: 'حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ',
        count: 100,
      ),
    ],
  ),

  // ─────────────────────────────────────────────
  // MORNING ADHKAR (AUTHENTIC CORE)
  // ─────────────────────────────────────────────
  TasbeehCollection(
    name: 'Morning Adhkar',
    arabicName: 'أذكار الصباح',
    items: [
      TasbeehItem(
        phrase: 'Ayat al-Kursi',
        arabicPhrase: 'اللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ',
        count: 1,
      ),
      TasbeehItem(
        phrase: 'SubhanAllahi wa bihamdihi',
        arabicPhrase: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
        count: 100,
      ),
      TasbeehItem(
        phrase: 'Bismillah alladhi la yadurru ma\'asmihi shay\'un...',
        arabicPhrase:
            'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ',
        count: 3,
      ),
    ],
  ),

  // ─────────────────────────────────────────────
  // TABLEEGHI ADHKAR
  // ─────────────────────────────────────────────
  TasbeehCollection(
    name: 'Tableeghi Adhkar',
    arabicName: 'أذكار التبليغ',
    items: [
      TasbeehItem(
        phrase:
            'La ilaha illAllahu wahdahu la sharika lah, lahul mulku wa lahul hamdu wa huwa \'ala kulli shay\'in qadeer',
        arabicPhrase:
            'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
        count: 100,
      ),
      TasbeehItem(
        phrase: 'Allahumma salli \'ala Muhammad',
        arabicPhrase: 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ',
        count: 100,
      ),
      TasbeehItem(
        phrase: 'Astaghfirullah',
        arabicPhrase: 'أَسْتَغْفِرُ اللَّهَ',
        count: 100,
      ),
    ],
  ),
];

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _navy = Color.fromARGB(255, 10, 25, 60);
const Color _navyMid = Color.fromARGB(255, 18, 42, 95);
const Color _navyLight = Color.fromARGB(255, 28, 58, 120);
const Color _gold = Color.fromARGB(255, 212, 175, 95);
const Color _goldLight = Color.fromARGB(255, 252, 243, 210);
const Color _mintGreen = Color.fromARGB(255, 72, 200, 155);
const Color _white = Color.fromARGB(255, 255, 255, 255);
const Color _offWhite = Color.fromARGB(255, 247, 249, 255);
const Color _textDark = Color.fromARGB(255, 15, 30, 65);
const Color _textMid = Color.fromARGB(255, 90, 115, 160);
const Color _border = Color.fromARGB(255, 210, 220, 240);

String _prefKey(String n, String s) => 'tasbih_${n.replaceAll(' ', '_')}_$s';

// ══════════════════════════════════════════════════════════════════════════════
// BEAD STRAND WIDGET
// Full-width animated bead strand painted on a Canvas.
// Beads scroll left when leftToRight=true, right when false.
// ══════════════════════════════════════════════════════════════════════════════
class _BeadStrand extends StatefulWidget {
  final int totalBeads;
  final int currentBead;
  final bool leftToRight;
  const _BeadStrand(
      {required this.totalBeads,
      required this.currentBead,
      required this.leftToRight});

  @override
  State<_BeadStrand> createState() => _BeadStrandState();
}

class _BeadStrandState extends State<_BeadStrand>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  double _offset = 0;

  // Must match _BeadPainter._arcSpacing
  static const double _step = 38.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _anim = Tween<double>(begin: 0, end: 0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_BeadStrand old) {
    super.didUpdateWidget(old);
    if (old.currentBead != widget.currentBead) {
      final double step = widget.leftToRight ? _step : -_step;
      final double from = _offset;
      final double to = _offset + step;
      _anim = Tween<double>(begin: from, end: to)
          .chain(CurveTween(curve: Curves.easeOut))
          .animate(_ctrl);
      _ctrl.forward(from: 0).then((_) => _offset = to);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => CustomPaint(
          painter: _BeadPainter(
            totalBeads: widget.totalBeads,
            currentBead: widget.currentBead,
            scrollOffset: _anim.value,
            leftToRight: widget.leftToRight,
          ),
        ),
      );
}

class _BeadPainter extends CustomPainter {
  final int totalBeads;
  final int currentBead;
  final double scrollOffset;
  final bool leftToRight;

  static const double _r = 17.0;
  // Arc spacing: how far apart beads are along the arc (in "arc-length" units)
  static const double _arcSpacing = 38.0;

  _BeadPainter(
      {required this.totalBeads,
      required this.currentBead,
      required this.scrollOffset,
      required this.leftToRight});

  // ── Arc geometry ──────────────────────────────────────────────────
  // The cord is a quadratic bezier from top-right to bottom-left.
  // Start: (width, 0)  End: (0, height)  Control: slightly inward for gentle bow.
  Offset _arcPoint(Size size, double t) {
    // Quadratic bezier: P = (1-t)^2 * P0 + 2(1-t)t * P1 + t^2 * P2
    final Offset p0 = Offset(size.width, 0);
    final Offset p1 =
        Offset(size.width * 0.38, size.height * 0.38); // control — gentle bow
    final Offset p2 = Offset(0, size.height);
    final double mt = 1 - t;
    return p0 * (mt * mt) + p1 * (2 * mt * t) + p2 * (t * t);
  }

  // Approximate arc length to normalise spacing
  double _approxArcLength(Size size, {int steps = 80}) {
    double len = 0;
    Offset prev = _arcPoint(size, 0);
    for (int i = 1; i <= steps; i++) {
      final Offset cur = _arcPoint(size, i / steps);
      len += (cur - prev).distance;
      prev = cur;
    }
    return len;
  }

  // Given a distance along the arc, find the t parameter (binary search)
  double _tAtDistance(Size size, double targetDist, double totalLen) {
    double lo = 0, hi = 1;
    for (int iter = 0; iter < 20; iter++) {
      final double mid = (lo + hi) / 2;
      // Approx length from 0 to mid
      double len = 0;
      Offset prev = _arcPoint(size, 0);
      final int steps = 40;
      for (int i = 1; i <= steps; i++) {
        final Offset cur = _arcPoint(size, mid * i / steps);
        len += (cur - prev).distance;
        prev = cur;
      }
      if (len < targetDist)
        lo = mid;
      else
        hi = mid;
    }
    return (lo + hi) / 2;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double totalLen = _approxArcLength(size);

    // ── Cord ─────────────────────────────────────────────────────────
    final cordPath = Path();
    cordPath.moveTo(size.width, 0);
    // Draw the bezier cord
    final Offset p0 = Offset(size.width, 0);
    final Offset p1 = Offset(size.width * 0.38, size.height * 0.38);
    final Offset p2 = Offset(0, size.height);
    cordPath.quadraticBezierTo(p1.dx, p1.dy, p2.dx, p2.dy);

    canvas.drawPath(
        cordPath,
        Paint()
          ..color = const Color.fromARGB(210, 95, 65, 25)
          ..strokeWidth = 3.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);

    // ── Beads along the arc ────────────────────────────────────────
    // We place beads at evenly-spaced arc distances, offset by scrollOffset.
    // scrollOffset shifts which distance the "first" bead starts at.
    final double scrolledDist = scrollOffset % _arcSpacing;
    // How many bead slots needed to fill the arc plus overflow
    final int beadCount = (totalLen / _arcSpacing).ceil() + 4;

    for (int vi = 0; vi < beadCount; vi++) {
      // Distance from the start of the arc for this visual slot
      double dist = vi * _arcSpacing - scrolledDist;
      // Clamp to arc (beads beyond ends are hidden)
      if (dist < -_r * 2 || dist > totalLen + _r * 2) continue;
      final double clampedDist = dist.clamp(0.0, totalLen);
      final double t = _tAtDistance(size, clampedDist, totalLen);
      final Offset pos = _arcPoint(size, t);

      // Map visual slot to bead index
      final int slot =
          ((vi + currentBead - (beadCount ~/ 2)) % totalBeads + totalBeads) %
              totalBeads;
      final bool isActive = slot == currentBead;
      final bool isPast = leftToRight ? slot < currentBead : slot > currentBead;

      _drawBead(canvas, pos, isActive: isActive, isPast: isPast);
    }
  }

  void _drawBead(Canvas canvas, Offset c,
      {required bool isActive, required bool isPast}) {
    // Shadow
    canvas.drawCircle(c + const Offset(2.5, 4), _r,
        Paint()..color = Colors.black.withOpacity(0.32));

    // Base colour
    final Color base = isActive
        ? const Color.fromARGB(255, 212, 175, 95) // gold
        : isPast
            ? const Color.fromARGB(255, 42, 88, 54) // dark green (counted)
            : const Color.fromARGB(255, 16, 12, 8); // near-black (pending)

    // Sphere gradient — 3D look
    final rect = Rect.fromCircle(center: c, radius: _r);
    canvas.drawCircle(
        c,
        _r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.38, -0.45),
            radius: 1.0,
            colors: [
              Color.lerp(const Color(0xFFFFFFFF), base, 0.28)!,
              base,
              Color.lerp(base, Colors.black, 0.62)!,
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(rect));

    // Specular highlight
    canvas.drawCircle(
      c + Offset(-_r * 0.3, -_r * 0.33),
      _r * 0.27,
      Paint()
        ..color = Colors.white.withOpacity(isActive ? 0.82 : 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );

    // Gold ring + glow for active
    if (isActive) {
      canvas.drawCircle(
          c,
          _r + 4,
          Paint()
            ..color = _gold.withOpacity(0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5);
      canvas.drawCircle(
          c,
          _r + 9,
          Paint()
            ..color = _gold.withOpacity(0.15)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    }
  }

  @override
  bool shouldRepaint(_BeadPainter o) =>
      o.currentBead != currentBead ||
      o.scrollOffset != scrollOffset ||
      o.leftToRight != leftToRight;
}

// ══════════════════════════════════════════════════════════════════════════════
// ENTRY POINT
// ══════════════════════════════════════════════════════════════════════════════
class TasbihScreen extends StatelessWidget {
  const TasbihScreen({super.key});
  @override
  Widget build(BuildContext context) => const CollectionSelectionScreen();
}

// ══════════════════════════════════════════════════════════════════════════════
// COLLECTION SELECTION SCREEN (unchanged)
// ══════════════════════════════════════════════════════════════════════════════
class CollectionSelectionScreen extends StatelessWidget {
  const CollectionSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      appBar:
          buildAppBar(context, 'Tasbih', const MoreOptionsScreen(), screenFrom),
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: _navy,
              borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(26),
                  bottomRight: Radius.circular(26)),
              border: Border(
                  bottom:
                      BorderSide(color: _gold.withOpacity(0.45), width: 1.5)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            child: Column(
              children: [
                const Text('الأذكار والتسبيح',
                    style: TextStyle(
                        color: _gold,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5),
                    textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text('Select a collection to begin',
                    style: TextStyle(
                        color: _white.withOpacity(0.5), fontSize: 13)),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: _offWhite,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
                children: [
                  _buildBlankCard(context),
                  const SizedBox(height: 10),
                  _buildCustomCard(context),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10, left: 2),
                    child: Text('COLLECTIONS',
                        style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w700,
                            color: _textMid.withOpacity(0.6))),
                  ),
                  ...tasbeehCollections.asMap().entries.map((entry) {
                    final index = entry.key;
                    final collection = entry.value;
                    final int total =
                        collection.items.fold(0, (s, i) => s + i.count);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => TasbihCounterScreen(
                                    collection: collection))),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _border, width: 1),
                            boxShadow: [
                              BoxShadow(
                                  color: _navy.withOpacity(0.07),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3))
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                    color: _navy,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: _gold.withOpacity(0.5),
                                        width: 1.5)),
                                child: Center(
                                    child: Text('${index + 1}',
                                        style: const TextStyle(
                                            color: _gold,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold))),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                  child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(collection.arabicName,
                                      style: const TextStyle(
                                          fontSize: 16,
                                          color: _gold,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(collection.name,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: _textMid,
                                          fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 4),
                                  Text(
                                      collection.items
                                          .map((i) =>
                                              '${i.phrase.split('\n').first} ×${i.count}')
                                          .join('  ·  '),
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: _textMid.withOpacity(0.7)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ],
                              )),
                              const SizedBox(width: 10),
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                            color: _goldLight,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: _gold.withOpacity(0.3),
                                                width: 1)),
                                        child: Text('$total',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Color.fromARGB(
                                                    255, 140, 105, 30)))),
                                    const SizedBox(height: 4),
                                    const Icon(Icons.arrow_forward_ios_rounded,
                                        size: 13, color: _textMid),
                                  ]),
                            ]),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlankCard(BuildContext context) => GestureDetector(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => TasbihCounterScreen(collection: blankTasbih))),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_navy, _navyMid],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _gold.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: _navy.withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: _gold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _gold.withOpacity(0.5), width: 1.5)),
                  child: const Icon(Icons.radio_button_unchecked_rounded,
                      color: _gold, size: 24)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('تسبيح حر',
                        style: TextStyle(
                            fontSize: 16,
                            color: _gold,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    const Text('Blank Tasbih',
                        style: TextStyle(
                            fontSize: 13,
                            color: _white,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text('Unlimited · loops every 100 · progress saved',
                        style: TextStyle(
                            fontSize: 11, color: _white.withOpacity(0.5)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ])),
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 13, color: _gold),
            ]),
          ),
        ),
      );

  Widget _buildCustomCard(BuildContext context) => GestureDetector(
        onTap: () => _showCustomDialog(context),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [
              Color.fromARGB(255, 30, 80, 55),
              Color.fromARGB(255, 20, 55, 38)
            ], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _mintGreen.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: _navy.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: _mintGreen.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _mintGreen.withOpacity(0.5), width: 1.5)),
                  child: const Icon(Icons.tune_rounded,
                      color: _mintGreen, size: 22)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('تسبيح مخصص',
                        style: TextStyle(
                            fontSize: 16,
                            color: _mintGreen,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    const Text('Custom Tasbih',
                        style: TextStyle(
                            fontSize: 13,
                            color: _white,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text('Set your own target number',
                        style: TextStyle(
                            fontSize: 11, color: _white.withOpacity(0.5))),
                  ])),
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 13, color: _mintGreen),
            ]),
          ),
        ),
      );

  void _showCustomDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _offWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Set Custom Target',
            style: TextStyle(
                color: _textDark, fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Enter how many times you want to count',
              style: TextStyle(color: _textMid, fontSize: 13)),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'e.g. 500',
              hintStyle: TextStyle(color: _textMid.withOpacity(0.5)),
              filled: true,
              fillColor: _white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: _gold.withOpacity(0.7), width: 1.5)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: TextStyle(color: _textMid, fontSize: 13))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: _gold,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              final int? t = int.tryParse(ctrl.text.trim());
              if (t != null && t > 0) {
                Navigator.pop(ctx);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => TasbihCounterScreen(
                            collection: buildCustomTasbih(t))));
              }
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// COUNTER SCREEN — Tasbih tab (bead view) + Counter tab (original ring view)
// ══════════════════════════════════════════════════════════════════════════════
class TasbihCounterScreen extends StatefulWidget {
  final TasbeehCollection collection;
  const TasbihCounterScreen({super.key, required this.collection});
  @override
  State<TasbihCounterScreen> createState() => _TasbihCounterScreenState();
}

class _TasbihCounterScreenState extends State<TasbihCounterScreen>
    with TickerProviderStateMixin {
  int currentIndex = 0;
  int count = 0;
  int blankTotal = 0;
  int blankLoops = 0;
  bool _showComplete = false;
  bool _prefsLoaded = false;

  // 0 = Tasbih (bead view, default), 1 = Counter (ring view)
  int _activeTab = 0;

  // Direction: true = left→right (+), false = right→left (-)
  bool _leftToRight = true;

  late AnimationController _tapCtrl, _completeCtrl;
  late Animation<double> _tapScale, _completeScale, _completeFade;

  int _beadCount = 0;
  int get _beadTotal => 33;

  @override
  void initState() {
    super.initState();
    _tapCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _tapScale = Tween<double>(begin: 1.0, end: 0.88)
        .animate(CurvedAnimation(parent: _tapCtrl, curve: Curves.easeInOut));
    _completeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _completeScale = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _completeCtrl, curve: Curves.elasticOut));
    _completeFade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _completeCtrl, curve: Curves.easeOut));
    _loadPrefs();
  }

  @override
  void dispose() {
    _tapCtrl.dispose();
    _completeCtrl.dispose();
    super.dispose();
  }

  String get _name => widget.collection.name;

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    if (widget.collection.isBlank) {
      setState(() {
        count = p.getInt(_prefKey(_name, 'blank_count')) ?? 0;
        blankLoops = p.getInt(_prefKey(_name, 'blank_loops')) ?? 0;
        blankTotal = p.getInt(_prefKey(_name, 'blank_total')) ?? 0;
        _beadCount = blankTotal % _beadTotal;
        _prefsLoaded = true;
      });
    } else {
      final si = p.getInt(_prefKey(_name, 'index')) ?? 0;
      final ci = si.clamp(0, widget.collection.items.length - 1);
      final sc = p.getInt(_prefKey(_name, 'count_$ci')) ?? 0;
      setState(() {
        currentIndex = ci;
        count = sc;
        _beadCount = count % _beadTotal;
        _prefsLoaded = true;
      });
    }
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    if (widget.collection.isBlank) {
      await p.setInt(_prefKey(_name, 'blank_count'), count);
      await p.setInt(_prefKey(_name, 'blank_loops'), blankLoops);
      await p.setInt(_prefKey(_name, 'blank_total'), blankTotal);
    } else {
      await p.setInt(_prefKey(_name, 'index'), currentIndex);
      await p.setInt(_prefKey(_name, 'count_$currentIndex'), count);
    }
  }

  Future<void> _clearPrefs() async {
    final p = await SharedPreferences.getInstance();
    if (widget.collection.isBlank) {
      await p.remove(_prefKey(_name, 'blank_count'));
      await p.remove(_prefKey(_name, 'blank_loops'));
      await p.remove(_prefKey(_name, 'blank_total'));
    } else {
      await p.remove(_prefKey(_name, 'index'));
      for (int i = 0; i < widget.collection.items.length; i++) {
        await p.remove(_prefKey(_name, 'count_$i'));
      }
    }
  }

  void _increment() {
    HapticFeedback.lightImpact();
    _tapCtrl.forward().then((_) => _tapCtrl.reverse());

    if (widget.collection.isBlank) {
      setState(() {
        count++;
        blankTotal++;
        _beadCount = (_beadCount + (_leftToRight ? 1 : -1)) % _beadTotal;
        if (_beadCount < 0) _beadCount += _beadTotal;
        if (count == 100) {
          HapticFeedback.mediumImpact();
          blankLoops++;
          count = 0;
          _flash();
        }
      });
      _savePrefs();
      return;
    }

    setState(() {
      final item = widget.collection.items[currentIndex];
      final bool isLast = currentIndex == widget.collection.items.length - 1;
      _beadCount = (_beadCount + (_leftToRight ? 1 : -1)) % _beadTotal;
      if (_beadCount < 0) _beadCount += _beadTotal;
      if (count < item.count) {
        count++;
        if (count == item.count) {
          HapticFeedback.mediumImpact();
          _flash();
        }
      } else {
        if (!isLast) {
          currentIndex++;
          count = 1;
          _savePrefs();
        }
      }
    });
    _savePrefs();
  }

  void _flash() {
    _showComplete = true;
    _completeCtrl.forward(from: 0).then((_) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _showComplete = false);
      });
    });
  }

  void _resetCounter() {
    HapticFeedback.selectionClick();
    setState(() {
      count = 0;
      currentIndex = 0;
      blankLoops = 0;
      blankTotal = 0;
      _beadCount = 0;
      _showComplete = false;
    });
    _clearPrefs();
  }

  TasbeehItem get _curItem => widget.collection.isBlank
      ? TasbeehItem(phrase: '', arabicPhrase: '', count: 0)
      : widget.collection.items[currentIndex];

  int get _dc => widget.collection.isBlank ? count % 100 : count;
  int get _tc => widget.collection.isBlank ? 100 : _curItem.count;

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (!_prefsLoaded) {
      return Scaffold(
        backgroundColor: _navy,
        appBar: buildAppBar(context, widget.collection.name,
            const MoreOptionsScreen(), screenFrom),
        body: const Center(child: CircularProgressIndicator(color: _gold)),
      );
    }

    return Scaffold(
      backgroundColor: _navy,
      appBar:
          buildAppBar(context, 'Tasbih', const MoreOptionsScreen(), screenFrom),
      body: Column(children: [
        _phraseHeader(),
        _tabToggle(),
        Expanded(child: _activeTab == 0 ? _tasbihTab() : _counterTab()),
      ]),
    );
  }

  // ── Phrase header ──────────────────────────────────────────────────────────
  Widget _phraseHeader() {
    final col = widget.collection;
    final item = _curItem;
    final int n = col.items.length;

    return Container(
      decoration: BoxDecoration(
        color: _navy,
        border:
            Border(bottom: BorderSide(color: _gold.withOpacity(0.3), width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(children: [
        Text(col.arabicName,
            style: const TextStyle(
                color: _gold, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(col.name,
            style: TextStyle(color: _white.withOpacity(0.45), fontSize: 11)),
        if (!col.isBlank) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _navyMid,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _gold.withOpacity(0.35), width: 1.5),
            ),
            child: Column(children: [
              if (item.arabicPhrase.isNotEmpty)
                Text(item.arabicPhrase,
                    style: const TextStyle(
                        color: _gold,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.5),
                    textAlign: TextAlign.center),
              if (item.phrase.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(item.phrase,
                    style: TextStyle(
                        color: _white.withOpacity(0.6),
                        fontSize: 12,
                        height: 1.4),
                    textAlign: TextAlign.center),
              ],
            ]),
          ),
          if (n > 1) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(n, (i) {
                final bool done = i < currentIndex, active = i == currentIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: done
                        ? _mintGreen
                        : active
                            ? _gold
                            : _white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ],
        ],
        if (col.isBlank) ...[
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _statChip(label: 'Total', value: '$blankTotal'),
            const SizedBox(width: 12),
            _statChip(label: 'Rounds', value: '$blankLoops'),
          ]),
        ],
      ]),
    );
  }

  // ── Tab toggle ─────────────────────────────────────────────────────────────
  Widget _tabToggle() => Container(
        color: _navyMid,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(children: [
          Expanded(child: _tabBtn('Tasbih', 0, Icons.lens_rounded)),
          const SizedBox(width: 10),
          Expanded(
              child: _tabBtn('Counter', 1, Icons.radio_button_checked_rounded)),
        ]),
      );

  Widget _tabBtn(String label, int idx, IconData icon) {
    final bool active = _activeTab == idx;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _activeTab = idx);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active ? _navy : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? _gold.withOpacity(0.6) : _white.withOpacity(0.12),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 14, color: active ? _gold : _white.withOpacity(0.4)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? _gold : _white.withOpacity(0.45),
                  letterSpacing: 0.3)),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TASBIH TAB — dark bead screen, tap anywhere to count
  // ══════════════════════════════════════════════════════════════════════════
  Widget _tasbihTab() => GestureDetector(
        // Swipe right = count (L→R mode); swipe left = count (R→L mode)
        onHorizontalDragEnd: (details) {
          final double v = details.primaryVelocity ?? 0;
          if (_leftToRight && v > 80) _increment();
          if (!_leftToRight && v < -80) _increment();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: const Color.fromARGB(255, 5, 12, 36),
          child: Stack(children: [
            // Soft radial glow
            Center(
                child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                      colors: [_gold.withOpacity(0.045), Colors.transparent])),
            )),

            Column(children: [
              // ── Count display ────────────────────────────────────────────
              Expanded(
                  flex: 3,
                  child: Center(
                      child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.collection.isBlank && blankLoops > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                                color: _gold.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: _gold.withOpacity(0.3), width: 1)),
                            child: Text('Loop $blankLoops',
                                style: const TextStyle(
                                    color: _gold,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),

                      // Big count
                      TweenAnimationBuilder<int>(
                        tween: IntTween(begin: 0, end: _dc),
                        duration: const Duration(milliseconds: 150),
                        builder: (_, val, __) => Text('$val',
                            style: const TextStyle(
                                color: _white,
                                fontSize: 80,
                                fontWeight: FontWeight.w200,
                                height: 1.0,
                                letterSpacing: 2)),
                      ),

                      // / target
                      if (_tc > 0)
                        Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('/ $_tc',
                                  style: TextStyle(
                                      color: _white.withOpacity(0.35),
                                      fontSize: 20,
                                      fontWeight: FontWeight.w300)),
                              const SizedBox(width: 6),
                              Icon(Icons.loop_rounded,
                                  size: 14, color: _white.withOpacity(0.25)),
                            ]),
                    ],
                  ))),

              // ── Bead strand ──────────────────────────────────────────────
              Expanded(
                  flex: 4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Direction button
                      Padding(
                        padding: const EdgeInsets.only(right: 18, bottom: 10),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _leftToRight = !_leftToRight);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                  color: _navyMid.withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: _gold.withOpacity(0.4), width: 1)),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                        _leftToRight
                                            ? Icons.arrow_forward_rounded
                                            : Icons.arrow_back_rounded,
                                        color: _gold,
                                        size: 13),
                                    const SizedBox(width: 4),
                                    Text(_leftToRight ? 'L → R' : 'R → L',
                                        style: const TextStyle(
                                            color: _gold,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5)),
                                  ]),
                            ),
                          ),
                        ),
                      ),

                      // Bead strand — diagonal arc from top-right to bottom-left
                      SizedBox(
                        width: double.infinity,
                        height: 180,
                        child: _BeadStrand(
                            totalBeads: _beadTotal,
                            currentBead: _beadCount,
                            leftToRight: _leftToRight),
                      ),

                      const SizedBox(height: 14),
                      Text(
                          _leftToRight
                              ? 'Swipe right  →  to count'
                              : '←  Swipe left  to count',
                          style: TextStyle(
                              color: _white.withOpacity(0.22),
                              fontSize: 11,
                              letterSpacing: 0.5)),
                    ],
                  )),

              // ── Bottom buttons ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _darkBtn(
                      label: 'Reset',
                      icon: Icons.refresh_rounded,
                      onTap: _resetCounter),
                  const SizedBox(width: 12),
                  _darkBtn(
                      label: 'Select Tasbih',
                      icon: Icons.list_rounded,
                      isGold: true,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const CollectionSelectionScreen()))),
                ]),
              ),
            ]),

            if (_showComplete) _flashWidget(),
          ]),
        ),
      );

  // ══════════════════════════════════════════════════════════════════════════
  // COUNTER TAB — original ring view, completely unchanged
  // ══════════════════════════════════════════════════════════════════════════
  Widget _counterTab() {
    final double progress = _tc > 0 ? (_dc / _tc).clamp(0.0, 1.0) : 0.0;
    final bool isComplete = _tc > 0 && _dc >= _tc;
    final bool isLast = widget.collection.isBlank
        ? false
        : currentIndex == widget.collection.items.length - 1;

    return Container(
      color: _offWhite,
      child: Stack(alignment: Alignment.center, children: [
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          // Ring
          Stack(alignment: Alignment.center, children: [
            Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                  BoxShadow(
                      color: _gold.withOpacity(isComplete ? 0.25 : 0.08),
                      blurRadius: 30,
                      spreadRadius: isComplete ? 8 : 2)
                ])),
            SizedBox(
                width: 200,
                height: 200,
                child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    builder: (_, val, __) => CircularProgressIndicator(
                        value: val,
                        strokeWidth: 10,
                        backgroundColor: _navy.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                            isComplete ? _mintGreen : _gold),
                        strokeCap: StrokeCap.round))),
            Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                    color: _white,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color:
                            isComplete ? _mintGreen.withOpacity(0.3) : _border,
                        width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: _navy.withOpacity(0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4))
                    ]),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TweenAnimationBuilder<int>(
                          tween: IntTween(begin: 0, end: _dc),
                          duration: const Duration(milliseconds: 150),
                          builder: (_, val, __) => Text('$val',
                              style: const TextStyle(
                                  fontSize: 52,
                                  fontWeight: FontWeight.bold,
                                  color: _navy,
                                  height: 1))),
                      Text(
                          _tc > 0
                              ? (widget.collection.isBlank && blankLoops > 0
                                  ? '+ ${blankLoops}×100'
                                  : 'of $_tc')
                              : 'of 100',
                          style: const TextStyle(
                              fontSize: 14,
                              color: _textMid,
                              fontWeight: FontWeight.w500)),
                    ])),
          ]),

          const SizedBox(height: 28),

          // Tap button
          GestureDetector(
            onTap: _increment,
            child: AnimatedBuilder(
              animation: _tapScale,
              builder: (_, __) => Transform.scale(
                scale: _tapScale.value,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [
                        isComplete ? _mintGreen : _navy,
                        isComplete
                            ? const Color.fromARGB(255, 40, 160, 115)
                            : _navyLight
                      ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      border: Border.all(
                          color: isComplete
                              ? _mintGreen.withOpacity(0.5)
                              : _gold.withOpacity(0.6),
                          width: 2),
                      boxShadow: [
                        BoxShadow(
                            color: (isComplete ? _mintGreen : _navy)
                                .withOpacity(0.35),
                            blurRadius: 20,
                            spreadRadius: 2,
                            offset: const Offset(0, 8))
                      ]),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                            isComplete && !isLast
                                ? Icons.skip_next_rounded
                                : isComplete && isLast
                                    ? Icons.check_rounded
                                    : Icons.add_rounded,
                            size: 40,
                            color: isComplete ? _white : _gold),
                        Text(
                            isComplete && !isLast
                                ? 'Next'
                                : isComplete && isLast
                                    ? 'Done'
                                    : 'Count',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isComplete
                                    ? _white
                                    : _gold.withOpacity(0.85))),
                      ]),
                ),
              ),
            ),
          ),

          const SizedBox(height: 22),

          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _bottomBtn(
                label: 'Reset',
                icon: Icons.refresh_rounded,
                onTap: _resetCounter,
                bg: _white,
                textColor: _textDark,
                borderColor: _border),
            const SizedBox(width: 12),
            _bottomBtn(
                label: 'Select Tasbih',
                icon: Icons.list_rounded,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CollectionSelectionScreen())),
                bg: _navy,
                textColor: _gold,
                borderColor: _gold.withOpacity(0.5)),
          ]),
        ]),
        if (_showComplete) _flashWidget(),
      ]),
    );
  }

  // ── Flash overlay ──────────────────────────────────────────────────────────
  Widget _flashWidget() {
    final bool isLast = widget.collection.isBlank
        ? false
        : currentIndex == widget.collection.items.length - 1;
    final String msg = widget.collection.isBlank
        ? '$blankLoops × 100 — SubhanAllah! 🤲'
        : isLast
            ? 'Collection Complete! 🤲'
            : '${_curItem.phrase.split('\n').first} Done!';
    final Color fc = widget.collection.isBlank ? _gold : _mintGreen;
    final Color tc = widget.collection.isBlank ? _navy : _white;

    return AnimatedBuilder(
      animation: _completeCtrl,
      builder: (_, __) => FadeTransition(
        opacity: _completeFade,
        child: ScaleTransition(
          scale: _completeScale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
                color: fc,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: fc.withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 6))
                ]),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                  widget.collection.isBlank
                      ? Icons.loop_rounded
                      : Icons.check_circle_rounded,
                  color: tc,
                  size: 22),
              const SizedBox(width: 8),
              Text(msg,
                  style: TextStyle(
                      color: tc, fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Buttons ────────────────────────────────────────────────────────────────
  Widget _darkBtn(
          {required String label,
          required IconData icon,
          required VoidCallback onTap,
          bool isGold = false}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
              color:
                  isGold ? _gold.withOpacity(0.12) : _navyMid.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isGold
                      ? _gold.withOpacity(0.5)
                      : _white.withOpacity(0.15),
                  width: 1.5)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                size: 16, color: isGold ? _gold : _white.withOpacity(0.6)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isGold ? _gold : _white.withOpacity(0.6))),
          ]),
        ),
      );

  Widget _bottomBtn(
          {required String label,
          required IconData icon,
          required VoidCallback onTap,
          required Color bg,
          required Color textColor,
          required Color borderColor}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: _navy.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3))
              ]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor)),
          ]),
        ),
      );

  Widget _statChip({required String label, required String value}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
            color: _navyMid,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _gold.withOpacity(0.3), width: 1)),
        child: Column(children: [
          Text(value,
              style: const TextStyle(
                  color: _gold, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label,
              style: TextStyle(color: _white.withOpacity(0.55), fontSize: 11)),
        ]),
      );
}
