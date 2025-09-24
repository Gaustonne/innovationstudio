import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const _usernameKey = 'user.username';
  static const _emailKey = 'user.email';
  static const _dietRuleKey = 'user.dietRule';

  Future<SharedPreferences> _prefs() async =>
      await SharedPreferences.getInstance();

  Future<String?> getUsername() async {
    final p = await _prefs();
    return p.getString(_usernameKey);
  }

  Future<void> setUsername(String value) async {
    final p = await _prefs();
    await p.setString(_usernameKey, value);
  }

  Future<String?> getEmail() async {
    final p = await _prefs();
    return p.getString(_emailKey);
  }

  Future<void> setEmail(String value) async {
    final p = await _prefs();
    await p.setString(_emailKey, value);
  }

  Future<String?> getDietRule() async {
    final p = await _prefs();
    return p.getString(_dietRuleKey);
  }

  Future<void> addDietRule(String value) async {
    final p = await _prefs();
    await p.setStringList(_dietRuleKey, [
      ...(p.getStringList(_dietRuleKey) ?? []),
      value,
    ]);
  }

  Future<void> removeDietRule(String value) async {
    final p = await _prefs();
    await p.setStringList(
      _dietRuleKey,
      (p.getStringList(_dietRuleKey) ?? []).where((e) => e != value).toList(),
    );
  }

  Future<void> clear() async {
    final p = await _prefs();
    await p.remove(_usernameKey);
    await p.remove(_emailKey);
    await p.remove(_dietRuleKey);
  }
}
