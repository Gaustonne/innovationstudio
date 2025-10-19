import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

import '../../../common/db/collections/meal_plan_store.dart';

enum MealType { breakfast, lunch, dinner }
String mealTypeToText(MealType m) =>
    m == MealType.breakfast ? 'Breakfast' : (m == MealType.lunch ? 'Lunch' : 'Dinner');

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  final store = MealPlanStore();
  final days = const ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
  final meals = const [MealType.breakfast, MealType.lunch, MealType.dinner];

  late DateTime weekStart; // Monday of current week
  // state: dayIndex -> mealType -> {recipeId, recipeName, servings}
  late Map<int, Map<MealType, Map<String, dynamic>?>> plan;

  bool loading = true;

  @override
  void initState() {
    super.initState();
    weekStart = _mondayOf(DateTime.now());
    plan = { for (var i = 0; i < 7; i++) i: { for (final m in meals) m: null } };
    _load();
  }

  Future<void> _load() async {
    final entries = await store.loadWeek(weekStart);
    setState(() {
      for (final e in entries) {
        final mt = _parseMeal(e.mealType);
        plan[e.dayIndex]![mt] = {
          'recipeId': e.recipeId,
          'recipeName': e.recipeName,
          'servings': e.servings,
        };
      }
      loading = false;
    });
  }

  MealType _parseMeal(String s) =>
      s == 'breakfast' ? MealType.breakfast : (s == 'lunch' ? MealType.lunch : MealType.dinner);

  String _mealKey(MealType m) => m == MealType.breakfast ? 'breakfast' : (m == MealType.lunch ? 'lunch' : 'dinner');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Meal Plan — ${_weekLabel(weekStart)}'),
        actions: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeWeek(-7)),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeWeek(7)),
          TextButton(
            onPressed: _save,
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: 7,
        separatorBuilder: (_, __) => const Divider(height: 28),
        itemBuilder: (_, di) => _buildDay(di),
      ),
    );
  }

  Widget _buildDay(int dayIndex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(days[dayIndex], style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final mt in meals) _buildSlot(dayIndex, mt),
      ],
    );
  }

  Widget _buildSlot(int di, MealType mt) {
    final data = plan[di]![mt];

    if (data == null) {
      return ListTile(
        dense: true,
        leading: const Icon(Icons.add),
        title: Text('Add ${mealTypeToText(mt)}'),
        onTap: () => _pickRecipe(di, mt),
      );
    }

    final servings = data['servings'] as int? ?? 2;
    final recipeName = data['recipeName'] as String? ?? 'Recipe';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(recipeName),
        subtitle: Text('${mealTypeToText(mt)}  •  Servings: $servings'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Decrease servings',
              onPressed: servings > 1
                  ? () => setState(() => plan[di]![mt]!['servings'] = servings - 1)
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text('$servings', style: const TextStyle(fontWeight: FontWeight.w600)),
            IconButton(
              tooltip: 'Increase servings',
              onPressed: () => setState(() => plan[di]![mt]!['servings'] = servings + 1),
              icon: const Icon(Icons.add_circle_outline),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'change') _pickRecipe(di, mt);
                if (v == 'remove') setState(() => plan[di]![mt] = null);
              },
              itemBuilder: (c) => const [
                PopupMenuItem(value: 'change', child: Text('Change recipe')),
                PopupMenuItem(value: 'remove', child: Text('Remove')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRecipe(int dayIndex, MealType mt) async {
    final selected = await showModalBottomSheet<Map<String, Object?>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RecipePicker(load: (q) => store.listRecipes(query: q)),
    );
    if (selected == null) return;

    setState(() {
      plan[dayIndex]![mt] = {
        'recipeId': selected['id'],
        'recipeName': selected['name'],
        'servings': 2,
      };
    });
  }

  Future<void> _save() async {
    final entries = <WeeklyPlanEntry>[];

    for (var di = 0; di < 7; di++) {
      for (final mt in meals) {
        final cell = plan[di]![mt];
        if (cell == null) continue;
        entries.add(WeeklyPlanEntry(
          dayIndex: di,
          mealType: _mealKey(mt),
          recipeId: cell['recipeId'] as String,
          recipeName: cell['recipeName'] as String,
          servings: (cell['servings'] as int?) ?? 2,
        ));
      }
    }

    await store.saveWholeWeek(weekStart, entries);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Meal plan saved')));
  }

  void _changeWeek(int deltaDays) async {
    setState(() {
      loading = true;
      plan = { for (var i = 0; i < 7; i++) i: { for (final m in meals) m: null } };
    });
    weekStart = _mondayOf(weekStart.add(Duration(days: deltaDays)));
    await _load();
  }

  DateTime _mondayOf(DateTime d) => d.subtract(Duration(days: d.weekday - 1));

  String _weekLabel(DateTime w) {
    String two(int n) => n.toString().padLeft(2, '0');
    final end = w.add(const Duration(days: 6));
    return '${two(w.day)}/${two(w.month)}—${two(end.day)}/${two(end.month)}';
  }
}

/// Bottom-sheet to pick a recipe (loads from DB; simple search)
class _RecipePicker extends StatefulWidget {
  final Future<List<Map<String, Object?>>> Function(String query) load;
  const _RecipePicker({required this.load});

  @override
  State<_RecipePicker> createState() => _RecipePickerState();
}

class _RecipePickerState extends State<_RecipePicker> {
  String query = '';
  List<Map<String, Object?>> items = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final rows = await widget.load(query);
    setState(() => items = rows);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              height: 4, width: 40, margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
            ),
            TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search recipes'),
              onChanged: (v) { query = v; _reload(); },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final r = items[i];
                  final name = (r['name'] as String?) ?? 'Recipe';
                  final mins = r['cookTimeMinutes']?.toString() ?? '';
                  final tags = (r['tags'] as String?) ?? '';
                  return Card(
                    child: ListTile(
                      title: Text(name),
                      subtitle: Text([if (mins.isNotEmpty) '$mins min', if (tags.isNotEmpty) tags].whereNotNull().join(' • ')),
                      onTap: () => Navigator.pop(context, r),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
