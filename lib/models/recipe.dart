class Recipe {
  final String name;
  final List<String> ingredients;
  final int cookTimeMinutes;
  final List<String> tags;
  final String ruleType;

  Map<String, dynamic>? extra;

  Recipe({
    required this.name,
    required this.ingredients,
    required this.cookTimeMinutes,
    required this.tags,
    required this.ruleType,
    this.extra,
  });
}