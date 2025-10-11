enum IngredientCategory {
  vegetables,
  fruits,
  meat,
  dairy,
  pantry,
  other,
}

class IngredientCategorizer {
  static const Map<String, IngredientCategory> _categoryMap = {
    // Vegetables
    'lettuce': IngredientCategory.vegetables,
    'tomato': IngredientCategory.vegetables,
    'cucumber': IngredientCategory.vegetables,
    'onion': IngredientCategory.vegetables,
    'zucchini': IngredientCategory.vegetables,
    'carrots': IngredientCategory.vegetables,
    'potatoes': IngredientCategory.vegetables,
    'bell pepper': IngredientCategory.vegetables,
    'broccoli': IngredientCategory.vegetables,
    'spinach': IngredientCategory.vegetables,
    'garlic': IngredientCategory.vegetables,

    // Fruits
    'banana': IngredientCategory.fruits,
    'strawberry': IngredientCategory.fruits,
    'apple': IngredientCategory.fruits,
    'orange': IngredientCategory.fruits,
    'lemon': IngredientCategory.fruits,
    'lime': IngredientCategory.fruits,

    // Meat
    'chicken': IngredientCategory.meat,
    'beef': IngredientCategory.meat,
    'pork': IngredientCategory.meat,
    'bacon': IngredientCategory.meat,
    'fish': IngredientCategory.meat,
    'salmon': IngredientCategory.meat,

    // Dairy
    'milk': IngredientCategory.dairy,
    'cheese': IngredientCategory.dairy,
    'butter': IngredientCategory.dairy,
    'yogurt': IngredientCategory.dairy,
    'cream': IngredientCategory.dairy,
    'sour cream': IngredientCategory.dairy,
    'almond milk': IngredientCategory.dairy,

    // Pantry
    'pasta': IngredientCategory.pantry,
    'rice': IngredientCategory.pantry,
    'flour': IngredientCategory.pantry,
    'sugar': IngredientCategory.pantry,
    'salt': IngredientCategory.pantry,
    'pepper': IngredientCategory.pantry,
    'spices': IngredientCategory.pantry,
    'olive oil': IngredientCategory.pantry,
    'vegetable oil': IngredientCategory.pantry,
    'soy sauce': IngredientCategory.pantry,
    'vinegar': IngredientCategory.pantry,
    'baking powder': IngredientCategory.pantry,
    'baking soda': IngredientCategory.pantry,
    'bread': IngredientCategory.pantry,
    'eggs': IngredientCategory.pantry,
  };

  static IngredientCategory categorize(String ingredient) {
    final lowerIngredient = ingredient.toLowerCase();
    for (var entry in _categoryMap.entries) {
      if (lowerIngredient.contains(entry.key)) {
        return entry.value;
      }
    }
    return IngredientCategory.other;
  }

  static Map<IngredientCategory, List<T>> categorizeList<T>(List<T> items, String Function(T) getName) {
    final categorized = <IngredientCategory, List<T>>{};
    for (var item in items) {
      final category = categorize(getName(item));
      (categorized[category] ??= []).add(item);
    }
    return categorized;
  }
}
