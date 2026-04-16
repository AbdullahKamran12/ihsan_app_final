import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ihsan_app_final/sharedWidgets.dart';
import 'package:ihsan_app_final/screens/homeScreen.dart';
import 'package:ihsan_app_final/screens/moreoptionsScreen.dart';
import 'package:ihsan_app_final/screens/prayerScreen.dart';
import 'package:ihsan_app_final/screens/qiblaScreen.dart';

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  _QuranScreenState createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> with WidgetsBindingObserver {
  // ── PDF state ─────────────────────────────────────────────────────
  int currentPage = 0;
  int totalPages = 0;
  PDFViewController? _portraitCtrl;
  String? pdfPath;
  bool isPdfLoaded = false;

  // ── UI state ──────────────────────────────────────────────────────
  bool surahJuzBool = true;
  bool _isLandscape = false;
  // Guard so the orientation button can't be double-tapped mid-transition
  bool _orientationLocked = false;
  // ── Mode: 0 = PDF, 1 = Ayah by Ayah ─────────────────────────────
  int _quranMode = 0;

  // ── Prefs ─────────────────────────────────────────────────────────
  int? _bookmarkedPage;
  int? _lastReadPage;

  // ── Landscape PageController ──────────────────────────────────────
  PageController? _spreadCtrl;

  // ── Palette ───────────────────────────────────────────────────────
  static const Color navy = Color.fromARGB(255, 10, 25, 60);
  static const Color navyMid = Color.fromARGB(255, 18, 42, 95);
  static const Color navyLight = Color.fromARGB(255, 28, 58, 120);
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

  // ──────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Lock to portrait initially
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _loadSavedDataThenPdf();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _spreadCtrl?.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  // ── WidgetsBindingObserver — fires when OS actually rotates ───────
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) return;
    final size = WidgetsBinding.instance.window.physicalSize;
    final isNowLandscape = size.width > size.height;

    // Only act when it matches what we requested, and only if locked
    if (_orientationLocked) {
      if (isNowLandscape && !_isLandscape) {
        // Phone has physically rotated to landscape — now show spread view
        final int spread = _spreadOf(currentPage);
        _spreadCtrl?.dispose();
        _spreadCtrl = PageController(initialPage: spread);
        setState(() {
          _isLandscape = true;
          _orientationLocked = false;
        });
      } else if (!isNowLandscape && _isLandscape) {
        // Phone has physically rotated back to portrait.
        // Clear old controller — onViewCreated will assign a fresh one
        // and call setPage(currentPage) via microtask. No postFrameCallback
        // here to avoid racing with onViewCreated and causing exceptions.
        _portraitCtrl = null;
        _spreadCtrl?.dispose();
        _spreadCtrl = null;
        setState(() {
          _isLandscape = false;
          _orientationLocked = false;
        });
      }
    }
  }

  // ── Load prefs, then PDF ──────────────────────────────────────────
  Future<void> _loadSavedDataThenPdf() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final lastRead = prefs.getInt('quran_last_read');
    setState(() {
      _bookmarkedPage = prefs.getInt('quran_bookmark');
      _lastReadPage = lastRead;
      if (lastRead != null && lastRead > 0) currentPage = lastRead;
    });
    await _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      final data = await rootBundle.load('assets/quran_majeed_13_line.pdf');
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/Quran.pdf';
      await File(path).writeAsBytes(data.buffer.asUint8List());
      if (!mounted) return;
      setState(() {
        pdfPath = path;
        isPdfLoaded = true;
      });
    } catch (e) {
      debugPrint('PDF load error: $e');
    }
  }

  // ── Prefs helpers ─────────────────────────────────────────────────
  Future<void> _saveBookmark(int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('quran_bookmark', page);
    if (!mounted) return;
    setState(() => _bookmarkedPage = page);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.bookmark, color: gold, size: 18),
        const SizedBox(width: 8),
        Text('Bookmarked page ${page + 1}',
            style: const TextStyle(color: white)),
      ]),
      backgroundColor: navyMid,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _saveLastRead(int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('quran_last_read', page);
    if (!mounted) return;
    // Don't call setState here — it would rebuild the PDF view and cause flashes.
    // Just update the prefs and the in-memory field silently.
    _lastReadPage = page;
  }

  // ── Navigation ────────────────────────────────────────────────────
  void _onItemTapped(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        break;
      case 1:
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const PrayerTimesScreen()));
        break;
      case 2:
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const QiblaScreen()));
        break;
      case 3:
        break;
      case 4:
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const MoreOptionsScreen()));
        break;
    }
  }

  // ── Go to page (1-based) ─────────────────────────────────────────
  void _goToPage(int pageNumber) {
    final int idx = pageNumber - 1;
    if (idx < 0 || (totalPages > 0 && idx >= totalPages)) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: navyMid,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: gold.withOpacity(0.4), width: 1.5)),
          title: const Text('Invalid Page',
              style: TextStyle(color: gold, fontWeight: FontWeight.bold)),
          content: Text('Please enter a page number between 1 and $totalPages.',
              style: const TextStyle(color: white)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK',
                  style: TextStyle(color: gold, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    if (_isLandscape && _spreadCtrl != null && _spreadCtrl!.hasClients) {
      _spreadCtrl!.jumpToPage(_spreadOf(idx));
      setState(() => currentPage = idx);
      _saveLastRead(idx);
    } else {
      _portraitCtrl?.setPage(idx);
      // currentPage and _lastReadPage will be updated via onPageChanged
    }
  }

  // ── Orientation toggle ────────────────────────────────────────────
  void _toggleOrientation() {
    if (_orientationLocked) return; // ignore taps mid-transition
    _orientationLocked = true;

    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    // _isLandscape is flipped in didChangeMetrics once the OS has actually rotated
  }

  // ── Spread helpers ────────────────────────────────────────────────
  // RTL Mushaf layout:
  //   Spread 0 → LEFT = PDF[0], RIGHT = blank
  //   Spread n → LEFT = PDF[2n], RIGHT = PDF[2n-1]
  int _spreadOf(int page) => page == 0 ? 0 : 1 + ((page - 1) ~/ 2);
  int _leftPageOf(int spread) => spread * 2;
  int _rightPageOf(int spread) => spread == 0 ? -1 : spread * 2 - 1;

  // ── Go-to-page dialog ─────────────────────────────────────────────
  Future<void> _showGoToPageDialog() async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: navyMid,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: gold.withOpacity(0.4), width: 1.5)),
        title: const Text('Go to Page',
            style: TextStyle(color: gold, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: white),
          decoration: InputDecoration(
            hintText: 'Enter page number (1–$totalPages)',
            hintStyle: TextStyle(color: white.withOpacity(0.45)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: gold.withOpacity(0.35)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: gold, width: 1.5),
            ),
            filled: true,
            fillColor: navyLight.withOpacity(0.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child:
                Text('Cancel', style: TextStyle(color: white.withOpacity(0.6))),
          ),
          TextButton(
            onPressed: () {
              final n = int.tryParse(ctrl.text);
              if (n != null) _goToPage(n);
              Navigator.of(context).pop();
            },
            child: const Text('Go',
                style: TextStyle(color: gold, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Derived helpers ───────────────────────────────────────────────
  String get _currentSurahName {
    final p = currentPage + 1;
    for (int i = surahPages.length - 1; i >= 0; i--) {
      if (p >= surahPages[i]) return surahNames[i];
    }
    return '';
  }

  double get _readingProgress =>
      totalPages > 0 ? (currentPage + 1) / totalPages : 0.0;

  // ══════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final bool isBookmarked = _bookmarkedPage == currentPage;

    return Scaffold(
      backgroundColor: navy,
      appBar: _isLandscape
          ? null
          : buildAppBar(context, 'Quran', const HomeScreen(), null),
      bottomNavigationBar: _isLandscape
          ? null
          : buildBottomNavigationBar(context, 3, _onItemTapped),

      // ── DRAWER ─────────────────────────────────────────────────
      drawer: _buildDrawer(),

      // ── BODY ───────────────────────────────────────────────────
      body: _isLandscape
          ? _buildLandscapeBody()
          : Column(
              children: [
                // ── Mode toggle bar (PDF vs Ayah by Ayah) ──────────
                Container(
                  color: navyMid,
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                  child: Row(
                    children: [
                      _modeTab(
                          label: 'PDF',
                          index: 0,
                          icon: Icons.menu_book_rounded),
                      const SizedBox(width: 8),
                      _modeTab(
                          label: 'Ayah by Ayah',
                          index: 1,
                          icon: Icons.format_list_numbered_rounded),
                    ],
                  ),
                ),
                Expanded(
                  child: _quranMode == 0
                      ? _buildPortraitBody(isBookmarked)
                      : const _QuranAyahView(),
                ),
              ],
            ),
    );
  }

  Widget _modeTab(
      {required String label, required int index, required IconData icon}) {
    final bool selected = _quranMode == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _quranMode = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? gold : navyLight.withOpacity(0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? gold : gold.withOpacity(0.2),
              width: selected ? 0 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: selected ? navy : textMid),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? navy : textMid,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // PORTRAIT BODY
  // ══════════════════════════════════════════════════════════════════
  Widget _buildPortraitBody(bool isBookmarked) {
    return Stack(
      children: [
        Column(
          children: [
            // ── Top bar ─────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: navyMid,
                border: Border(
                  bottom: BorderSide(color: gold.withOpacity(0.35), width: 1.5),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(4, 6, 8, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Builder(
                        builder: (ctx) => IconButton(
                          onPressed: () => Scaffold.of(ctx).openDrawer(),
                          icon: const Icon(Icons.menu_book_rounded,
                              color: gold, size: 22),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(_currentSurahName,
                                style: const TextStyle(
                                  color: gold,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis),
                            Text(
                              'Page ${currentPage + 1}  ·  '
                              '${totalPages > 0 ? totalPages : "—"} total',
                              style: TextStyle(
                                  color: white.withOpacity(0.55), fontSize: 11),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _saveBookmark(currentPage),
                        icon: Icon(
                          isBookmarked
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_outline_rounded,
                          color: isBookmarked ? gold : white.withOpacity(0.7),
                          size: 22,
                        ),
                      ),
                      IconButton(
                        onPressed: _showGoToPageDialog,
                        icon: Icon(Icons.search_rounded,
                            color: white.withOpacity(0.8), size: 22),
                      ),
                    ],
                  ),
                  // Progress bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _readingProgress,
                              backgroundColor: white.withOpacity(0.1),
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(gold),
                              minHeight: 4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(_readingProgress * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                              color: gold.withOpacity(0.85),
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── PDF — stable key so it never remounts on page changes ──
            Expanded(
              child: !isPdfLoaded
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: gold),
                          const SizedBox(height: 16),
                          Text('Loading Quran…',
                              style: TextStyle(
                                  color: white.withOpacity(0.6), fontSize: 14)),
                        ],
                      ),
                    )
                  : PDFView(
                      // Stable key — never changes, so no flash on page turn.
                      key: const ValueKey('portrait_pdf'),
                      filePath: pdfPath!,
                      defaultPage: currentPage, // used only on first mount
                      enableSwipe: true,
                      swipeHorizontal: false,
                      pageFling: true,
                      autoSpacing: false,
                      pageSnap: true,
                      fitPolicy: FitPolicy.WIDTH,
                      onRender: (pages) {
                        if (pages != null && pages > 0 && totalPages == 0) {
                          setState(() => totalPages = pages);
                        }
                      },
                      onPageChanged: (page, total) {
                        if (page == null) return;
                        // Update in-place — no key change, no remount, no flash
                        currentPage = page;
                        if (total != null && total > 0) totalPages = total;
                        // Light setState just to refresh the top-bar text
                        if (mounted) setState(() {});
                        _saveLastRead(page);
                      },
                      onViewCreated: (PDFViewController ctrl) {
                        _portraitCtrl = ctrl;
                        // If we came back from landscape, jump to the saved page.
                        // defaultPage already handles the very first load.
                        if (currentPage > 0) {
                          Future.microtask(() {
                            if (mounted) ctrl.setPage(currentPage);
                          });
                        }
                      },
                      onError: (e) => debugPrint('PDF error: $e'),
                      onPageError: (p, e) => debugPrint('Page $p error: $e'),
                    ),
            ),
          ],
        ),

        // ── Rotate button ─────────────────────────────────────────
        Positioned(
          bottom: 72,
          right: 16,
          child: _rotateButton(),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // LANDSCAPE BODY
  // ══════════════════════════════════════════════════════════════════
  Widget _buildLandscapeBody() {
    if (!isPdfLoaded || pdfPath == null) {
      return const Center(child: CircularProgressIndicator(color: gold));
    }
    if (totalPages == 0) {
      // totalPages not yet known — show a placeholder; it will populate when
      // the portrait PDFView fires onRender on first load before orientation change.
      return const Center(child: CircularProgressIndicator(color: gold));
    }
    return _buildSpreadView();
  }

  // ══════════════════════════════════════════════════════════════════
  // LANDSCAPE SPREAD VIEW
  // ══════════════════════════════════════════════════════════════════
  Widget _buildSpreadView() {
    final int nSpreads = 1 + ((totalPages) ~/ 2);

    // Controller is created in didChangeMetrics before this builds
    _spreadCtrl ??= PageController(initialPage: _spreadOf(currentPage));

    // One static page half — no onPageChanged, no setState, pure display
    Widget pageHalf(int pageIndex) {
      if (pageIndex < 0 || pageIndex >= totalPages) {
        return Container(color: const Color.fromARGB(255, 245, 238, 220));
      }
      return PDFView(
        key: ValueKey('lp_$pageIndex'),
        filePath: pdfPath!,
        defaultPage: pageIndex,
        enableSwipe: false, // PageView handles swipe
        swipeHorizontal: false,
        pageFling: false,
        autoSpacing: false,
        pageSnap: false,
        fitPolicy: FitPolicy.BOTH,
        // No onPageChanged — each half is a fixed single page display.
        // Zoom is allowed by default (native PDFView pinch-to-zoom).
        onError: (e) => debugPrint('PDF error: $e'),
        onPageError: (p, e) => debugPrint('Page $p error: $e'),
      );
    }

    return Stack(
      children: [
        // ── Spread PageView (RTL swipe) ───────────────────────────
        PageView.builder(
          controller: _spreadCtrl,
          reverse: true, // swipe right = forward (RTL Mushaf)
          itemCount: nSpreads,
          onPageChanged: (spreadIdx) {
            final lp = _leftPageOf(spreadIdx);
            if (lp < totalPages) {
              setState(() => currentPage = lp);
              _saveLastRead(lp);
            }
          },
          itemBuilder: (_, spreadIdx) {
            final int lPage = _leftPageOf(spreadIdx);
            final int rPage = _rightPageOf(spreadIdx);
            return Row(
              children: [
                Expanded(child: pageHalf(lPage)),
                Container(
                    width: 2, color: const Color.fromARGB(255, 160, 140, 100)),
                Expanded(child: pageHalf(rPage)),
              ],
            );
          },
        ),

        // ── Rotate back — top centre ──────────────────────────────
        Positioned(
          top: 12,
          left: 0,
          right: 0,
          child: Center(child: _rotateButton()),
        ),

        // ── Left arrow (forward in book) — 45 px from left edge ──
        Positioned(
          left: 45,
          top: 0,
          bottom: 0,
          child: Center(
            child: GestureDetector(
              onTap: () {
                if (_spreadCtrl == null || !_spreadCtrl!.hasClients) return;
                final cur = _spreadCtrl!.page?.round() ?? 0;
                if (cur < nSpreads - 1) {
                  _spreadCtrl!.animateToPage(cur + 1,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut);
                }
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: navyMid.withOpacity(0.85),
                  shape: BoxShape.circle,
                  border: Border.all(color: gold.withOpacity(0.4), width: 1),
                ),
                child: const Icon(Icons.arrow_back_ios_rounded,
                    color: gold, size: 16),
              ),
            ),
          ),
        ),

        // ── Right arrow (back in book) — 45 px from right edge ───
        Positioned(
          right: 45,
          top: 0,
          bottom: 0,
          child: Center(
            child: GestureDetector(
              onTap: () {
                if (_spreadCtrl == null || !_spreadCtrl!.hasClients) return;
                final cur = _spreadCtrl!.page?.round() ?? 0;
                if (cur > 0) {
                  _spreadCtrl!.animateToPage(cur - 1,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut);
                }
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: navyMid.withOpacity(0.85),
                  shape: BoxShape.circle,
                  border: Border.all(color: gold.withOpacity(0.4), width: 1),
                ),
                child: const Icon(Icons.arrow_forward_ios_rounded,
                    color: gold, size: 16),
              ),
            ),
          ),
        ),

        // ── Page indicator — bottom centre ────────────────────────
        Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: navyMid.withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: gold.withOpacity(0.4), width: 1),
              ),
              child: Text(
                '${currentPage + 1} / $totalPages',
                style: const TextStyle(
                    color: gold, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Shared rotate button widget ───────────────────────────────────
  Widget _rotateButton() => GestureDetector(
        onTap: _orientationLocked ? null : _toggleOrientation,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: navyMid,
            shape: BoxShape.circle,
            border: Border.all(color: gold.withOpacity(0.7), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: navy.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(Icons.screen_rotation_rounded,
              color: _orientationLocked ? gold.withOpacity(0.4) : gold,
              size: 22),
        ),
      );

  // ══════════════════════════════════════════════════════════════════
  // DRAWER
  // ══════════════════════════════════════════════════════════════════
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: navy,
      child: Builder(builder: (context) {
        final double dw = MediaQuery.of(context).size.width;
        final double dh = MediaQuery.of(context).size.height;

        return Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                  dw * 0.04, dh * 0.055, dw * 0.04, dh * 0.025),
              decoration: BoxDecoration(
                color: navyMid,
                border: Border(
                    bottom:
                        BorderSide(color: gold.withOpacity(0.4), width: 1.5)),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_rounded,
                          color: white, size: 18),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const Text('القرآن الكريم',
                              style: TextStyle(
                                color: gold,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              )),
                          const SizedBox(height: 2),
                          Text('The Noble Quran',
                              style: TextStyle(
                                color: white.withOpacity(0.6),
                                fontSize: 12,
                                letterSpacing: 0.8,
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),

            // Quick jump
            if (_bookmarkedPage != null || _lastReadPage != null)
              Container(
                margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: navyLight.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: gold.withOpacity(0.3), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('QUICK JUMP',
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                          color: gold,
                        )),
                    const SizedBox(height: 8),
                    if (_lastReadPage != null)
                      _quickJumpTile(
                        icon: Icons.history_rounded,
                        label: 'Last Read',
                        subtitle: 'Page ${_lastReadPage! + 1}',
                        color: skyBlue,
                        onTap: () {
                          _goToPage(_lastReadPage! + 1);
                          Navigator.of(context).pop();
                        },
                      ),
                    if (_bookmarkedPage != null) ...[
                      const SizedBox(height: 6),
                      _quickJumpTile(
                        icon: Icons.bookmark_rounded,
                        label: 'Bookmark',
                        subtitle: 'Page ${_bookmarkedPage! + 1}',
                        color: gold,
                        onTap: () {
                          _goToPage(_bookmarkedPage! + 1);
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: 14),

            // Surah / Juz toggle
            Padding(
              padding: EdgeInsets.symmetric(horizontal: dw * 0.04),
              child: Container(
                decoration: BoxDecoration(
                  color: navyLight.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: gold.withOpacity(0.3), width: 1),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => surahJuzBool = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: surahJuzBool ? gold : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text('Surah',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: surahJuzBool ? navy : textMid,
                              )),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => surahJuzBool = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !surahJuzBool ? gold : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text('Juz / Parah',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: !surahJuzBool ? navy : textMid,
                              )),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // List
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: dw * 0.04),
                child: ListView.separated(
                  itemCount: surahJuzBool ? 114 : 30,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: white.withOpacity(0.06)),
                  itemBuilder: (context, index) {
                    final pageNumber =
                        surahJuzBool ? surahPages[index] : juzPages[index];
                    final bool isCurrent = surahJuzBool
                        ? (index < surahPages.length - 1
                            ? currentPage + 1 >= surahPages[index] &&
                                currentPage + 1 < surahPages[index + 1]
                            : currentPage + 1 >= surahPages[index])
                        : (index < juzPages.length - 1
                            ? currentPage + 1 >= juzPages[index] &&
                                currentPage + 1 < juzPages[index + 1]
                            : currentPage + 1 >= juzPages[index]);

                    return GestureDetector(
                      onTap: () {
                        _goToPage(pageNumber);
                        Navigator.of(context).pop();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? gold.withOpacity(0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? gold.withOpacity(0.2)
                                    : navyLight.withOpacity(0.4),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isCurrent
                                      ? gold.withOpacity(0.6)
                                      : white.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Text('${index + 1}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isCurrent ? gold : textMid,
                                    )),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        surahJuzBool
                                            ? surahNames[index]
                                            : 'Juz ${index + 1}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isCurrent
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: isCurrent ? gold : white,
                                        ),
                                      ),
                                      if (!surahJuzBool)
                                        Text(
                                          _juzArabicNames[index],
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: isCurrent
                                                ? gold
                                                : white.withOpacity(0.55),
                                          ),
                                          textDirection: TextDirection.rtl,
                                        ),
                                    ],
                                  ),
                                  Text('Page $pageNumber',
                                      style: TextStyle(
                                          fontSize: 11, color: textMid)),
                                ],
                              ),
                            ),
                            if (isCurrent)
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: gold,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  // ── Quick jump tile ───────────────────────────────────────────────
  Widget _quickJumpTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  Text(subtitle,
                      style: TextStyle(
                          color: white.withOpacity(0.6), fontSize: 11)),
                ],
              ),
              const Spacer(),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: color.withOpacity(0.6), size: 12),
            ],
          ),
        ),
      );

  // ══════════════════════════════════════════════════════════════════
  // STATIC DATA
  // ══════════════════════════════════════════════════════════════════
  static const List<String> surahNames = [
    'Al-Fatihah',
    'Al-Baqarah',
    'Ali \'Imran',
    'An-Nisa',
    'Al-Ma\'idah',
    'Al-An\'am',
    'Al-A\'raf',
    'Al-Anfal',
    'At-Tawbah',
    'Yunus',
    'Hud',
    'Yusuf',
    'Ar-Ra\'d',
    'Ibrahim',
    'Al-Hijr',
    'An-Nahl',
    'Al-Isra',
    'Al-Kahf',
    'Maryam',
    'Ta-Ha',
    'Al-Anbiya',
    'Al-Hajj',
    'Al-Mu\'minun',
    'An-Nur',
    'Al-Furqan',
    'Ash-Shu\'ara',
    'An-Naml',
    'Al-Qasas',
    'Al-\'Ankabut',
    'Ar-Rum',
    'Luqman',
    'As-Sajdah',
    'Al-Ahzab',
    'Saba',
    'Fatir',
    'Ya-Sin',
    'As-Saffat',
    'Sad',
    'Az-Zumar',
    'Ghafir',
    'Fussilat',
    'Ash-Shura',
    'Az-Zukhruf',
    'Ad-Dukhan',
    'Al-Jathiyah',
    'Al-Ahqaf',
    'Muhammad',
    'Al-Fath',
    'Al-Hujurat',
    'Qaf',
    'Adh-Dhariyat',
    'At-Tur',
    'An-Najm',
    'Al-Qamar',
    'Ar-Rahman',
    'Al-Waqi\'ah',
    'Al-Hadid',
    'Al-Mujadila',
    'Al-Hashr',
    'Al-Mumtahanah',
    'As-Saf',
    'Al-Jumu\'ah',
    'Al-Munafiqun',
    'At-Taghabun',
    'At-Talaq',
    'At-Tahrim',
    'Al-Mulk',
    'Al-Qalam',
    'Al-Haqqah',
    'Al-Ma\'arij',
    'Nuh',
    'Al-Jinn',
    'Al-Muzzammil',
    'Al-Muddaththir',
    'Al-Qiyamah',
    'Al-Insan',
    'Al-Mursalat',
    'An-Naba',
    'An-Nazi\'at',
    '\'Abasa',
    'At-Takwir',
    'Al-Infitar',
    'Al-Mutaffifin',
    'Al-Inshiqaq',
    'Al-Buruj',
    'At-Tariq',
    'Al-A\'la',
    'Al-Ghashiyah',
    'Al-Fajr',
    'Al-Balad',
    'Ash-Shams',
    'Al-Layl',
    'Ad-Duha',
    'Ash-Sharh',
    'At-Tin',
    'Al-\'Alaq',
    'Al-Qadr',
    'Al-Bayyinah',
    'Az-Zalzalah',
    'Al-\'Adiyat',
    'Al-Qari\'ah',
    'At-Takathur',
    'Al-\'Asr',
    'Al-Humazah',
    'Al-Fil',
    'Quraysh',
    'Al-Ma\'un',
    'Al-Kawthar',
    'Al-Kafirun',
    'An-Nasr',
    'Al-Masad',
    'Al-Ikhlas',
    'Al-Falaq',
    'An-Nas',
  ];

  final List<int> surahPages = [
    2,
    3,
    68,
    106,
    147,
    177,
    209,
    246,
    260,
    288,
    308,
    328,
    346,
    355,
    364,
    372,
    393,
    408,
    425,
    435,
    449,
    462,
    477,
    487,
    501,
    511,
    525,
    537,
    552,
    562,
    571,
    577,
    581,
    595,
    603,
    611,
    618,
    628,
    635,
    647,
    659,
    668,
    677,
    686,
    691,
    697,
    704,
    710,
    716,
    721,
    725,
    729,
    732,
    736,
    740,
    745,
    750,
    757,
    761,
    766,
    770,
    773,
    775,
    777,
    780,
    783,
    787,
    790,
    794,
    797,
    800,
    803,
    806,
    808,
    811,
    813,
    816,
    819,
    820,
    822,
    824,
    825,
    826,
    828,
    829,
    830,
    831,
    832,
    833,
    835,
    836,
    837,
    838,
    838,
    839,
    839,
    840,
    840,
    841,
    842,
    843,
    843,
    844,
    844,
    844,
    845,
    845,
    846,
    846,
    846,
    847,
    847,
    847,
    848,
  ];

  final List<int> juzPages = [
    2,
    29,
    57,
    85,
    113,
    141,
    169,
    197,
    225,
    253,
    281,
    309,
    337,
    365,
    393,
    421,
    449,
    477,
    505,
    533,
    559,
    587,
    613,
    641,
    667,
    697,
    727,
    757,
    787,
    819,
  ];

  static const List<String> _juzArabicNames = [
    'الم',
    'سَيَقُولُ',
    'تِلْكَ الرُّسُلُ',
    'لَنْ تَنَالُوا',
    'وَالْمُحْصَنَاتُ',
    'لَا يُحِبُّ اللَّهُ',
    'وَإِذَا سَمِعُوا',
    'وَلَوْ أَنَّنَا',
    'قَالَ الْمَلَأُ',
    'وَاعْلَمُوا',
    'يَعْتَذِرُونَ',
    'وَمَا مِنْ دَابَّةٍ',
    'وَمَا أُبَرِّئُ',
    'رُبَمَا',
    'سُبْحَانَ الَّذِي',
    'قَالَ أَلَمْ',
    'اقْتَرَبَ',
    'قَدْ أَفْلَحَ',
    'وَقَالَ الَّذِينَ',
    'أَمَّنْ خَلَقَ',
    'اتْلُ مَا أُوحِيَ',
    'وَمَنْ يَقْنُتْ',
    'وَمَا لِيَ',
    'فَمَنْ أَظْلَمُ',
    'إِلَيْهِ يُرَدُّ',
    'حم',
    'قَالَ فَمَا خَطْبُكُمْ',
    'قَدْ سَمِعَ اللَّهُ',
    'تَبَارَكَ الَّذِي',
    'عَمَّ',
  ];
}

