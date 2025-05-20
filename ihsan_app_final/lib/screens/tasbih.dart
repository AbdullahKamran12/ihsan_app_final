import 'package:flutter/material.dart';
import 'package:ihsan_app_final/screens/moreoptionsScreen.dart';
import 'package:ihsan_app_final/sharedWidgets.dart';

class TasbeehItem {
  final String phrase;
  final int count;
  TasbeehItem({required this.phrase, required this.count});
}

class TasbeehCollection {
  final String name;
  final List<TasbeehItem> items;
  TasbeehCollection({required this.name, required this.items});
}

final List<TasbeehCollection> tasbeehCollections = [
  TasbeehCollection(
    name: "Tasbeeh Fatima",
    items: [
      TasbeehItem(phrase: "SubhanAllah", count: 33),
      TasbeehItem(phrase: "Alhamdulillah", count: 33),
      TasbeehItem(phrase: "Allahu Akbar", count: 34),
    ],
  ),
  TasbeehCollection(
    name: "Kalimatan",
    items: [
      TasbeehItem(phrase: "SubhanAllahi wa bihamdihi", count: 100),
    ],
  ),
  TasbeehCollection(
    name: "Tasbeeh o Tamheed (3rd Kalimah)",
    items: [
      TasbeehItem(
          phrase: "SubhanAllahi wal Hamdulillahi\n"
              "wa la ilaha ilAllahu wAllahu Akbar\n"
              "Wa la hawla wa la quwwata illa billahil 'Aliyyil 'Adheem",
          count: 100),
    ],
  ),
  TasbeehCollection(
    name: "Durood",
    items: [
      TasbeehItem(phrase: "Allahumma Salli 'Ala Muhammad", count: 100),
    ],
  ),
  TasbeehCollection(
    name: "Istighfar",
    items: [
      TasbeehItem(
          phrase: "Astaghfirullah alathi la ilaha illa hu\n"
              "al Hayy ul Qayyum wa atubu ilaih",
          count: 100),
    ],
  ),
];

const Color deepBlue = Color.fromARGB(255, 41, 82, 122);
const Color lightGold = Color(0xFFFFD700);
const Color offWhite = Color(0xFFF8F8F8);

class CollectionSelectionScreen extends StatelessWidget {
  const CollectionSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: offWhite,
      appBar: buildAppBar(
          context, 'Select Tasbih', const TasbihScreen(), screenFrom),
      body: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: ListView.builder(
          itemCount: tasbeehCollections.length,
          itemBuilder: (context, index) {
            final collection = tasbeehCollections[index];
            return Card(
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                title: Text(
                  collection.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: deepBlue,
                  ),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: deepBlue,
                  size: 20,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          TasbihScreen(collection: collection),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class TasbihScreen extends StatefulWidget {
  final TasbeehCollection? collection;
  const TasbihScreen({super.key, this.collection});

  @override
  _TasbihScreenState createState() => _TasbihScreenState();
}

class _TasbihScreenState extends State<TasbihScreen> {
  int currentIndex = 0;
  int count = 0;

  void _incrementCounter() {
    setState(() {
      final collection = widget.collection!;
      if (count < collection.items[currentIndex].count) {
        count++;
      } else {
        count = 0;
        if (currentIndex < collection.items.length - 1) {
          currentIndex++;
        }
      }
    });
  }

  void _TasbihSelectScreenGoTo() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => const CollectionSelectionScreen()),
    );
  }

  void _resetCounter() {
    setState(() {
      count = 0;
      currentIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.collection == null) {
      return Scaffold(
        backgroundColor: offWhite,
        appBar: buildAppBar(
            context, "Tasbih", const MoreOptionsScreen(), screenFrom),
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.calculate_rounded,
                  size: 60,
                  color: deepBlue,
                ),
                const SizedBox(height: 20),
                const Text(
                  "No Tasbeeh collection selected.",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: deepBlue,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _TasbihSelectScreenGoTo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: deepBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    "Select a Tasbih",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final collection = widget.collection!;
    final tasbeeh = collection.items[currentIndex];
    final progress = count / tasbeeh.count;

    return Scaffold(
      backgroundColor: offWhite,
      appBar:
          buildAppBar(context, "Tasbih", const MoreOptionsScreen(), screenFrom),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 30, bottom: 40),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: deepBlue,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 0,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    collection.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: lightGold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    tasbeeh.phrase,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 180,
                  width: 180,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 12,
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(lightGold),
                  ),
                ),
                Container(
                  height: 150,
                  width: 150,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        spreadRadius: 0,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: deepBlue,
                        ),
                      ),
                      Text(
                        'of ${tasbeeh.count}',
                        style: TextStyle(
                          fontSize: 16,
                          color: deepBlue.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: _incrementCounter,
              child: Container(
                height: 100,
                width: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [deepBlue, Color.fromARGB(255, 35, 71, 107)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: deepBlue.withOpacity(0.4),
                      spreadRadius: 1,
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add,
                  size: 50,
                  color: Colors.white,
                ),
              ),
            ),
            const Spacer(),
            Container(
              margin: const EdgeInsets.only(bottom: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _resetCounter,
                    icon: const Icon(Icons.refresh, size: 20),
                    label: const Text(
                      "Reset",
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: deepBlue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: deepBlue, width: 1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton.icon(
                    onPressed: _TasbihSelectScreenGoTo,
                    icon: const Icon(Icons.list, size: 20),
                    label: const Text(
                      "Select Tasbih",
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: deepBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
