import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class NotificationScreen extends StatelessWidget {
  final String? classId;
  const NotificationScreen({super.key, this.classId});

  // Adds the assignment ID to the user's hidden list in Firestore
  Future<void> _hideNotification(String assignmentId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);

    // Fetch current list to check length
    DocumentSnapshot snap = await userDoc.get();
    List hidden = List.from(snap.get('hidden_notifications') ?? []);

    // Safety Cap: If list is too large, remove the oldest (first) item
    if (hidden.length >= 50) {
      hidden.removeAt(0);
    }

    // Add the new ID
    if (!hidden.contains(assignmentId)) {
      hidden.add(assignmentId);
    }

    // Update Firestore
    await userDoc.update({'hidden_notifications': hidden});
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    // Define the "Window" of relevance (e.g., last 30 days)
    final DateTime thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7), // 👈 Matches the app's soft background
      body: SafeArea(
        child: Column(
          children: [
            // ── CUSTOM HEADER ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 20,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    "Activity",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),

            // ── NOTIFICATION LIST ──
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                // Step 1: Listen to the user document for the "hidden_notifications" list
                stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());

                  var userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                  List hiddenIds = userData?['hidden_notifications'] ?? [];

                  return StreamBuilder<QuerySnapshot>(
                    // Step 2: Fetch assignments for this class within the 30-day window
                    stream: FirebaseFirestore.instance
                        .collection('assignments')
                        .where('class_id', isEqualTo: classId)
                        .where('created_at', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
                        .orderBy('created_at', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                      // Step 3: Filter out documents that have been swiped away
                      var visibleDocs = snapshot.data!.docs.where((doc) => !hiddenIds.contains(doc.id)).toList();

                      if (visibleDocs.isEmpty) return _buildEmptyState();

                      return ListView.builder(
                        itemCount: visibleDocs.length,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        itemBuilder: (context, index) {
                          var doc = visibleDocs[index];
                          var timestamp = (doc['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();
                          String formattedTime = DateFormat.jm().format(timestamp);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16), // 👈 Margin outside dismissible
                            child: Dismissible(
                              key: Key(doc.id),
                              direction: DismissDirection.startToEnd,
                              onDismissed: (direction) => _hideNotification(doc.id),
                              // ── CUSTOM SWIPE BACKGROUND ──
                              background: Container(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 24),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF8B8B), // Soft red
                                  borderRadius: BorderRadius.circular(20), // Matches card curve
                                ),
                                child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
                              ),
                              child: _buildNotificationTile(doc, formattedTime),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper: The UI Tile for each notification ---
  Widget _buildNotificationTile(DocumentSnapshot doc, String time) {
    String title = doc['title'] ?? 'Untitled Assignment';
    String className = doc['class_id'] ?? 'your class';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pastel Icon Container
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE1F5FE), // Soft pastel blue
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.assignment, color: Colors.blueAccent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(
                  "New assignment posted in $className.",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.3),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper: Beautiful Empty State ---
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: const Icon(Icons.notifications_active_outlined, size: 50, color: Color(0xFFDCDCDC)),
          ),
          const SizedBox(height: 24),
          const Text(
            "You're all caught up!",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          const Text(
            "No new activity right now.",
            style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}