// ══════════════════════════════════════════════════════════════════════════════
// AYAH BY AYAH VIEW
// Audio: everyayah.com/data/{ReciterFolder}/{surah3digit}{ayah3digit}.mp3
// No global ayah number needed — surah+ayah directly. No 403 issues.
// Reciters: Sudais, Alafasy, Husary
// Translations: EN (Sahih Intl), FR (Hamidullah), UR (Ahmed Ali)
// ══════════════════════════════════════════════════════════════════════════════

class _QuranAyahView extends StatefulWidget {
  const _QuranAyahView();
  @override
  State<_QuranAyahView> createState() => _QuranAyahViewState();
}

class _QuranAyahViewState extends State<_QuranAyahView> {
  // ── Palette ──────────────────────────────────────────────────────
  static const Color navy = Color.fromARGB(255, 10, 25, 60);
  static const Color navyMid = Color.fromARGB(255, 18, 42, 95);
  static const Color navyLight = Color.fromARGB(255, 28, 58, 120);
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

  // ── Reciters — everyayah.com folder names ────────────────────────
  static const List<Map<String, String>> _reciters = [
    {'folder': 'Abdurrahmaan_As-Sudais_192kbps', 'name': 'Sudais'},
    {
      'folder': 'warsh/warsh_yassin_al_jazaery_64kbps',
      'name': 'Warsh (Al-Jazaeri)'
    },
    {'folder': 'Saood_ash-Shuraym_128kbps', 'name': 'Shuraim'},
    {'folder': 'MaherAlMuaiqly128kbps', 'name': 'Maher Al-Muaqliy'},
    {'folder': 'Alafasy_128kbps', 'name': 'Alafasy'},
    {'folder': 'Husary_128kbps', 'name': 'Husary'},
    {'folder': 'Nasser_Alqatami_128kbps', 'name': 'Nasser Al-Qatami'},
    {'folder': 'Yasser_Ad-Dussary_128kbps', 'name': 'Yasser Al-Dawsari'},
    {'folder': 'Ghamadi_40kbps', 'name': 'Saad Al-Ghamdi'},
    {'folder': 'Salah_Al_Budair_128kbps', 'name': 'Salah Al-Budair'},
  ];

