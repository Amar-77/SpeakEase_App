import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speakease/screens/student/home/profile/editprofile.dart';
import 'package:speakease/screens/student/home/profile/settings.dart';
import 'leaderboard_screen.dart'; // Import your leaderboard screen

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      backgroundColor: const Color(0xFF9B8DD9),
      appBar: AppBar(
        title: const Text("profile", style: TextStyle(color: Colors.white, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }

          var userData = snapshot.data!.data() as Map<String, dynamic>;
          final classId = userData['class_id'] ?? '';

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Profile Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8D4E8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        // Row with Profile Picture (left) and Achievement Badge (right)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Profile Picture with Trophy Badge
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 40,
                                  backgroundColor: Colors.white,
                                  child: Icon(Icons.person, size: 50, color: Colors.grey[400]),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF9B4DCA),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.emoji_events, color: Colors.white, size: 16),
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(width: 15),
                            
                            // Achievement Badge Box (Tappable)
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  // Navigate to leaderboard
                                  if (classId.isNotEmpty) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => LeaderboardScreen(classId: classId),
                                      ),
                                    );
                                  } else {
                                    // Show message if no class assigned
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('You are not assigned to a class yet!'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: const Text(
                                    "You are #1\namong your\nfriends!",
                                    textAlign: TextAlign.left,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.3,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Username (outside the box)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            userData['name']?.toLowerCase() ?? 'amargod',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 5),
                        
                        // Email (outside the box)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            userData['email'] ?? 'user@gmail.com',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black.withOpacity(0.6),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 15),
                        
                        // Edit Profile Button (outside the box)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfilePage()),
    );
                            },
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text("edit profile"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9B4DCA),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Settings and Overview Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        _buildMenuItem(
                          icon: Icons.settings,
                          title: "Settings",
                          onTap: () {
                            Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
                          },
                        ),
                        const Divider(height: 1, indent: 60),
                        _buildMenuItem(
                          icon: Icons.bar_chart,
                          title: "Overview",
                          onTap: () {
                            // Navigate to overview
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // About Us and Logout Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        _buildMenuItem(
                          icon: Icons.info_outline,
                          title: "About us",
                          onTap: () {
                            // Navigate to about us
                          },
                        ),
                        const Divider(height: 1, indent: 60),
                        _buildMenuItem(
                          icon: Icons.logout,
                          title: "Logout",
                          iconColor: Colors.red,
                          titleColor: Colors.red,
                          onTap: () async {
                            await FirebaseAuth.instance.signOut();
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? titleColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Colors.black87),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: titleColor ?? Colors.black87,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    );
  }
}