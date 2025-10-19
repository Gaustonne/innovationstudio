// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import '../../../features/inventory/presentation/inventory.dart'
//     show InventoryPage;
//
// typedef PageCallback = void Function();
//
// class AppDrawer extends StatelessWidget {
//   final InventoryPage activePage;
//   final int expiredCount;
//   final int wastedCount;
//   final VoidCallback onMain;
//   final VoidCallback onExpired;
//   final VoidCallback onWasted;
//   final VoidCallback onRecipes;
//   final VoidCallback onShoppingList;
//   final VoidCallback? onSeed;
//   final String? username;
//
//   const AppDrawer({
//     super.key,
//     required this.activePage,
//     required this.expiredCount,
//     required this.wastedCount,
//     required this.onMain,
//     required this.onExpired,
//     required this.onWasted,
//     required this.onRecipes,
//     required this.onShoppingList,
//     this.onSeed,
//     this.username,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Drawer(
//       child: SafeArea(
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             DrawerHeader(
//               decoration: BoxDecoration(
//                 color: Theme.of(context).colorScheme.primary,
//               ),
//               child: Text(
//                 'Inventory',
//                 style: Theme.of(context).textTheme.headlineSmall!.copyWith(
//                       color: Theme.of(context).colorScheme.onPrimary,
//                     ),
//               ),
//             ),
//             ListTile(
//               leading: const Icon(Icons.list),
//               title: const Text('Main inventory'),
//               selected: activePage == InventoryPage.main,
//               onTap: onMain,
//             ),
//             ListTile(
//               leading: const Icon(Icons.history_edu),
//               title: Text('Expired items ($expiredCount)'),
//               selected: activePage == InventoryPage.expired,
//               onTap: onExpired,
//             ),
//             ListTile(
//               leading: const Icon(Icons.delete_forever),
//               title: Text('Wasted items ($wastedCount)'),
//               selected: activePage == InventoryPage.wasted,
//               onTap: onWasted,
//             ),
//             ListTile(
//               leading: const Icon(Icons.restaurant_menu),
//               title: const Text('Recipes'),
//               selected: activePage == InventoryPage.recipes,
//               onTap: onRecipes,
//             ),
//             ListTile(
//               leading: const Icon(Icons.shopping_cart),
//               title: const Text('Shopping List'),
//               selected: activePage == InventoryPage.shoppingList,
//               onTap: onShoppingList,
//             ),
//             // Debug-only seed action
//             if (kDebugMode && onSeed != null)
//               ListTile(
//                 leading: const Icon(Icons.bug_report),
//                 title: const Text('Seed DB (debug)'),
//                 onTap: onSeed,
//               ),
//             const Spacer(),
//             if (username != null)
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 10.0),
//                 child: Text(
//                   'Signed in as: $username',
//                   style: Theme.of(context).textTheme.bodySmall,
//                 ),
//               ),
//             Padding(
//               padding: const EdgeInsets.all(12.0),
//               child: Text('v1.0', style: Theme.of(context).textTheme.bodySmall),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }


import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// keeps your existing type import
import '../../../features/inventory/presentation/inventory.dart' show InventoryPage;

// meal plan screen route
import '../../../features/meal_plan/presentation/meal_plan_screen.dart'
    show MealPlanScreen;

typedef PageCallback = void Function();

class AppDrawer extends StatelessWidget {
  final InventoryPage activePage;
  final int expiredCount;
  final int wastedCount;

  final VoidCallback onMain;
  final VoidCallback onExpired;
  final VoidCallback onWasted;
  final VoidCallback onWasteCharts; // NEW
  final VoidCallback onRecipes;
  final VoidCallback onShoppingList;

  final VoidCallback? onSeed;
  final String? username;

  const AppDrawer({
    super.key,
    required this.activePage,
    required this.expiredCount,
    required this.wastedCount,
    required this.onMain,
    required this.onExpired,
    required this.onWasted,
    required this.onWasteCharts, // NEW
    required this.onRecipes,
    required this.onShoppingList,
    this.onSeed,
    this.username,
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
            // NEW: Waste charts/insights
            ListTile(
              leading: const Icon(Icons.insights),
              title: const Text('Waste Charts'),
              selected: activePage == InventoryPage.wasteCharts,
              onTap: onWasteCharts,
            ),
            ListTile(
              leading: const Icon(Icons.restaurant_menu),
              title: const Text('Recipes'),
              selected: activePage == InventoryPage.recipes,
              onTap: onRecipes,
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart),
              title: const Text('Shopping List'),
              selected: activePage == InventoryPage.shoppingList,
              onTap: onShoppingList,
            ),

            // Weekly plan deep-link
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Weekly Plan'),
              onTap: () {
                Navigator.of(context).pop(); // close the drawer
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MealPlanScreen(),
                  ),
                );
              },
            ),

            if (kDebugMode && onSeed != null)
              ListTile(
                leading: const Icon(Icons.bug_report),
                title: const Text('Seed DB (debug)'),
                onTap: onSeed,
              ),
            const Spacer(),
            if (username != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Text(
                  'Signed in as: $username',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
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
