import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../common/db/models/ingredient.dart';
import '../../receipt_scanner/receipt_scanner_screen.dart';

/// Result returned by the editor screen to indicate a save or delete action.
class EditResult {
  final Ingredient? item;
  final String? deletedId;

  const EditResult._({this.item, this.deletedId});

  const EditResult.saved(Ingredient i) : this._(item: i);
  const EditResult.deleted(String id) : this._(deletedId: id);
}

class AddIngredientScreen extends StatefulWidget {
  /// If [ingredient] is provided the screen will act as an edit form and
  /// return an updated Ingredient on save. If null, a new Ingredient is
  /// created and returned.
  final Ingredient? ingredient;

  const AddIngredientScreen({super.key, this.ingredient});

  @override
  State<AddIngredientScreen> createState() => _AddIngredientScreenState();
}

class _AddIngredientScreenState extends State<AddIngredientScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  DateTime? _selectedDate;
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  bool get _isEditing => widget.ingredient != null;
  int? _selectedQuickDays;

  Future<void> _scanReceipt() async {
    final List<Ingredient>? scannedItems = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ReceiptScannerScreen()),
    );

    if (scannedItems != null && scannedItems.isNotEmpty) {
      // For simplicity, we'll just use the first scanned item.
      // A real implementation might show a list to the user to select from.
      final firstItem = scannedItems.first;
      setState(() {
        _nameController.text = firstItem.name;
        _quantityController.text = firstItem.quantity.toString();
        _weightController.text = firstItem.weightKg.toString();
        _selectedDate = firstItem.expiry;
      });
    }
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final initial = _selectedDate ?? widget.ingredient?.expiry ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );

    if (picked != null) {
      setState(() {
        // If user manually picks a date, clear any quick-chip selection.
        _selectedQuickDays = null;
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
      if (_isEditing) {
        // preserve id when editing
        final updated = widget.ingredient!.copyWith(
          name: name,
          weightKg: double.tryParse(weightText) ?? 0.0,
          quantity: int.tryParse(quantityText) ?? 1,
          expiry: _selectedDate!,
        );
        Navigator.pop(context, EditResult.saved(updated));
      } else {
        final newIngredient = Ingredient(
          name: name,
          weightKg: double.tryParse(weightText) ?? 0.0,
          quantity: int.tryParse(quantityText) ?? 1,
          expiry: _selectedDate!,
        );

        Navigator.pop(context, EditResult.saved(newIngredient));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and pick a date')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // prefill when editing
    if (_isEditing) {
      final it = widget.ingredient!;
      _nameController.text = it.name;
      _weightController.text = it.weightKg.toString();
      _quantityController.text = it.quantity.toString();
      _selectedDate = it.expiry;
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Ingredient' : 'Add Ingredient'),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: _scanReceipt,
            tooltip: 'Scan Receipt',
          ),
        ],
      ),
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
            // Quick expiry chips
            Wrap(
              spacing: 8,
              children: [
                _expiryChip(label: '3 days', days: 3, today: today),
                _expiryChip(label: '7 days', days: 7, today: today),
                _expiryChip(label: '14 days', days: 14, today: today),
                _expiryChip(label: '30 days', days: 30, today: today),
              ],
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
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveIngredient,
                    child: Text(
                      _isEditing ? 'Save Changes' : 'Save Ingredient',
                    ),
                  ),
                ),
                if (_isEditing) ...[
                  const SizedBox(width: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    onPressed: () async {
                      // confirm before deleting
                      final navigator = Navigator.of(context);
                      final confirmed =
                          await showDialog<bool>(
                            context: context,
                            builder: (dctx) => AlertDialog(
                              title: const Text('Delete item?'),
                              content: const Text(
                                'This will permanently delete the item from inventory.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(dctx).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(dctx).pop(true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          ) ??
                          false;

                      if (!mounted) return;

                      if (confirmed) {
                        navigator.pop(
                          EditResult.deleted(widget.ingredient!.id),
                        );
                      }
                    },
                    child: const Icon(Icons.delete_forever),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _expiryChip({
    required String label,
    required int days,
    required DateTime today,
  }) {
    final selected = _selectedQuickDays == days;
    return ActionChip(
      label: Text(label),
      onPressed: () {
        setState(() {
          _selectedQuickDays = days;
          _selectedDate = DateTime(
            today.year,
            today.month,
            today.day,
          ).add(Duration(days: days));
        });
      },
      backgroundColor: selected ? Colors.blue.shade100 : null,
    );
  }
}
