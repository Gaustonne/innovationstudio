import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'ingredient_overview_screen.dart';
import '../models/ingredient.dart';

class MealPlanScreen extends StatefulWidget {
  final List<Ingredient> ingredients;
  final Map<String, Map<String, List<Ingredient>>> weeklyMealPlan;

  const MealPlanScreen({
    super.key,
    required this.ingredients,
    required this.weeklyMealPlan,
  });

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  late Map<String, Map<String, List<Ingredient>>> _weeklyMealPlan;
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _weeklyMealPlan = widget.weeklyMealPlan;
  }

  void _addIngredient(String day, String meal, Ingredient ingredient) {
    setState(() {
      _weeklyMealPlan[day]![meal]!.add(ingredient);
    });
  }

  Future<void> _pickIngredient(String day, String meal) async {
    final pickedIngredient = await Navigator.push<Ingredient>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            IngredientOverviewScreen(ingredients: widget.ingredients),
      ),
    );

    if (pickedIngredient != null) {
      _addIngredient(day, meal, pickedIngredient);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Meal Plan')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: _weeklyMealPlan.entries.map((dayEntry) {
          final day = dayEntry.key;
          final meals = dayEntry.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                day,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...meals.entries.map((mealEntry) {
                final meal = mealEntry.key;
                final ingredients = mealEntry.value;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(meal,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      ...ingredients.map((ing) => Text(
                          "${ing.name} - ${ing.weightKg} kg, Qty: ${ing.quantity} (Expiry: ${_dateFormat.format(ing.expiry)})")),
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text("Add item"),
                        onPressed: () => _pickIngredient(day, meal),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(),
            ],
          );
        }).toList(),
      ),
    );
  }
}