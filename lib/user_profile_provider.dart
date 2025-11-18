import 'package:flutter/foundation.dart';

class UserProfileProvider extends ChangeNotifier {
  int age = 25;
  double heightCm = 170;
  double weightKg = 70;
  double targetWeightKg = 65;
  String sex = 'male';              // 'male' or 'female'
  String activityLevel = 'moderate'; // 'low', 'moderate', 'high'

  int recommendedCalories = 2200;

  // Macro goals (per day, in grams)
  int targetProteinG = 120;
  int targetCarbsG = 250;
  int targetFatsG = 70;

  void updateProfile({
    required int age,
    required double heightCm,
    required double weightKg,
    required double targetWeightKg,
    required String sex,
    required String activityLevel,
  }) {
    this.age = age;
    this.heightCm = heightCm;
    this.weightKg = weightKg;
    this.targetWeightKg = targetWeightKg;
    this.sex = sex;
    this.activityLevel = activityLevel;

    _recalculatePlan();
    notifyListeners();
  }

  void _recalculatePlan() {
    // --------- 1. Calculate calories (TDEE) ---------
    final s = sex == 'male' ? 5 : -161; // Mifflin-St Jeor
    final bmr = 10 * weightKg + 6.25 * heightCm - 5 * age + s;

    double multiplier;
    switch (activityLevel) {
      case 'low':
        multiplier = 1.2; // sedentary
        break;
      case 'moderate':
        multiplier = 1.45; // light/moderate
        break;
      case 'high':
        multiplier = 1.7; // very active
        break;
      default:
        multiplier = 1.4;
    }

    final tdee = bmr * multiplier;

    // Weight goal logic
    if (targetWeightKg < weightKg) {
      // lose weight: ~500 kcal deficit
      recommendedCalories = (tdee - 500).round();
    } else if (targetWeightKg > weightKg) {
      // gain weight: small surplus
      recommendedCalories = (tdee + 250).round();
    } else {
      // maintain
      recommendedCalories = tdee.round();
    }

    // Safety clamp
    if (recommendedCalories < 1200) {
      recommendedCalories = 1200;
    }

    // --------- 2. Calculate macros from weight & goal ---------
    // VERY simple, general fitness-style rules (not medical advice):

    // Protein: more when losing weight, moderate when gaining/maintaining
    double proteinPerKg;
    if (targetWeightKg < weightKg) {
      proteinPerKg = 2.0; // cutting
    } else if (targetWeightKg > weightKg) {
      proteinPerKg = 1.8; // bulking
    } else {
      proteinPerKg = 1.6; // maintenance
    }
    double protein = proteinPerKg * weightKg; // or use targetWeightKg

    // Fats: keep reasonable min amount
    double fats = 0.8 * weightKg; // g per kg
    if (fats < 40) fats = 40;

    // Calories from protein & fats
    final calFromProtein = protein * 4;
    final calFromFats = fats * 9;

    // Remaining calories go to carbs
    double remainingCal = recommendedCalories - calFromProtein - calFromFats;
    if (remainingCal < 0) remainingCal = 0;
    double carbs = remainingCal / 4.0;

    targetProteinG = protein.round();
    targetFatsG = fats.round();
    targetCarbsG = carbs.round();
  }
}