  // ── Translations ─────────────────────────────────────────────────
  static const List<Map<String, String>> _translations = [
    {'key': 'en', 'label': 'EN'},
    {'key': 'fr', 'label': 'FR'},
    {'key': 'ur', 'label': 'UR'},
  ];

  // ── Surah names ──────────────────────────────────────────────────
  static const List<String> _surahNames = [
    'Al-Fatihah',
    'Al-Baqarah',
    'Ali \'Imran',
    'An-Nisa',
    'Al-Ma\'idah',
    'Al-An\'am',
    'Al-A\'raf',
    'Al-Anfal',
    'At-Tawbah',
    'Yunus',
    'Hud',
    'Yusuf',
    'Ar-Ra\'d',
    'Ibrahim',
    'Al-Hijr',
    'An-Nahl',
    'Al-Isra',
    'Al-Kahf',
    'Maryam',
    'Ta-Ha',
    'Al-Anbiya',
    'Al-Hajj',
    'Al-Mu\'minun',
    'An-Nur',
    'Al-Furqan',
    'Ash-Shu\'ara',
    'An-Naml',
    'Al-Qasas',
    'Al-\'Ankabut',
    'Ar-Rum',
    'Luqman',
    'As-Sajdah',
    'Al-Ahzab',
    'Saba',
    'Fatir',
    'Ya-Sin',
    'As-Saffat',
    'Sad',
    'Az-Zumar',
    'Ghafir',
    'Fussilat',
    'Ash-Shura',
    'Az-Zukhruf',
    'Ad-Dukhan',
    'Al-Jathiyah',
    'Al-Ahqaf',
    'Muhammad',
    'Al-Fath',
    'Al-Hujurat',
    'Qaf',
    'Adh-Dhariyat',
    'At-Tur',
    'An-Najm',
    'Al-Qamar',
    'Ar-Rahman',
    'Al-Waqi\'ah',
    'Al-Hadid',
    'Al-Mujadila',
    'Al-Hashr',
    'Al-Mumtahanah',
    'As-Saf',
    'Al-Jumu\'ah',
    'Al-Munafiqun',
    'At-Taghabun',
    'At-Talaq',
    'At-Tahrim',
    'Al-Mulk',
    'Al-Qalam',
    'Al-Haqqah',
    'Al-Ma\'arij',
    'Nuh',
    'Al-Jinn',
    'Al-Muzzammil',
    'Al-Muddaththir',
    'Al-Qiyamah',
    'Al-Insan',
    'Al-Mursalat',
    'An-Naba',
    'An-Nazi\'at',
    '\'Abasa',
    'At-Takwir',
    'Al-Infitar',
    'Al-Mutaffifin',
    'Al-Inshiqaq',
    'Al-Buruj',
    'At-Tariq',
    'Al-A\'la',
    'Al-Ghashiyah',
    'Al-Fajr',
    'Al-Balad',
    'Ash-Shams',
    'Al-Layl',
    'Ad-Duha',
    'Ash-Sharh',
    'At-Tin',
    'Al-\'Alaq',
    'Al-Qadr',
    'Al-Bayyinah',
    'Az-Zalzalah',
    'Al-\'Adiyat',
    'Al-Qari\'ah',
    'At-Takathur',
    'Al-\'Asr',
    'Al-Humazah',
    'Al-Fil',
    'Quraysh',
    'Al-Ma\'un',
    'Al-Kawthar',
    'Al-Kafirun',
    'An-Nasr',
    'Al-Masad',
    'Al-Ikhlas',
    'Al-Falaq',
    'An-Nas',
  ];

