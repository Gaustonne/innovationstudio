import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'add_ingredient_screen.dart';
import '../models/ingredient.dart';

class IngredientOverviewScreen extends StatefulWidget {
  final List<Ingredient> ingredients;

  const IngredientOverviewScreen({super.key, required this.ingredients});

  @override
  State<IngredientOverviewScreen> createState() =>
      _IngredientOverviewScreenState();
}

class _IngredientOverviewScreenState extends State<IngredientOverviewScreen> {
  bool _isEditing = false;
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  void _deleteIngredient(int index) {
    setState(() {
      widget.ingredients.removeAt(index);
    });
  }

  Future<void> _addNewIngredient() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddIngredientScreen(ingredients: widget.ingredients),
      ),
    );
    setState(() {});
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
                                        decoration:
                                            const InputDecoration(labelText: 'Name'),
                                        controller: TextEditingController(
                                            text: ingredient.name),
                                        onChanged: (val) {
                                          setState(() {
                                            ingredient.name = val;
                                          });
                                        },
                                      ),
                                      TextField(
                                        decoration:
                                            const InputDecoration(labelText: 'Weight (kg)'),
                                        controller: TextEditingController(
                                            text: ingredient.weightKg.toString()),
                                        keyboardType: TextInputType.number,
                                        onChanged: (val) {
                                          setState(() {
                                            ingredient.weightKg = double.tryParse(val) ?? 0.0;
                                          });
                                        },
                                      ),
                                      TextField(
                                        decoration: const InputDecoration(labelText: 'Quantity'),
                                        controller: TextEditingController(
                                            text: ingredient.quantity.toString()),
                                        keyboardType: TextInputType.number,
                                        onChanged: (val) {
                                          setState(() {
                                            ingredient.quantity = int.tryParse(val) ?? 1;
                                          });
                                        },
                                      ),
                                      TextField(
                                        decoration: const InputDecoration(
                                            labelText: 'Expiry'),
                                        controller: TextEditingController(
                                            text: _dateFormat.format(ingredient.expiry)),
                                        onTap: () async {
                                          final picked = await showDatePicker(
                                            context: context,
                                            initialDate: ingredient.expiry,
                                            firstDate: DateTime.now(),
                                            lastDate: DateTime(DateTime.now().year + 2),
                                          );
                                          if (picked != null) {
                                            setState(() {
                                              ingredient.expiry = picked;
                                            });
                                          }
                                        },
                                        readOnly: true,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListTile(
                              title: Text(ingredient.name),
                              subtitle: Text(
                                  'Weight: ${ingredient.weightKg} kg, Qty: ${ingredient.quantity}, Expiry: ${_dateFormat.format(ingredient.expiry)}'),
                              onTap: () {
                                if (!_isEditing) {
                                  Navigator.pop(context, ingredient);
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