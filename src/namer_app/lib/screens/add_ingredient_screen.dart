import 'package:flutter/material.dart';

class IngredientListScreen extends StatefulWidget {
  final List<Map<String, String>> ingredients; // shared list

  const IngredientListScreen({super.key, required this.ingredients});

  @override
  State<IngredientListScreen> createState() => _IngredientListScreenState();
}

class _IngredientListScreenState extends State<IngredientListScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  DateTime? _selectedDate;

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
    final amount = _amountController.text.trim();

    if (name.isNotEmpty && amount.isNotEmpty && _selectedDate != null) {
      final newIngredient = {
        'name': name,
        'amount': amount,
        'expiry': _selectedDate!.toIso8601String().split('T').first,
      };

      widget.ingredients.add(newIngredient); // Add to shared list

      Navigator.pop(context, newIngredient); // Return new ingredient
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
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount (e.g., 1 cup)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedDate == null
                        ? 'No date chosen'
                        : 'Expiry: ${_selectedDate!.toIso8601String().split('T').first}',
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
