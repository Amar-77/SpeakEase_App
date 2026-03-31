import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 👈 REQUIRED FOR HAPTICS
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Adjust these paths to match your actual project structure
import 'package:speakease/screens/student/home/widgets/student_app_bar.dart';
import '../../../services/gamification_service.dart';
import '../chat/speaky_screen.dart' show SpeakyChatScreen;
import '../dashboard/word_practice_screen.dart';
import '../practice/practice_list_screen.dart';
import '../dashboard/student_dashboard_screen.dart';
import 'leaderboard_screen.dart';
import 'notification_screen.dart';

class StudentHome extends StatefulWidget {
  const StudentHome({super.key});

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  final PageController _pageController = PageController();
  final GamificationService _gamificationService = GamificationService();

  /// 0 = Home dashboard, 1 = Leaderboard
  int _currentIndex = 0;
  String? _classId;

  @override
  void initState() {
    super.initState();
    _fetchUserClass();
    _runStartupChecks();
  }

  void _runStartupChecks() async {
    await _gamificationService.checkStreakOnStartup();
  }

  void _fetchUserClass() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (mounted) {
        setState(() {
          _classId = doc.data()?['class_id'];
        });
      }
    }
  }

  void _onItemTapped(int index) {
    // 📳 Trigger haptic feedback when a nav icon is tapped
    HapticFeedback.lightImpact();

    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Opens Speaky as a full-screen page (not part of the PageView tabs)
  void _openSpeaky() {
    // 📳 Trigger haptic feedback for the chatbot button
    HapticFeedback.lightImpact();

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SpeakyChatScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── PageView: only 2 pages now ──────────────────────────────────
          PageView(
            controller: _pageController,
            // ✨ Removed the NeverScrollableScrollPhysics so you can swipe again!
            onPageChanged: (index) => setState(() => _currentIndex = index),
            children: [
              // PAGE 0 – Dashboard
              const _DashboardContent(),

              // PAGE 1 – Leaderboard
              LeaderboardScreen(classId: _classId ?? 'loading'),
            ],
          ),

          // ── Floating Bottom Navigation ──────────────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 30, left: 30, right: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── LEFT PILL (Home + Leaderboard) ─────────────────────
                  Container(
                    height: 70,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF222222),
                      borderRadius: BorderRadius.circular(35),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildNavItem('assets/icons/home_icon.svg', 0),
                        const SizedBox(width: 4),
                        _buildNavItem('assets/icons/leaderboard_icon.svg', 1),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  // ── RIGHT ISLAND (Speaky – separate circle) ────────────
                  GestureDetector(
                    onTap: _openSpeaky,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: const Color(0xFF222222),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      // 🤖 Updated to use the custom SVG chatbot icon
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/icons/chatbot_icon.svg', // Ensure path matches your project
                          width: 28,
                          height: 28,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(String svgPath, int index) {
    final bool isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 70,
        height: 54,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Center(
          child: SvgPicture.asset(
            svgPath,
            width: 26,
            height: 26,
            colorFilter: ColorFilter.mode(
              isActive ? Colors.black : Colors.white54,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// DASHBOARD CONTENT
// =============================================================================
class _DashboardContent extends StatelessWidget {
  const _DashboardContent();

  String _getCurrentDate() {
    final now = DateTime.now();
    String day = DateFormat('d').format(now);
    String suffix = 'th';
    if (day.endsWith('1') && day != '11') suffix = 'st';
    else if (day.endsWith('2') && day != '12') suffix = 'nd';
    else if (day.endsWith('3') && day != '13') suffix = 'rd';
    return "$day$suffix ${DateFormat('MMMM y').format(now)}";
  }

  Future<void> _handleNotificationClick(
      BuildContext context, String uid, String? classId) async {
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => NotificationScreen(classId: classId)),
      );
    }
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'last_notification_check': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _navigateToWordPractice(
      BuildContext context, String uid) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (context.mounted) {
        Navigator.pop(context);
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          final fetchedWords =
          List<String>.from(data['mistake_words'] ?? []);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WordPracticeScreen(
                mistakeWords: fetchedWords,
                studentId: uid,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final user = FirebaseAuth.instance.currentUser!;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final userData = snap.data!.data() as Map<String, dynamic>;
        final String? classId = userData['class_id'];
        final String userName = userData['name'] ?? 'Student';
        final int level = userData['level'] ?? 1;
        final int currentXp = userData['current_xp'] ?? 0;
        final int maxXp = userData['max_xp'] ?? 1200;
        final int streak = userData['current_streak'] ?? 0;
        // final int coins = userData['coins'] ?? 0; // Unused variable commented out

        return SafeArea(
          child: SingleChildScrollView(
            // Keeps vertical scrolling active so layout doesn't break on small devices
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── App Bar ─────────────────────────────────────────────
                const StudentAppBar(),

                const SizedBox(height: 10),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── HERO CARD ──────────────────────────────────────
                      Container(
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
                            // ── Text column ──────────────────────────────
                            Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 🔤 WELCOME TEXT
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

                                  // 👤 USER NAME
                                  Text(
                                    '${userName.toUpperCase()}!',
                                    style: const TextStyle(
                                      fontSize: 35,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black,
                                      height: 1,
                                    ),
                                  ),

                                  const SizedBox(height: 6),

                                  // 📅 DATE
                                  Text(
                                    _getCurrentDate(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  // 🔥 STREAK
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.local_fire_department,
                                        color: Colors.orange,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$streak Day Streak',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const Spacer(),

                                  // 📊 LEVEL + PROGRESS
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'lvl $level',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black,
                                        ),
                                      ),

                                      const SizedBox(height: 6),

                                      // 🟩 PROGRESS BAR
                                      SizedBox(
                                        width: 160,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: LinearProgressIndicator(
                                            value: maxXp == 0 ? 0 : currentXp / maxXp,
                                            minHeight: 8,
                                            backgroundColor: Colors.black12,
                                            valueColor: const AlwaysStoppedAnimation(
                                              Color(0xFF01C85A),
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 6),

                                      Text(
                                        '$currentXp/$maxXp',
                                        style: GoogleFonts.poppins(
                                          fontSize: 20,
                                          color: Colors.black54,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // ── 3-D character ──
                            Positioned(
                              height: 350,
                              right: -140,
                              bottom: 0,
                              child: Image.asset(
                                'assets/images/home_kid_with_mic.png',
                                height: size.height * 0.30,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── CATEGORY HEADING ────────────────────────────────
                      const Text(
                        'Category',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ── CATEGORY GRID ────────────────────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // LEFT – Homeworks Pending
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PracticeSessionList(
                                      classId: classId ?? ''),
                                ),
                              ),
                              child: Container(
                                height: 304,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFBF4D4),
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: Stack(
                                  children: [
                                    Center(
                                      child: Transform.translate(
                                        offset: const Offset(0, -50),
                                        child: Image.asset(
                                          'assets/images/homework_pending.png',
                                          height: 220,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    const Positioned(
                                      bottom: 40,
                                      left: 16,
                                      child: Text(
                                        'Homeworks\nPending',
                                        style: TextStyle(
                                          fontSize: 25,
                                          fontWeight: FontWeight.bold,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 14),

                          // RIGHT – two stacked cards
                          Expanded(
                            child: Column(
                              children: [
                                // ── Word Practice ──────────────────────────
                                GestureDetector(
                                  onTap: () => _navigateToWordPractice(context, user.uid),
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
                                          top: -80,
                                          left: 0,
                                          right: 0,
                                          child: Center(
                                            child: Image.asset(
                                              'assets/images/mic_floating.png',
                                              height: 200,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        const Positioned(
                                          bottom: 16,
                                          left: 16,
                                          right: 16,
                                          child: Text(
                                            'New Practice\nSessions',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                              height: 1.2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 14),

                                // ── Detailed Analysis ──────────────────────
                                GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const StudentDashboardScreen(),
                                    ),
                                  ),
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
                                          right: -10,
                                          child: Image.asset(
                                            'assets/images/detailed_analysis.png',
                                            height: 110,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        const Positioned(
                                          top: 16,
                                          left: 16,
                                          child: Text(
                                            'Detailed\nAnalysis',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                              height: 1.2,
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}