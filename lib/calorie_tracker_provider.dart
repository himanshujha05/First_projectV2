import 'package:flutter/foundation.dart';

class CalorieTrackerProvider extends ChangeNotifier {
  // ---- Calories ----
  int _calories = 0;
  int get calories => _calories;

  int _calorieGoal = 2000;
  int get calorieGoal => _calorieGoal;

  // ---- Nutrients (macros) ----
  final Map<String, Map<String, int>> _nutrients = {
    'Protein': {'value': 0, 'max': 120},
    'Carbs'  : {'value': 0, 'max': 250},
    'Fats'   : {'value': 0, 'max': 70},
  };
  Map<String, Map<String, int>> get nutrients => _nutrients;

  // ---- Water intake (ml) ----
  int _waterMl = 0;
  int _waterGoalMl = 2000;
  int get waterMl => _waterMl;
  int get waterGoalMl => _waterGoalMl;

  // ---- Protein history (last 7 days, today at the end) ----
  // Keep simple integers (grams). You can replace with real persistence later.
  List<int> _proteinWeek = [60, 75, 50, 80, 90, 70, 0];
  List<int> get proteinWeek => List.unmodifiable(_proteinWeek);

  // ---- Calories API ----
  void addCalories(int amount) {
    _calories += amount;
    notifyListeners();
  }

  void setCalories(int newCalories) {
    _calories = newCalories;
    notifyListeners();
  }

  void setCalorieGoal(int newGoal) {
    _calorieGoal = newGoal.clamp(500, 5000);
    notifyListeners();
  }

  // ---- Nutrients API ----
  void updateNutrient(String name, int value) {
    if (_nutrients.containsKey(name)) {
      _nutrients[name]!['value'] = value.clamp(0, 1000000);
      _syncProteinToday();
      notifyListeners();
    }
  }

  void addMacros({double protein = 0, double carbs = 0, double fats = 0}) {
    _inc('Protein', protein);
    _inc('Carbs',   carbs);
    _inc('Fats',    fats);
    _syncProteinToday();
    notifyListeners();
  }

  void addMeal({
    required int caloriesPerUnit,
    required int quantity,
    double proteinPerUnit = 0,
    double carbsPerUnit = 0,
    double fatsPerUnit = 0,
  }) {
    final totalCals = caloriesPerUnit * quantity;
    final totalP = proteinPerUnit * quantity;
    final totalC = carbsPerUnit   * quantity;
    final totalF = fatsPerUnit    * quantity;

    _calories += totalCals;
    _inc('Protein', totalP);
    _inc('Carbs',   totalC);
    _inc('Fats',    totalF);
    _syncProteinToday();
    notifyListeners();
  }

  /// Optionally adjust daily macro goals (grams).
  void setGoals({int? protein, int? carbs, int? fats}) {
    if (protein != null && _nutrients.containsKey('Protein')) {
      _nutrients['Protein']!['max'] = protein;
    }
    if (carbs != null && _nutrients.containsKey('Carbs')) {
      _nutrients['Carbs']!['max'] = carbs;
    }
    if (fats != null && _nutrients.containsKey('Fats')) {
      _nutrients['Fats']!['max'] = fats;
    }
    notifyListeners();
  }

  // ---- Water API ----
  void addWater(int ml) {
    _waterMl = (_waterMl + ml).clamp(0, 20000);
    notifyListeners();
  }

  void setWater(int ml) {
    _waterMl = ml.clamp(0, 20000);
    notifyListeners();
  }

  void setWaterGoal(int ml) {
    _waterGoalMl = ml.clamp(500, 6000);
    notifyListeners();
  }

  // ---- Reset ----
  void resetToday() {
    _calories = 0;
    for (final e in _nutrients.values) {
      e['value'] = 0;
    }
    _waterMl = 0;

    // shift week left, clear "today"
    _proteinWeek = [
      _proteinWeek[1],
      _proteinWeek[2],
      _proteinWeek[3],
      _proteinWeek[4],
      _proteinWeek[5],
      _proteinWeek[6],
      0
    ];
    notifyListeners();
  }

  // ---- helpers ----
  void _inc(String key, double by) {
    if (!_nutrients.containsKey(key)) return;
    final current = _nutrients[key]!['value'] ?? 0;
    _nutrients[key]!['value'] = (current + by.round()).clamp(0, 1000000);
  }

  void _syncProteinToday() {
    // Mirror the current protein "value" into the last slot of the week array.
    final todayProtein = _nutrients['Protein']?['value'] ?? 0;
    if (_proteinWeek.isEmpty) {
      _proteinWeek = [todayProtein];
    } else {
      _proteinWeek[_proteinWeek.length - 1] = todayProtein;
    }
  }
}
