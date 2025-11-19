import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:first_project/calorie_tracker_provider.dart';

class AddFoodScreen extends StatefulWidget {
  const AddFoodScreen({super.key});

  @override
  State<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _calPerUnitCtrl = TextEditingController();
  final _unitLabelCtrl = TextEditingController(text: '100 g'); // example default
  final _quantityCtrl = TextEditingController(text: '1');

  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _calPerUnitCtrl.dispose();
    _unitLabelCtrl.dispose();
    _quantityCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameCtrl.text.trim();
    final unitLabel = _unitLabelCtrl.text.trim();
    final calPerUnit = int.tryParse(_calPerUnitCtrl.text.trim()) ?? 0;
    final qty = int.tryParse(_quantityCtrl.text.trim()) ?? 0;

    final totalCalories = calPerUnit * qty;
    if (totalCalories <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Calories must be greater than 0'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      // 1) Update app state via Provider
      context.read<CalorieTrackerProvider>().addCalories(totalCalories);

      // 2) Optional: save to Firestore if signed-in (safe no-op otherwise)
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('meals')
            .add({
          'name': name,
          'unitLabel': unitLabel,
          'caloriesPerUnit': calPerUnit,
          'quantity': qty,
          'calories': totalCalories,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Logged: $qty × $unitLabel $name\n$totalCalories kcal'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to log: $e'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Food')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Food name',
                  hintText: 'e.g., Chicken Breast',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter a food name' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _calPerUnitCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Calories per unit',
                        hintText: 'e.g., 165',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n <= 0) {
                          return 'Enter cal/unit';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _unitLabelCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Unit label',
                        hintText: 'e.g., 100 g / slice / cup',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter unit' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityCtrl,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  hintText: 'e.g., 2',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n <= 0) return 'Enter quantity';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                    height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: const Text('Log'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
