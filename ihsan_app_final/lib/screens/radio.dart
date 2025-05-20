import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:ihsan_app_final/screens/moreoptionsScreen.dart';
import 'package:ihsan_app_final/sharedWidgets.dart';

class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key});

  @override
  _RadioScreenState createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  final AudioPlayer _player = AudioPlayer();
  // activeStationIndex: index of the currently playing station; -1 means no station playing.
  int activeStationIndex = -1;
  bool isLoading = false;

  // Updated BBC Radio 1 URL (HTTPS) and additional stations.
  final List<Map<String, dynamic>> radioStations = [
    {
      "name": "Zakariyya Mosque Bolton",
      "url": "https://relay.emasjidlive.uk/zjmbolton",
      "icon": Icons.mosque
    },
    {
      "name": "BBC Radio 1",
      "url": "https://stream.live.vc.bbcmedia.co.uk/bbc_radio_one",
      "icon": Icons.radio
    },
    {
      "name": "Quran Recitation",
      "url": "http://server8.mp3quran.net:8000/radio_roq",
      "icon": Icons.menu_book
    },
    {
      "name": "Islamic Lectures",
      "url": "http://stream.radio.co/s93c489494/listen",
      "icon": Icons.mic
    },
  ];

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _handleStationTap(int index) async {
    // If the tapped station is already active, stop playback.
    if (activeStationIndex == index) {
      await _player.stop();
      if (!mounted) return;
      setState(() {
        activeStationIndex = -1;
      });
      return;
    }

    // Stop any currently playing station.
    if (activeStationIndex != -1) {
      await _player.stop();
    }

    // Set the new active station and show loading.
    setState(() {
      activeStationIndex = index;
      isLoading = true;
    });

    try {
      final station = radioStations[index];
      await _player.setUrl(station["url"]);
      await _player.play();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "Error playing ${radioStations[index]["name"]}: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        activeStationIndex = -1;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  // Builds a button for each station.
  Widget _buildStationButton(int index, Color themeColor) {
    final bool isActive = activeStationIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: InkWell(
        onTap: () => _handleStationTap(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            // Active station gets a solid white background.
            color: isActive ? Colors.white : Colors.white.withOpacity(0.3),
            // For a square look, we use a small border radius.
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                radioStations[index]["icon"],
                color: isActive ? themeColor : Colors.white,
                size: 30,
              ),
              const SizedBox(height: 8),
              Text(
                radioStations[index]["name"],
                style: TextStyle(
                  color: isActive ? themeColor : Colors.white,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 8),
              // Show loading indicator if active station is loading.
              isActive && isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  // If active and not loading, show stop icon; otherwise, play icon.
                  : Icon(
                      isActive ? Icons.stop : Icons.play_arrow,
                      color: themeColor,
                    ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = const Color.fromARGB(255, 105, 170, 190);

    return Scaffold(
      backgroundColor: themeColor,
      appBar: buildAppBar(
          context, 'Mosque Radio', const MoreOptionsScreen(), screenFrom),
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // A card that shows details about the active station.
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // Show the icon for the active station, or a default one.
                    Icon(
                      activeStationIndex != -1
                          ? radioStations[activeStationIndex]["icon"]
                          : Icons.radio,
                      size: 60,
                      color: themeColor,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Live Radio Broadcast',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 70, 70, 70),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      activeStationIndex != -1
                          ? radioStations[activeStationIndex]["name"]
                          : 'No Station Playing',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color.fromARGB(255, 100, 100, 100),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // A large button that mirrors the functionality of the active station button.
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: themeColor.withOpacity(0.1),
                      ),
                      child: Center(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: activeStationIndex == -1 || isLoading
                                ? null
                                : () => _handleStationTap(activeStationIndex),
                            customBorder: const CircleBorder(),
                            child: Ink(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: themeColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                              width: 80,
                              height: 80,
                              child: Center(
                                child: isLoading
                                    ? const SizedBox(
                                        height: 30,
                                        width: 30,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 3,
                                        ),
                                      )
                                    : Icon(
                                        activeStationIndex != -1
                                            ? Icons.stop
                                            : Icons.play_arrow,
                                        color: Colors.white,
                                        size: 40,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      activeStationIndex != -1 ? 'Stop' : 'Play',
                      style: TextStyle(
                        fontSize: 16,
                        color: themeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Select Station',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            // Station selection row with individual buttons.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(
                  radioStations.length,
                  (index) => _buildStationButton(index, themeColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
