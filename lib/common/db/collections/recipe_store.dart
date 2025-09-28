import 'package:sqflite/sqflite.dart';
import '../../../features/recipes/domain/recipe.dart';
import '../db.dart';

class RecipeStore {
  Future<void> insert(Recipe recipe) async {
    final db = await AppDatabase.instance;
    await db.transaction((txn) async {
      await txn.insert(
        'recipes',
        recipe.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (final ingredient in recipe.ingredients) {
        await txn.insert(
          'recipe_ingredients',
          {'recipeId': recipe.id, 'name': ingredient},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<Recipe>> getAll() async {
    final db = await AppDatabase.instance;
    final recipeMaps = await db.query('recipes');
    final recipes = <Recipe>[];

    for (final recipeMap in recipeMaps) {
      final ingredientMaps = await db.query(
        'recipe_ingredients',
        where: 'recipeId = ?',
        whereArgs: [recipeMap['id']],
      );
      final ingredients =
          ingredientMaps.map((map) => map['name'] as String).toList();
      recipes.add(Recipe.fromMap(recipeMap, ingredients));
    }

    return recipes;
  }
}
