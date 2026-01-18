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
    if (hidden.length >= 100) {
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Activity", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
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
                padding: const EdgeInsets.symmetric(vertical: 10),
                itemBuilder: (context, index) {
                  var doc = visibleDocs[index];
                  var timestamp = (doc['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();
                  String formattedTime = DateFormat.jm().format(timestamp);

                  return Dismissible(
                    key: Key(doc.id), // Unique key for the list item
                    direction: DismissDirection.startToEnd, // Only allow right swipe
                    onDismissed: (direction) => _hideNotification(doc.id),
                    background: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 20),
                      color: Colors.redAccent,
                      child: const Icon(Icons.delete_outline, color: Colors.white),
                    ),
                    child: _buildNotificationTile(doc, formattedTime),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // --- Helper: The UI Tile for each notification ---
  Widget _buildNotificationTile(DocumentSnapshot doc, String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: Color(0xFFE8F0FE),
            child: Icon(Icons.assignment_turned_in_rounded, color: Colors.blueAccent),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black, fontSize: 14),
                    children: [
                      const TextSpan(text: "New Assignment: ", style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: "${doc['title']} was posted in ${doc['class_id']}."),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Text(time, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("No new activity", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Text("Recent assignments will appear here", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}