import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final initial = await _LocalStore.readProfile() ?? const UserProfile();
  runApp(MyApp(initialProfile: initial));
}

/* ====================== DOMAIN ====================== */

class DietaryRules {
  final bool halal, vegetarian, vegan, lowCarb;
  const DietaryRules({this.halal = false, this.vegetarian = false, this.vegan = false, this.lowCarb = false});

  String get humanLabel {
    if (halal) return 'Halal';
    if (vegan) return 'Vegan';
    if (vegetarian) return 'Vegetarian';
    if (lowCarb) return 'Low-carb';
    return 'No restrictions';
  }

  Map<String, dynamic> toJson() => {'halal': halal, 'vegetarian': vegetarian, 'vegan': vegan, 'lowCarb': lowCarb};
  factory DietaryRules.fromJson(Map<String, dynamic> j) =>
      DietaryRules(halal: j['halal'] ?? false, vegetarian: j['vegetarian'] ?? false, vegan: j['vegan'] ?? false, lowCarb: j['lowCarb'] ?? false);
}

class UserProfile {
  final String name, email, address;
  final DietaryRules rules;
  const UserProfile({this.name = '', this.email = '', this.address = '', this.rules = const DietaryRules()});

  UserProfile copyWith({String? name, String? email, String? address, DietaryRules? rules}) =>
      UserProfile(name: name ?? this.name, email: email ?? this.email, address: address ?? this.address, rules: rules ?? this.rules);

  Map<String, dynamic> toJson() => {'name': name, 'email': email, 'address': address, 'rules': rules.toJson()};
  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        name: (j['name'] ?? '') as String,
        email: (j['email'] ?? '') as String,
        address: (j['address'] ?? '') as String,
        rules: DietaryRules.fromJson(((j['rules'] ?? <String, dynamic>{}) as Map).cast<String, dynamic>()),
      );
}

/* ================== PERSISTENCE ===================== */

class _LocalStore {
  static const _key = 'user_profile_v1';
  static Future<UserProfile?> readProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try { return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>); } catch (_) { return null; }
  }

  static Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(profile.toJson()));
  }
}

/* ======================= APP ======================== */

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.initialProfile});
  final UserProfile initialProfile;
  @override State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late UserProfile _profile;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile;
  }

  Future<void> _applyProfile(UserProfile p) async {
    setState(() => _profile = p);
    await _LocalStore.saveProfile(p);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meal Prep',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
        ),
      ),
      home: Builder(
        builder: (ctx) => HomePage(
          profile: _profile,
          onOpenAccount: () async {
            final updated = await Navigator.of(ctx).push<UserProfile>(
              MaterialPageRoute(builder: (_) => ProfileScreen(initialProfile: _profile)),
            );
            if (updated != null) _applyProfile(updated);
          },
          onOpenDietary: () async {
            final updatedRules = await Navigator.of(ctx).push<DietaryRules>(
              MaterialPageRoute(builder: (_) => DietaryScreen(initial: _profile.rules)),
            );
            if (updatedRules != null) _applyProfile(_profile.copyWith(rules: updatedRules));
          },
        ),
      ),
    );
  }
}