  // ── State ────────────────────────────────────────────────────────
  bool _isFetchingData = false;
  String _fetchStatus = '';
  bool _dataReady = false;

  // quranData[i] = { 'name': String, 'arabic': [], 'en': [], 'fr': [], 'ur': [] }
  List<Map<String, dynamic>> _quranData = [];

  int _selectedSurah = 0;
  int _selectedReciter = 0;
  int _selectedTrans = 0;

  // Bookmarks & last read (ayah scope)
  int? _bookmarkedSurah;
  int? _bookmarkedAyah;
  int? _lastReadSurah;
  int? _lastReadAyah;

  // Focused ayah — updated whenever user taps a card or audio advances.
  // Used as the bookmark target when nothing is playing.
  int _focusedAyah = 0;

  // Audio
  final AudioPlayer _player = AudioPlayer();
  int _playingAyah = -1;
  bool _isPlaying = false;
  bool _isLoadingAudio = false;
  bool _isAdvancing = false; // guard against double-fire on completion

  // Scroll + ayah keys
  final ScrollController _scrollCtrl = ScrollController();
  final Map<int, GlobalKey> _ayahKeys = {};

  // ── Audio URL (everyayah.com) ────────────────────────────────────
  // Surah is 1-based, ayah is 1-based, both zero-padded to 3 digits.
  String _audioUrl(int surahOneBased, int ayahOneBased) {
    final folder = _reciters[_selectedReciter]['folder']!;
    final s = surahOneBased.toString().padLeft(3, '0');
    final a = ayahOneBased.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/$folder/$s$a.mp3';
  }

