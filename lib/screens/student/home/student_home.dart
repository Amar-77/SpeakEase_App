import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:speakease/screens/student/home/profile.dart';
import 'package:speakease/screens/student/home/widgets/student_app_bar.dart';
import '../../../services/gamification_service.dart';
import '../dashboard/word_practice_screen.dart';
import '../practice/practice_list_screen.dart';
import '../dashboard/student_dashboard_screen.dart';
import 'achievements_screen.dart';
import 'leaderboard_screen.dart';
import 'notification_screen.dart';

class StudentHome extends StatefulWidget {
  const StudentHome({super.key});

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  // Controller for the sliding pages
  final PageController _pageController = PageController();
  final GamificationService _gamificationService = GamificationService();
  int _currentIndex = 0;
  String? _classId;

  @override
  void initState() {
    super.initState();
    _fetchUserClass();
    _runStartupChecks();
  }

  void _runStartupChecks() async {
    // Because your UI listens to a Stream, if this resets the streak to 0, the UI will update automatically instantly!
    await _gamificationService.checkStreakOnStartup();
  }

  void _fetchUserClass() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          _classId = doc.data()?['class_id'];
        });
      }
    }
  }

  // Navigation Logic
  void _onItemTapped(int index) {
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. THE HORIZONTAL SLIDER
          PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            children: [
              // PAGE 0: Your Home Dashboard (The code you sent, extracted below)
              const _DashboardContent(),

              // PAGE 1: Achievements
              AchievementsScreen(), // Pass data if needed

              // PAGE 2: Leaderboard
              LeaderboardScreen(classId: _classId ?? 'loading'),
            ],
          ),

          // 2. THE FLOATING BOTTOM NAV (Stays on top)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 30, left: 40, right: 40),
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFF222222),
                borderRadius: BorderRadius.circular(35),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(Icons.home_rounded, 0),
                  _buildNavItem(Icons.emoji_events_outlined, 1),
                  _buildNavItem(Icons.bar_chart_rounded, 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    bool isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: AnimatedContainer(
        padding: EdgeInsets.only(top: 10,bottom: 10),
        duration: const Duration(milliseconds: 300),
        width: 85,
        height: 50,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(35),
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.black : Colors.white54,
          size: 28,
        ),
      ),
    );
  }
}

// ==========================================
// YOUR ORIGINAL DASHBOARD LOGIC (Moved Here)
// ==========================================
class _DashboardContent extends StatelessWidget {
  const _DashboardContent();

  //  NEW: Dynamic Date Logic
  String _getCurrentDate() {
    DateTime now = DateTime.now();
    String day = DateFormat('d').format(now);
    String suffix = 'th';
    if (day.endsWith('1') && day != '11') {suffix = 'st';}
    else if (day.endsWith('2') && day != '12') {suffix = 'nd';}
    else if (day.endsWith('3') && day != '13') {suffix = 'rd';}
    return "$day$suffix ${DateFormat('MMMM y').format(now)}";
  }

