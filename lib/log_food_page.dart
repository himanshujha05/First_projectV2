import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'calorie_tracker_provider.dart';

class FoodItem {
  final String name;
  final int caloriesPerUnit;
  final String assetPath;
  final double proteinG; // per unit
  final double carbsG;   // per unit
  final double fatsG;    // per unit

  const FoodItem({
    required this.name,
    required this.caloriesPerUnit,
    required this.assetPath,
    required this.proteinG,
    required this.carbsG,
    required this.fatsG,
  });
}

class LogFoodPage extends StatefulWidget {
  final void Function(int) onCaloriesLogged;
  const LogFoodPage({super.key, required this.onCaloriesLogged});

  @override
  State<LogFoodPage> createState() => _LogFoodPageState();
}

class _LogFoodPageState extends State<LogFoodPage> {
  final Map<FoodItem, TextEditingController> quantityControllers = {};

  // ⚠️ Make sure these filenames exist in assets/images and match case exactly.
  final List<FoodItem> foodItems = const [
    // Fruits (per 1 medium or 100 g noted)
    FoodItem(name: 'Apple (1 medium)',   caloriesPerUnit: 95,  assetPath: 'assets/images/apple.jpg',  proteinG: 0.5, carbsG: 25.0, fatsG: 0.3),
    FoodItem(name: 'Banana (1 medium)',  caloriesPerUnit: 105, assetPath: 'assets/images/banana.jpg', proteinG: 1.3, carbsG: 27.0, fatsG: 0.4),
    FoodItem(name: 'Orange (1 medium)',  caloriesPerUnit: 62,  assetPath: 'assets/images/orange.jpg', proteinG: 1.2, carbsG: 15.4, fatsG: 0.2),
    FoodItem(name: 'Strawberries (100 g)', caloriesPerUnit: 32, assetPath: 'assets/images/strawberries.jpg', proteinG: 0.7, carbsG: 7.7, fatsG: 0.3),
    FoodItem(name: 'Blueberries (100 g)',  caloriesPerUnit: 57, assetPath: 'assets/images/blueberries.jpg',  proteinG: 0.7, carbsG: 14.5, fatsG: 0.3),
    FoodItem(name: 'Avocado (1/2)',      caloriesPerUnit: 120, assetPath: 'assets/images/avocado.jpg', proteinG: 1.5, carbsG: 6.0, fatsG: 10.5),

    // Veg (per 100 g unless stated)
    FoodItem(name: 'Broccoli (100 g)',   caloriesPerUnit: 55,  assetPath: 'assets/images/broccoli.jpg', proteinG: 3.7, carbsG: 11.2, fatsG: 0.6),
    FoodItem(name: 'Spinach (100 g)',    caloriesPerUnit: 23,  assetPath: 'assets/images/spinach.jpg',  proteinG: 2.9, carbsG: 3.6,  fatsG: 0.4),
    FoodItem(name: 'Carrots (100 g)',    caloriesPerUnit: 41,  assetPath: 'assets/images/carrots.jpg',  proteinG: 0.9, carbsG: 9.6,  fatsG: 0.2),
    FoodItem(name: 'Sweet Potato (100 g)', caloriesPerUnit: 86, assetPath: 'assets/images/sweet_potato.jpg', proteinG: 1.6, carbsG: 20.1, fatsG: 0.1),

    // Grains / starches
    FoodItem(name: 'Rice (100 g cooked)', caloriesPerUnit: 130, assetPath: 'assets/images/rice.jpg',      proteinG: 2.4, carbsG: 28.2, fatsG: 0.3),
    FoodItem(name: 'Pasta (100 g cooked)', caloriesPerUnit: 131, assetPath: 'assets/images/pasta.jpg',    proteinG: 5.0, carbsG: 25.0, fatsG: 1.1),
    FoodItem(name: 'Quinoa (100 g cooked)', caloriesPerUnit: 120, assetPath: 'assets/images/quinoa.jpg',  proteinG: 4.4, carbsG: 21.3, fatsG: 1.9),
    FoodItem(name: 'Oatmeal (1 cup cooked)', caloriesPerUnit: 158, assetPath: 'assets/images/oatmeal.jpg', proteinG: 6.0, carbsG: 27.0, fatsG: 3.2),
    FoodItem(name: 'Whole Wheat Bread (slice)', caloriesPerUnit: 80, assetPath: 'assets/images/whole_wheat_bread.jpg', proteinG: 4.0, carbsG: 14.0, fatsG: 1.0),

    // Proteins (per 100 g unless stated)
    FoodItem(name: 'Chicken Breast (100 g)', caloriesPerUnit: 165, assetPath: 'assets/images/chicken_breast.jpg', proteinG: 31.0, carbsG: 0.0, fatsG: 3.6),
    FoodItem(name: 'Chicken Thigh (100 g)',  caloriesPerUnit: 209, assetPath: 'assets/images/chicken_thigh.jpg',  proteinG: 26.0, carbsG: 0.0, fatsG: 10.9),
    FoodItem(name: 'Turkey Breast (100 g)',  caloriesPerUnit: 135, assetPath: 'assets/images/turkey_breast.jpg',  proteinG: 29.0, carbsG: 0.0, fatsG: 1.0),
    FoodItem(name: 'Beef Steak (100 g)',     caloriesPerUnit: 271, assetPath: 'assets/images/beef_steak.jpg',     proteinG: 25.0, carbsG: 0.0, fatsG: 19.0),
    FoodItem(name: 'Pork Chop (100 g)',      caloriesPerUnit: 231, assetPath: 'assets/images/pork_chop.jpg',      proteinG: 26.0, carbsG: 0.0, fatsG: 14.0),
    FoodItem(name: 'Salmon (100 g)',         caloriesPerUnit: 208, assetPath: 'assets/images/salmon.jpg',         proteinG: 20.0, carbsG: 0.0, fatsG: 13.0),
    FoodItem(name: 'Tuna (100 g)',           caloriesPerUnit: 132, assetPath: 'assets/images/tuna.jpg',           proteinG: 29.0, carbsG: 0.0, fatsG: 1.0),
    FoodItem(name: 'Shrimp (100 g)',         caloriesPerUnit: 99,  assetPath: 'assets/images/shrimp.jpg',         proteinG: 24.0, carbsG: 0.2, fatsG: 0.3),
    FoodItem(name: 'Tofu (100 g)',           caloriesPerUnit: 76,  assetPath: 'assets/images/tofu.jpg',           proteinG: 8.0,  carbsG: 1.9, fatsG: 4.8),
    FoodItem(name: 'Boiled Egg (1)',         caloriesPerUnit: 78,  assetPath: 'assets/images/boiled_egg.jpg',     proteinG: 6.0,  carbsG: 0.6, fatsG: 5.3),

    // Dairy / snacks (per common serving)
    FoodItem(name: 'Greek Yogurt (170 g)',   caloriesPerUnit: 100, assetPath: 'assets/images/greek_yogurt.jpg', proteinG: 17.0, carbsG: 6.0, fatsG: 0.7),
    FoodItem(name: 'Cottage Cheese (100 g)', caloriesPerUnit: 98,  assetPath: 'assets/images/cottage_cheese.jpg', proteinG: 11.0, carbsG: 3.4, fatsG: 4.3),
    FoodItem(name: 'Peanut Butter (1 tbsp)', caloriesPerUnit: 94,  assetPath: 'assets/images/peanut_butter.jpg', proteinG: 3.5,  carbsG: 3.2, fatsG: 8.0),
    FoodItem(name: 'Almonds (28 g)',         caloriesPerUnit: 164, assetPath: 'assets/images/almonds.jpg',       proteinG: 6.0,  carbsG: 6.0, fatsG: 14.0),
  ];

