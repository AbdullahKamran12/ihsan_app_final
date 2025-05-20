import 'package:flutter/material.dart';
import 'package:ihsan_app_final/screens/exports.dart';

String screenFrom = "Home";

AppBar buildAppBarHome(BuildContext context) {
  return AppBar(
    backgroundColor: const Color.fromARGB(255, 0, 128, 128),
    leading: Builder(
      builder: (context) {
        return IconButton(
          icon: const Icon(Icons.menu, size: 40),
          onPressed: () {
            Scaffold.of(context).openDrawer();
          },
        );
      },
    ),
    actions: [
      Padding(
        padding: const EdgeInsets.only(right: 16.0),
        child: Image(
          image:
              const AssetImage('assets/Untitled_design-removebg-preview.png'),
          width: MediaQuery.of(context).size.width * 0.15,
          height: MediaQuery.of(context).size.height * 0.15,
        ),
      ),
    ],
  );
}

AppBar buildAppBar(
    BuildContext context, String title, Widget screento, String? screenFrom) {
  return AppBar(
    title: Text(title),
    backgroundColor: const Color.fromARGB(255, 105, 170, 190),
    elevation: 0,
    centerTitle: true,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        if (screenFrom == "Home") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomeScreen()),
          );
        } else if (screenFrom == "More") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => MoreOptionsScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => screento),
          );
        }
      },
    ),
  );
}

Widget buildBottomNavigationBar(
    BuildContext context, int currentIndex, Function(int) onTap) {
  return BottomNavigationBar(
    backgroundColor: const Color.fromARGB(255, 0, 128, 128),
    items: const <BottomNavigationBarItem>[
      BottomNavigationBarItem(
        icon: Icon(Icons.home),
        label: 'Home',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.access_time),
        label: 'Prayer Times',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.explore),
        label: 'Qibla',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.book),
        label: 'Quran',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.more_horiz),
        label: 'More Options',
      ),
    ],
    currentIndex: currentIndex,
    selectedItemColor: Colors.white,
    unselectedItemColor: Colors.white.withOpacity(0.6),
    showUnselectedLabels: true,
    type: BottomNavigationBarType.fixed,
    onTap: onTap,
  );
}
