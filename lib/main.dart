import 'package:flutter/material.dart';
import 'screens/meal_plan_screen.dart';
import 'screens/add_ingredient_screen.dart';
import 'screens/ingredient_overview_screen.dart';
import 'screens/recipe_screen.dart';
import 'models/ingredient.dart';

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
  // Shared ingredient list (dummy data)
  final List<Ingredient> _ingredients = [
    Ingredient(
      name: 'Lobster',
      weightKg: 1,
      quantity: 2,
      expiry: DateTime.parse('2025-12-02'),
    ),
    Ingredient(
      name: 'Spinach',
      weightKg: 0.5,
      quantity: 1,
      expiry: DateTime.parse('2025-09-15'),
    ),
    Ingredient(
      name: 'Rice',
      weightKg: 1.0,
      quantity: 3,
      expiry: DateTime.parse('2025-10-01'),
    ),
  ];

  // Shared weekly meal plan
  final Map<String, Map<String, List<Ingredient>>> _weeklyMealPlan = {
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => IngredientOverviewScreen(
                                ingredients: _ingredients),
                          ),
                        );
                        setState(() {});
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
                              weeklyMealPlan: _weeklyMealPlan,
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
                                AddIngredientScreen(ingredients: _ingredients),
                          ),
                        );
                        setState(() {});
                      },
                      child: const Text('Add Ingredient'),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecipeScreen(
                              userIngredients: _ingredients,
                              weeklyMealPlan: _weeklyMealPlan,
                            ),
                          ),
                        );
                      },
                      child: const Text('View Recipes'),
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
