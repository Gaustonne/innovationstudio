import 'package:flutter/material.dart';
import '../../../features/inventory/presentation/inventory.dart'
    show InventoryPage;

typedef PageCallback = void Function();

class AppDrawer extends StatelessWidget {
  final InventoryPage activePage;
  final int expiredCount;
  final int wastedCount;
  final VoidCallback onMain;
  final VoidCallback onExpired;
  final VoidCallback onWasted;

  const AppDrawer({
    super.key,
    required this.activePage,
    required this.expiredCount,
    required this.wastedCount,
    required this.onMain,
    required this.onExpired,
    required this.onWasted,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Text(
                'Inventory',
                style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('Main inventory'),
              selected: activePage == InventoryPage.main,
              onTap: onMain,
            ),
            ListTile(
              leading: const Icon(Icons.history_edu),
              title: Text('Expired items ($expiredCount)'),
              selected: activePage == InventoryPage.expired,
              onTap: onExpired,
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever),
              title: Text('Wasted items ($wastedCount)'),
              selected: activePage == InventoryPage.wasted,
              onTap: onWasted,
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text('v1.0', style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}
