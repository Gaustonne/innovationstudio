import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/local_store.dart';
import '../models/user_profile.dart';

/// Notifier-based provider (no StateNotifier or extra deps needed)
final profileControllerProvider =
    NotifierProvider<ProfileController, UserProfile>(ProfileController.new);

class ProfileController extends Notifier<UserProfile> {
  ProfileController();

  final _store = LocalStore();

  @override
  UserProfile build() {
    // Load persisted profile asynchronously
    _load();
    return const UserProfile();
  }

 Future<void> _load() async {
  final p = await _store.readProfile();
  if (!ref.mounted) return;   // <-- use ref.mounted with Notifier
  if (p != null) state = p;
}


  Future<void> setRules(DietaryRules rules) async {
    state = state.copyWith(rules: rules);
    await _store.saveProfile(state);
  }

  Future<void> setAccount({
    String? name,
    String? email,
    String? address,
  }) async {
    state = state.copyWith(name: name, email: email, address: address);
    await _store.saveProfile(state);
  }
}
