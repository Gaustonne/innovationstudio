import 'package:uuid/uuid.dart';

class MealPlan {
  final String id;
  final String title;
  final String description;
  final int prepTimeMinutes;
  final List<String> tags;

  MealPlan({
    String? id,
    required this.title,
    required this.description,
    required this.prepTimeMinutes,
    required this.tags,
  }) : id = id ?? Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'prepTimeMinutes': prepTimeMinutes,
      'tags': tags.join(','),
    };
  }

  factory MealPlan.fromMap(Map<String, dynamic> map) {
    return MealPlan(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      prepTimeMinutes: map['prepTimeMinutes'] as int,
      tags: (map['tags'] as String).split(','),
    );
  }
}