  @override
  void initState() {
    super.initState();
    for (var item in foodItems) {
      quantityControllers[item] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (var c in quantityControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _logFood(FoodItem item) {
    final qtyText = quantityControllers[item]?.text.trim();
    final qty = int.tryParse(qtyText ?? '') ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a quantity greater than 0')),
      );
      return;
    }

    // Update Provider: calories + macros
    context.read<CalorieTrackerProvider>().addMeal(
      caloriesPerUnit: item.caloriesPerUnit,
      quantity: qty,
      // round macro grams to int for the provider
      proteinPerUnit: item.proteinG,
      carbsPerUnit: item.carbsG,
      fatsPerUnit: item.fatsG,
    );

    // Notify parent (if needed for any local UI)
    widget.onCaloriesLogged(item.caloriesPerUnit * qty);

    // Feedback
    final totalP = (item.proteinG * qty).toStringAsFixed(1);
    final totalC = (item.carbsG   * qty).toStringAsFixed(1);
    final totalF = (item.fatsG    * qty).toStringAsFixed(1);
    final totalK = item.caloriesPerUnit * qty;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Logged $qty × ${item.name} • $totalK kcal • '
          'P $totalP / C $totalC / F $totalF g',
        ),
      ),
    );

    quantityControllers[item]?.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log Food')),
      body: ListView.builder(
        itemCount: foodItems.length,
        itemBuilder: (context, index) {
          final item = foodItems[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  item.assetPath,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    width: 50,
                    height: 50,
                    child: ColoredBox(
                      color: Color(0x11000000),
                      child: Icon(Icons.broken_image),
                    ),
                  ),
                ),
              ),
              title: Text(item.name),
              subtitle: Text(
                '${item.caloriesPerUnit} kcal • '
                'P ${item.proteinG.toStringAsFixed(1)}g  '
                'C ${item.carbsG.toStringAsFixed(1)}g  '
                'F ${item.fatsG.toStringAsFixed(1)}g  per unit',
              ),
              trailing: SizedBox(
                width: 140,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: quantityControllers[item],
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: const InputDecoration(
                          hintText: 'Qty',
                          isDense: true,
                          contentPadding: EdgeInsets.all(8),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => _logFood(item),
                      tooltip: 'Add',
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
