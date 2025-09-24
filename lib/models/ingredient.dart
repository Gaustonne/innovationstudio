class Ingredient {
  String name;
  double weightKg; // Changed from String amount
  int quantity;    // New field
  DateTime expiry;

  Ingredient({
    required this.name,
    required this.weightKg,
    required this.quantity,
    required this.expiry,
  });

  // Convert Ingredient to a Map (useful for debugging or saving later)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'weightKg': weightKg,
      'quantity': quantity,
      'expiry': expiry.toIso8601String().split('T').first,
    };
  }

  // Factory to create Ingredient from Map
  factory Ingredient.fromMap(Map<String, dynamic> map) {
    return Ingredient(
      name: map['name'],
      weightKg: (map['weightKg'] as num).toDouble(),
      quantity: map['quantity'],
      expiry: DateTime.parse(map['expiry']),
    );
  }

  // Optional: a formatted string for display
  String formattedExpiry() {
    return "${expiry.day.toString().padLeft(2, '0')}-${expiry.month.toString().padLeft(2, '0')}-${expiry.year}";
  }
}