  Future<void> _handleNotificationClick(BuildContext context, String uid, String? classId) async {
    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationScreen(classId: classId)));
    }
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'last_notification_check': FieldValue.serverTimestamp(),
    });
  }

  //  NEW: Fetch 'mistake_words' and navigate
  Future<void> _navigateToWordPractice(BuildContext context, String uid) async {
    // 1. Show a loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 2. Fetch the latest user data
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (context.mounted) {
        Navigator.pop(context); // Close the loading spinner

        if (userDoc.exists) {
          Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;

          // 3. Safely extract the words list
          // Ensure your Firestore field is actually named 'mistake_words'
          List<String> fetchedWords = List<String>.from(data['mistake_words'] ?? []);

          // 4. Navigate
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WordPracticeScreen(
                mistakeWords: fetchedWords,
                studentId: uid, // ✅ Matches your screen's parameter name
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loader if error
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final user = FirebaseAuth.instance.currentUser!;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());

        var userData = userSnapshot.data!.data() as Map<String, dynamic>;
        String? classId = userData['class_id'];
        String userName = userData['name'] ?? 'Student';
        int level = userData['level'] ?? 1;
        int currentXp = userData['current_xp'] ?? 0;
        int maxXp = userData['max_xp'] ?? 1200;
        int streak = userData['current_streak'] ?? 0;

        // Added padding at bottom so content isn't hidden behind the floating nav
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          
                // ✅ JUST ONE LINE NOW!
                const StudentAppBar(),
          
                const SizedBox(height: 10),
          
                // --- HERO SECTION (With Dynamic Date) ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: size.height * 0.38,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [Colors.blue.shade50, Colors.purple.shade50]),
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('WELCOME,', style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                                const SizedBox(height: 4),
                                Text('${userName.toUpperCase()}!', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
                                const SizedBox(height: 10),
          
                                //  UPDATED DATE
                                Text(_getCurrentDate(), style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          
                                const SizedBox(height: 15),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Icons.local_fire_department, color: Colors.orange, size: 18),
                                    const SizedBox(width: 4),
                                    Text('$streak Day Streak', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ]),
                                ),
                                const Spacer(),
                                // Level Bar logic (Same as before)...
                                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('lvl $level', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: currentXp / maxXp, minHeight: 12, backgroundColor: Colors.grey.shade300, valueColor: const AlwaysStoppedAnimation(Color(0xFF4CAF50)))),
                                  const SizedBox(height: 6),
                                  Text('$currentXp/$maxXp', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ])
                              ]),
                            ),
                            Positioned(right: -70, bottom: 0, child: Image.asset('assets/images/home_kid_with_mic.png', height: size.height * 0.28)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      const Text('Category', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 15),
          
                      // --- GRID (Same as before) ---
                      Row(
                        children: [
                          Expanded(child: GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PracticeSessionList(classId: classId ?? ''))),
                            child: Container(
                                height: 240,
                                decoration: BoxDecoration(
                                    color: const Color(0xFFFBF4D4),
                                    borderRadius: BorderRadius.circular(28)
                                ),
                                child: Stack(
                                    children: [
                                      // Positioned(
                                      //     top: 15,
                                      //     right: 15,
                                      //     child: Container(
                                      //         padding: const EdgeInsets.symmetric(
                                      //             horizontal: 12,
                                      //             vertical: 6
                                      //         ),
                                      //         decoration: BoxDecoration(
                                      //             color: const Color(0xFFFFFFFF),
                                      //             borderRadius: BorderRadius.circular(20)
                                      //         ),
                                      //         child: const Text(
                                      //             'NEW', style: TextStyle(
                                      //             fontSize: 11,
                                      //             fontWeight: FontWeight.bold,
                                      //             color: Colors.red))
                                      //     )),
                                      Center(
                                          child: Image.asset('assets/images/homework_pending.png',
                                              height: 120
                                          )),
                                      const Positioned(
                                          bottom: 20,
                                          left: 20,
                                          child: Text(
                                              'Homeworks\nPending\n',
                                              style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  height: 1.1
                                              )))
                                    ])),
                          )),
                          const SizedBox(width: 16),
                          Expanded(child: Column(children: [
                            GestureDetector(
                              onTap: () => _navigateToWordPractice(context, user.uid), // 👈 Calls the new function
                              child: Container(
                                height: 112,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3E5F5), // Light Cream
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Row(
                                  children: [
                                    Image.asset('assets/images/mic_floating.png', height: 50),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Word', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.0)),
                                          Text('Practice', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.0)),
                                          Text('Pending', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.0)),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
          
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentDashboardScreen())),
                              child: Container(
                                  height: 112,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFE1F5FE),
                                      borderRadius: BorderRadius.circular(24)),
                                  child: Row(
                                      children: [
                                        const Expanded(child:
                                        Text('Detailed\nAnalysis',
                                            style: TextStyle(fontWeight: FontWeight.bold,
                                                height: 1.1))),
                                        Image.asset('assets/images/detailed_analysis.png',
                                            height: 50)])),
                            ),
                          ])),
                        ],
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}