import 'package:flutter/material.dart';
import '../../../common/db/models/wasted_item.dart';

class WasteLogResult {
  final WastedItem item;
  const WasteLogResult(this.item);
}

class WasteLogForm extends StatefulWidget {
  const WasteLogForm({super.key});

  @override
  State<WasteLogForm> createState() => _WasteLogFormState();
}

class _WasteLogFormState extends State<WasteLogForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _qty = TextEditingController();
  final _value = TextEditingController();

  String _reason = 'Expired';
  String? _unit;

  final _reasons = const ['Expired', 'Spoiled', 'Leftovers', 'Overbought', 'Other'];
  final _units = const ['pcs', 'g', 'kg', 'ml', 'L'];

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Log Waste'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // item name
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Item name',
                  hintText: 'e.g., Bananas',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // quantity + unit
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qty,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Quantity'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _unit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: _units
                          .map((u) =>
                              DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (v) => setState(() => _unit = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // reason
              DropdownButtonFormField<String>(
                value: _reason,
                items: _reasons
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setState(() => _reason = v ?? 'Expired'),
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
              const SizedBox(height: 12),

              // estimated value
              TextFormField(
                controller: _value,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Estimated value (optional, \$)',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final qty = double.tryParse(_qty.text.trim());
            final val = double.tryParse(_value.text.trim());
            final item = WastedItem(
              name: _name.text.trim(),
              quantity: qty,
              unit: _unit,
              reason: _reason,
              estValue: val,
            );
            Navigator.pop(context, WasteLogResult(item));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}