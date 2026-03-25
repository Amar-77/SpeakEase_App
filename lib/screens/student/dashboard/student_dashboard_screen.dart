import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';

// Adjust these paths to match your actual project structure
import '../chat/speaky_screen.dart';
import '../home/achievements_screen.dart';
import 'word_practice_screen.dart'; // 👈 Added import for navigation

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  // Week offset: 0 = this week, 1 = last week, etc.
  int _weekOffset = 0;

  // Slide-to-summarize state
  bool _summaryUnlocked = false;
  double _sliderValue = 0.0;

  // Cache loaded data
  Map<String, int> _weeklyData = {};
  Map<String, double> _metrics = {};
  int _totalCoins = 0;
  List<String> _mistakeWords = [];
  bool _loadingStats = false;

  late String _uid;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser!.uid;
    _loadAllData();
  }

  // ─── DATE HELPERS ────────────────────────────────────────────────────────────

  DateTime get _endDate =>
      DateTime.now().subtract(Duration(days: _weekOffset * 7));

  DateTime get _startDate => _endDate.subtract(const Duration(days: 6));

  String get _weekLabel {
    if (_weekOffset == 0) return "This week";
    return "${DateFormat('MMM d').format(_startDate)} - ${DateFormat('MMM d').format(_endDate)}";
  }

  // ─── DATA LOADING ─────────────────────────────────────────────────────────────

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _loadingStats = true);
    await Future.wait([
      _loadWeeklyChart(),
      _loadMetrics(),
      _loadCoins(),
      _loadMistakeWords(),
    ]);
    if (mounted) setState(() => _loadingStats = false);
  }

  Future<void> _loadWeeklyChart() async {
    List<DateTime> days =
    List.generate(7, (i) => _startDate.add(Duration(days: i)));
    List<String> dateKeys =
    days.map((d) => "${d.year}-${d.month}-${d.day}").toList();

    Map<String, int> map = {
      "Mon": 0, "Tue": 0, "Wed": 0, "Thu": 0,
      "Fri": 0, "Sat": 0, "Sun": 0,
    };

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('daily_stats')
          .where(FieldPath.documentId, whereIn: dateKeys)
          .get();

      for (var doc in snap.docs) {
        var data = doc.data();
        String dateStr = data['date'] ?? doc.id;
        num raw = data['minutes_spent'] ?? 0;
        List<String> parts = dateStr.split('-');
        DateTime date = DateTime(
            int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        String dayName = DateFormat('E').format(date);
        map[dayName] = raw.round();
      }
    } catch (e) {
      debugPrint("Chart error: $e");
    }
    _weeklyData = map;
  }

  Future<void> _loadMetrics() async {
    final Timestamp start = Timestamp.fromDate(_startDate);
    final Timestamp end =
    Timestamp.fromDate(_endDate.add(const Duration(days: 1)));

    try {
      final snap = await FirebaseFirestore.instance
          .collection('submissions')
          .where('student_id', isEqualTo: _uid)
          .where('submitted_at', isGreaterThanOrEqualTo: start)
          .where('submitted_at', isLessThanOrEqualTo: end)
          .get();

      if (snap.docs.isEmpty) {
        _metrics = {};
        return;
      }

      double acc = 0, flu = 0, clar = 0, pron = 0, wpm = 0;
      for (var doc in snap.docs) {
        var d = doc.data();
        acc += (d['accuracy_score'] ?? 0).toDouble();
        flu += (d['fluency_score'] ?? 0).toDouble();
        clar += (d['clarity_score'] ?? 0).toDouble();
        pron += (d['pronunciation_score'] ?? 0).toDouble();
        wpm += (d['wpm'] ?? 0).toDouble();
      }
      int c = snap.docs.length;
      _metrics = {
        'accuracy': acc / c,
        'fluency': flu / c,
        'clarity': clar / c,
        'pronunciation': pron / c,
        'wpm': wpm / c,
      };
    } catch (e) {
      debugPrint("Metrics error: $e");
    }
  }

  Future<void> _loadCoins() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('daily_stats')
          .get();
      int total = 0;
      for (var doc in snap.docs) {
        total += (doc.data()['coins_earned'] as int? ?? 0);
      }
      _totalCoins = total;
    } catch (e) {
      debugPrint("Coins error: $e");
    }
  }

  Future<void> _loadMistakeWords() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();
      var data = doc.data();
      _mistakeWords = List<String>.from(data?['mistake_words'] ?? []);
    } catch (e) {
      debugPrint("Words error: $e");
    }
  }

  void _changeWeek(int delta) {
    int newOffset = _weekOffset + delta;
    if (newOffset < 0) return;
    setState(() {
      _weekOffset = newOffset;
      _summaryUnlocked = false;
      _sliderValue = 0.0;
    });
    _loadAllData();
  }

  // ─── NAVIGATION ──────────────────────────────────────────────────────────────

  void _navigateToWordPractice() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WordPracticeScreen(
          mistakeWords: _mistakeWords,
          studentId: _uid,
        ),
      ),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    String firstName = user.displayName?.split(' ')[0] ?? "Student";

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              _buildHeader(firstName),
              const SizedBox(height: 20),

              // ── Week Navigator + Bar Chart ──
              _buildWeekNav(),
              const SizedBox(height: 12),
              _buildBarChart(),
              const SizedBox(height: 24),

              // ── Speaky Slide Card ──
              _summaryUnlocked ? _buildUnlockedSummary() : _buildSpeakySlideCard(),
              const SizedBox(height: 24),

              // ── SpeechCoins ──
              _buildCoinBanner(),
              const SizedBox(height: 16),

              // ── Achievements Navigation ──
              _buildAchievementsBanner(context),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ─── HEADER ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(String name) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            // 🔙 Custom Back Button
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(right: 16),
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

            // Titles
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Your Dashboard",
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black)),
                const SizedBox(height: 2),
                Text(_weekLabel,
                    style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ─── WEEK NAV ─────────────────────────────────────────────────────────────────

  Widget _buildWeekNav() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        GestureDetector(
          onTap: () => _changeWeek(1),
          child: const Icon(Icons.chevron_left, size: 20, color: Colors.grey),
        ),
        const SizedBox(width: 6),
        Text(
          "${DateFormat('MMM d').format(_startDate)} - ${DateFormat('MMM d').format(_endDate)}",
          style: const TextStyle(
              fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: _weekOffset == 0 ? null : () => _changeWeek(-1),
          child: Icon(Icons.chevron_right,
              size: 20,
              color: _weekOffset == 0 ? Colors.grey.shade300 : Colors.grey),
        ),
      ],
    );
  }

  // ─── BAR CHART ───────────────────────────────────────────────────────────────

  Widget _buildBarChart() {
    final days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    final int maxVal = _weeklyData.values.fold(1, (m, v) => v > m ? v : m);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: _loadingStats
          ? const SizedBox(
        height: 140,
        child: Center(child: CircularProgressIndicator()),
      )
          : SizedBox(
        height: 160,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final barWidth = constraints.maxWidth / 9;

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: days.map((day) {
                int val = _weeklyData[day] ?? 0;
                double frac = maxVal == 0 ? 0 : val / maxVal;

                // Match colors exactly to the reference image
                bool isWeekend = day == "Sat" || day == "Sun";
                Color activeColor = isWeekend
                    ? const Color(0xFFFF8B8B) // Soft salmon red
                    : const Color(0xFF918CFF); // Soft periwinkle purple

                double barHeight = 0;
                if (frac > 0) {
                  barHeight = 110.0 * frac;
                  if (barHeight < barWidth) {
                    barHeight = barWidth;
                  }
                }

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // 🟣 BAR BACKGROUND
                      Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          // background capsule
                          Container(
                            width: barWidth,
                            height: 110,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEEEEE), // Softer background grey
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),

                          // animated fill
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOut,
                            width: barWidth,
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: activeColor,
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // day label
                      Text(
                        day,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF8A8A8A), // Softer grey
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }

  // ─── SPEAKY SLIDE CARD ───────────────────────────────────────────────────────

  Widget _buildSpeakySlideCard() {
    const double cardHeight = 450;
    const double avatarBreakout = 60;
    const double avatarHeight = 360;

    return SizedBox(
      height: cardHeight + avatarBreakout,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. 🟡 The Yellow Background Card
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            top: avatarBreakout,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              decoration: BoxDecoration(
                color: const Color(0xFFF6BC57),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF6BC57).withOpacity(0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text("Meet Speaky!",
                      style: TextStyle(
                          color: Colors.black87,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text(
                      "Our personal assistant, she will help you\nsummarize your usage data",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Color(0xAA000000),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.3)),
                  const SizedBox(height: 24),
                  // The slide button
                  _buildSlider(),
                ],
              ),
            ),
          ),

          // 2. 🤖 Speaky Avatar
          Positioned(
            top: 0,
            right: 0,
            left: 0,
            child: Center(
              child: Image.asset(
                'assets/images/speaky_analysing.png',
                height: avatarHeight,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider() {
    return LayoutBuilder(builder: (context, constraints) {
      double trackWidth = constraints.maxWidth;
      double thumbSize = 56.0;
      double maxSlide = trackWidth - thumbSize;

      return GestureDetector(
        onHorizontalDragUpdate: (details) {
          setState(() {
            _sliderValue =
                (_sliderValue + details.delta.dx / maxSlide).clamp(0.0, 1.0);
          });
          if (_sliderValue >= 0.85) {
            setState(() {
              _summaryUnlocked = true;
              _sliderValue = 1.0;
            });
          }
        },
        onHorizontalDragEnd: (_) {
          if (_sliderValue < 0.85) {
            setState(() => _sliderValue = 0.0);
          }
        },
        child: Container(
          height: 56,
          width: trackWidth,
          decoration: BoxDecoration(
            color: const Color(0xFF333333),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  "Slide to summarize",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ),
              Positioned(
                left: _sliderValue * maxSlide,
                top: 0,
                bottom: 0,
                child: Container(
                  width: thumbSize,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300, width: 0.5),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/icons/ai_icon.svg',
                      width: 24,
                      height: 24,
                      colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ─── UNLOCKED SUMMARY ────────────────────────────────────────────────────────

  Widget _buildUnlockedSummary() {
    if (_loadingStats) {
      return const Center(child: CircularProgressIndicator());
    }

    double fluency = _metrics['fluency'] ?? 0;
    double pronunciation = _metrics['pronunciation'] ?? 0;
    double clarity = _metrics['clarity'] ?? 0;
    double accuracy = _metrics['accuracy'] ?? 0;
    double wpm = _metrics['wpm'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildBigRing(
                  "Overall\nProgress", accuracy, const Color(0xFFFFC107)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  _buildSmallRing(
                      "Overall\nFluency", fluency, const Color(0xFF7B72F0)),
                  const SizedBox(height: 12),
                  _buildSmallRing("Overall\nPronunciation", pronunciation,
                      const Color(0xFF7B72F0)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _buildSmallRing(
                    "Overall\nclarity", clarity, const Color(0xFFFF8B8B))),
            const SizedBox(width: 12),
            Expanded(child: _buildWpmCard(wpm)),
          ],
        ),
        const SizedBox(height: 12),
        _buildMasteryHub(),
        const SizedBox(height: 6),
        Center(
          child: TextButton.icon(
            onPressed: () => setState(() {
              _summaryUnlocked = false;
              _sliderValue = 0.0;
            }),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text("Hide Summary"),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildBigRing(String label, double value, Color color) {
    double pct = value.clamp(0, 100);
    return Container(
      height: 194, // Perfect height to align with the right-side cards
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 110, // Larger overall diameter
            height: 110,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Clean, flat progress ring (No overlapping shadow masks)
                SizedBox(
                  width: 110,
                  height: 110,
                  child: CircularProgressIndicator(
                    value: pct / 100,
                    strokeWidth: 14, // Thick and chunky
                    backgroundColor: const Color(0xFFEEEEEE), // Crisp, light grey track
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                // Styled Dual-Size Text (Big Number, Small %)
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: "${pct.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontSize: 32, // Large number
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const TextSpan(
                        text: "%",
                        style: TextStyle(
                          fontSize: 16, // Smaller percentage sign
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  height: 1.2)),
        ],
      ),
    );
  }

  Widget _buildSmallRing(String label, double value, Color color) {
    double pct = value.clamp(0, 100);
    return Container(
      height: 86,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: CircularProgressIndicator(
                    value: pct / 100,
                    strokeWidth: 7, // Thicker small ring
                    backgroundColor: const Color(0xFFEEEEEE),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                // Dual-Size Text for small ring
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: "${pct.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const TextSpan(
                        text: "%",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    height: 1.2)),
          ),
        ],
      ),
    );
  }

  Widget _buildWpmCard(double wpm) {
    return Container(
      height: 87,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF7B72F0),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF7B72F0).withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(wpm.toStringAsFixed(0),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              const Text("WPM",
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const Spacer(),
          const Text("Reading Speed",
              style: TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildMasteryHub() {
    return GestureDetector(
      // 👈 Updated onTap implementation here
      onTap: _mistakeWords.isEmpty
          ? null
          : () => _navigateToWordPractice(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [Colors.orange.shade400, Colors.red.shade400]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.orange.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.psychology, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Mastery Hub",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  Text(
                      _mistakeWords.isEmpty
                          ? "You've mastered everything! 🎉"
                          : "${_mistakeWords.length} words need your attention",
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  // ─── COIN BANNER ─────────────────────────────────────────────────────────────

  Widget _buildCoinBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.monetization_on, color: Colors.amber, size: 28),
          const SizedBox(width: 12),
          const Text("Total SpeechCoins: ",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          Text("$_totalCoins",
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange)),
        ],
      ),
    );
  }

  // ─── ACHIEVEMENTS BANNER ─────────────────────────────────────────────────────

  Widget _buildAchievementsBanner(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AchievementsScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.emoji_events,
                color: Colors.amber,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "View Achievements",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Check your unlocked badges and goals!",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey.shade400,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}