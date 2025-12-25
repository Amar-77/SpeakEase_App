import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/assignment_service.dart';

class CreateAssignmentScreen extends StatefulWidget {
  // If this is passed, we are in "Edit Mode"
  final DocumentSnapshot? assignmentToEdit;

  const CreateAssignmentScreen({super.key, this.assignmentToEdit});

  @override
  State<CreateAssignmentScreen> createState() => _CreateAssignmentScreenState();
}

class _CreateAssignmentScreenState extends State<CreateAssignmentScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  // Default selections
  String _selectedDifficulty = 'Easy';
  String _selectedCategory = 'Story';

  bool _isLoading = false;
  bool _isEditing = false; // Flag to track mode
  String? _teacherClassId;
  final AssignmentService _assignmentService = AssignmentService();

  @override
  void initState() {
    super.initState();
    _fetchTeacherDetails();

    // CHECK: Are we editing?
    if (widget.assignmentToEdit != null) {
      _isEditing = true;
      var data = widget.assignmentToEdit!.data() as Map<String, dynamic>;

      // Pre-fill the form with existing data
      _titleController.text = data['title'];
      _contentController.text = data['content'];
      _selectedDifficulty = data['difficulty'];
      // Handle case where old assignments might not have a category
      _selectedCategory = data['category'] ?? 'Story';
    }
  }

  Future<void> _fetchTeacherDetails() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        if (mounted) {
          setState(() {
            var data = doc.data() as Map<String, dynamic>;
            _teacherClassId = data['class_id'] ?? 'class_6A';
          });
        }
      }
    }
  }

  void _submitAssignment() async {
    // 1. Validation
    if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() => _isLoading = true);
    String? error;

    if (_isEditing) {
      // --- UPDATE EXISTING ---
      error = await _assignmentService.updateAssignment(
        docId: widget.assignmentToEdit!.id, // The ID of the doc we are editing
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        difficulty: _selectedDifficulty,
        category: _selectedCategory,
      );
    } else {
      // --- CREATE NEW ---
      if (_teacherClassId == null) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Class ID not found")));
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

    // 2. Success/Error Handling
    if (error == null) {
      if (mounted) {
        String message = _isEditing ? "Updated Successfully! ✅" : "Posted Successfully! 🚀";
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        Navigator.pop(context); // Go back to Dashboard/History
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Change Title based on mode
    String appBarTitle = _isEditing ? "Edit Assignment" : "New Assignment";
    String buttonText = _isEditing ? "Update Assignment" : "Post Assignment";

    return Scaffold(
      appBar: AppBar(title: Text(appBarTitle), backgroundColor: Colors.teal),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("Task Details", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Text("Customize the content and reward.", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),

              // Title
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: "Title (e.g. Daily Reading)", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),

              // Category Dropdown
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: "Category", border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Story', child: Text("Story 📖")),
                  DropdownMenuItem(value: 'Tongue Twister', child: Text("Tongue Twister 👅")),
                  DropdownMenuItem(value: 'Daily Phrase', child: Text("Daily Phrase 💬")),
                  DropdownMenuItem(value: 'Vowel Practice', child: Text("Vowel Practice 🗣️")),
                ],
                onChanged: (val) => setState(() => _selectedCategory = val!),
              ),
              const SizedBox(height: 15),

              // Difficulty Dropdown
              DropdownButtonFormField<String>(
                value: _selectedDifficulty,
                decoration: const InputDecoration(labelText: "Difficulty Level", border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Easy', child: Text("Easy (3 Coins)")),
                  DropdownMenuItem(value: 'Medium', child: Text("Medium (5 Coins)")),
                  DropdownMenuItem(value: 'Hard', child: Text("Hard (10 Coins)")),
                ],
                onChanged: (val) => setState(() => _selectedDifficulty = val!),
              ),
              const SizedBox(height: 15),

              // Content
              TextField(
                controller: _contentController,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: "Content",
                  hintText: "Type the full text here...",
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 30),

              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                onPressed: _submitAssignment,
                icon: Icon(_isEditing ? Icons.save : Icons.send),
                label: Text(buttonText),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}