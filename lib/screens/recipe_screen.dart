import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../models/recipe_data.dart';
import '../models/ingredient.dart';

class RecipeScreen extends StatefulWidget {
  final List<Ingredient> userIngredients;
  final Map<String, Map<String, List<Ingredient>>> weeklyMealPlan;

  const RecipeScreen({
    super.key,
    required this.userIngredients,
    required this.weeklyMealPlan,
  });

  @override
  State<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends State<RecipeScreen> {
  List<Recipe> filteredRecipes = [];
  List<String> selectedTags = [];
  String? selectedRuleType;
  int maxCookTime = 60;

  @override
  void initState() {
    super.initState();
    filteredRecipes = List.from(seededRecipes);
    filterRecipes(); // Apply scoring on initial load
  }

  void filterRecipes() {
    setState(() {
      // 1. Filter by tags, diet, cook time
      filteredRecipes = seededRecipes.where((recipe) {
        final matchesTags =
            selectedTags.isEmpty || recipe.tags.any((tag) => selectedTags.contains(tag));
        final matchesRule =
            selectedRuleType == null || recipe.ruleType == selectedRuleType;
        final matchesTime = recipe.cookTimeMinutes <= maxCookTime;
        return matchesTags && matchesRule && matchesTime;
      }).toList();

      // 2. Apply ingredient-based scoring (friend's feature)
      final userIngredientNames =
          widget.userIngredients.map((i) => i.name.toLowerCase()).toSet();

      filteredRecipes = filteredRecipes.map((recipe) {
        final lowerRecipeIngredients =
            recipe.ingredients.map((i) => i.toLowerCase()).toList();
        final matched =
            lowerRecipeIngredients.where((i) => userIngredientNames.contains(i)).toList();
        final missing =
            lowerRecipeIngredients.where((i) => !userIngredientNames.contains(i)).toList();

        // Safely store extra info in Recipe.extra
        recipe.extra = {
          'matchedCount': matched.length,
          'missingIngredients': missing,
        };

        return recipe;
      }).toList();

      // 3. Sort by least missing ingredients first
      filteredRecipes.sort((a, b) {
        int missingA = (a.extra?['missingIngredients'] as List?)?.length ?? 0;
        int missingB = (b.extra?['missingIngredients'] as List?)?.length ?? 0;
        return missingA.compareTo(missingB);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final allTags = seededRecipes.expand((r) => r.tags).toSet().toList();
    final allRuleTypes = seededRecipes.map((r) => r.ruleType).toSet().toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Recipes')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Filters row
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    hint: const Text('Select Diet'),
                    value: selectedRuleType,
                    items: [null, ...allRuleTypes].map((rule) {
                      return DropdownMenuItem<String>(
                        value: rule,
                        child: Text(rule ?? 'All'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      selectedRuleType = value;
                      filterRecipes();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    children: allTags.map((tag) {
                      final selected = selectedTags.contains(tag);
                      return FilterChip(
                        label: Text(tag),
                        selected: selected,
                        onSelected: (s) {
                          if (s) {
                            selectedTags.add(tag);
                          } else {
                            selectedTags.remove(tag);
                          }
                          filterRecipes();
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),

            // Cook time slider
            Slider(
              value: maxCookTime.toDouble(),
              min: 0,
              max: 120,
              divisions: 24,
              label: '$maxCookTime min',
              onChanged: (value) {
                setState(() {
                  maxCookTime = value.toInt();
                  filterRecipes();
                });
              },
            ),
            const SizedBox(height: 12),

            // Recipe list
            Expanded(
              child: filteredRecipes.isEmpty
                  ? const Center(child: Text('No recipes found.'))
                  : ListView.builder(
                      itemCount: filteredRecipes.length,
                      itemBuilder: (context, index) {
                        final recipe = filteredRecipes[index];
                        final missing = recipe.extra?['missingIngredients'] ?? [];
                        final matchedCount = recipe.extra?['matchedCount'] ?? 0;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            title: Text(recipe.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Ingredients: ${recipe.ingredients.join(', ')}'),
                                Text('Cook Time: ${recipe.cookTimeMinutes} min'),
                                Text('Tags: ${recipe.tags.join(', ')}'),
                                Text('Diet: ${recipe.ruleType}'),
                                if (missing.isNotEmpty)
                                  Text(
                                    'Missing Ingredients: ${missing.join(', ')} (Matched: $matchedCount/${recipe.ingredients.length})',
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
