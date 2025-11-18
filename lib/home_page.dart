import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'calorie_tracker_provider.dart';
import 'map_screen.dart';
import 'app_drawer.dart';
import 'add_food_screen.dart';
import 'log_food_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    _loadGoalsFromFirestore();
  }

  /// Load saved goals (recommendedCalories, macros) from Firestore
  /// and push them into CalorieTrackerProvider so HomePage uses them.
  Future<void> _loadGoalsFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get provider BEFORE any await -> no use_build_context_synchronously warning
      final tracker =
          Provider.of<CalorieTrackerProvider>(context, listen: false);

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) return;
      final data = doc.data() ?? {};

      // Keep current consumed values (don't reset user's daily progress)
      final currentProtein = tracker.nutrients['Protein']?['value'] ?? 0;
      final currentCarbs = tracker.nutrients['Carbs']?['value'] ?? 0;
      final currentFats = tracker.nutrients['Fats']?['value'] ?? 0;

      // Read saved targets, with fallbacks
      final calGoalRaw =
          data['recommendedCalories'] ?? data['calorieGoal'] ?? tracker.calorieGoal;
      final protGoalRaw = data['recommendedProtein'] ??
          tracker.nutrients['Protein']?['max'] ??
          120;
      final carbGoalRaw =
          data['recommendedCarbs'] ?? tracker.nutrients['Carbs']?['max'] ?? 250;
      final fatGoalRaw =
          data['recommendedFats'] ?? tracker.nutrients['Fats']?['max'] ?? 70;

      int _toInt(dynamic v, int fallback) {
        if (v is int) return v;
        if (v is double) return v.round();
        return int.tryParse(v.toString()) ?? fallback;
      }

      final calGoal = _toInt(calGoalRaw, tracker.calorieGoal);
      final protGoal =
          _toInt(protGoalRaw, tracker.nutrients['Protein']?['max'] ?? 120);
      final carbGoal =
          _toInt(carbGoalRaw, tracker.nutrients['Carbs']?['max'] ?? 250);
      final fatGoal =
          _toInt(fatGoalRaw, tracker.nutrients['Fats']?['max'] ?? 70);

      tracker.setCalorieGoal(calGoal);
      tracker.setNutrient('Protein', currentProtein, protGoal);
      tracker.setNutrient('Carbs', currentCarbs, carbGoal);
      tracker.setNutrient('Fats', currentFats, fatGoal);
    } catch (e) {
      debugPrint('Failed to sync profile goals to HomePage: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Dark gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.25),
                  Colors.black.withOpacity(0.70),
                ],
              ),
            ),
          ),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _HeaderBar()),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                const SliverToBoxAdapter(child: _GreetingTitle()),
                const SliverToBoxAdapter(child: SizedBox(height: 22)),
                SliverToBoxAdapter(child: _QuickActions()),
                const SliverToBoxAdapter(child: SizedBox(height: 22)),

                // Big ring card
                SliverToBoxAdapter(child: _CalorieRingCard()),
                const SliverToBoxAdapter(child: SizedBox(height: 22)),

                // Water meter
                SliverToBoxAdapter(child: _WaterCard()),
                const SliverToBoxAdapter(child: SizedBox(height: 22)),

                // Nutrients
                SliverToBoxAdapter(child: _NutrientsCard()),
                const SliverToBoxAdapter(child: SizedBox(height: 22)),

                // Protein chart
                SliverToBoxAdapter(child: _ProteinChartCard()),
                const SliverToBoxAdapter(child: SizedBox(height: 22)),

                // Nearby
                SliverToBoxAdapter(child: _NearbyCard()),
                const SliverToBoxAdapter(child: SizedBox(height: 26)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------------ Header Bar ------------------------------ */

class _HeaderBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Row(
        children: [
          Builder(
            builder: (context) => _GlassIconButton(
              icon: Icons.menu,
              onTap: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          const Spacer(),
          _GlassResetButton(
            onTap: () {
              context.read<CalorieTrackerProvider>().resetAll();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Daily log has been reset")),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      radius: 28,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _GlassResetButton extends StatelessWidget {
  final VoidCallback onTap;

  const _GlassResetButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.28),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.7)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Text(
          "RESET",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

/* ----------------------------- Greeting Title ---------------------------- */

class _GreetingTitle extends StatelessWidget {
  const _GreetingTitle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        builder: (context, t, _) {
          return Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, 16 * (1 - t)),
              child: const Text(
                "Calories\nTracker 2.0",
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.1,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 2),
                      blurRadius: 4,
                      color: Colors.black26,
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

/* ------------------------------ Quick Actions --------------------------- */

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          _QuickActionChip(
            icon: Icons.restaurant_menu,
            label: "Log Food",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LogFoodPage(
                    onCaloriesLogged: (calories) {
                      context
                          .read<CalorieTrackerProvider>()
                          .addCalories(calories);
                    },
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          _QuickActionChip(
            icon: Icons.map_outlined,
            label: "Open Map",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MapScreen()),
            ),
          ),
          const SizedBox(width: 12),
          _QuickActionChip(
            icon: Icons.fastfood_outlined,
            label: "Add Meal",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddFoodScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.28)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ---------------------------- Calorie Ring Card -------------------------- */

class _CalorieRingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<CalorieTrackerProvider>(
      builder: (context, provider, _) {
        final total = provider.calories;
        final goal = provider.calorieGoal;

        final rawProgress = goal == 0 ? 0.0 : total / goal;
        final progress = rawProgress.clamp(0.0, 1.0);
        final bool overGoal = goal > 0 && total > goal;
        final int diff =
            (overGoal ? total - goal : goal - total).clamp(0, 100000);

        return _GlassCard(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              // Bigger ring
              SizedBox(
                width: 170,
                height: 170,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return CustomPaint(
                      painter: _CalorieRingPainter(
                        value,
                        stroke: 16,
                        overGoal: overGoal,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "${(rawProgress * 100).clamp(0, 999).toInt()}%",
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "of goal",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Today's Intake",
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: total.toDouble()),
                      duration: const Duration(milliseconds: 800),
                      builder: (context, v, __) => Text(
                        "${v.toInt()} cal",
                        style: const TextStyle(
                          fontSize: 36,
                          height: 1.0,
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Goal row + edit button
                    Row(
                      children: [
                        Text(
                          "Goal: $goal cal",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: () =>
                              _showEditCalorieGoalDialog(context, goal),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.25),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit, size: 14, color: Colors.white),
                                SizedBox(width: 6),
                                Text(
                                  "Edit goal",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        value: progress.clamp(0.0, 1.0),
                        backgroundColor: Colors.white.withOpacity(0.18),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          overGoal ? Colors.redAccent : Colors.tealAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      overGoal
                          ? "Over goal by $diff cal"
                          : "Remaining $diff cal",
                      style: TextStyle(
                        color: overGoal
                            ? Colors.redAccent.shade100
                            : Colors.lightGreenAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CalorieRingPainter extends CustomPainter {
  final double progress; // 0..1 for ring visualization
  final double stroke;
  final bool overGoal;

  _CalorieRingPainter(this.progress,
      {this.stroke = 10, this.overGoal = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide / 2) - stroke;

    final bg = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final fg = Paint()
      ..shader = LinearGradient(
        colors: overGoal
            ? const [Color(0xffFF6A6A), Color(0xffFF8A80)]
            : const [Color(0xff7DF4E5), Color(0xff6AD3FF)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    const start = -90 * 3.1415926 / 180;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      2 * 3.1415926,
      false,
      bg,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      2 * 3.1415926 * progress,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _CalorieRingPainter old) =>
      old.progress != progress ||
      old.stroke != stroke ||
      old.overGoal != overGoal;
}

/* ------------------------------ Water Card ------------------------------- */

class _WaterCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<CalorieTrackerProvider>(
      builder: (context, p, _) {
        final goal = p.waterGoalMl;
        final val = p.waterMl;
        final ratio = (goal == 0) ? 0.0 : (val / goal).clamp(0.0, 1.0);

        return _GlassCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              // Bottle / vertical meter
              SizedBox(
                width: 64,
                height: 160,
                child: CustomPaint(
                  painter: _BottlePainter(ratio),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _CardTitle(text: "Water Intake"),
                    const SizedBox(height: 6),
                    Text(
                      "$val / $goal ml",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: ratio,
                        backgroundColor: Colors.white.withOpacity(0.18),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.lightBlueAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _waterBtn(context, "+250 ml", () => p.addWater(250)),
                        const SizedBox(width: 8),
                        _waterBtn(context, "+500 ml", () => p.addWater(500)),
                        const Spacer(),
                        _waterBtn(context, "Reset", () => p.setWater(0)),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _waterBtn(BuildContext ctx, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _BottlePainter extends CustomPainter {
  final double fill; // 0..1
  _BottlePainter(this.fill);

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(18),
    );
    final paintBorder = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final paintFill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Color(0xFF4FC3F7), Color(0xFFB3E5FC)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..color = Colors.lightBlueAccent.withOpacity(0.9);

    // Fill height
    final h = size.height * fill;
    final fillRect = Rect.fromLTWH(0, size.height - h, size.width, h);
    final clip = Path()..addRRect(r);

    canvas.save();
    canvas.clipPath(clip);
    canvas.drawRect(fillRect, paintFill);
    canvas.restore();

    // Border
    canvas.drawRRect(r, paintBorder);
  }

  @override
  bool shouldRepaint(covariant _BottlePainter oldDelegate) =>
      oldDelegate.fill != fill;
}

/* ----------------------------- Nutrients Card ---------------------------- */

class _NutrientsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<CalorieTrackerProvider>(
      builder: (context, provider, _) {
        final n = provider.nutrients;

        int val(String k) => (n[k]?['value'] ?? 0) as int;
        int max(String k) => (n[k]?['max'] ??
                {
                  'Protein': 120,
                  'Carbs': 250,
                  'Fats': 70,
                }[k]) as int;

        final items = [
          _NutrientData(
            "Protein",
            Icons.fitness_center,
            val("Protein"),
            max("Protein"),
            Colors.orange,
          ),
          _NutrientData(
            "Carbs",
            Icons.rice_bowl_outlined,
            val("Carbs"),
            max("Carbs"),
            Colors.lightBlue,
          ),
          _NutrientData(
            "Fats",
            Icons.bubble_chart_outlined,
            val("Fats"),
            max("Fats"),
            Colors.greenAccent.shade400,
          ),
        ];

        return _GlassCard(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CardTitle(text: "Nutrients"),
              const SizedBox(height: 10),
              ...items.map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: _NutrientRow(data: e),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NutrientData {
  final String name;
  final IconData icon;
  final int value;
  final int max;
  final Color color;

  _NutrientData(this.name, this.icon, this.value, this.max, this.color);
}

class _NutrientRow extends StatelessWidget {
  final _NutrientData data;

  const _NutrientRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final clamped = data.value.clamp(0, data.max);
    final percent = data.max == 0 ? 0 : (clamped / data.max * 100).round();

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: Icon(
            data.icon,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (context, c) {
                  final w = (clamped / data.max) * c.maxWidth;
                  return Stack(
                    children: [
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOut,
                        width: w,
                        height: 8,
                        decoration: BoxDecoration(
                          color: data.color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "${data.value}/${data.max} g",
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              "$percent%",
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/* --------------------------- Protein Chart Card -------------------------- */

class _ProteinChartCard extends StatefulWidget {
  @override
  State<_ProteinChartCard> createState() => _ProteinChartCardState();
}

class _ProteinChartCardState extends State<_ProteinChartCard> {
  // simple toggle: Day (single bar) or Week (7 bars)
  bool showWeek = true;

  @override
  Widget build(BuildContext context) {
    return Consumer<CalorieTrackerProvider>(
      builder: (context, p, _) {
        final week = p.proteinWeek; // 7 values, last is today
        final today = p.nutrients['Protein']?['value'] ?? 0;
        final data = showWeek ? week : [today];
        final labels =
            showWeek ? ['M', 'T', 'W', 'T', 'F', 'S', 'Today'] : ['Today'];

        return _GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _CardTitle(text: "Protein Intake"),
                  const Spacer(),
                  _segmented(
                    left: "Day",
                    right: "Week",
                    valueRight: showWeek,
                    onChanged: (v) => setState(() => showWeek = v),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 190,
                child: CustomPaint(
                  painter: _BarChartPainter(
                    values: data.map((e) => e.toDouble()).toList(),
                    labels: labels,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _segmented({
    required String left,
    required String right,
    required bool valueRight,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          _segBtn(left, !valueRight, () => onChanged(false)),
          _segBtn(right, valueRight, () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _segBtn(String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white.withOpacity(0.30) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;

  _BarChartPainter({required this.values, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final maxVal =
        (values.reduce((a, b) => a > b ? a : b)).clamp(1, double.infinity);
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..strokeWidth = 1;

    // Grid lines (4)
    for (int i = 1; i <= 4; i++) {
      final y = size.height * (1 - i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final count = values.length;
    final gap = 10.0;
    final barWidth = (size.width - gap * (count + 1)) / count;

    final labelPainter = TextPainter(textDirection: TextDirection.ltr);
    final valuePainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < count; i++) {
      final v = values[i];
      final h = (v / maxVal) * (size.height - 32); // leave space for labels
      final x = gap + i * (barWidth + gap);

      final barRect = Rect.fromLTWH(
        x,
        size.height - h - 22,
        barWidth,
        h,
      );

      final barPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xFFFFB74D), Color(0xFFFFE082)],
        ).createShader(barRect);

      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, const Radius.circular(8)),
        barPaint,
      );

      // value label (grams)
      valuePainter.text = TextSpan(
        text: v.toInt().toString(),
        style: const TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      );
      valuePainter.layout();
      valuePainter.paint(
        canvas,
        Offset(
          x + (barWidth - valuePainter.width) / 2,
          size.height - h - 34,
        ),
      );

      // day label
      labelPainter.text = TextSpan(
        text: labels[i],
        style: const TextStyle(
          fontSize: 10,
          color: Colors.white70,
        ),
      );
      labelPainter.layout();
      labelPainter.paint(
        canvas,
        Offset(
          x + (barWidth - labelPainter.width) / 2,
          size.height - 16,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) =>
      old.values != values || old.labels != labels;
}

/* ------------------------------ Nearby Card ------------------------------ */

class _NearbyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _CardTitle(text: "Recommended Nearby"),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.lightBlueAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.26)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.location_on, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      "~0.3 mi",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MapScreen()),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.1),
                ),
                child: const Image(
                  image: AssetImage('assets/map_placeholder.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _RestaurantTile(
            name: "McDonald's",
            logoUrl:
                'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2e/McDonald%27s_logo.svg/1200px-McDonald%27s_logo.svg.png',
            rating: 4.1,
            timeAway: "5 min",
          ),
          const SizedBox(height: 12),
          const _RestaurantTile(
            name: "Subway",
            logoUrl:
                'https://upload.wikimedia.org/wikipedia/commons/thumb/7/70/Subway_2016_logo.svg/2560px-Subway_2016_logo.svg.png',
            rating: 4.0,
            timeAway: "7 min",
          ),
        ],
      ),
    );
  }
}

class _RestaurantTile extends StatelessWidget {
  final String name;
  final String logoUrl;
  final double rating;
  final String timeAway;

  const _RestaurantTile({
    required this.name,
    required this.logoUrl,
    required this.rating,
    required this.timeAway,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 56,
              height: 56,
              color: Colors.white,
              child: CachedNetworkImage(
                imageUrl: logoUrl,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.restaurant, color: Colors.black54),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      "$rating",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.schedule,
                        color: Colors.white70, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      "$timeAway away",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* --------------------------------- Utils -------------------------------- */

class _GlassCard extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final Widget child;

  const _GlassCard({required this.padding, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  final String text;
  const _CardTitle({required this.text});
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 20,
      ),
    );
  }
}

/* ------------------------- Helpers: Edit Goal Dialog --------------------- */

Future<void> _showEditCalorieGoalDialog(
    BuildContext context, int currentGoal) async {
  final controller = TextEditingController(text: currentGoal.toString());
  final formKey = GlobalKey<FormState>();

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.grey.shade900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Text(
        "Set Calorie Goal",
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(
            signed: false,
            decimal: false,
          ),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "e.g. 2200",
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.tealAccent),
            ),
          ),
          validator: (text) {
            final n = int.tryParse(text ?? "");
            if (n == null) return "Enter a valid number";
            if (n < 500 || n > 5000) {
              return "Goal must be 500–5000";
            }
            return null;
          },
          onFieldSubmitted: (_) {
            if (formKey.currentState!.validate()) {
              final n = int.parse(controller.text);
              context.read<CalorieTrackerProvider>().setCalorieGoal(n);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Calorie goal updated to $n"),
                ),
              );
            }
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              final n = int.parse(controller.text);
              context.read<CalorieTrackerProvider>().setCalorieGoal(n);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Calorie goal updated to $n"),
                ),
              );
            }
          },
          child: const Text("Save"),
        ),
      ],
    ),
  );
}
