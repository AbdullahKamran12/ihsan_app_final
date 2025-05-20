import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ihsan_app_final/sharedWidgets.dart';
import 'package:ihsan_app_final/screens/moreOptionsScreen.dart';

class InfoScreen extends StatefulWidget {
  const InfoScreen({Key? key}) : super(key: key);

  @override
  _InfoScreenState createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  late String pdfPath;
  bool isPdfLoaded = false;
  int currentPage = 0;
  int totalPages = 0;
  PDFViewController? pdfController;

  // Page numbers for various sections
  final int duaasPage = 12;
  final int salahPage = 31;
  final int wuduPage = 27;
  final int adhaanPage = 45;
  final int eidPage = 54;
  final int janazahPage = 59;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    loadPdfFromAssets();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scaffoldKey.currentState?.openDrawer();
    });
  }

  Future<void> loadPdfFromAssets() async {
    try {
      final pdfData =
          await rootBundle.load('assets/ONLINE-PDF-A-Childs-Gift.pdf');
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/ChildsGift.pdf';
      final file = File(tempPath);
      await file.writeAsBytes(pdfData.buffer.asUint8List());
      setState(() {
        pdfPath = tempPath;
        isPdfLoaded = true;
      });
    } catch (e) {
      print('Error loading PDF asset: $e');
    }
  }

  void _goToPage(int pageNumber) {
    if (pageNumber > 0 && pageNumber <= totalPages) {
      pdfController?.setPage(pageNumber - 1);
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invalid Page Number'),
          content:
              Text('Please enter a page number between 1 and $totalPages.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            )
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 105, 170, 190),
      appBar: buildAppBar(context, "Information and Basics of Islam",
          const MoreOptionsScreen(), null),
      body: isPdfLoaded
          ? Column(
              children: [
                // Top bar with menu button and current page info (without search)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Builder(
                        builder: (BuildContext innerContext) {
                          return IconButton(
                            icon: const Icon(Icons.menu),
                            onPressed: () {
                              Scaffold.of(innerContext).openDrawer();
                            },
                          );
                        },
                      ),
                      Text(
                        'Page: ${currentPage + 1} / $totalPages',
                        style:
                            const TextStyle(fontSize: 18, color: Colors.black),
                      ),
                      const SizedBox(width: 48), // placeholder for symmetry
                    ],
                  ),
                ),
                Expanded(
                  child: PDFView(
                    filePath: pdfPath,
                    enableSwipe: true,
                    swipeHorizontal: true,
                    autoSpacing: false,
                    pageFling: true,
                    onViewCreated: (PDFViewController controller) {
                      pdfController = controller;
                    },
                    onPageChanged: (page, total) {
                      setState(() {
                        currentPage = page ?? 0;
                        totalPages = total ?? 0;
                      });
                    },
                    onError: (error) {
                      print('Error loading PDF: $error');
                    },
                    onPageError: (page, error) {
                      print('Error on page $page: $error');
                    },
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
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
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      const Expanded(
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
                // List of options for navigation
                Expanded(
                  child: ListView(
                    padding:
                        EdgeInsets.symmetric(horizontal: horizontalPadding),
                    children: [
                      _buildDrawerButton('Duaas', duaasPage),
                      _buildDrawerButton('How to Perform Salah', salahPage),
                      _buildDrawerButton('How to Do Wudu', wuduPage),
                      _buildDrawerButton('How to do Adhaan', adhaanPage),
                      _buildDrawerButton('How to pray Eid Salah', eidPage),
                      _buildDrawerButton(
                          'How to Do pray Janazah Salah', janazahPage),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDrawerButton(String label, int pageNumber) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          padding: const EdgeInsets.symmetric(vertical: 15.0),
        ),
        onPressed: () {
          _goToPage(pageNumber);
          Navigator.of(context).pop();
        },
        child: Text(
          label,
          style: const TextStyle(fontSize: 20, color: Colors.black),
        ),
      ),
    );
  }
}
