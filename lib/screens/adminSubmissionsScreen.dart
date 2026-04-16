import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:ihsan_app_final/sharedWidgets.dart';
import 'package:ihsan_app_final/screens/moreoptionsScreen.dart';
import 'package:gal/gal.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _navy = Color.fromARGB(255, 10, 25, 60);
const Color _navyMid = Color.fromARGB(255, 18, 42, 95);
const Color _navyLight = Color.fromARGB(255, 28, 55, 115);
const Color _gold = Color.fromARGB(255, 212, 175, 95);
const Color _goldLight = Color.fromARGB(255, 252, 243, 210);
const Color _mint = Color.fromARGB(255, 72, 200, 155);
const Color _mintLight = Color.fromARGB(255, 210, 245, 232);
const Color _offWhite = Color.fromARGB(255, 247, 249, 255);
const Color _textMid = Color.fromARGB(255, 150, 175, 220);
const Color _border = Color.fromARGB(255, 40, 65, 130);

// ══════════════════════════════════════════════════════════════════════════════
class AdminSubmissionsScreen extends StatefulWidget {
  const AdminSubmissionsScreen({super.key});
  @override
  State<AdminSubmissionsScreen> createState() => _AdminSubmissionsScreenState();
}

class _AdminSubmissionsScreenState extends State<AdminSubmissionsScreen> {
  // ── Helpers ──────────────────────────────────────────────────────────────

