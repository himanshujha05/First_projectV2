import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CalorieTrackerProvider extends ChangeNotifier {
  // ---- Calories ----
  int calories = 0;
  int calorieGoal = 2200;

  // ---- Water ----
  int waterMl = 0;
  int waterGoalMl = 2000;

  // ---- Nutrients (g) ----
  // value = consumed today, max = daily target
  Map<String, Map<String, int>> nutrients = {
    'Protein': {'value': 0, 'max': 120},
    'Carbs': {'value': 0, 'max': 250},
    'Fats': {'value': 0, 'max': 70},
  };

  // 7-day protein history (Mon..Today)
  List<int> proteinWeek = List<int>.filled(7, 0);

  // ---------------- CONSTRUCTOR: load user targets ----------------

  CalorieTrackerProvider() {
    _loadUserTargets();
  }

  Future<void> _loadUserTargets() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = snap.data();
      if (data == null) return;

      int _asInt(dynamic v, int fallback) {
        if (v == null) return fallback;
        if (v is int) return v;
        if (v is double) return v.round();
        if (v is num) return v.toInt();
        return fallback;
      }

      final calGoal = _asInt(
        data['recommendedCalories'] ?? data['calorieGoal'],
        calorieGoal,
      );
      final proteinGoal = _asInt(
        data['recommendedProtein'],
        nutrients['Protein']?['max'] ?? 120,
      );
      final carbsGoal = _asInt(
        data['recommendedCarbs'],
        nutrients['Carbs']?['max'] ?? 250,
      );
      final fatsGoal = _asInt(
        data['recommendedFats'],
        nutrients['Fats']?['max'] ?? 70,
      );

      // apply to provider
      updateTargets(
        calorieGoal: calGoal,
        proteinGoal: proteinGoal,
        carbsGoal: carbsGoal,
        fatsGoal: fatsGoal,
      );
    } catch (e) {
      if (kDebugMode) {
        print('CalorieTrackerProvider: failed to load user targets: $e');
      }
    }
  }

  // ---------------- Calories ----------------

  void addCalories(int value) {
    calories += value;
    if (calories < 0) calories = 0;
    notifyListeners();
  }

  void setCalorieGoal(int value) {
    calorieGoal = value;
    notifyListeners();
  }

  // 🔥 update everything from profile plan or Firestore
  void updateTargets({
    required int calorieGoal,
    required int proteinGoal,
    required int carbsGoal,
    required int fatsGoal,
  }) {
    this.calorieGoal = calorieGoal;

    // ensure keys exist
    nutrients['Protein'] ??= {'value': 0, 'max': proteinGoal};
    nutrients['Carbs'] ??= {'value': 0, 'max': carbsGoal};
    nutrients['Fats'] ??= {'value': 0, 'max': fatsGoal};

    nutrients['Protein']!['max'] = proteinGoal;
    nutrients['Carbs']!['max'] = carbsGoal;
    nutrients['Fats']!['max'] = fatsGoal;

    notifyListeners();
  }

  // ---------------- Water ----------------

  void addWater(int value) {
    waterMl += value;
    if (waterMl < 0) waterMl = 0;
    notifyListeners();
  }

  void setWater(int value) {
    waterMl = value;
    if (waterMl < 0) waterMl = 0;
    notifyListeners();
  }

  void setWaterGoal(int value) {
    waterGoalMl = value;
    notifyListeners();
  }

  // ---------------- Nutrients ----------------

  void setNutrient(String name, int value, int max) {
    nutrients[name] = {'value': value, 'max': max};
    notifyListeners();
  }

  void addNutrient(String name, int delta) {
    final current = nutrients[name]?['value'] ?? 0;
    final max = nutrients[name]?['max'] ?? 0;
    nutrients[name] = {
      'value': (current + delta).clamp(0, 100000),
      'max': max,
    };
    notifyListeners();
  }

  // optional: update today's protein in the week array
  void setTodayProtein(int grams) {
    if (proteinWeek.isEmpty) return;
    proteinWeek[proteinWeek.length - 1] = grams;
    notifyListeners();
  }

  // ---------------- RESET ALL ----------------

  /// Reset whole daily log (calories, water, nutrients, chart).
  void resetAll() {
    calories = 0;
    waterMl = 0;

    nutrients.updateAll((key, value) => {
          'value': 0,
          'max': value['max'] ?? 0,
        });

    for (int i = 0; i < proteinWeek.length; i++) {
      proteinWeek[i] = 0;
    }

    notifyListeners();
  }

  // ---------------- Meals from LogFoodPage ----------------

  void addMeal({
    required int caloriesPerUnit,
    required int quantity,
    required double proteinPerUnit,
    required double carbsPerUnit,
    required double fatsPerUnit,
  }) {
    final totalCalories = caloriesPerUnit * quantity;
    final totalProtein = (proteinPerUnit * quantity).round();
    final totalCarbs = (carbsPerUnit * quantity).round();
    final totalFats = (fatsPerUnit * quantity).round();

    addCalories(totalCalories);
    addNutrient('Protein', totalProtein);
    addNutrient('Carbs', totalCarbs);
    addNutrient('Fats', totalFats);

    // also reflect today's protein in weekly chart
    final todayProtein = nutrients['Protein']?['value'] ?? 0;
    setTodayProtein(todayProtein);
  }
}
