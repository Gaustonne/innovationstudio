import '../models/ingredient.dart';
import '../models/pantry_item.dart';
import '../models/recipe.dart';

class DemoDataProvider {
  static List<Recipe> getSampleRecipes() {
    return [
      Recipe(
        id: '1',
        name: 'Spaghetti Carbonara',
        description: 'Classic Italian pasta dish with eggs, cheese, and pancetta',
        servings: 4,
        prepTimeMinutes: 15,
        cookTimeMinutes: 20,
        difficulty: 'Medium',
        tags: ['Italian', 'Pasta', 'Dinner'],
        ingredients: [
          const Ingredient(
            id: '1',
            name: 'Spaghetti',
            quantity: 400,
            unit: 'g',
            packSize: 500,
            category: 'Pantry',
          ),
          const Ingredient(
            id: '2',
            name: 'Eggs',
            quantity: 4,
            unit: 'pieces',
            packSize: 12,
            category: 'Dairy',
          ),
          const Ingredient(
            id: '3',
            name: 'Pancetta',
            quantity: 150,
            unit: 'g',
            packSize: 100,
            category: 'Meat',
          ),
          const Ingredient(
            id: '4',
            name: 'Parmesan Cheese',
            quantity: 100,
            unit: 'g',
            packSize: 200,
            category: 'Dairy',
          ),
          const Ingredient(
            id: '5',
            name: 'Black Pepper',
            quantity: 5,
            unit: 'g',
            packSize: 50,
            category: 'Spices',
          ),
        ],
        instructions: [
          'Bring a large pot of salted water to boil',
          'Cook spaghetti according to package instructions',
          'Meanwhile, cook pancetta until crispy',
          'Beat eggs with grated Parmesan and black pepper',
          'Drain pasta, reserving some pasta water',
          'Mix hot pasta with egg mixture, adding pasta water if needed',
          'Add crispy pancetta and serve immediately',
        ],
      ),
      Recipe(
        id: '2',
        name: 'Caesar Salad',
        description: 'Fresh romaine lettuce with Caesar dressing and croutons',
        servings: 4,
        prepTimeMinutes: 20,
        cookTimeMinutes: 0,
        difficulty: 'Easy',
        tags: ['Salad', 'Vegetarian', 'Lunch'],
        ingredients: [
          const Ingredient(
            id: '6',
            name: 'Romaine Lettuce',
            quantity: 2,
            unit: 'heads',
            packSize: 1,
            category: 'Vegetables',
          ),
          const Ingredient(
            id: '4',
            name: 'Parmesan Cheese',
            quantity: 50,
            unit: 'g',
            packSize: 200,
            category: 'Dairy',
          ),
          const Ingredient(
            id: '7',
            name: 'Bread',
            quantity: 4,
            unit: 'slices',
            packSize: 20,
            category: 'Bakery',
          ),
          const Ingredient(
            id: '8',
            name: 'Olive Oil',
            quantity: 60,
            unit: 'ml',
            packSize: 500,
            category: 'Pantry',
          ),
          const Ingredient(
            id: '9',
            name: 'Lemon',
            quantity: 1,
            unit: 'pieces',
            packSize: 1,
            category: 'Produce',
          ),
          const Ingredient(
            id: '10',
            name: 'Garlic',
            quantity: 2,
            unit: 'cloves',
            packSize: 1,
            category: 'Vegetables',
          ),
        ],
        instructions: [
          'Wash and chop romaine lettuce',
          'Make croutons by toasting bread cubes with olive oil',
          'Prepare Caesar dressing with garlic, lemon, and oil',
          'Toss lettuce with dressing',
          'Top with croutons and grated Parmesan',
        ],
      ),
      Recipe(
        id: '3',
        name: 'Chicken Stir Fry',
        description: 'Quick and healthy chicken with mixed vegetables',
        servings: 4,
        prepTimeMinutes: 15,
        cookTimeMinutes: 15,
        difficulty: 'Easy',
        tags: ['Asian', 'Healthy', 'Quick'],
        ingredients: [
          const Ingredient(
            id: '11',
            name: 'Chicken Breast',
            quantity: 500,
            unit: 'g',
            packSize: 400,
            category: 'Meat',
          ),
          const Ingredient(
            id: '12',
            name: 'Bell Peppers',
            quantity: 2,
            unit: 'pieces',
            packSize: 1,
            category: 'Vegetables',
          ),
          const Ingredient(
            id: '13',
            name: 'Broccoli',
            quantity: 300,
            unit: 'g',
            packSize: 400,
            category: 'Vegetables',
          ),
          const Ingredient(
            id: '14',
            name: 'Soy Sauce',
            quantity: 60,
            unit: 'ml',
            packSize: 250,
            category: 'Condiments',
          ),
          const Ingredient(
            id: '10',
            name: 'Garlic',
            quantity: 3,
            unit: 'cloves',
            packSize: 1,
            category: 'Vegetables',
          ),
          const Ingredient(
            id: '8',
            name: 'Olive Oil',
            quantity: 30,
            unit: 'ml',
            packSize: 500,
            category: 'Pantry',
          ),
        ],
        instructions: [
          'Cut chicken into bite-sized pieces',
          'Chop vegetables into uniform pieces',
          'Heat oil in a wok or large pan',
          'Stir-fry chicken until cooked through',
          'Add vegetables and cook until tender-crisp',
          'Add soy sauce and garlic, toss to combine',
          'Serve immediately over rice',
        ],
      ),
    ];
  }

  static List<PantryItem> getSamplePantryItems() {
    return [
      const PantryItem(
        id: 'p1',
        name: 'Spaghetti',
        quantity: 200,
        unit: 'g',
        category: 'Pantry',
      ),
      const PantryItem(
        id: 'p2',
        name: 'Eggs',
        quantity: 8,
        unit: 'pieces',
        category: 'Dairy',
      ),
      const PantryItem(
        id: 'p3',
        name: 'Olive Oil',
        quantity: 400,
        unit: 'ml',
        category: 'Pantry',
      ),
      const PantryItem(
        id: 'p4',
        name: 'Garlic',
        quantity: 5,
        unit: 'cloves',
        category: 'Vegetables',
      ),
      const PantryItem(
        id: 'p5',
        name: 'Black Pepper',
        quantity: 40,
        unit: 'g',
        category: 'Spices',
      ),
    ];
  }

  /// Get a subset of recipes for meal planning demo
  static List<Recipe> getWeeklyMealPlan() {
    final allRecipes = getSampleRecipes();
    return [
      allRecipes[0], // Carbonara
      allRecipes[2], // Stir Fry
    ];
  }
}