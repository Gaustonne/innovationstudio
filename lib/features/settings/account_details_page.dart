import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/profile_provider.dart';

class AccountDetailsPage extends ConsumerStatefulWidget {
  const AccountDetailsPage({super.key});
  @override
  ConsumerState<AccountDetailsPage> createState() =>
      _AccountDetailsPageState();
}

class _AccountDetailsPageState extends ConsumerState<AccountDetailsPage> {
  final _name = TextEditingController(),
      _email = TextEditingController(),
      _address = TextEditingController();

  @override
  void initState() {
    super.initState();
    final p = ref.read(profileControllerProvider);
    _name.text = p.name;
    _email.text = p.email;
    _address.text = p.address;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Account details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _FieldCard(
            label: 'Full name',
            icon: Icons.person,
            child: TextField(
              controller: _name,
              decoration: const InputDecoration(hintText: 'Your name'),
            ),
          ),
          const SizedBox(height: 12),
          _FieldCard(
            label: 'Email',
            icon: Icons.email,
            child: TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'name@example.com'),
            ),
          ),
          const SizedBox(height: 12),
          _FieldCard(
            label: 'Address',
            icon: Icons.home,
            child: TextField(
              controller: _address,
              maxLines: 2,
              decoration:
                  const InputDecoration(hintText: 'Street, City, ZIP'),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save'),
            onPressed: () async {
              final email = _email.text.trim();
              if (email.isNotEmpty && !email.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid email')),
                );
                return;
              }
              await ref.read(profileControllerProvider.notifier).setAccount(
                    name: _name.text.trim(),
                    email: email,
                    address: _address.text.trim(),
                  );
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Saved')));
              }
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You can set diet in the guest step; it’s saved locally.',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({
    required this.label,
    required this.icon,
    required this.child,
  });
  final String label;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 6),
                  child,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