  // ── initState ────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initData();
    // Clear loading indicator the moment the player actually starts playing.
    // just_audio buffers before playing, so _isLoadingAudio must be cleared
    // on the playing state transition, not just after play() returns.
    _player.playingStream.listen((playing) {
      if (!mounted) return;
      if (playing && _isLoadingAudio) {
        setState(() {
          _isPlaying = true;
          _isLoadingAudio = false;
        });
      }
    });

    // Listen only to processingState changes, and only act on completed
    // when we were actually playing (guards against false completed fires
    // that just_audio emits during stop/setUrl transitions).
    _player.processingStateStream.listen((state) {
      if (!mounted) return;
      if (state == ProcessingState.completed && _isPlaying) {
        _onAyahCompleted();
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Data init — load from cache or fetch ─────────────────────────
  Future<void> _initData() async {
    final prefs = await SharedPreferences.getInstance();
    // Load bookmarks / last read
    _bookmarkedSurah = prefs.getInt('ayah_bookmark_surah');
    _bookmarkedAyah = prefs.getInt('ayah_bookmark_ayah');
    _lastReadSurah = prefs.getInt('ayah_last_surah');
    _lastReadAyah = prefs.getInt('ayah_last_ayah');
    // Restore last read position
    if (_lastReadSurah != null) {
      _selectedSurah = _lastReadSurah!;
    }

    final cached = prefs.getString('quran_ayah_data_v1');
    if (cached != null) {
      try {
        final List<dynamic> raw = jsonDecode(cached);
        if (mounted)
          setState(() {
            _quranData = raw.cast<Map<String, dynamic>>();
            _dataReady = true;
          });
        return;
      } catch (_) {
        await prefs.remove('quran_ayah_data_v1');
      }
    }
    await _fetchAllSurahs(prefs);
  }

  Future<void> _fetchAllSurahs(SharedPreferences prefs) async {
    if (!mounted) return;
    setState(() {
      _isFetchingData = true;
      _fetchStatus = 'Starting download…';
    });

    const editions = 'quran-uthmani,en.sahih,fr.hamidullah,ur.ahmedali';
    final List<Map<String, dynamic>> allData = [];

    for (int s = 1; s <= 114; s++) {
      if (!mounted) return;
      setState(() => _fetchStatus = 'Downloading surah $s / 114…');
      try {
        final url = 'https://api.alquran.cloud/v1/surah/$s/editions/$editions';
        final resp = await http.get(Uri.parse(url));
        if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
        final body = jsonDecode(resp.body);
        final List ed = body['data'] as List;

        List<String> texts(dynamic e) => (e['ayahs'] as List)
            .map<String>((a) => (a['text'] as String).trim())
            .toList();

        allData.add({
          'name': _surahNames[s - 1],
          'arabic': texts(ed[0]),
          'en': texts(ed[1]),
          'fr': texts(ed[2]),
          'ur': texts(ed[3]),
        });
      } catch (e) {
        debugPrint('Surah $s error: $e');
        allData.add({
          'name': _surahNames[s - 1],
          'arabic': [],
          'en': [],
          'fr': [],
          'ur': []
        });
      }
      await Future.delayed(const Duration(milliseconds: 120));
    }

    await prefs.setString('quran_ayah_data_v1', jsonEncode(allData));
    if (!mounted) return;
    setState(() {
      _quranData = allData;
      _isFetchingData = false;
      _dataReady = true;
    });
  }

  // ── Prefs helpers ────────────────────────────────────────────────
  Future<void> _saveBookmark(int surahIdx, int ayahIdx) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('ayah_bookmark_surah', surahIdx);
    await prefs.setInt('ayah_bookmark_ayah', ayahIdx);
    if (!mounted) return;
    setState(() {
      _bookmarkedSurah = surahIdx;
      _bookmarkedAyah = ayahIdx;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.bookmark, color: gold, size: 18),
        const SizedBox(width: 8),
        Text('Bookmarked ${_surahNames[surahIdx]} — Ayah ${ayahIdx + 1}',
            style: const TextStyle(color: white)),
      ]),
      backgroundColor: navyMid,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _saveLastRead(int surahIdx, int ayahIdx) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('ayah_last_surah', surahIdx);
    await prefs.setInt('ayah_last_ayah', ayahIdx);
    _lastReadSurah = surahIdx;
    _lastReadAyah = ayahIdx;
  }

  // ── Audio ────────────────────────────────────────────────────────
  Future<void> _playAyah(int ayahIdx) async {
    if (!mounted) return;
    _isAdvancing = false; // reset on any manual play call
    _focusedAyah = ayahIdx;
    setState(() {
      _isLoadingAudio = true;
      _playingAyah = ayahIdx;
      _isPlaying = false;
    });
    try {
      await _player.stop();
      // everyayah.com uses 1-based surah + ayah
      await _player.setUrl(_audioUrl(_selectedSurah + 1, ayahIdx + 1));
      await _player.play();
      if (mounted)
        setState(() {
          _isPlaying = true;
          _isLoadingAudio = false;
        });
      await _saveLastRead(_selectedSurah, ayahIdx);
    } catch (e) {
      debugPrint('Audio error: $e');
      if (mounted)
        setState(() {
          _isPlaying = false;
          _isLoadingAudio = false;
        });
    }
  }

  void _onAyahCompleted() {
    if (_isAdvancing) return; // guard: just_audio can fire completed twice
    _isAdvancing = true;
    final total = (_quranData[_selectedSurah]['arabic'] as List).length;
    if (_playingAyah < total - 1) {
      final next = _playingAyah + 1;
      _playAyah(next).then((_) => _isAdvancing = false);
      _scrollToAyah(next);
    } else {
      _isAdvancing = false;
      if (mounted)
        setState(() {
          _isPlaying = false;
          _playingAyah = -1;
        });
    }
  }

  Future<void> _togglePlayPause() async {
    if (_playingAyah == -1) {
      await _playAyah(0);
      _scrollToAyah(0);
      return;
    }
    if (_isPlaying) {
      await _player.pause();
      if (mounted) setState(() => _isPlaying = false);
    } else {
      await _player.play();
      if (mounted) setState(() => _isPlaying = true);
    }
  }

  Future<void> _playPrev() async {
    if (_playingAyah > 0) {
      await _playAyah(_playingAyah - 1);
      _scrollToAyah(_playingAyah);
    }
  }

  Future<void> _playNext() async {
    final total = (_quranData[_selectedSurah]['arabic'] as List).length;
    if (_playingAyah < total - 1) {
      await _playAyah(_playingAyah + 1);
      _scrollToAyah(_playingAyah);
    }
  }

  void _scrollToAyah(int idx) {
    if (!_scrollCtrl.hasClients) return;
    // Use ensureVisible if key context is available (best accuracy),
    // otherwise fall back to proportional scroll.
    final key = _ayahKeys[idx];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
      return;
    }
    // Fallback: proportional position for items not yet built
    final total = _quranData.isNotEmpty
        ? (_quranData[_selectedSurah]['arabic'] as List).length
        : 1;
    final double max = _scrollCtrl.position.maxScrollExtent;
    final double target = total > 1 ? (idx / (total - 1)) * max : 0.0;
    _scrollCtrl.animateTo(
      target.clamp(0.0, max),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _stopAudio() {
    _player.stop();
    if (mounted)
      setState(() {
        _isPlaying = false;
        _playingAyah = -1;
      });
  }

  // ── Go to ayah dialog (ayah finder) ─────────────────────────────
  Future<void> _showGoToAyahDialog() async {
    if (!_dataReady) return;
    final total = (_quranData[_selectedSurah]['arabic'] as List).length;
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: navyMid,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: gold.withOpacity(0.4), width: 1.5)),
        title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Go to Ayah',
                  style: TextStyle(
                      color: gold, fontWeight: FontWeight.bold, fontSize: 16)),
              Text('${_surahNames[_selectedSurah]}  ·  $total ayahs',
                  style:
                      TextStyle(color: white.withOpacity(0.5), fontSize: 11)),
            ]),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: white),
          decoration: InputDecoration(
            hintText: 'Enter ayah number (1–$total)',
            hintStyle: TextStyle(color: white.withOpacity(0.4)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: gold.withOpacity(0.35))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: gold, width: 1.5)),
            filled: true,
            fillColor: navyLight.withOpacity(0.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child:
                Text('Cancel', style: TextStyle(color: white.withOpacity(0.6))),
          ),
          TextButton(
            onPressed: () {
              final n = int.tryParse(ctrl.text);
              if (n != null && n >= 1 && n <= total) {
                Navigator.of(context).pop();
                final idx = n - 1;
                // Use a two-step approach: first jump the ScrollController to
                // an estimated offset so the item builds, then ensureVisible.
                Future.delayed(const Duration(milliseconds: 150), () {
                  if (!mounted) return;
                  // Estimated card height ~190px — close enough to get the
                  // item into the build range, then ensureVisible fine-tunes.
                  // Two-pass scroll: jump to end to force ListView to build
                  // all items (resolving true maxScrollExtent), then jump to
                  // the proportional target position.
                  _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    final double max = _scrollCtrl.position.maxScrollExtent;
                    final double target =
                        total > 1 ? (idx / (total - 1)) * max : 0.0;
                    _scrollCtrl.jumpTo(target.clamp(0.0, max));
                  });
                });
              }
            },
            child: const Text('Go',
                style: TextStyle(color: gold, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Drawer (mirrors PDF drawer style) ───────────────────────────
  Widget _buildAyahDrawer() {
    return Drawer(
      backgroundColor: navy,
      child: Builder(builder: (ctx) {
        final double dw = MediaQuery.of(ctx).size.width;
        final double dh = MediaQuery.of(ctx).size.height;
        return Column(children: [
          // ── Header ─────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
                dw * 0.04, dh * 0.055, dw * 0.04, dh * 0.025),
            decoration: BoxDecoration(
              color: navyMid,
              border: Border(
                  bottom: BorderSide(color: gold.withOpacity(0.4), width: 1.5)),
            ),
            child: SafeArea(
              bottom: false,
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded,
                      color: white, size: 18),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                Expanded(
                    child: Column(children: [
                  const Text('القرآن الكريم',
                      style: TextStyle(
                          color: gold,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text('Ayah by Ayah',
                      style: TextStyle(
                          color: white.withOpacity(0.6),
                          fontSize: 12,
                          letterSpacing: 0.8)),
                ])),
                const SizedBox(width: 48),
              ]),
            ),
          ),

          // ── Quick jump (bookmark + last read) ──────────────────
          if (_bookmarkedSurah != null || _lastReadSurah != null)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: navyLight.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: gold.withOpacity(0.3), width: 1),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('QUICK JUMP',
                        style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w700,
                            color: gold)),
                    const SizedBox(height: 8),
                    if (_lastReadSurah != null)
                      _drawerQuickTile(
                        icon: Icons.history_rounded,
                        label: 'Last Read',
                        subtitle:
                            '${_surahNames[_lastReadSurah!]} — Ayah ${(_lastReadAyah ?? 0) + 1}',
                        color: skyBlue,
                        onTap: () {
                          setState(() {
                            _selectedSurah = _lastReadSurah!;
                            _ayahKeys.clear();
                          });
                          Navigator.of(ctx).pop();
                          Future.delayed(const Duration(milliseconds: 200), () {
                            _scrollToAyah(_lastReadAyah ?? 0);
                          });
                        },
                      ),
                    if (_bookmarkedSurah != null) ...[
                      const SizedBox(height: 6),
                      _drawerQuickTile(
                        icon: Icons.bookmark_rounded,
                        label: 'Bookmark',
                        subtitle:
                            '${_surahNames[_bookmarkedSurah!]} — Ayah ${(_bookmarkedAyah ?? 0) + 1}',
                        color: gold,
                        onTap: () {
                          setState(() {
                            _selectedSurah = _bookmarkedSurah!;
                            _ayahKeys.clear();
                          });
                          Navigator.of(ctx).pop();
                          Future.delayed(const Duration(milliseconds: 200), () {
                            _scrollToAyah(_bookmarkedAyah ?? 0);
                          });
                        },
                      ),
                    ],
                  ]),
            ),

          const SizedBox(height: 14),

          // ── Surah list label ────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(horizontal: dw * 0.04),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: navyLight.withOpacity(0.4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: gold.withOpacity(0.25), width: 1),
              ),
              child: Row(children: [
                const Icon(Icons.list_rounded, color: gold, size: 14),
                const SizedBox(width: 8),
                const Text('SURAH',
                    style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w700,
                        color: gold)),
              ]),
            ),
          ),

          const SizedBox(height: 8),

          // ── Surah list ──────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: dw * 0.04),
              child: ListView.separated(
                itemCount: 114,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: white.withOpacity(0.06)),
                itemBuilder: (ctx2, i) {
                  final bool isCurrent = i == _selectedSurah;
                  return GestureDetector(
                    onTap: () {
                      _stopAudio();
                      setState(() {
                        _selectedSurah = i;
                        _ayahKeys.clear();
                      });
                      Navigator.of(ctx).pop();
                      _scrollCtrl.animateTo(0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? gold.withOpacity(0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? gold.withOpacity(0.2)
                                : navyLight.withOpacity(0.4),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: isCurrent
                                    ? gold.withOpacity(0.6)
                                    : white.withOpacity(0.1)),
                          ),
                          child: Center(
                              child: Text('${i + 1}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isCurrent ? gold : textMid))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text(_surahNames[i],
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isCurrent
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isCurrent ? gold : white))),
                        if (isCurrent)
                          Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                  color: gold, shape: BoxShape.circle)),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ),
        ]);
      }),
    );
  }

  Widget _drawerQuickTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(label,
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  Text(subtitle,
                      style: TextStyle(
                          color: white.withOpacity(0.6), fontSize: 11),
                      overflow: TextOverflow.ellipsis),
                ])),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded,
                color: color.withOpacity(0.6), size: 12),
          ]),
        ),
      );

  // ── Reciter picker sheet ─────────────────────────────────────────
  void _showReciterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: offWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                margin: const EdgeInsets.only(top: 10, bottom: 16),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: textMid.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(2))),
            const Text('Select Reciter',
                style: TextStyle(
                    color: textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            ..._reciters.asMap().entries.map((e) {
              final bool sel = e.key == _selectedReciter;
              return GestureDetector(
                onTap: () {
                  _stopAudio();
                  setState(() => _selectedReciter = e.key);
                  Navigator.pop(context);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: sel ? goldLight : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: sel ? gold.withOpacity(0.6) : border,
                        width: sel ? 1.5 : 1),
                  ),
                  child: Row(children: [
                    Icon(Icons.mic_rounded,
                        color: sel
                            ? const Color.fromARGB(255, 140, 105, 30)
                            : textMid,
                        size: 18),
                    const SizedBox(width: 12),
                    Text(e.value['name']!,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: sel
                                ? const Color.fromARGB(255, 120, 85, 20)
                                : textDark)),
                    const Spacer(),
                    if (sel)
                      const Icon(Icons.check_circle_rounded,
                          color: gold, size: 18),
                  ]),
                ),
              );
            }),
          ]),
        ),
      ),
    );
  }

  // ── BUILD ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Downloading screen
    if (_isFetchingData) {
      return Container(
        color: navy,
        child: Center(
            child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: navyMid,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: gold.withOpacity(0.35), width: 1.5)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(color: gold, strokeWidth: 2.5),
              const SizedBox(height: 20),
              const Text('Downloading Quran Data',
                  style: TextStyle(
                      color: gold, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(_fetchStatus,
                  style: TextStyle(color: white.withOpacity(0.6), fontSize: 12),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(
                  'This happens only once.\nAll data is cached on device.\nPlease do not leave screen.',
                  style: TextStyle(
                      color: gold.withOpacity(0.55), fontSize: 11, height: 1.5),
                  textAlign: TextAlign.center),
            ]),
          ),
        )),
      );
    }

    if (!_dataReady) {
      return const Center(child: CircularProgressIndicator(color: gold));
    }

    final surah = _quranData[_selectedSurah];
    final arabic = surah['arabic'] as List<dynamic>;
    final transKey = _translations[_selectedTrans]['key']!;
    final trans = surah[transKey] as List<dynamic>;
    final total = arabic.length;

    final bool isBookmarked = _bookmarkedSurah == _selectedSurah;

    return Scaffold(
      backgroundColor: offWhite,
      drawer: _buildAyahDrawer(),
      body: Column(children: [
        // ── Header bar ─────────────────────────────────────────────
        Container(
          color: navyMid,
          padding: const EdgeInsets.fromLTRB(4, 6, 8, 0),
          child: Column(children: [
            Row(children: [
              // Drawer burger
              Builder(
                  builder: (ctx) => IconButton(
                        onPressed: () => Scaffold.of(ctx).openDrawer(),
                        icon: const Icon(Icons.menu_book_rounded,
                            color: gold, size: 22),
                      )),
              // Surah name (centred, tappable → surah picker in drawer)
              Expanded(
                  child: Builder(
                      builder: (ctx) => GestureDetector(
                            onTap: () => Scaffold.of(ctx).openDrawer(),
                            child: Column(children: [
                              Text(_surahNames[_selectedSurah],
                                  style: const TextStyle(
                                      color: gold,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis),
                              Text('${_selectedSurah + 1}  ·  $total ayahs',
                                  style: TextStyle(
                                      color: white.withOpacity(0.55),
                                      fontSize: 11),
                                  textAlign: TextAlign.center),
                            ]),
                          ))),
              // Bookmark
              IconButton(
                onPressed: () => _saveBookmark(_selectedSurah, _focusedAyah),
                icon: Icon(
                  isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_outline_rounded,
                  color: isBookmarked ? gold : white.withOpacity(0.7),
                  size: 22,
                ),
              ),
              // Go to ayah
              IconButton(
                onPressed: _showGoToAyahDialog,
                icon: Icon(Icons.search_rounded,
                    color: white.withOpacity(0.8), size: 22),
              ),
            ]),
            // ── Controls row: translation + reciter ───────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
              child: Row(children: [
                // Translation cycle
                GestureDetector(
                  onTap: () => setState(() => _selectedTrans =
                      (_selectedTrans + 1) % _translations.length),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: skyLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: skyBlue.withOpacity(0.5)),
                    ),
                    child: Text(_translations[_selectedTrans]['label']!,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color.fromARGB(255, 30, 90, 160))),
                  ),
                ),
                const SizedBox(width: 6),
                // Reciter picker
                GestureDetector(
                  onTap: _showReciterSheet,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: goldLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: gold.withOpacity(0.45)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.mic_rounded,
                          size: 12, color: Color.fromARGB(255, 140, 105, 30)),
                      const SizedBox(width: 5),
                      Text(_reciters[_selectedReciter]['name']!,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color.fromARGB(255, 140, 105, 30))),
                    ]),
                  ),
                ),
                const Spacer(),
              ]),
            ),
          ]),
        ),

        // ── Ayah list ──────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 100),
            itemCount: total,
            itemBuilder: (_, i) {
              _ayahKeys[i] ??= GlobalKey();
              final bool isActive = _playingAyah == i;
              return KeyedSubtree(
                key: _ayahKeys[i],
                child: _AyahCard(
                  ayahNumber: i + 1,
                  arabic: arabic[i] as String,
                  translation: i < trans.length ? trans[i] as String : '',
                  isActive: isActive,
                  isPlaying: isActive && _isPlaying,
                  isLoading: isActive && _isLoadingAudio,
                  isBookmarked: _bookmarkedSurah == _selectedSurah &&
                      _bookmarkedAyah == i,
                  onTap: () async {
                    _focusedAyah = i;
                    if (isActive) {
                      await _togglePlayPause();
                    } else {
                      await _playAyah(i);
                    }
                  },
                  onLongPress: () {
                    _focusedAyah = i;
                    _saveBookmark(_selectedSurah, i);
                  },
                ),
              );
            },
          ),
        ),

        // ── Audio bar ──────────────────────────────────────────────
        if (_playingAyah >= 0)
          _AudioBar(
            surahName: _surahNames[_selectedSurah],
            ayahNumber: _playingAyah + 1,
            totalAyahs: total,
            isPlaying: _isPlaying,
            isLoading: _isLoadingAudio,
            reciterName: _reciters[_selectedReciter]['name']!,
            onPrev: _playingAyah > 0 ? _playPrev : null,
            onPlayPause: _togglePlayPause,
            onNext: _playingAyah < total - 1 ? _playNext : null,
            onClose: _stopAudio,
          ),
      ]),
    );
  }
}

