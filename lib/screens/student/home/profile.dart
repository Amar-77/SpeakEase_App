import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("My Profile", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          // Moved Logout here for a cleaner UI
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pop(context); // Go back to AuthWrapper
            },
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          var userData = snapshot.data!.data() as Map<String, dynamic>;

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                // 1. Large Profile Circle
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(2), // Border thickness
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 1),
                    ),
                    child: CircleAvatar(
                      radius: 80,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person_outline, size: 80, color: Colors.black.withOpacity(0.5)),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 2. Username and Email
                Text(
                  userData['name']?.toLowerCase() ?? 'username',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w400, letterSpacing: 1.2),
                ),
                Text(
                  userData['email'] ?? 'user@gmail.com',
                  style: TextStyle(fontSize: 16, color: Colors.black.withOpacity(0.7)),
                ),

                const SizedBox(height: 20),

                // 3. Edit Profile Button
                ElevatedButton(
                  onPressed: () {
                    // Logic for editing profile
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5E1C0), // Match image color
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  child: const Text("edit profile", style: TextStyle(fontSize: 16)),
                ),

                const SizedBox(height: 30),

                // 4. Large Decorative/Stats Container
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5E1C0).withOpacity(0.7),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Class ID: ${userData['class_id'] ?? 'N/A'}",
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 10),
                        Text("Speech Coins: ${userData['speech_coins'] ?? 0}",
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}