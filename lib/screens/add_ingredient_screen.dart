import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ingredient.dart';

class AddIngredientScreen extends StatefulWidget {
  final List<Ingredient> ingredients;

  const AddIngredientScreen({super.key, required this.ingredients});

  @override
  State<AddIngredientScreen> createState() => _AddIngredientScreenState();
}

class _AddIngredientScreenState extends State<AddIngredientScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  DateTime? _selectedDate;
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveIngredient() {
    final name = _nameController.text.trim();
    final weightText = _weightController.text.trim();
    final quantityText = _quantityController.text.trim();

    if (name.isNotEmpty &&
        weightText.isNotEmpty &&
        quantityText.isNotEmpty &&
        _selectedDate != null) {
      final newIngredient = Ingredient(
        name: name,
        weightKg: double.tryParse(weightText) ?? 0.0,
        quantity: int.tryParse(quantityText) ?? 1,
        expiry: _selectedDate!,
      );

      widget.ingredients.add(newIngredient);
      Navigator.pop(context, newIngredient);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and pick a date')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Ingredient')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Ingredient Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _weightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Weight (kg)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedDate == null
                        ? 'No date chosen'
                        : 'Expiry: ${_dateFormat.format(_selectedDate!)}',
                  ),
                ),
                TextButton(
                  onPressed: _pickExpiryDate,
                  child: const Text('Pick Date'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveIngredient,
              child: const Text('Save Ingredient'),
            ),
          ],
        ),
      ),
    );
  }
}