import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/auth_gate.dart';

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
      // ✅ Rebuild the app starting from the AuthGate!
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthGate()),
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
        backgroundColor: Color(0xffe8ad72),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Edit Name", style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: "Display Name",
            filled: true,
            fillColor: const Color(0xFFF9F9F9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF7B52C3), width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold))
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                // Update Firestore
                await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
                  'name': controller.text.trim(),
                });
                // Update Auth Profile
                await user!.updateDisplayName(controller.text.trim());
                if (mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B52C3),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text("Save", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Scaffold(body: Center(child: Text("Not logged in")));

    return Scaffold(
      backgroundColor: const Color(0xffffe5cb), // Soft app background
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
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

            return Column(
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
                        "My Profile",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── SCROLLABLE CONTENT ──
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // --- 1. PROFILE HEADER ---
                        Center(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    )
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 55,
                                  backgroundColor: Colors.grey.shade200,
                                  // Uses ui-avatars to safely generate an initial if no picture exists
                                  backgroundImage: NetworkImage("https://ui-avatars.com/api/?name=${name[0]}&background=random&size=200"),
                                  child: const Text("", style: TextStyle(color: Colors.transparent)),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () => _editName(name),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF7B52C3), // Purple accent
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 3),
                                    ),
                                    child: const Icon(Icons.edit, color: Colors.white, size: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black87)),
                        const SizedBox(height: 4),
                        Text(email, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54)),

                        const SizedBox(height: 36),

                        // --- 2. STATS OVERVIEW ---
                        Row(
                          children: [
                            _buildStatCard("Level", "$level", Icons.star_rounded, Colors.orange.shade600, const Color(0xFFFFF4B8)),
                            const SizedBox(width: 12),
                            _buildStatCard("Streak", "$streak", Icons.local_fire_department_rounded, Colors.red.shade400, const Color(0xFFFFD9D9)),
                            const SizedBox(width: 12),
                            _buildStatCard("Minutes", totalMinutes.toStringAsFixed(0), Icons.timer_rounded, Colors.blue.shade600, const Color(0xFFC7F0FF)),
                          ],
                        ),

                        const SizedBox(height: 30),

                        // --- 3. CLASS INFO CARD ---
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0D4FF), // Soft purple
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.school_rounded, color: Color(0xFF7B52C3), size: 28),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Class Code", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
                                  const SizedBox(height: 4),
                                  Text(classId, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: 1.0)),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),

                        // --- 4. LOGOUT BUTTON ---
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton.icon(
                            onPressed: _logout,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFEBEB), // Soft Red background
                              foregroundColor: const Color(0xFFFF4B4B), // Bold Red text/icon
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            ),
                            icon: const Icon(Icons.logout_rounded, size: 24),
                            label: const Text("Log Out", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
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

  // Modern chunky stat cards with pastel icon backgrounds
  Widget _buildStatCard(String label, String value, IconData icon, Color iconColor, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}