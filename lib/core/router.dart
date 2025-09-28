import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

// Guest + Account pages you just created
import '../features/auth/guest_welcome_page.dart';
import '../features/auth/guest_diet_page.dart';
import '../features/settings/account_details_page.dart';

GoRouter buildRouter() => GoRouter(
  // Start at Guest screen for the demo
  initialLocation: '/auth/guest',
  routes: [
    GoRoute(path: '/auth/guest', builder: (_, __) => const GuestWelcomePage()),
    GoRoute(path: '/auth/guest/diet', builder: (_, __) => const GuestDietPage()),
    GoRoute(path: '/settings/account', builder: (_, __) => const AccountDetailsPage()),

    // keep any other routes you already have...
  ],
);
