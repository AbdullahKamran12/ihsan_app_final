import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ihsan_app_final/sharedWidgets.dart';
import 'package:ihsan_app_final/screens/moreOptionsScreen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _navy = Color.fromARGB(255, 10, 25, 60);
const Color _navyMid = Color.fromARGB(255, 18, 42, 95);
const Color _gold = Color.fromARGB(255, 212, 175, 95);
const Color _goldLight = Color.fromARGB(255, 252, 243, 210);
const Color _offWhite = Color.fromARGB(255, 247, 249, 255);
const Color _textDark = Color.fromARGB(255, 15, 30, 65);
const Color _textMid = Color.fromARGB(255, 90, 115, 160);
const Color _border = Color.fromARGB(255, 210, 220, 240);

// ── Section data ──────────────────────────────────────────────────────────────
class _Section {
  final String title;
  final String subtitle;
  final IconData icon;
  final int page;
  const _Section(this.title, this.subtitle, this.icon, this.page);
}

const List<_Section> _sections = [
  _Section('Du\'aas', 'Supplications & remembrance',
      Icons.volunteer_activism_outlined, 12),
  _Section('How to Pray Salah', 'Step-by-step prayer guide',
      Icons.self_improvement_outlined, 31),
  _Section(
      'How to Do Wudu', 'Ritual purification', Icons.water_drop_outlined, 27),
  _Section('Adhaan', 'The call to prayer', Icons.spatial_audio_outlined, 45),
  _Section('Eid Salah', 'Eid prayer guide', Icons.celebration_outlined, 54),
  _Section('Janazah Salah', 'Funeral prayer guide',
      Icons.local_florist_outlined, 59),
];

class InfoScreen extends StatefulWidget {
  const InfoScreen({Key? key}) : super(key: key);

  @override
  _InfoScreenState createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen>
    with SingleTickerProviderStateMixin {
  late String pdfPath;
  bool isPdfLoaded = false;
  int currentPage = 0;
  int totalPages = 0;
  PDFViewController? pdfController;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _loadPdf();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showContentsSheet());
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPdf() async {
    try {
      final data = await rootBundle.load('assets/ONLINE-PDF-A-Childs-Gift.pdf');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/ChildsGift.pdf');
      await file.writeAsBytes(data.buffer.asUint8List());
      setState(() {
        pdfPath = file.path;
        isPdfLoaded = true;
      });
      _fadeCtrl.forward();
    } catch (e) {
      debugPrint('PDF load error: $e');
    }
  }

  void _goToPage(int page) {
    if (page > 0 && page <= totalPages) {
      pdfController?.setPage(page - 1);
    }
  }

  // ── Contents bottom sheet ──────────────────────────────────────────────────
  void _showContentsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ContentsSheet(
        sections: _sections,
        onSelect: (page) {
          Navigator.pop(context);
          _goToPage(page);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      appBar: buildAppBar(
          context, 'Information & Basics', const MoreOptionsScreen(), null),
      body: isPdfLoaded
          ? FadeTransition(
              opacity: _fadeAnim,
              child: Column(children: [
                // ── Top chrome bar ───────────────────────────────────────────
                _TopBar(
                  currentPage: currentPage,
                  totalPages: totalPages,
                  onContents: _showContentsSheet,
                  onPrev: currentPage > 0
                      ? () => _goToPage(
                          currentPage) // page is 0-indexed, so currentPage = prev+1
                      : null,
                  onNext: currentPage < totalPages - 1
                      ? () => _goToPage(currentPage + 2)
                      : null,
                ),
                // ── PDF viewer ───────────────────────────────────────────────
                Expanded(
                  child: PDFView(
                    filePath: pdfPath,
                    enableSwipe: true,
                    swipeHorizontal: true,
                    autoSpacing: false,
                    pageFling: true,
                    onViewCreated: (c) => pdfController = c,
                    onPageChanged: (page, total) => setState(() {
                      currentPage = page ?? 0;
                      totalPages = total ?? 0;
                    }),
                    onError: (e) => debugPrint('PDF error: $e'),
                    onPageError: (p, e) => debugPrint('Page $p error: $e'),
                  ),
                ),
                // ── Bottom page indicator ────────────────────────────────────
                _BottomBar(
                  currentPage: currentPage,
                  totalPages: totalPages,
                  onJump: _goToPage,
                ),
              ]),
            )
          : const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: _gold),
                  SizedBox(height: 16),
                  Text('Loading…',
                      style: TextStyle(color: _gold, fontSize: 13)),
                ],
              ),
            ),
    );
  }
}

