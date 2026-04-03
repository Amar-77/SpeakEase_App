import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/assignment_service.dart';

class CreateAssignmentScreen extends StatefulWidget {
  final DocumentSnapshot? assignmentToEdit;

  const CreateAssignmentScreen({super.key, this.assignmentToEdit});

  @override
  State<CreateAssignmentScreen> createState() =>
      _CreateAssignmentScreenState();
}

class _CreateAssignmentScreenState extends State<CreateAssignmentScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  String _selectedDifficulty = 'Easy';
  String _selectedCategory = 'Story';

  bool _isLoading = false;
  bool _isEditing = false;
  String? _teacherClassId;

  final AssignmentService _assignmentService = AssignmentService();

  @override
  void initState() {
    super.initState();
    _fetchTeacherDetails();

    if (widget.assignmentToEdit != null) {
      _isEditing = true;
      var data = widget.assignmentToEdit!.data() as Map<String, dynamic>;

      _titleController.text = data['title'];
      _contentController.text = data['content'];
      _selectedDifficulty = data['difficulty'];
      _selectedCategory = data['category'] ?? 'Story';
    }
  }

  Future<void> _fetchTeacherDetails() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        var data = doc.data() as Map<String, dynamic>;
        setState(() {
          _teacherClassId = data['class_id'] ?? 'class_6A';
        });
      }
    }
  }

  void _submitAssignment() async {
    if (_titleController.text.isEmpty ||
        _contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() => _isLoading = true);
    String? error;

    if (_isEditing) {
      error = await _assignmentService.updateAssignment(
        docId: widget.assignmentToEdit!.id,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        difficulty: _selectedDifficulty,
        category: _selectedCategory,
      );
    } else {
      if (_teacherClassId == null) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Error: Class ID not found")));
        return;
      }

      error = await _assignmentService.createAssignment(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        classId: _teacherClassId!,
        difficulty: _selectedDifficulty,
        category: _selectedCategory,
      );
    }

    setState(() => _isLoading = false);

    if (error == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_isEditing
                  ? "Updated Successfully! ✅"
                  : "Posted Successfully! 🚀")),
        );
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String appBarTitle =
        _isEditing ? "Edit Assignment" : "Create Assignment";
    String buttonText =
        _isEditing ? "Update Assignment" : "Create Assignment";

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      /// ✅ CLEAN APP BAR
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          appBarTitle,
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),

      /// ✅ BODY
      // ONLY UI IMPROVEMENTS APPLIED

body: SafeArea(
  child: LayoutBuilder(
    builder: (context, constraints) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight,
          ),
          child: IntrinsicHeight(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                  )
                ],
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const Text("Task Details",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  const Text("Customize the content and reward.",
                      style: TextStyle(color: Colors.grey)),

                  const SizedBox(height: 20),

                  /// TITLE
                  const Text("TITLE",
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),

                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: "e.g. Daily Reading",
                      filled: true,
                      fillColor: const Color(0xFFF3F3F3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  /// CATEGORY
                  const Text("CATEGORY",
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),

                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF3F3F3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Story', child: Text("📖 Story")),
                      DropdownMenuItem(value: 'Tongue Twister', child: Text("🙌 Tongue Twister")),
                      DropdownMenuItem(value: 'Daily Phrase', child: Text("💬 Daily Phrase")),
                      DropdownMenuItem(value: 'Vowel Practice', child: Text("🗣️ Vowel Practice")),
                    ],
                    onChanged: (val) =>
                        setState(() => _selectedCategory = val!),
                  ),

                  const SizedBox(height: 15),

                  /// DIFFICULTY
                  const Text("DIFFICULTY",
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 10),

                  DropdownButtonFormField<String>(
                    value: _selectedDifficulty,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF3F3F3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Easy', child: Text("Easy")),
                      DropdownMenuItem(value: 'Medium', child: Text("Medium")),
                      DropdownMenuItem(value: 'Hard', child: Text("Hard")),
                    ],
                    onChanged: (val) =>
                        setState(() => _selectedDifficulty = val!),
                  ),

                  const SizedBox(height: 15),

                  /// CONTENT (UPDATED 🔥)
                  const Text("CONTENT",
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),

                  TextField(
                    controller: _contentController,
                    keyboardType: TextInputType.multiline,
                    minLines: 6,      // ✅ bigger initial box
                    maxLines: null,   // ✅ expands dynamically
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF3F3F3),
                      contentPadding: const EdgeInsets.all(16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  /// BUTTON
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _submitAssignment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                            ),
                            child: Text(
                              buttonText,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  ),
),
    );
  }

  /// 🎯 CHIP (UI ONLY)
  Widget _buildChip(String label, String coins, Color color) {
    bool isSelected = _selectedDifficulty == label;

    return GestureDetector(
      onTap: () => setState(() => _selectedDifficulty = label),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          "$label - $coins",
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}