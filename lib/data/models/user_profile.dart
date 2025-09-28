class DietaryRules {
  final bool halal, vegetarian, vegan, lowCarb;
  const DietaryRules({
    this.halal = false,
    this.vegetarian = false,
    this.vegan = false,
    this.lowCarb = false,
  });

  String get humanLabel {
    if (halal) return 'Halal';
    if (vegan) return 'Vegan';
    if (vegetarian) return 'Vegetarian';
    if (lowCarb) return 'Low-carb';
    return 'No restrictions';
    }

  Map<String, dynamic> toJson() => {
    'halal': halal,
    'vegetarian': vegetarian,
    'vegan': vegan,
    'lowCarb': lowCarb,
  };

  factory DietaryRules.fromJson(Map<String, dynamic> j) => DietaryRules(
    halal: j['halal'] ?? false,
    vegetarian: j['vegetarian'] ?? false,
    vegan: j['vegan'] ?? false,
    lowCarb: j['lowCarb'] ?? false,
  );
}

class UserProfile {
  final String name, email, address;
  final DietaryRules rules;
  const UserProfile({
    this.name = '',
    this.email = '',
    this.address = '',
    this.rules = const DietaryRules(),
  });

  UserProfile copyWith({
    String? name,
    String? email,
    String? address,
    DietaryRules? rules,
  }) =>
      UserProfile(
        name: name ?? this.name,
        email: email ?? this.email,
        address: address ?? this.address,
        rules: rules ?? this.rules,
      );

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'address': address,
    'rules': rules.toJson(),
  };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    name: (j['name'] ?? '') as String,
    email: (j['email'] ?? '') as String,
    address: (j['address'] ?? '') as String,
    rules: DietaryRules.fromJson(
      ((j['rules'] ?? <String, dynamic>{}) as Map).cast<String, dynamic>(),
    ),
  );
}
