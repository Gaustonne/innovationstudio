import 'package:uuid/uuid.dart';

class Recipe {
  final String id;
  final String name;
  final List<String> ingredients;
  final int cookTimeMinutes;
  final List<String> tags;
  final String ruleType;

  Map<String, dynamic>? extra;

  Recipe({
    String? id,
    required this.name,
    required this.ingredients,
    required this.cookTimeMinutes,
    required this.tags,
    required this.ruleType,
    this.extra,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'cookTimeMinutes': cookTimeMinutes,
      'tags': tags.join(','),
      'ruleType': ruleType,
    };
  }

  factory Recipe.fromMap(Map<String, dynamic> map, List<String> ingredients) {
    return Recipe(
      id: map['id'],
      name: map['name'],
      cookTimeMinutes: map['cookTimeMinutes'],
      tags: (map['tags'] as String).split(','),
      ruleType: map['ruleType'],
      ingredients: ingredients,
    );
  }
}
