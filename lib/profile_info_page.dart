import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'package:first_project/calorie_tracker_provider.dart'; // ✅ FIXED: use package import

class ProfileInfoPage extends StatefulWidget {
  const ProfileInfoPage({super.key});

  @override
  State<ProfileInfoPage> createState() => _ProfileInfoPageState();
}

class _ProfileInfoPageState extends State<ProfileInfoPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  String _gender = 'Male';
  String _activityLevel = 'Moderate';
  String _goal = 'Maintain';
  bool _saving = false;

  // Calculated values
  int _recommendedCalories = 0;
  int _recommendedProtein = 0;
  int _recommendedCarbs = 0;
  int _recommendedFats = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser!;
    _nameCtrl.text = user.displayName ?? '';

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _ageCtrl.text = data['age']?.toString() ?? '';
          _heightCtrl.text = data['height']?.toString() ?? '';
          _weightCtrl.text = data['weight']?.toString() ?? '';
          _gender = data['gender'] ?? 'Male';
          _activityLevel = data['activityLevel'] ?? 'Moderate';
          _goal = data['goal'] ?? 'Maintain';

          if (_ageCtrl.text.isNotEmpty &&
              _heightCtrl.text.isNotEmpty &&
              _weightCtrl.text.isNotEmpty) {
            _calculateRecommendations();
          }
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  void _calculateRecommendations() {
    final age = int.tryParse(_ageCtrl.text) ?? 0;
    final height = double.tryParse(_heightCtrl.text) ?? 0;
    final weight = double.tryParse(_weightCtrl.text) ?? 0;

    if (age == 0 || height == 0 || weight == 0) return;

    // Calculate BMR using Mifflin-St Jeor Equation
    double bmr;
    if (_gender == 'Male') {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5;
    } else {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) - 161;
    }

    // Activity multiplier
    double activityMultiplier;
    switch (_activityLevel) {
      case 'Sedentary':
        activityMultiplier = 1.2;
        break;
      case 'Light':
        activityMultiplier = 1.375;
        break;
      case 'Moderate':
        activityMultiplier = 1.55;
        break;
      case 'Active':
        activityMultiplier = 1.725;
        break;
      case 'Very Active':
        activityMultiplier = 1.9;
        break;
      default:
        activityMultiplier = 1.55;
    }

    // Calculate TDEE (Total Daily Energy Expenditure)
    double tdee = bmr * activityMultiplier;

    // Adjust for goal
    double targetCalories;
    switch (_goal) {
      case 'Lose Weight':
        targetCalories = tdee - 500; // 500 cal deficit
        break;
      case 'Gain Weight':
        targetCalories = tdee + 500; // 500 cal surplus
        break;
      case 'Maintain':
      default:
        targetCalories = tdee;
    }

    // Calculate macros
    // Protein: 2g per kg body weight
    double proteinGrams = weight * 2;
    int proteinCalories = (proteinGrams * 4).toInt();

    // Fat: 28% of total calories
    int fatCalories = (targetCalories * 0.28).toInt();
    double fatGrams = fatCalories / 9;

    // Carbs: Remaining calories
    int carbCalories = targetCalories.toInt() - proteinCalories - fatCalories;
    double carbGrams = carbCalories / 4;

    setState(() {
      _recommendedCalories = targetCalories.toInt();
      _recommendedProtein = proteinGrams.toInt();
      _recommendedCarbs = carbGrams.toInt();
      _recommendedFats = fatGrams.toInt();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    _calculateRecommendations();

    final user = FirebaseAuth.instance.currentUser!;
    // ✅ Get provider BEFORE any await to avoid use_build_context_synchronously
    final tracker =
        Provider.of<CalorieTrackerProvider>(context, listen: false);

    setState(() => _saving = true);

    try {
      await user.updateDisplayName(_nameCtrl.text.trim());

      final userData = {
        'displayName': _nameCtrl.text.trim(),
        'email': user.email,
        'age': int.parse(_ageCtrl.text),
        'height': double.parse(_heightCtrl.text),
        'weight': double.parse(_weightCtrl.text),
        'gender': _gender,
        'activityLevel': _activityLevel,
        'goal': _goal,
        'recommendedCalories': _recommendedCalories,
        'recommendedProtein': _recommendedProtein,
        'recommendedCarbs': _recommendedCarbs,
        'recommendedFats': _recommendedFats,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userData, SetOptions(merge: true));

      // 🔥 Update CalorieTrackerProvider so HomePage uses these targets
      // Keep current consumed values, just update goals
      final currentProtein = tracker.nutrients['Protein']?['value'] ?? 0;
      final currentCarbs = tracker.nutrients['Carbs']?['value'] ?? 0;
      final currentFats = tracker.nutrients['Fats']?['value'] ?? 0;

      tracker.setCalorieGoal(_recommendedCalories);
      tracker.setNutrient('Protein', currentProtein, _recommendedProtein);
      tracker.setNutrient('Carbs', currentCarbs, _recommendedCarbs);
      tracker.setNutrient('Fats', currentFats, _recommendedFats);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar:
          AppBar(title: const Text('Complete Your Profile'), elevation: 0),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Profile Picture
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Theme.of(context).primaryColor,
                child: Text(
                  (user.displayName?.isNotEmpty ?? false)
                      ? user.displayName![0].toUpperCase()
                      : user.email?.substring(0, 1).toUpperCase() ?? '?',
                  style:
                      const TextStyle(fontSize: 36, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                user.email ?? '',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 32),

            // Basic Info Section
            const Text(
              'Basic Information',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (v) =>
                  v?.isEmpty ?? true ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ageCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Age',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.cake),
                    ),
                    validator: (v) =>
                        v?.isEmpty ?? true ? 'Required' : null,
                    onChanged: (_) => _calculateRecommendations(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _gender,
                    decoration: const InputDecoration(
                      labelText: 'Gender',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    items: ['Male', 'Female']
                        .map((g) => DropdownMenuItem(
                              value: g,
                              child: Text(g),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _gender = v!);
                      _calculateRecommendations();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _heightCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Height (cm)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.height),
                    ),
                    validator: (v) =>
                        v?.isEmpty ?? true ? 'Required' : null,
                    onChanged: (_) => _calculateRecommendations(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _weightCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Weight (kg)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.monitor_weight),
                    ),
                    validator: (v) =>
                        v?.isEmpty ?? true ? 'Required' : null,
                    onChanged: (_) => _calculateRecommendations(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Lifestyle Section
            const Text(
              'Lifestyle & Goals',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _activityLevel,
              decoration: const InputDecoration(
                labelText: 'Activity Level',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.directions_run),
              ),
              items: [
                'Sedentary',
                'Light',
                'Moderate',
                'Active',
                'Very Active',
              ]
                  .map((a) => DropdownMenuItem(
                        value: a,
                        child: Text(a),
                      ))
                  .toList(),
              onChanged: (v) {
                setState(() => _activityLevel = v!);
                _calculateRecommendations();
              },
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _goal,
              decoration: const InputDecoration(
                labelText: 'Goal',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.flag),
              ),
              items: [
                'Lose Weight',
                'Maintain',
                'Gain Weight',
              ]
                  .map((g) => DropdownMenuItem(
                        value: g,
                        child: Text(g),
                      ))
                  .toList(),
              onChanged: (v) {
                setState(() => _goal = v!);
                _calculateRecommendations();
              },
            ),
            const SizedBox(height: 32),

            // Recommendations Card
            if (_recommendedCalories > 0) ...[
              const Text(
                'Your Personalized Targets',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildRecommendationRow(
                        'Daily Calories',
                        '$_recommendedCalories kcal',
                        Icons.local_fire_department,
                        Colors.orange,
                      ),
                      const Divider(height: 24),
                      _buildRecommendationRow(
                        'Protein',
                        '$_recommendedProtein g',
                        Icons.egg,
                        Colors.red,
                      ),
                      const SizedBox(height: 12),
                      _buildRecommendationRow(
                        'Carbohydrates',
                        '$_recommendedCarbs g',
                        Icons.bakery_dining,
                        Colors.amber,
                      ),
                      const SizedBox(height: 12),
                      _buildRecommendationRow(
                        'Fats',
                        '$_recommendedFats g',
                        Icons.water_drop,
                        Colors.yellow,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'These targets are calculated based on your profile and will be saved.',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),

            // Save Button
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save Profile',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
