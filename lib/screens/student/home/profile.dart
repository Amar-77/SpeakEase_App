import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/login_screen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final User? user = FirebaseAuth.instance.currentUser;

  // --- LOGOUT FUNCTION ---
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      // Remove all routes and go back to Login
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (Route<dynamic> route) => false,
      );
    }
  }

  // --- EDIT NAME FUNCTION ---
  Future<void> _editName(String currentName) async {
    TextEditingController controller = TextEditingController(text: currentName);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Name"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Display Name"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                // Update Firestore
                await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
                  'name': controller.text.trim(),
                });
                // Update Auth Profile (optional but good practice)
                await user!.updateDisplayName(controller.text.trim());
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Scaffold(body: Center(child: Text("Not logged in")));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("My Profile", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          var data = snapshot.data!.data() as Map<String, dynamic>;
          String name = data['name'] ?? 'Student';
          String email = data['email'] ?? user!.email ?? '';
          String classId = data['class_id'] ?? 'Not Assigned';

          // Stats
          int level = data['level'] ?? 1;
          int streak = data['current_streak'] ?? 0;
          double totalMinutes = (data['total_practice_minutes'] ?? 0).toDouble();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // --- 1. PROFILE HEADER ---
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: const NetworkImage("https://ui-avatars.com/api/?background=random&size=200"),
                        child: Text(name[0], style: const TextStyle(fontSize: 40, color: Colors.transparent)), // Fallback text invisible
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _editName(name),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                            child: const Icon(Icons.edit, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text(email, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),

                const SizedBox(height: 30),

                // --- 2. STATS OVERVIEW ---
                Row(
                  children: [
                    _buildStatCard("Level", "$level", Icons.star_rounded, Colors.amber),
                    const SizedBox(width: 15),
                    _buildStatCard("Streak", "$streak", Icons.local_fire_department_rounded, Colors.orange),
                    const SizedBox(width: 15),
                    // Show rounded minutes (e.g. "120")
                    _buildStatCard("Minutes", totalMinutes.toStringAsFixed(0), Icons.timer_rounded, Colors.blue),
                  ],
                ),

                const SizedBox(height: 30),

                // --- 3. CLASS INFO CARD ---
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.purple.shade50, shape: BoxShape.circle),
                        child: const Icon(Icons.school_rounded, color: Colors.purple),
                      ),
                      const SizedBox(width: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Class Code", style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(classId, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // --- 4. LOGOUT BUTTON ---
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _logout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text("Log Out"),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.grey.shade100, blurRadius: 10, offset: const Offset(0, 5)),
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}