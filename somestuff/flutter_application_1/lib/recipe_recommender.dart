import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RecipeRecommenderPage extends StatefulWidget {
  @override
  _RecipeRecommenderPageState createState() => _RecipeRecommenderPageState();
}

class _RecipeRecommenderPageState extends State<RecipeRecommenderPage> {
  Future<Map<String, dynamic>?> fetchRecipeDetails(String idMeal) async {
    final url = Uri.parse('https://www.themealdb.com/api/json/v1/1/lookup.php?i=$idMeal');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['meals'] != null && data['meals'].isNotEmpty) {
        return data['meals'][0];
      }
    }
    return null;
  }
  List<dynamic> savedRecipes = [];
  final List<String> ingredients = [
    'Tomato',
    'Cheese',
    'Chicken',
    'Lettuce',
    'Egg',
    'Bread',
    'Onion',
    'Beef',
    'Potato',
  ];

  Set<String> selectedIngredients = {};
  List<dynamic> recipes = [];
  bool isLoading = false;

  Future<void> fetchRecipes() async {
    if (selectedIngredients.isEmpty) {
      setState(() {
        recipes = [];
      });
      return;
    }
    setState(() {
      isLoading = true;
    });
    final ingredient = selectedIngredients.first;
    final url = Uri.parse('https://www.themealdb.com/api/json/v1/1/filter.php?i=$ingredient');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        recipes = data['meals'] ?? [];
        isLoading = false;
      });
    } else {
      setState(() {
        recipes = [];
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Recipe Recommender')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Ingredients:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8.0,
              children: ingredients.map((ingredient) {
                final isSelected = selectedIngredients.contains(ingredient);
                return FilterChip(
                  label: Text(ingredient),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        selectedIngredients.add(ingredient);
                      } else {
                        selectedIngredients.remove(ingredient);
                      }
                    });
                    fetchRecipes();
                  },
                );
              }).toList(),
            ),
            SizedBox(height: 24),
            Text('Recommended Recipes:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (isLoading)
              Center(child: CircularProgressIndicator()),
            if (!isLoading && recipes.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('No recipes found for selected ingredient.', style: TextStyle(color: Colors.grey)),
              ),
            if (!isLoading)
              ...recipes.map((recipe) => ListTile(
                    leading: recipe['strMealThumb'] != null
                        ? Image.network(recipe['strMealThumb'], width: 50, height: 50, fit: BoxFit.cover)
                        : null,
                    title: Text(recipe['strMeal'] ?? ''),
                    subtitle: Text('ID: ${recipe['idMeal'] ?? ''}'),
                    trailing: IconButton(
                      icon: Icon(
                        savedRecipes.any((r) => r['idMeal'] == recipe['idMeal'])
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        color: Colors.deepPurple,
                      ),
                      onPressed: () {
                        setState(() {
                          if (savedRecipes.any((r) => r['idMeal'] == recipe['idMeal'])) {
                            savedRecipes.removeWhere((r) => r['idMeal'] == recipe['idMeal']);
                          } else {
                            savedRecipes.add(recipe);
                          }
                        });
                      },
                    ),
                    onTap: () async {
                      final details = await fetchRecipeDetails(recipe['idMeal']);
                      if (details != null) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(details['strMeal'] ?? ''),
                            content: Text('Category: ${details['strCategory'] ?? 'N/A'}'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Close'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  )),
            SizedBox(height: 32),
            if (savedRecipes.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Saved Recipes:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ...savedRecipes.map((recipe) => Card(
                        child: ListTile(
                          leading: recipe['strMealThumb'] != null
                              ? Image.network(recipe['strMealThumb'], width: 50, height: 50, fit: BoxFit.cover)
                              : null,
                          title: Text(recipe['strMeal'] ?? ''),
                          onTap: () async {
                            final details = await fetchRecipeDetails(recipe['idMeal']);
                            if (details != null) {
                              // Collect ingredients and measures
                              List<String> ingredients = [];
                              for (int i = 1; i <= 20; i++) {
                                final ingredient = details['strIngredient$i'];
                                final measure = details['strMeasure$i'];
                                if (ingredient != null && ingredient.isNotEmpty) {
                                  ingredients.add('$ingredient: ${measure ?? ''}');
                                }
                              }
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(details['strMeal'] ?? ''),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (details['strInstructions'] != null)
                                          Text('Instructions:\n${details['strInstructions']}'),
                                        SizedBox(height: 12),
                                        Text('Ingredients & Measures:'),
                                        ...ingredients.map((e) => Text(e)),
                                        SizedBox(height: 12),
                                        if (details['strYoutube'] != null && details['strYoutube'].isNotEmpty)
                                          InkWell(
                                            child: Text('YouTube Video', style: TextStyle(color: Colors.blue)),
                                            onTap: () {
                                              Navigator.pop(context);
                                              showDialog(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: Text('YouTube Link'),
                                                  content: SelectableText(details['strYoutube']),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context),
                                                      child: Text('Close'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text('Close'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                        ),
                      )),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
