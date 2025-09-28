import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/user_profile.dart';
import '../../data/providers/profile_provider.dart';

class GuestDietPage extends ConsumerStatefulWidget {
  const GuestDietPage({super.key});
  @override
  ConsumerState<GuestDietPage> createState() => _GuestDietPageState();
}

class _GuestDietPageState extends ConsumerState<GuestDietPage> {
  String _choice = 'none';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final options = <Map<String, String>>[
      {'key': 'none', 'label': 'No restrictions'},
      {'key': 'halal', 'label': 'Halal'},
      {'key': 'vegetarian', 'label': 'Vegetarian'},
      {'key': 'vegan', 'label': 'Vegan'},
      {'key': 'lowCarb', 'label': 'Low-carb'},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Dietary preference')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: options.map((o) {
                final selected = _choice == o['key'];
                return ChoiceChip(
                  label: Text(o['label']!),
                  selected: selected,
                  onSelected: (_) => setState(() => _choice = o['key']!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected ? cs.onPrimary : cs.onSurface,
                  ),
                );
              }).toList(),
            ),
            const Spacer(),
            FilledButton.icon(
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Continue'),
              onPressed: () async {
                final rules = switch (_choice) {
                  'halal' => const DietaryRules(halal: true),
                  'vegetarian' => const DietaryRules(vegetarian: true),
                  'vegan' => const DietaryRules(vegan: true),
                  'lowCarb' => const DietaryRules(lowCarb: true),
                  _ => const DietaryRules(),
                };
                await ref
                    .read(profileControllerProvider.notifier)
                    .setRules(rules);
                if (context.mounted) context.go('/settings/account');
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
