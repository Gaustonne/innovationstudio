import 'recipe.dart';

final List<Recipe> seededRecipes = [
  Recipe(
    name: 'Vegan Salad',
    ingredients: ['Lettuce', 'Tomato', 'Cucumber'],
    cookTimeMinutes: 10,
    tags: ['Easy', 'Quick'],
    ruleType: 'Vegan',
  ),
  Recipe(
    name: 'Chicken Curry',
    ingredients: ['Chicken', 'Onion', 'Spices'],
    cookTimeMinutes: 45,
    tags: ['Medium', 'Spicy'],
    ruleType: 'Halal',
  ),
  Recipe(
    name: 'Pasta Primavera',
    ingredients: ['Pasta', 'Tomato', 'Zucchini', 'Cheese'],
    cookTimeMinutes: 25,
    tags: ['Easy'],
    ruleType: 'Vegetarian',
  ),
  Recipe(
    name: 'Fruit Smoothie',
    ingredients: ['Banana', 'Strawberry', 'Almond Milk'],
    cookTimeMinutes: 5,
    tags: ['Quick', 'Easy'],
    ruleType: 'Vegan',
  ),
];