/* ===================== HOME ========================= */

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.profile, required this.onOpenAccount, required this.onOpenDietary});
  final UserProfile profile;
  final Future<void> Function() onOpenAccount;
  final Future<void> Function() onOpenDietary;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return Scaffold(
      appBar: AppBar(title: const Text('Meal Prep')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Card(
              elevation: 1,
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Account details'),
                subtitle: Text(profile.email.isEmpty ? 'Not set' : profile.email),
                trailing: const Icon(Icons.chevron_right),
                onTap: onOpenAccount,
                tileColor: surface,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 1,
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: const Icon(Icons.restaurant_menu),
                title: const Text('Dietary rules'),
                subtitle: Text(profile.rules.humanLabel),
                trailing: const Icon(Icons.chevron_right),
                onTap: onOpenDietary,
                tileColor: surface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ================ ACCOUNT (per-field edit) =========== */

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.initialProfile});
  final UserProfile initialProfile;
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late UserProfile _current;
  final _name = TextEditingController(), _email = TextEditingController(), _address = TextEditingController();
  final _nameF = FocusNode(), _emailF = FocusNode(), _addressF = FocusNode();
  bool _eName = false, _eEmail = false, _eAddress = false;

  @override
  void initState() {
    super.initState();
    _current = widget.initialProfile;
    _name.text = _current.name; _email.text = _current.email; _address.text = _current.address;
  }

  @override
  void dispose() { _name.dispose(); _email.dispose(); _address.dispose(); _nameF.dispose(); _emailF.dispose(); _addressF.dispose(); super.dispose(); }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  void _toggle({
    required bool editing,
    required void Function(bool) setEditing,
    required FocusNode node,
    required String label,
    required void Function() saveFn,
  }) {
    if (!editing) {
      setEditing(true); setState(() {}); Future.microtask(() => node.requestFocus());
    } else {
      saveFn();
      setEditing(false); setState(() {});
      _toast('$label updated successfully');
    }
  }

  void _saveName() => _current = _current.copyWith(name: _name.text.trim());
  void _saveAddress() => _current = _current.copyWith(address: _address.text.trim());
  void _saveEmail() {
    final v = _email.text.trim();
    if (v.isEmpty || !v.contains('@')) {
      _toast('Enter a valid email'); return;
    }
    _current = _current.copyWith(email: v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.pop(context, _current)),
        title: const Text('Account details'),
        actions: [
          IconButton(
            tooltip: 'Done',
            icon: const Icon(Icons.check),
            onPressed: () => Navigator.pop(context, _current),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _FieldCard(
            label: 'Full name',
            icon: Icons.person,
            child: TextField(
              controller: _name, focusNode: _nameF, enabled: _eName,
              decoration: const InputDecoration(hintText: 'Your name'),
            ),
            action: IconButton.filledTonal(
              icon: Icon(_eName ? Icons.check : Icons.edit),
              onPressed: () => _toggle(
                editing: _eName, setEditing: (v) => _eName = v, node: _nameF, label: 'Name', saveFn: _saveName,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _FieldCard(
            label: 'Email',
            icon: Icons.email,
            child: TextField(
              controller: _email, focusNode: _emailF, enabled: _eEmail, keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'name@example.com'),
            ),
            action: IconButton.filledTonal(
              icon: Icon(_eEmail ? Icons.check : Icons.edit),
              onPressed: () => _toggle(
                editing: _eEmail, setEditing: (v) => _eEmail = v, node: _emailF, label: 'Email', saveFn: _saveEmail,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _FieldCard(
            label: 'Address',
            icon: Icons.home,
            child: TextField(
              controller: _address, focusNode: _addressF, enabled: _eAddress, maxLines: 2,
              decoration: const InputDecoration(hintText: 'Street, City, ZIP'),
            ),
            action: IconButton.filledTonal(
              icon: Icon(_eAddress ? Icons.check : Icons.edit),
              onPressed: () => _toggle(
                editing: _eAddress, setEditing: (v) => _eAddress = v, node: _addressF, label: 'Address', saveFn: _saveAddress,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({required this.label, required this.icon, required this.child, required this.action});
  final String label; final IconData icon; final Widget child; final Widget action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 1, clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 6), child,
          ])),
          const SizedBox(width: 12), action,
        ]),
      ),
    );
  }
}

/* ================= DIETARY (single select) =========== */

enum _Diet { none, halal, vegetarian, vegan, lowCarb }

class DietaryScreen extends StatefulWidget {
  const DietaryScreen({super.key, required this.initial});
  final DietaryRules initial;
  @override State<DietaryScreen> createState() => _DietaryScreenState();
}

class _DietaryScreenState extends State<DietaryScreen> {
  late _Diet choice;

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    if (r.halal) choice = _Diet.halal;
    else if (r.vegan) choice = _Diet.vegan;
    else if (r.vegetarian) choice = _Diet.vegetarian;
    else if (r.lowCarb) choice = _Diet.lowCarb;
    else choice = _Diet.none;
  }

  DietaryRules _toRules(_Diet c) {
    switch (c) {
      case _Diet.halal: return const DietaryRules(halal: true);
      case _Diet.vegetarian: return const DietaryRules(vegetarian: true);
      case _Diet.vegan: return const DietaryRules(vegan: true);
      case _Diet.lowCarb: return const DietaryRules(lowCarb: true);
      case _Diet.none: return const DietaryRules();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.pop(context, _toRules(choice))),
        title: const Text('Dietary rules'),
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: () => Navigator.pop(context, _toRules(choice)))],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 1,
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            RadioListTile<_Diet>(title: const Text('No restrictions'), value: _Diet.none, groupValue: choice, onChanged: (v) => setState(() => choice = v!)),
            const Divider(height: 0),
            RadioListTile<_Diet>(title: const Text('Halal'), value: _Diet.halal, groupValue: choice, onChanged: (v) => setState(() => choice = v!)),
            RadioListTile<_Diet>(title: const Text('Vegetarian'), value: _Diet.vegetarian, groupValue: choice, onChanged: (v) => setState(() => choice = v!)),
            RadioListTile<_Diet>(title: const Text('Vegan'), value: _Diet.vegan, groupValue: choice, onChanged: (v) => setState(() => choice = v!)),
            RadioListTile<_Diet>(title: const Text('Low-carb'), value: _Diet.lowCarb, groupValue: choice, onChanged: (v) => setState(() => choice = v!)),
          ]),
        ),
      ),
    );
  }
}