  String _formatTs(Timestamp ts) {
    final dt = ts.toDate();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _downloadPhoto(String url, String fileName) async {
    try {
      // Show loading snackbar
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Row(children: [
          SizedBox(
            width: 18,
            height: 18,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          SizedBox(width: 12),
          Text('Saving to gallery…'),
        ]),
        duration: Duration(seconds: 10),
        backgroundColor: _navyMid,
        behavior: SnackBarBehavior.floating,
      ));

      // Check / request permission
      final hasAccess = await Gal.hasAccess(toAlbum: false);
      if (!hasAccess) {
        await Gal.requestAccess(toAlbum: false);
      }

      // Download bytes and save
      final response = await http.get(Uri.parse(url));
      await Gal.putImageBytes(response.bodyBytes, name: fileName);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text('Saved to Gallery'),
          ]),
          backgroundColor: _mint,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } on GalException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.type == GalExceptionType.accessDenied
              ? 'Gallery permission denied — enable it in Settings'
              : 'Save failed'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
  }

  Future<void> _deleteSubmission(
      String docId, String storagePath, String mosqueName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _offWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Submission',
            style: TextStyle(
                color: _navy, fontWeight: FontWeight.w700, fontSize: 16)),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(
                color: Color.fromARGB(255, 90, 115, 160),
                fontSize: 14,
                height: 1.5),
            children: [
              const TextSpan(text: 'Permanently delete the photo from '),
              TextSpan(
                  text: mosqueName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: _navy)),
              const TextSpan(text: '?\n\nThis cannot be undone.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color.fromARGB(255, 90, 115, 160))),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.delete_rounded, size: 16),
            label: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      if (storagePath.isNotEmpty) {
        await FirebaseStorage.instance.ref(storagePath).delete();
      }
      await FirebaseFirestore.instance
          .collection('mosque_submissions')
          .doc(docId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.delete_rounded, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Submission deleted'),
          ]),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Delete failed: $e'),
          backgroundColor: Colors.red.shade900,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ── Full-screen photo viewer ──────────────────────────────────────────────
  void _openPhoto(String url, String mosqueName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PhotoViewer(url: url, mosqueName: mosqueName),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      appBar: buildAppBar(
          context, 'Photo Submissions', const MoreOptionsScreen(), 'Home'),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('mosque_submissions')
            .orderBy('submittedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // ── Loading ──────────────────────────────────────────────────────
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: _gold, strokeWidth: 2),
                  const SizedBox(height: 16),
                  Text('Loading submissions…',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.5), fontSize: 13)),
                ],
              ),
            );
          }

          // ── Empty ────────────────────────────────────────────────────────
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _navyMid,
                      shape: BoxShape.circle,
                      border: Border.all(color: _border, width: 1.5),
                    ),
                    child: Icon(Icons.photo_library_outlined,
                        size: 36, color: _gold.withOpacity(0.7)),
                  ),
                  const SizedBox(height: 16),
                  const Text('No submissions yet',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('Mosque photo submissions will appear here',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4), fontSize: 13)),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          // ── Count badge ──────────────────────────────────────────────────
          return Column(
            children: [
              // Summary bar
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: _navyMid,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _gold.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: _gold.withOpacity(0.4), width: 1),
                      ),
                      child: Row(children: [
                        const Icon(Icons.photo_camera_outlined,
                            color: _gold, size: 14),
                        const SizedBox(width: 6),
                        Text(
                            '${docs.length} submission${docs.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                                color: _gold,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    const Spacer(),
                    Text('Newest first',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 11)),
                  ],
                ),
              ),

              // ── List ──────────────────────────────────────────────────────
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final docId = doc.id;
                    final mosqueName = data['mosqueName'] ?? 'Unknown Mosque';
                    final city = data['city'] ?? '';
                    final storagePath = data['storagePath'] ?? '';
                    final fileName = data['fileName'] ?? 'photo.jpg';
                    final submittedAt = data['submittedAt'] as Timestamp?;
                    final timeStr = submittedAt != null
                        ? _formatTs(submittedAt)
                        : 'Unknown time';

                    // Single future shared across photo + download
                    final urlFuture = storagePath.isNotEmpty
                        ? FirebaseStorage.instance
                            .ref(storagePath)
                            .getDownloadURL()
                        : Future<String?>.value(null);

                    return _SubmissionCard(
                      mosqueName: mosqueName,
                      city: city,
                      timeStr: timeStr,
                      fileName: fileName,
                      storagePath: storagePath,
                      urlFuture: urlFuture,
                      onDelete: () =>
                          _deleteSubmission(docId, storagePath, mosqueName),
                      onDownload: (url) => _downloadPhoto(url, fileName),
                      onPhotoTap: (url) => _openPhoto(url, mosqueName),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Submission card — stateful so it can handle its own download loading state
// ══════════════════════════════════════════════════════════════════════════════
class _SubmissionCard extends StatefulWidget {
  final String mosqueName;
  final String city;
  final String timeStr;
  final String fileName;
  final String storagePath;
  final Future<String?> urlFuture;
  final VoidCallback onDelete;
  final Function(String url) onDownload;
  final Function(String url) onPhotoTap;

  const _SubmissionCard({
    required this.mosqueName,
    required this.city,
    required this.timeStr,
    required this.fileName,
    required this.storagePath,
    required this.urlFuture,
    required this.onDelete,
    required this.onDownload,
    required this.onPhotoTap,
  });

  @override
  State<_SubmissionCard> createState() => _SubmissionCardState();
}

class _SubmissionCardState extends State<_SubmissionCard> {
  bool _isDownloading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _navyMid,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _gold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: _gold.withOpacity(0.25), width: 1),
                  ),
                  child:
                      const Icon(Icons.mosque_rounded, color: _gold, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.mosqueName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                      const SizedBox(height: 3),
                      if (widget.city.isNotEmpty)
                        Row(children: [
                          Icon(Icons.location_on_outlined,
                              size: 11, color: Colors.white.withOpacity(0.4)),
                          const SizedBox(width: 3),
                          Text(widget.city,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.45),
                                  fontSize: 11)),
                        ]),
                      const SizedBox(height: 2),
                      Row(children: [
                        Icon(Icons.access_time_rounded,
                            size: 11, color: Colors.white.withOpacity(0.3)),
                        const SizedBox(width: 3),
                        Text(widget.timeStr,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.35),
                                fontSize: 11)),
                      ]),
                    ],
                  ),
                ),
                // Delete
                GestureDetector(
                  onTap: widget.onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.red.withOpacity(0.25), width: 1),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: Colors.redAccent, size: 18),
                  ),
                ),
              ],
            ),
          ),

          // ── Divider ───────────────────────────────────────────────────────
          Divider(height: 1, color: _border.withOpacity(0.7)),

          // ── Photo ─────────────────────────────────────────────────────────
          if (widget.storagePath.isNotEmpty)
            FutureBuilder<String?>(
              future: widget.urlFuture,
              builder: (context, urlSnap) {
                if (urlSnap.connectionState == ConnectionState.waiting) {
                  return Container(
                    height: 200,
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _navyLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                            color: _gold, strokeWidth: 2),
                        const SizedBox(height: 10),
                        Text('Loading photo…',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 12)),
                      ],
                    ),
                  );
                }

                if (urlSnap.hasError || urlSnap.data == null) {
                  return Container(
                    height: 120,
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _navyLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.red.withOpacity(0.2), width: 1),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_outlined,
                            color: Colors.white.withOpacity(0.3), size: 28),
                        const SizedBox(height: 6),
                        Text('Photo unavailable',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.35),
                                fontSize: 12)),
                      ],
                    ),
                  );
                }

                final url = urlSnap.data!;
                return Column(
                  children: [
                    // Photo — tappable for full screen
                    GestureDetector(
                      onTap: () => widget.onPhotoTap(url),
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: _gold.withOpacity(0.15), width: 1),
                        ),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                url,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 220,
                                loadingBuilder: (ctx, child, progress) {
                                  if (progress == null) return child;
                                  final pct =
                                      progress.expectedTotalBytes != null
                                          ? progress.cumulativeBytesLoaded /
                                              progress.expectedTotalBytes!
                                          : null;
                                  return Container(
                                    height: 220,
                                    color: _navyLight,
                                    alignment: Alignment.center,
                                    child: CircularProgressIndicator(
                                        value: pct,
                                        color: _gold,
                                        strokeWidth: 2),
                                  );
                                },
                                errorBuilder: (_, __, ___) => Container(
                                  height: 120,
                                  color: _navyLight,
                                  alignment: Alignment.center,
                                  child: Icon(Icons.broken_image_outlined,
                                      color: Colors.white.withOpacity(0.3),
                                      size: 28),
                                ),
                              ),
                            ),
                            // Tap to expand hint
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.fullscreen_rounded,
                                        size: 12, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text('Expand',
                                        style: TextStyle(
                                            color: Colors.white, fontSize: 10)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Action row ───────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                      child: Row(
                        children: [
                          // File name chip
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: _navyLight,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _border, width: 1),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.image_outlined,
                                      size: 13,
                                      color: Colors.white.withOpacity(0.4)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      widget.fileName,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color:
                                              Colors.white.withOpacity(0.45)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Download button
                          GestureDetector(
                            onTap: _isDownloading
                                ? null
                                : () async {
                                    setState(() => _isDownloading = true);
                                    await widget.onDownload(url);
                                    if (mounted) {
                                      setState(() => _isDownloading = false);
                                    }
                                  },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                color: _isDownloading
                                    ? _navyLight
                                    : _gold.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: _isDownloading
                                        ? _border
                                        : _gold.withOpacity(0.5),
                                    width: 1.2),
                              ),
                              child: _isDownloading
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: _gold))
                                  : const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.download_rounded,
                                            color: _gold, size: 16),
                                        SizedBox(width: 6),
                                        Text('Download',
                                            style: TextStyle(
                                                color: _gold,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12)),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            )
          else
            // No photo submitted
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _navyLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border, width: 1),
                ),
                child: Row(children: [
                  Icon(Icons.hide_image_outlined,
                      size: 16, color: Colors.white.withOpacity(0.3)),
                  const SizedBox(width: 8),
                  Text('No photo attached',
                      style: TextStyle(
                          fontSize: 12, color: Colors.white.withOpacity(0.35))),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Full-screen photo viewer
// ══════════════════════════════════════════════════════════════════════════════
class _PhotoViewer extends StatelessWidget {
  final String url;
  final String mosqueName;
  const _PhotoViewer({required this.url, required this.mosqueName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(mosqueName,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white54, size: 18),
              label: const Text('Close',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
            ),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                      : null,
                  color: _gold,
                  strokeWidth: 2,
                ),
              );
            },
            errorBuilder: (_, __, ___) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined,
                    color: Colors.white.withOpacity(0.3), size: 48),
                const SizedBox(height: 12),
                Text('Could not load image',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4), fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
