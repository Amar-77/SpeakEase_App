import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:speakease/screens/student/home/widgets/teacher_app_bar.dart';

import '../assignments/create_assignment_screen.dart';
import '../assignments/teacher_history_screen.dart';
import '../students/student_list_screen.dart';

class TeacherHome extends StatelessWidget {
  const TeacherHome({super.key});

  String _getCurrentDate() {
    DateTime now = DateTime.now();
    String day = DateFormat('d').format(now);

    String suffix = 'th';
    if (day.endsWith('1') && day != '11') suffix = 'st';
    else if (day.endsWith('2') && day != '12') suffix = 'nd';
    else if (day.endsWith('3') && day != '13') suffix = 'rd';

    return "$day$suffix ${DateFormat('MMMM y').format(now)}";
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;

          String name = data['name'] ?? "Teacher";
          String classId = data['class_id'] ?? "N/A";

          final size = MediaQuery.of(context).size;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const TeacherAppBar(),

                  const SizedBox(height: 10),

                  /// 🔥 HERO (NOW EXACTLY MATCHES STUDENT)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      width: double.infinity,
                      height: size.height * 0.38,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFCFEA), Color(0xFF82A5E8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [

                          /// TEXT SIDE (SAME AS STUDENT)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [

                                const Text(
                                  'WELCOME,',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w300,
                                    color: Color(0xFF171717),
                                    letterSpacing: 1.5,
                                  ),
                                ),

                                const SizedBox(height: 2),

                                Text(
                                  '${name.toUpperCase()}!',
                                  style: const TextStyle(
                                    fontSize: 35,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black,
                                    height: 1,
                                  ),
                                ),

                                const SizedBox(height: 6),

                                Text(
                                  _getCurrentDate(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),

                                const SizedBox(height: 10),

                                /// CLASS ID BOX
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "Class ID: $classId",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),

                                const Spacer(),

                                /// KEEP SPACE (IMPORTANT FOR ALIGNMENT)
                                const SizedBox(height: 60),
                              ],
                            ),
                          ),

                          /// 👩‍🏫 IMAGE (EXACT POSITION LIKE STUDENT)
                          Positioned(
                            height: 280,
                            right: -30,
                            bottom: 0,
                            child: Image.asset(
                              'assets/images/teacherhome.png',
                              height: size.height * 0.30,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Category',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  /// 🔥 GRID (MATCHED TO STUDENT)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        /// BIG TILE
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const CreateAssignmentScreen()),
                              );
                            },
                            child: Container(
                              height: 304, // SAME AS STUDENT
                              decoration: BoxDecoration(
                                color: const Color(0xFFBEE8B5),
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Transform.translate(
                                      offset: const Offset(0, -40),
                                      child: Image.asset(
                                        'assets/images/createassignment.png',
                                        height: 200,
                                      ),
                                    ),
                                  ),
                                  const Positioned(
                                    bottom: 40,
                                    left: 16,
                                    child: Text(
                                      'Create New\nAssignment',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 14),

                        /// RIGHT SIDE
                        Expanded(
                          child: Column(
                            children: [

                              /// VIEW SENT
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const TeacherHistoryScreen()),
                                  );
                                },
                                child: Container(
                                  height: 170,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3E5F5),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned(
                                        top: -60,
                                        left: 0,
                                        right: 0,
                                        child: Center(
                                          child: Image.asset(
                                            'assets/images/sendassignment.png',
                                            height: 160,
                                          ),
                                        ),
                                      ),
                                      const Positioned(
                                        bottom: 16,
                                        left: 16,
                                        right: 16,
                                        child: Text(
                                          'View Sent\nAssignments',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 14),

                              /// STUDENTS
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          StudentListScreen(classId: classId),
                                    ),
                                  );
                                },
                                child: Container(
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE1F5FE),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned(
                                        bottom: -10,
                                        right: -5,
                                        child: Image.asset(
                                          'assets/images/mystudents.png',
                                          height: 110,
                                        ),
                                      ),
                                      const Positioned(
                                        top: 16,
                                        left: 16,
                                        child: Text(
                                          'My Students',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
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
}