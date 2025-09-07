import 'package:flutter/material.dart';
import 'add_ingredient_screen.dart';

class IngredientOverviewScreen extends StatefulWidget {
  final List<Map<String, String>> ingredients; // shared ingredient list

  const IngredientOverviewScreen({super.key, required this.ingredients});

  @override
  State<IngredientOverviewScreen> createState() =>
      _IngredientOverviewScreenState();
}

class _IngredientOverviewScreenState extends State<IngredientOverviewScreen> {
  bool _isEditing = false;

  void _deleteIngredient(int index) {
    setState(() {
      widget.ingredients.removeAt(index);
    });
  }

  Future<void> _addNewIngredient() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IngredientListScreen(ingredients: widget.ingredients),
      ),
    );
    setState(() {}); // Refresh UI after returning
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ingredient Overview'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.done : Icons.edit),
            tooltip: _isEditing ? 'Done' : 'Edit List',
            onPressed: () {
              setState(() {
                _isEditing = !_isEditing;
              });
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: widget.ingredients.length,
                itemBuilder: (context, index) {
                  final ingredient = widget.ingredients[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: _isEditing
                          ? Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteIngredient(index),
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      TextField(
                                        decoration: const InputDecoration(labelText: 'Name'),
                                        controller: TextEditingController(
                                          text: ingredient['name'],
                                        ),
                                        onChanged: (val) =>
                                            widget.ingredients[index]['name'] = val,
                                      ),
                                      TextField(
                                        decoration: const InputDecoration(labelText: 'Amount'),
                                        controller: TextEditingController(
                                          text: ingredient['amount'],
                                        ),
                                        onChanged: (val) =>
                                            widget.ingredients[index]['amount'] = val,
                                      ),
                                      TextField(
                                        decoration: const InputDecoration(
                                            labelText: 'Expiry (YYYY-MM-DD)'),
                                        controller: TextEditingController(
                                          text: ingredient['expiry'],
                                        ),
                                        onChanged: (val) =>
                                            widget.ingredients[index]['expiry'] = val,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListTile(
                              title: Text(ingredient['name'] ?? 'Unknown'),
                              subtitle: Text(
                                  'Amount: ${ingredient['amount'] ?? 'N/A'}, Expiry: ${ingredient['expiry'] ?? 'N/A'}'),
                              onTap: () {
                                if (!_isEditing) {
                                  Navigator.pop(context, ingredient); // Return picked ingredient
                                }
                              },
                            ),
                    ),
                  );
                },
              ),
            ),
            if (_isEditing)
              ElevatedButton.icon(
                onPressed: _addNewIngredient,
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
              ),
          ],
        ),
      ),
    );
  }
}
