import 'package:flutter/material.dart';
import '../../../common/services/cook_service.dart';

/// What the dialog returns to the caller.
class CookDialogResult {
  final CookResult result; // what we deducted + shortages
  const CookDialogResult(this.result);
}

/// Top-level private helper representing one editable row.
class _CookLine {
  final TextEditingController name = TextEditingController();
  final TextEditingController qty = TextEditingController();

  void dispose() {
    name.dispose();
    qty.dispose();
  }
}

class CookDialog extends StatefulWidget {
  /// Optional list of suggested ingredient names (from the recipe).
  final List<String> suggestions;

  const CookDialog({super.key, this.suggestions = const []});

  @override
  State<CookDialog> createState() => _CookDialogState();
}

class _CookDialogState extends State<CookDialog> {
  final _formKey = GlobalKey<FormState>();
  final List<_CookLine> _lines = [ _CookLine() ];
  bool _submitting = false;

  @override
  void dispose() {
    for (final l in _lines) { l.dispose(); }
    super.dispose();
  }

  void _addRow() => setState(() => _lines.add(_CookLine()));

  void _removeRow(int i) {
    if (_lines.length == 1) return; // keep at least one row
    setState(() {
      _lines[i].dispose();
      _lines.removeAt(i);
    });
  }

  String? _validateName(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Enter ingredient name';
    return null;
  }

  String? _validateQty(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Qty';
    final n = int.tryParse(t);
    if (n == null || n <= 0) return 'Positive number';
    return null;
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    // Build {name -> qty}
    final Map<String, int> useByName = {};
    for (final l in _lines) {
      final name = l.name.text.trim();
      final qty = int.parse(l.qty.text.trim());
      useByName.update(name, (v) => v + qty, ifAbsent: () => qty);
    }

    setState(() => _submitting = true);
    try {
      final cook = CookService();
      final result = await cook.apply(useByName);

      if (!mounted) return;
      Navigator.of(context).pop(CookDialogResult(result));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to apply: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mark meal as cooked'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter ingredients used and their quantities. '
                'We’ll deduct these from your pantry.',
              ),
              const SizedBox(height: 12),
              ...List.generate(_lines.length, (i) {
                final row = _lines[i];
                return Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _NameField(
                          controller: row.name,
                          suggestions: widget.suggestions,
                          validator: _validateName,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: row.qty,
                          decoration: const InputDecoration(
                            labelText: 'Qty',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: _validateQty,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Remove',
                        onPressed: () => _removeRow(i),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addRow,
                  icon: const Icon(Icons.add),
                  label: const Text('Add ingredient'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _onSubmit,
          child: _submitting
              ? const SizedBox(
                  height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Apply'),
        ),
      ],
    );
  }
}

/// Simple name field with optional suggestions as dropdown.
class _NameField extends StatefulWidget {
  final TextEditingController controller;
  final List<String> suggestions;
  final String? Function(String?)? validator;

  const _NameField({
    required this.controller,
    this.suggestions = const [],
    this.validator,
  });

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    // If suggestions provided, show a dropdown; otherwise a plain text field.
    if (widget.suggestions.isNotEmpty) {
      return DropdownButtonFormField<String>(
        value: _selected,
        items: [
          ...widget.suggestions.map(
            (s) => DropdownMenuItem<String>(value: s, child: Text(s)),
          ),
        ],
        onChanged: (v) {
          setState(() => _selected = v);
          widget.controller.text = v ?? '';
        },
        decoration: const InputDecoration(
          labelText: 'Ingredient',
          border: OutlineInputBorder(),
        ),
        // Validate using the controller text (covers dropdown + free-typed)
        validator: (_) => widget.validator?.call(widget.controller.text),
      );
    }

    return TextFormField(
      controller: widget.controller,
      decoration: const InputDecoration(
        labelText: 'Ingredient',
        border: OutlineInputBorder(),
      ),
      validator: widget.validator,
    );
  }
}