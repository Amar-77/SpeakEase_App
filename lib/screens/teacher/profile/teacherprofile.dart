import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/auth_gate.dart';

class TeacherProfilePage extends StatefulWidget {
  const TeacherProfilePage({super.key});

  @override
  State<TeacherProfilePage> createState() => _TeacherProfilePageState();
}

class _TeacherProfilePageState extends State<TeacherProfilePage> {
  final User? user = FirebaseAuth.instance.currentUser;

  /// 🔴 LOGOUT
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthGate()),
        (route) => false,
      );
    }
  }

  /// ✏️ EDIT NAME
  Future<void> _editName(String currentName) async {
    TextEditingController controller =
        TextEditingController(text: currentName);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Name"),
        content: TextField(
          controller: controller,
          decoration:
              const InputDecoration(labelText: "Display Name"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user!.uid)
                    .update({
                  'name': controller.text.trim(),
                });

                await user!.updateDisplayName(
                    controller.text.trim());

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
    if (user == null) {
      return const Scaffold(
          body: Center(child: Text("Not logged in")));
    }

    return Scaffold(
      backgroundColor: Colors.white,

      /// 🔥 APP BAR
      appBar: AppBar(
        title: const Text(
          "My Profile",
          style:
              TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),

      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .snapshots(),
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator());
          }

          var data =
              snapshot.data!.data() as Map<String, dynamic>;

          String name = data['name'] ?? 'Teacher';
          String email = data['email'] ?? user!.email ?? '';
          String classId = data['class_id'] ?? 'Not Assigned';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [

                /// 👤 PROFILE IMAGE
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey.shade200,
                        child: Text(
                          name[0],
                          style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold),
                        ),
                      ),

                      /// EDIT BUTTON
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _editName(name),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.edit,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                /// NAME
                Text(
                  name,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),

                /// EMAIL
                Text(
                  email,
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600),
                ),

                const SizedBox(height: 10),

                /// ROLE TAG
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Teacher",
                    style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 30),

                /// 🏫 CLASS CARD
                Container(
                  width: double.infinity,
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
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.school,
                            color: Colors.purple),
                      ),
                      const SizedBox(width: 15),
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text("Class Code",
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey)),
                          Text(
                            classId,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                /// 🔴 LOGOUT
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _logout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red,
                      padding:
                          const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.logout),
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
}