import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/recipe.dart';

class RecipeService {
  static const String _apiKey = '1'; // TheMealDB provides a test API key '1'
  static const String _baseUrl = 'https://www.themealdb.com/api/json/v1/$_apiKey/filter.php';

  Future<List<Recipe>> getRecipes(List<String> ingredients) async {
    if (ingredients.isEmpty) {
      return [];
    }

    // TheMealDB API can only filter by one main ingredient.
    // We'll use the first ingredient for the query.
    final response = await http.get(Uri.parse('$_baseUrl?i=${ingredients.first}'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['meals'] != null) {
        final List<dynamic> meals = data['meals'];
        // The filter.php endpoint doesn't return full recipe details,
        // so we need to fetch each recipe individually.
        List<Recipe> recipes = [];
        for (var meal in meals) {
          final recipe = await _getRecipeDetails(meal['idMeal']);
          if (recipe != null) {
            recipes.add(recipe);
          }
        }
        return recipes;
      }
    }
    return [];
  }

  Future<Recipe?> _getRecipeDetails(String mealId) async {
    final response = await http.get(Uri.parse('https://www.themealdb.com/api/json/v1/$_apiKey/lookup.php?i=$mealId'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['meals'] != null && data['meals'].isNotEmpty) {
        final mealData = data['meals'][0];
        
        List<String> ingredients = [];
        for (int i = 1; i <= 20; i++) {
          if (mealData['strIngredient$i'] != null && mealData['strIngredient$i'].isNotEmpty) {
            ingredients.add(mealData['strIngredient$i']);
          }
        }

        return Recipe(
          name: mealData['strMeal'],
          ingredients: ingredients,
          cookTimeMinutes: 0, // API doesn't provide cook time
          tags: (mealData['strTags'] as String?)?.split(',') ?? [],
          ruleType: mealData['strCategory'] ?? '',
          imageUrl: mealData['strMealThumb'],
        );
      }
    }
    return null;
  }
}
