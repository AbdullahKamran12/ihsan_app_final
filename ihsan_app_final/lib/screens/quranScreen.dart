import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

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

class _QuranScreenState extends State<QuranScreen> {
  int _selectedIndex = 0;
  int currentPage = 0;
  int totalPages = 0;
  PDFViewController? pdfViewController;
  late String pdfPath;
  bool isPdfLoaded = false;
  bool surahJuzBool = true;
  bool _isUiVisible = true;

  @override
  void initState() {
    super.initState();
    loadPdfFromAssets();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PrayerTimesScreen()),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const QiblaScreen()),
        );
        break;
      case 3:
        break;
      case 4:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MoreOptionsScreen()),
        );
        break;
    }
  }

  Future<void> loadPdfFromAssets() async {
    try {
      final pdfData = await rootBundle
          .load('assets/Quran Majeed (Arabic only - 13 Line).pdf');
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/Quran.pdf';

      // Save the PDF to the temporary directory
      final file = File(tempPath);
      await file.writeAsBytes(pdfData.buffer.asUint8List());

      setState(() {
        pdfPath = tempPath;
        isPdfLoaded = true; // Mark PDF as loaded
      });
    } catch (e) {
      print('Error loading PDF asset: $e');
    }
  }

  void _goToPage(int pageNumber) {
    if (pageNumber > 0 && pageNumber <= totalPages) {
      pdfViewController?.setPage(pageNumber - 1);
    } else {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Invalid Page Number'),
            content:
                Text('Please enter a page number between 1 and $totalPages.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

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
  void _toggleUiVisibility() {
    setState(() {
      _isUiVisible = !_isUiVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 105, 170, 190),
      appBar: _isUiVisible
          ? buildAppBar(context, 'Quran', const HomeScreen(), null)
          : null,
      body: Stack(
        children: [
          Column(
            children: [
              if (_isUiVisible)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Builder(
                        builder: (BuildContext innerContext) {
                          return IconButton(
                            onPressed: () {
                              Scaffold.of(innerContext).openDrawer();
                            },
                            icon: Icon(Icons.menu),
                          );
                        },
                      ),
                      Text(
                        'Page: ${currentPage + 1} / $totalPages',
                        style: TextStyle(fontSize: 18, color: Colors.black),
                      ),
                      IconButton(
                        icon: Icon(Icons.search),
                        onPressed: () async {
                          final pageController = TextEditingController();
                          await showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: Text('Go to Page'),
                                content: TextField(
                                  controller: pageController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                      hintText: 'Enter page number'),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      final pageNumber =
                                          int.tryParse(pageController.text);
                                      if (pageNumber != null) {
                                        _goToPage(pageNumber);
                                      }
                                      Navigator.of(context).pop();
                                    },
                                    child: Text('Go'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: isPdfLoaded
                    ? PDFView(
                        filePath: pdfPath,
                        pageFling: false,
                        autoSpacing: false,
                        swipeHorizontal:
                            false, // Make PDF scroll vertically as a single strip
                        pageSnap:
                            false, // Disable page snapping for continuous scrolling
                        onPageChanged: (page, total) {
                          setState(() {
                            currentPage = page ?? 0;
                            totalPages = total ?? 0;
                          });
                        },
                        onViewCreated: (PDFViewController controller) {
                          pdfViewController = controller;
                        },
                        onError: (error) {
                          print('Error loading PDF: $error');
                        },
                        onPageError: (page, error) {
                          print('Error on page $page: $error');
                        },
                      )
                    : Center(child: CircularProgressIndicator()),
              ),
            ],
          ),

          // Floating button to toggle UI visibility
          Positioned(
            bottom: 80, // Position above the bottom navigation bar
            right: 16,
            child: FloatingActionButton(
              backgroundColor: Colors.white.withOpacity(0.8),
              elevation: 2,
              mini: true,
              onPressed: _toggleUiVisibility,
              child: Icon(
                _isUiVisible ? Icons.fullscreen : Icons.fullscreen_exit,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _isUiVisible
          ? buildBottomNavigationBar(context, 3, _onItemTapped)
          : null,
      drawer: Drawer(
        backgroundColor: const Color.fromARGB(255, 105, 170, 190),
        child: Builder(
          builder: (context) {
            double drawerWidth = MediaQuery.of(context).size.width;
            double drawerHeight = MediaQuery.of(context).size.height;

            double horizontalPadding = drawerWidth * 0.02;
            double verticalPadding = drawerHeight * 0.04;

            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: verticalPadding,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      Expanded(
                        child: Text(
                          'Select Option',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero),
                            padding: EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () {
                            setState(() {
                              surahJuzBool = true;
                            });
                          },
                          child: Text(
                            "Surah",
                            style: TextStyle(fontSize: 25, color: Colors.black),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero),
                            padding: EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () {
                            setState(() {
                              surahJuzBool = false;
                            });
                          },
                          child: Text(
                            "Juz/Parah",
                            style: TextStyle(fontSize: 25, color: Colors.black),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: ListView.builder(
                      itemCount: surahJuzBool ? 114 : 30,
                      itemBuilder: (context, index) {
                        final pageNumber =
                            surahJuzBool ? surahPages[index] : juzPages[index];
                        final label = surahJuzBool
                            ? "Surah ${index + 1} - Page $pageNumber"
                            : "Juz ${index + 1} - Page $pageNumber";

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5.0),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero),
                              padding: EdgeInsets.symmetric(vertical: 15.0),
                            ),
                            onPressed: () {
                              _goToPage(pageNumber);
                              Navigator.of(context).pop();
                            },
                            child: Text(
                              label,
                              style:
                                  TextStyle(fontSize: 20, color: Colors.black),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
