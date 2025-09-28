import 'ingredient.dart';

class Recipe {
  final String id;
  final String name;
  final String description;
  final List<Ingredient> ingredients;
  final List<String> instructions;
  final int servings;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final String difficulty;
  final List<String> tags;

  const Recipe({
    required this.id,
    required this.name,
    required this.description,
    required this.ingredients,
    required this.instructions,
    this.servings = 4,
    this.prepTimeMinutes = 30,
    this.cookTimeMinutes = 30,
    this.difficulty = 'Medium',
    this.tags = const [],
  });

  Recipe copyWith({
    String? id,
    String? name,
    String? description,
    List<Ingredient>? ingredients,
    List<String>? instructions,
    int? servings,
    int? prepTimeMinutes,
    int? cookTimeMinutes,
    String? difficulty,
    List<String>? tags,
  }) {
    return Recipe(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      servings: servings ?? this.servings,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      cookTimeMinutes: cookTimeMinutes ?? this.cookTimeMinutes,
      difficulty: difficulty ?? this.difficulty,
      tags: tags ?? this.tags,
    );
  }

  int get totalTimeMinutes => prepTimeMinutes + cookTimeMinutes;

  /// Scale recipe ingredients for a different number of servings
  Recipe scaleForServings(int newServings) {
    final scaleFactor = newServings / servings;
    final scaledIngredients = ingredients.map((ingredient) =>
      ingredient.copyWith(quantity: ingredient.quantity * scaleFactor)
    ).toList();

    return copyWith(
      ingredients: scaledIngredients,
      servings: newServings,
    );
  }

  @override
  String toString() {
    return 'Recipe(name: $name, servings: $servings, ingredients: ${ingredients.length})';
  }
}