// ── Top chrome bar ─────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final int currentPage, totalPages;
  final VoidCallback onContents;
  final VoidCallback? onPrev, onNext;

  const _TopBar({
    required this.currentPage,
    required this.totalPages,
    required this.onContents,
    this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _navyMid,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(children: [
        // Contents button
        _NavBtn(
          icon: Icons.menu_book_rounded,
          label: 'Contents',
          onTap: onContents,
        ),
        const Spacer(),
        // Prev / page count / next
        _IconBtn(Icons.chevron_left_rounded, onPrev),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            totalPages > 0 ? '${currentPage + 1} / $totalPages' : '—',
            style: const TextStyle(
                color: _gold, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        _IconBtn(Icons.chevron_right_rounded, onNext),
      ]),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: _gold.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _gold.withOpacity(0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: _gold),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: _gold, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _IconBtn(this.icon, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: onTap != null ? _gold.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 22, color: onTap != null ? _gold : _gold.withOpacity(0.25)),
      ),
    );
  }
}

// ── Bottom bar with jump-to-page ───────────────────────────────────────────────
class _BottomBar extends StatefulWidget {
  final int currentPage, totalPages;
  final ValueChanged<int> onJump;
  const _BottomBar(
      {required this.currentPage,
      required this.totalPages,
      required this.onJump});

  @override
  State<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<_BottomBar> {
  final _ctrl = TextEditingController();
  bool _editing = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final page = int.tryParse(_ctrl.text);
    if (page != null) widget.onJump(page);
    _ctrl.clear();
    setState(() => _editing = false);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.totalPages > 0
        ? (widget.currentPage + 1) / widget.totalPages
        : 0.0;

    return Container(
      color: _navyMid,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: _gold.withOpacity(0.15),
            valueColor: const AlwaysStoppedAnimation<Color>(_gold),
            minHeight: 3,
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.auto_stories_outlined, size: 13, color: _textMid),
          const SizedBox(width: 6),
          Text(
            'Page ${widget.currentPage + 1} of ${widget.totalPages}',
            style: const TextStyle(color: _textMid, fontSize: 11),
          ),
          const Spacer(),
          // Jump to page
          _editing
              ? SizedBox(
                  width: 80,
                  height: 30,
                  child: TextField(
                    controller: _ctrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: _gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Go to…',
                      hintStyle: TextStyle(
                          color: _gold.withOpacity(0.5), fontSize: 11),
                      filled: true,
                      fillColor: _gold.withOpacity(0.1),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: _gold.withOpacity(0.4)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: _gold.withOpacity(0.4)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _gold),
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                )
              : GestureDetector(
                  onTap: () => setState(() => _editing = true),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _gold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _gold.withOpacity(0.3)),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.keyboard_outlined, size: 12, color: _gold),
                      SizedBox(width: 5),
                      Text('Go to page',
                          style: TextStyle(
                              color: _gold,
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ),
        ]),
      ]),
    );
  }
}

// ── Contents bottom sheet ──────────────────────────────────────────────────────
class _ContentsSheet extends StatelessWidget {
  final List<_Section> sections;
  final ValueChanged<int> onSelect;

  const _ContentsSheet({required this.sections, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _offWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 16),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: _border, borderRadius: BorderRadius.circular(2)),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: _navy, borderRadius: BorderRadius.circular(10)),
              child:
                  const Icon(Icons.menu_book_rounded, size: 18, color: _gold),
            ),
            const SizedBox(width: 12),
            const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Table of Contents",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _textDark)),
                  Text("Jump to any section",
                      style: TextStyle(fontSize: 12, color: _textMid)),
                ]),
          ]),
        ),
        const Divider(height: 1, color: _border),
        // Section tiles
        ...sections.asMap().entries.map((e) {
          final i = e.key;
          final section = e.value;
          return _SectionTile(
            section: section,
            index: i + 1,
            isLast: i == sections.length - 1,
            onTap: () => onSelect(section.page),
          );
        }),
      ]),
    );
  }
}

class _SectionTile extends StatelessWidget {
  final _Section section;
  final int index;
  final bool isLast;
  final VoidCallback onTap;

  const _SectionTile({
    required this.section,
    required this.index,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      InkWell(
        onTap: onTap,
        splashColor: _navy.withOpacity(0.05),
        highlightColor: _navy.withOpacity(0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(children: [
            // Number badge
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _goldLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _gold.withOpacity(0.4)),
              ),
              child: Center(
                child: Text('$index',
                    style: const TextStyle(
                        color: Color.fromARGB(255, 140, 105, 30),
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 14),
            // Icon
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: _navy.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(section.icon, size: 16, color: _navy),
            ),
            const SizedBox(width: 12),
            // Text
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(section.title,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _textDark)),
                    Text(section.subtitle,
                        style: const TextStyle(fontSize: 11, color: _textMid)),
                  ]),
            ),
            // Page number + chevron
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('p. ${section.page}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: _textMid,
                      fontWeight: FontWeight.w500)),
              const Icon(Icons.chevron_right_rounded,
                  size: 16, color: _textMid),
            ]),
          ]),
        ),
      ),
      if (!isLast)
        const Divider(height: 1, indent: 20, endIndent: 20, color: _border),
    ]);
  }
}
