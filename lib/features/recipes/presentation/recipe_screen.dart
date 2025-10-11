import 'package:flutter/material.dart';
import '../../../common/db/collections/shopping_list_store.dart';
import '../../../common/db/models/shopping_list_item.dart';
import '../data/recipe_service.dart';
import '../domain/recipe.dart';
import '../../../common/db/models/ingredient.dart';

class RecipeScreen extends StatefulWidget {
  final List<Ingredient> userIngredients;
  final VoidCallback? onShoppingListUpdated;

  const RecipeScreen({
    super.key,
    required this.userIngredients,
    this.onShoppingListUpdated,
  });

  @override
  State<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends State<RecipeScreen> {
  final RecipeService _recipeService = RecipeService();
  List<Recipe> _allRecipes = [];
  List<Recipe> filteredRecipes = [];
  List<String> selectedTags = [];
  String? selectedRuleType;
  int maxCookTime = 240; // API doesn't provide cook time, so this is a placeholder
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRecipes();
  }

  Future<void> _fetchRecipes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final ingredientNames = widget.userIngredients.map((i) => i.name).toList();
      _allRecipes = await _recipeService.getRecipes(ingredientNames);
      filterRecipes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load recipes: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void filterRecipes() {
    setState(() {
      // 1. Filter by tags, diet
      filteredRecipes = _allRecipes.where((recipe) {
        final matchesTags =
            selectedTags.isEmpty || recipe.tags.any((tag) => selectedTags.contains(tag));
        final matchesRule =
            selectedRuleType == null || recipe.ruleType == selectedRuleType;
        return matchesTags && matchesRule;
      }).toList();

      // 2. Apply ingredient-based scoring and filtering
      final userIngredientNames =
          widget.userIngredients.map((i) => i.name.toLowerCase()).toSet();

      filteredRecipes = filteredRecipes.map((recipe) {
        final lowerRecipeIngredients =
            recipe.ingredients.map((i) => i.toLowerCase()).toList();
        final matched =
            lowerRecipeIngredients.where((i) => userIngredientNames.contains(i)).toList();
        final missing =
            lowerRecipeIngredients.where((i) => !userIngredientNames.contains(i)).toList();

        recipe.extra = {
          'matchedCount': matched.length,
          'missingIngredients': missing,
          'matchedIngredients': matched,
        };

        return recipe;
      }).where((recipe) {
        final matchedCount = recipe.extra?['matchedCount'] as int? ?? 0;
        return matchedCount > 0;
      }).toList();

      // 3. Sort by most matched ingredients first, then by least missing
      filteredRecipes.sort((a, b) {
        final matchedA = a.extra?['matchedCount'] as int? ?? 0;
        final matchedB = b.extra?['matchedCount'] as int? ?? 0;
        
        if (matchedA != matchedB) {
          return matchedB.compareTo(matchedA);
        }

        final missingA = (a.extra?['missingIngredients'] as List?)?.length ?? 0;
        final missingB = (b.extra?['missingIngredients'] as List?)?.length ?? 0;
        return missingA.compareTo(missingB);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final allTags = _allRecipes.expand((r) => r.tags).toSet().toList();
    final allRuleTypes = _allRecipes.map((r) => r.ruleType).toSet().toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Recipes')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
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
            // Slider(
            //   value: maxCookTime.toDouble(),
            //   min: 0,
            //   max: 120,
            //   divisions: 24,
            //   label: '$maxCookTime min',
            //   onChanged: (value) {
            //     setState(() {
            //       maxCookTime = value.toInt();
            //       filterRecipes();
            //     });
            //   },
            // ),
            const SizedBox(height: 12),

            // Recipe list
            Expanded(
              child: filteredRecipes.isEmpty
                  ? const Center(child: Text('No recipes found.'))
                  : ListView.builder(
                      itemCount: filteredRecipes.length,
                      itemBuilder: (context, index) {
                        final recipe = filteredRecipes[index];
                        final missing = recipe.extra?['missingIngredients'] as List? ?? [];
                        final matched = recipe.extra?['matchedIngredients'] as List? ?? [];

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: recipe.imageUrl != null
                                ? Image.network(recipe.imageUrl!)
                                : null,
                            title: Text(recipe.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Tags: ${recipe.tags.join(', ')}'),
                                Text('Diet: ${recipe.ruleType}'),
                                if (matched.isNotEmpty)
                                  Text(
                                    'Matched: ${matched.join(', ')}',
                                    style: const TextStyle(color: Colors.green),
                                  ),
                                if (missing.isNotEmpty)
                                  Text(
                                    'Missing: ${missing.join(', ')} (${matched.length}/${recipe.ingredients.length})',
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                if (missing.isNotEmpty)
                                  ElevatedButton(
                                    onPressed: () async {
                                      final store = ShoppingListStore();
                                      for (final ingredientName in missing) {
                                        await store.insert(ShoppingListItem(
                                          name: ingredientName,
                                          quantity: 1,
                                          unit: 'unit',
                                        ));
                                      }
                                      widget.onShoppingListUpdated?.call();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Added ${missing.length} ingredients to your shopping list.',
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text('Add Missing to Shopping List'),
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