// ── Ayah card ────────────────────────────────────────────────────────────────
class _AyahCard extends StatelessWidget {
  final int ayahNumber;
  final String arabic, translation;
  final bool isActive, isPlaying, isLoading, isBookmarked;
  final VoidCallback onTap, onLongPress;

  const _AyahCard({
    required this.ayahNumber,
    required this.arabic,
    required this.translation,
    required this.isActive,
    required this.isPlaying,
    required this.isLoading,
    required this.isBookmarked,
    required this.onTap,
    required this.onLongPress,
  });

  static const Color navy = Color.fromARGB(255, 10, 25, 60);
  static const Color navyMid = Color.fromARGB(255, 18, 42, 95);
  static const Color gold = Color.fromARGB(255, 212, 175, 95);
  static const Color goldLight = Color.fromARGB(255, 252, 243, 210);
  static const Color white = Color.fromARGB(255, 255, 255, 255);
  static const Color textDark = Color.fromARGB(255, 15, 30, 65);
  static const Color textMid = Color.fromARGB(255, 90, 115, 160);
  static const Color border = Color.fromARGB(255, 210, 220, 240);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color.fromARGB(255, 255, 248, 225) : white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? gold.withOpacity(0.7) : border,
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
                color: navy.withOpacity(0.07),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ── Number row ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isActive
                  ? gold.withOpacity(0.12)
                  : const Color.fromARGB(255, 247, 249, 255),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(13)),
              border: Border(
                  bottom: BorderSide(
                      color: isActive ? gold.withOpacity(0.3) : border,
                      width: 0.8)),
            ),
            child: Row(children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isActive ? gold : navyMid,
                  shape: BoxShape.circle,
                ),
                child: Center(
                    child: Text('$ayahNumber',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isActive ? navy : gold))),
              ),
              const SizedBox(width: 10),
              Text('Ayah $ayahNumber',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? const Color.fromARGB(255, 120, 85, 20)
                          : textMid)),
              if (isBookmarked) ...[
                const SizedBox(width: 6),
                const Icon(Icons.bookmark_rounded, color: gold, size: 14),
              ],
              const Spacer(),
              if (isLoading)
                const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                        CircularProgressIndicator(strokeWidth: 2, color: gold))
              else
                Icon(
                  isActive && isPlaying
                      ? Icons.pause_circle_rounded
                      : Icons.play_circle_rounded,
                  color: isActive ? gold : textMid.withOpacity(0.45),
                  size: 22,
                ),
            ]),
          ),
          // ── Arabic ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Text(arabic,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                    fontSize: 22, height: 1.85, color: textDark)),
          ),
          // ── Translation ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Text(translation,
                style:
                    const TextStyle(fontSize: 13, height: 1.5, color: textMid)),
          ),
        ]),
      ),
    );
  }
}

