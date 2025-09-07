import 'package:flutter/material.dart';
import 'screens/meal_plan_screen.dart';
import 'screens/add_ingredient_screen.dart';
import 'screens/ingredient_overview_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meal Planner',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Shared ingredient list
  final List<Map<String, String>> _ingredients = [
    {'name': 'Lobster', 'amount': '350 grams', 'expiry': '2025-12-02'},
    {'name': 'Spinach', 'amount': '200 grams', 'expiry': '2025-09-15'},
    {'name': 'Rice', 'amount': '1 kg', 'expiry': '2025-10-01'},
  ];

  // Lifted weekly meal plan
  final Map<String, Map<String, List<Map<String, String>>>> _weeklyMealPlan = {
    'Monday': {'Breakfast': [], 'Lunch': [], 'Dinner': []},
    'Tuesday': {'Breakfast': [], 'Lunch': [], 'Dinner': []},
    'Wednesday': {'Breakfast': [], 'Lunch': [], 'Dinner': []},
    'Thursday': {'Breakfast': [], 'Lunch': [], 'Dinner': []},
    'Friday': {'Breakfast': [], 'Lunch': [], 'Dinner': []},
    'Saturday': {'Breakfast': [], 'Lunch': [], 'Dinner': []},
    'Sunday': {'Breakfast': [], 'Lunch': [], 'Dinner': []},
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meal Planner Home')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        IngredientOverviewScreen(ingredients: _ingredients),
                  ),
                );
                setState(() {}); // Refresh after returning
              },
              child: const Text('Ingredient Overview'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MealPlanScreen(
                      ingredients: _ingredients,
                      weeklyMealPlan: _weeklyMealPlan, // pass shared meal plan
                    ),
                  ),
                );
              },
              child: const Text('View Meal Plan'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        IngredientListScreen(ingredients: _ingredients),
                  ),
                );
                setState(() {}); // Refresh after adding
              },
              child: const Text('Add Ingredient'),
            ),
          ],
        ),
      ),
    );
  }
}
