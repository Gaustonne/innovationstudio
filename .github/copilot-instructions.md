This repository is a small Flutter app that manages a kitchen inventory. The guidance below helps an AI coding agent be productive immediately by describing the architecture, important patterns, developer workflows, and concrete examples from the codebase.

1) Big picture
- Flutter app (multi-platform) with a small feature-focused structure under `lib/`:
  - `lib/main.dart` — app entry (standard Flutter app bootstrap).
  - `lib/features/` — feature UI and pages (e.g. `inventory/` contains `inventory.dart`, `expired.dart`, `wasted.dart`, `item_card.dart`).
  - `lib/common/` — cross-cutting code:
    - `common/db/` — local sqflite DB helpers and models (`db.dart`, `collections/*_store.dart`, `models/ingredient.dart`).
    - `common/storage/preferences.dart` — simple SharedPreferences wrapper for user prefs.
    - `common/widgets/` — reusable widgets such as the app drawer (`navigation/drawer.dart`).

2) Data layer / persistence
- The app uses sqflite via a singleton `AppDatabase.instance` in `lib/common/db/db.dart`.
  - Tables created on DB `onCreate` include `inventory`, `wasted`, `meal_plans`, and `meal_plan_ingredients`.
  - Data model: `Ingredient` in `common/db/models/ingredient.dart` — maps to/from DB via `toMap()` / `fromMap()` and stores expiry as ISO8601 strings.
  - Accessor objects in `common/db/collections/*_store.dart` encapsulate CRUD (examples: `InventoryStore`, `WastedStore`). They always call `await AppDatabase.instance` before queries.

3) UI & state patterns
- Navigation: a ValueNotifier `activePageNotifier` (declared in `lib/features/inventory/presentation/inventory.dart`) is used to switch between inventory / expired / wasted pages. Many widgets subscribe with `ValueListenableBuilder` to update titles and the drawer.
- Local in-memory state: `InventoryHomePage` keeps an in-memory list `_items` (single source of truth for the UI) and `_wastedItems` for wasted entries. Persistence operations update the DB and then update in-memory lists.
- Pop handling: `PopScope` (custom wrapper used in `inventory.dart`) is used to manage a local navigation history stack (`_history`) and avoid full Navigator pops when switching pages.
- UI patterns: `ItemCard` is the canonical list item widget used by main, expired, and wasted lists. `Dismissible` is used for swipe actions (add days / move to wasted) across multiple pages. Note how code captures `ScaffoldMessenger.of(context)` before awaiting dialogs to avoid using a stale BuildContext across async gaps.

4) Developer workflows (build/test/debug)
- Run app as a normal Flutter app (IDE or `flutter run`). The project includes platform folders for Android/iOS/Windows etc.
- Tests: unit/widget tests under `test/`. Example: `test/db_seed_test.dart` shows how tests call `initTestDatabase()` / `closeAndDeleteAppDatabase()` helpers (see `test/test_helpers/db_test_helper.dart`) to create and tear down the DB for deterministic tests.
- Local debug seed: there is a debug-only "Seed DB" action in the drawer (`AppDrawer`) that calls `_seedDatabase()` in `inventory.dart` — this clears DB and inserts sample rows, and sets a username in `PreferencesService`. It is gated by `kDebugMode`.

5) Project-specific conventions and patterns
- Single source-of-truth in-memory list: UI widgets rely on `_items` (in `InventoryHomePage`) instead of querying DB repeatedly. Persistence methods (insert/update/delete) must update `_items` and then call the store methods to keep both in sync.
- Date handling: expiry dates are treated as date-only (time portion ignored when comparing). See `_isExpired()` and the way dates are normalized with `DateTime(year,month,day)` in `inventory.dart` and `item_card.dart`'s `date_utils` usage.
- Avoid using BuildContext across async gaps: code consistently captures `ScaffoldMessenger.of(context)` or Navigator before awaiting dialogs to avoid context-lifetime issues.
- Feature-local page routing: `activePageNotifier` plus a local `_history` list in `InventoryHomePage` emulate small in-widget navigation without pushing new routes. When adding features, prefer this pattern for closely related views rather than spawning new pages unless they need deep linking.

6) Integration points and external dependencies
- Core plugins used:
  - `sqflite` + `path` for local DB (`lib/common/db/*`).
  - `shared_preferences` for lightweight settings (`lib/common/storage/preferences.dart`).
  - `uuid` for generating IDs in `Ingredient` model.
- Tests rely on a test DB helper under `test/test_helpers/` — inspect these helpers before changing tests that touch the DB.

7) Concrete examples an AI agent can use
- To read all inventory items: use `await InventoryStore().getAll()` (see `inventory.dart` and tests).
- To persist an expiry update: call `InventoryStore().update(updated)` and update the in-memory `_items` list first, following the pattern in `_addDaysToItem`.
- To move an item to wasted: remove it from `_items`, insert into `_wastedItems` and call `InventoryStore().delete(id)` and `WastedStore().insert(item, movedAt: DateTime.now())` as in `_moveToWasted`.

8) Editing & tests quality gates
- When changing DB schema, bump `_dbVersion` in `AppDatabase` and add migration logic (currently DB opens with `onCreate` only). Tests will create a fresh DB via helpers — update them if the schema changes.
- Run tests after changes: `flutter test` (preferred) or run specific test file, e.g. `flutter test test/db_seed_test.dart`.

9) Files worth reading first (fast path for a new agent)
- `lib/features/inventory/presentation/inventory.dart` — main UI and where most logic lives.
- `lib/common/db/db.dart`, `lib/common/db/collections/inventory_store.dart`, `lib/common/db/collections/wasted_store.dart`, `lib/common/db/models/ingredient.dart` — persistence model and stores.
- `lib/common/storage/preferences.dart` — small wrapper around SharedPreferences used by the UI.
- `test/db_seed_test.dart` and `test/test_helpers/db_test_helper.dart` — test patterns for DB setup/teardown.

10) When to ask the human
- If a change needs DB migrations, clarify expected migration policy and whether app data should be preserved or reset in debug vs production.
- If adding new features that require cross-feature routing (deep links or separate screens), confirm whether to follow the local ValueNotifier pattern or use Navigator routes.

If you want, I can merge this into an existing copilot-instructions file or expand any section with concrete code snippets or example PR descriptions. Please tell me which areas you'd like me to expand or any company-specific rules to include.