// ── Audio bar ─────────────────────────────────────────────────────────────────
class _AudioBar extends StatelessWidget {
  final String surahName, reciterName;
  final int ayahNumber, totalAyahs;
  final bool isPlaying, isLoading;
  final VoidCallback? onPrev, onNext;
  final VoidCallback onPlayPause, onClose;

  const _AudioBar({
    required this.surahName,
    required this.reciterName,
    required this.ayahNumber,
    required this.totalAyahs,
    required this.isPlaying,
    required this.isLoading,
    required this.onPlayPause,
    required this.onClose,
    this.onPrev,
    this.onNext,
  });

  static const Color navy = Color.fromARGB(255, 10, 25, 60);
  static const Color navyMid = Color.fromARGB(255, 18, 42, 95);
  static const Color gold = Color.fromARGB(255, 212, 175, 95);
  static const Color white = Color.fromARGB(255, 255, 255, 255);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: navy,
        border:
            Border(top: BorderSide(color: gold.withOpacity(0.35), width: 1.5)),
        boxShadow: [
          BoxShadow(
              color: navy.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, -3))
        ],
      ),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(surahName,
              style: const TextStyle(
                  color: gold, fontSize: 12, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis),
          Text('Ayah $ayahNumber  ·  $reciterName',
              style: TextStyle(color: white.withOpacity(0.55), fontSize: 11)),
        ])),
        _BarBtn(
            icon: Icons.skip_previous_rounded,
            color: onPrev != null ? gold : gold.withOpacity(0.25),
            onTap: onPrev),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onPlayPause,
          child: Container(
            width: 44,
            height: 44,
            decoration:
                BoxDecoration(color: gold, shape: BoxShape.circle, boxShadow: [
              BoxShadow(
                  color: gold.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ]),
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child:
                        CircularProgressIndicator(strokeWidth: 2, color: navy))
                : Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: navy,
                    size: 26),
          ),
        ),
        const SizedBox(width: 4),
        _BarBtn(
            icon: Icons.skip_next_rounded,
            color: onNext != null ? gold : gold.withOpacity(0.25),
            onTap: onNext),
        const SizedBox(width: 4),
        _BarBtn(
            icon: Icons.close_rounded,
            color: white.withOpacity(0.45),
            onTap: onClose),
      ]),
    );
  }
}

class _BarBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _BarBtn({required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: color, size: 24)),
      );
}
