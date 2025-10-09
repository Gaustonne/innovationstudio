import 'package:flutter/foundation.dart';

/// Super lightweight app-wide event signaler.
class AppEvents {
  AppEvents._();
  static final AppEvents instance = AppEvents._();

  // Bump the value to signal listeners to reload data.
  final ValueNotifier<int> reloadTick = ValueNotifier<int>(0);

  void requestReloadAll() {
    reloadTick.value++;
  }
}