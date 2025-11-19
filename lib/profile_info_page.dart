import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'calorie_tracker_provider.dart';

class ProfileInfoPage extends StatefulWidget {
  const ProfileInfoPage({super.key});

  @override
  State<ProfileInfoPage> createState() => _ProfileInfoPageState();
}

class _ProfileInfoPageState extends State<ProfileInfoPage> {
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _goalCtrl = TextEditingController();

  String _gender = 'Male';
  String _activityLevel = 'Moderate';
  bool _saving = false;
  bool _isLoading = true;
  int _calculatedCalories = 0;

  final List<String> genders = ['Male', 'Female'];
  final List<String> activityLevels = ['Sedentary', 'Light', 'Moderate', 'Very Active', 'Extremely Active'];
  final Map<String, double> activityMultipliers = {
    'Sedentary': 1.2,
    'Light': 1.375,
    'Moderate': 1.55,
    'Very Active': 1.725,
    'Extremely Active': 1.9,
  };

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser!;
    _nameCtrl.text = user.displayName ?? '';
    
    // Load profile data without blocking UI
    _loadProfileDataOptimized();
  }

  Future<void> _loadProfileDataOptimized() async {
    final user = FirebaseAuth.instance.currentUser!;
    bool loaded = false;

    // Race between cache and server with 500ms timeout
    try {
      final cacheDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(GetOptions(source: Source.cache));

      final serverDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(milliseconds: 500));

      // Complete with whichever finishes first
      final doc = await Future.any([cacheDoc, serverDoc]).catchError((_) => cacheDoc);

      if (mounted && doc.exists && !loaded) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _ageCtrl.text = data['age']?.toString() ?? '';
          _heightCtrl.text = data['height']?.toString() ?? '';
          _weightCtrl.text = data['weight']?.toString() ?? '';
          _goalCtrl.text = data['goal']?.toString() ?? '';
          _gender = data['gender'] ?? 'Male';
          _activityLevel = data['activityLevel'] ?? 'Moderate';
          _calculatedCalories = data['dailyCalories'] ?? 0;
          _isLoading = false;
        });
        loaded = true;
      }
    } catch (e) {
      print('Error loading profile: $e');
    } finally {
      if (mounted && !loaded) setState(() => _isLoading = false);
    }
  }

  /// Calculate BMR using Mifflin-St Jeor equation
  int _calculateBMR(int age, int height, int weight, String gender) {
    double bmr;
    if (gender == 'Male') {
      bmr = 10 * weight + 6.25 * height - 5 * age + 5;
    } else {
      bmr = 10 * weight + 6.25 * height - 5 * age - 161;
    }
    return bmr.toInt();
  }

  /// Calculate daily calorie needs
  void _calculateCalories() {
    if (_ageCtrl.text.isEmpty ||
        _heightCtrl.text.isEmpty ||
        _weightCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill age, height, and weight'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      final age = int.parse(_ageCtrl.text);
      final height = int.parse(_heightCtrl.text);
      final weight = int.parse(_weightCtrl.text);

      if (age < 13 || age > 120 || height < 100 || height > 250 || weight < 20 || weight > 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter valid values'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      final bmr = _calculateBMR(age, height, weight, _gender);
      final multiplier = activityMultipliers[_activityLevel] ?? 1.55;
      final tdee = (bmr * multiplier).toInt();

      setState(() => _calculatedCalories = tdee);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Daily calorie need: $tdee kcal'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _save() async {
    if (_ageCtrl.text.isEmpty ||
        _heightCtrl.text.isEmpty ||
        _weightCtrl.text.isEmpty ||
        _goalCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_calculatedCalories == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please calculate calories first!'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser!;
    setState(() => _saving = true);

    try {
      // Update Provider IMMEDIATELY (no waiting)
      final provider = Provider.of<CalorieTrackerProvider>(context, listen: false);
      provider.setCalorieGoal(_calculatedCalories);

      // Update Firebase Auth display name (fast operation)
      await user.updateDisplayName(_nameCtrl.text.trim());

      // Save to Firestore in background (don't wait)
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'displayName': _nameCtrl.text.trim(),
        'email': user.email,
        'age': int.parse(_ageCtrl.text),
        'height': int.parse(_heightCtrl.text),
        'weight': int.parse(_weightCtrl.text),
        'goal': _goalCtrl.text.trim(),
        'gender': _gender,
        'activityLevel': _activityLevel,
        'dailyCalories': _calculatedCalories,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true))
          .then((_) {
        // Success in background - no need to notify
        print('Profile saved to Firestore');
      })
          .catchError((e) {
        print('Firestore save error: $e');
      });

      // Show success immediately
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Profile saved! Goal: $_calculatedCalories kcal'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Navigate back after brief delay
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() => _saving = false);
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _goalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Profile'),
        elevation: 0,
        backgroundColor: Colors.blue.shade700,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade700,
              Colors.blue.shade50,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _isLoading
              ? _buildSkeletonLoader()
              : Column(
                  children: [
              // Profile Header
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    (user.displayName?.isNotEmpty ?? false)
                        ? user.displayName![0].toUpperCase()
                        : user.email?.substring(0, 1).toUpperCase() ?? '?',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                user.email ?? '',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 32),

              // Card: Basic Info
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Basic Information',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _ageCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Age',
                                prefixIcon: const Icon(Icons.cake),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _gender,
                              decoration: InputDecoration(
                                labelText: 'Gender',
                                prefixIcon: const Icon(Icons.wc),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              items: genders.map((g) {
                                return DropdownMenuItem(
                                  value: g,
                                  child: Text(g),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _gender = val);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Card: Physical Metrics
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Physical Metrics',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _heightCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Height (cm)',
                                prefixIcon: const Icon(Icons.height),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _weightCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Weight (kg)',
                                prefixIcon: const Icon(Icons.scale),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Card: Fitness Goals
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fitness Goals & Activity',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _goalCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Your Goal (e.g., Lose weight, Build muscle)',
                          prefixIcon: const Icon(Icons.flag),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _activityLevel,
                        decoration: InputDecoration(
                          labelText: 'Activity Level',
                          prefixIcon: const Icon(Icons.directions_run),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: activityLevels.map((level) {
                          return DropdownMenuItem(
                            value: level,
                            child: Text(level),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _activityLevel = val);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Card: Calculated Calories
              if (_calculatedCalories > 0)
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.local_fire_department,
                          color: Colors.orange.shade600,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Daily Calorie Goal',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              '$_calculatedCalories kcal',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _calculateCalories,
                      icon: const Icon(Icons.calculate),
                      label: const Text('Calculate Calories'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                          : const Icon(Icons.save),
                      label: Text(_saving ? 'Saving...' : 'Save Profile'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Column(
      children: [
        const SizedBox(height: 20),
        // Skeleton avatar
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 16),
        // Skeleton text lines
        _skeletonLine(width: 200, height: 14),
        const SizedBox(height: 12),
        _skeletonLine(width: 150, height: 12),
        const SizedBox(height: 24),
        // Skeleton form fields
        ...[for (int i = 0; i < 6; i++) ...[_skeletonLine(height: 50), const SizedBox(height: 12)]],
        _skeletonLine(height: 48),
      ],
    );
  }

  Widget _skeletonLine({double width = double.infinity, double height = 16}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
