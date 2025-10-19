import 'package:flutter/foundation.dart';
import '../common/db/collections/wasted_store.dart';
import '../common/db/models/wasted_item.dart';

/// Run once to sanity-check the WastedStore new helpers.
/// Safe to call multiple times — it just adds one test row each call.
Future<void> runDevWasteTest() async {
  if (!kDebugMode) return; // avoid in release

  final store = WastedStore();

  await store.insertManual(WastedItem(
    name: 'Test Banana',
    quantity: 2,
    unit: 'pcs',
    reason: 'Spoiled',
    estValue: 1.80,
  ));

  final summary = await store.getWeeklySummary();
  debugPrint('[DEV] WEEK: items=${summary.itemCount}, \$=${summary.totalValue.toStringAsFixed(2)}');

  final recent = await store.listRecent(limit: 3);
  debugPrint('[DEV] RECENT: ${recent.map((w) => '${w.name}/${w.reason}/\$${w.estValue}').toList()}');
}