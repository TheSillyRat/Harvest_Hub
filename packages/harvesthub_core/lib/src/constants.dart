class Roles {
  static const String customer = 'customer';
  static const String farmer = 'farmer';
  static const String admin = 'admin';
}

class OrderStatus {
  static const String pending = 'Pending';
  static const String confirmed = 'Confirmed';
  static const String readyForPickup = 'ReadyForPickup';
  static const String completed = 'Completed';
  static const String cancelled = 'Cancelled';
  static const Map<String, String> next = {
    pending: confirmed,
    confirmed: readyForPickup,
    readyForPickup: completed,
  };
  static const Map<String, String> labels = {
    pending: 'Pending',
    confirmed: 'Confirmed',
    readyForPickup: 'Ready for Pickup',
    completed: 'Completed',
    cancelled: 'Cancelled',
  };
  static String labelVi(String s) => labels[s] ?? s;
  static bool canCancel(String s) => s == pending || s == confirmed;
}

const Map<String, String> pickupSlots = {
  'morning_07_10': 'Morning 7:00–10:00',
  'afternoon_15_18': 'Afternoon 15:00–18:00',
};

const List<String> productUnits = [
  'kg',
  'g',
  'L',
  'tray',
  'box',
  'pack',
  'bunch',
  'bottle',
  'bag',
  'jar',
];

const String simulationNotice = 'Simulated order — no real payment required';
const String pickupNotice = 'Pickup at farm hub — no home delivery';

/// Strict category to fixed unit mapping.
/// Unit is locked per category and cannot be altered by farmers.
const Map<String, String> categoryFixedUnit = {
  'vegetables': 'kg',
  'fruits': 'kg',
  'berries': 'kg',
  'root_vegetables': 'kg',
  'mushrooms': 'kg',
  'herbs': 'bunch',
  'spices': 'kg',
  'grains': 'kg',
  'nuts': 'kg',
  'eggs': 'tray',
  'honey': 'L',
  'dairy': 'L',
};

const Map<String, List<String>> categoryUnits = {
  'vegetables': ['kg'],
  'fruits': ['kg'],
  'berries': ['kg'],
  'root_vegetables': ['kg'],
  'mushrooms': ['kg'],
  'herbs': ['bunch'],
  'spices': ['kg'],
  'grains': ['kg'],
  'nuts': ['kg'],
  'eggs': ['tray'],
  'honey': ['L'],
  'dairy': ['L'],
};

String getFixedUnitForCategory(String? categoryId) {
  if (categoryId == null) return 'kg';
  return categoryFixedUnit[categoryId.toLowerCase()] ?? 'kg';
}


/// Predefined standard gram increments for customer weight stepping (100g to 900g).
const List<int> kStandardGramSteps = [
  100,
  200,
  300,
  400,
  500,
  600,
  700,
  800,
  900,
];

/// Proportional gram price calculation based on price per 1 kg.
double calculateGramPrice({required num baseKgPrice, required int grams}) {
  return (baseKgPrice * grams / 1000.0);
}

/// Identifies if a category is weight-based.
bool isWeightBasedCategory(String? categoryId) {
  if (categoryId == null) return false;
  return const {
    'vegetables',
    'fruits',
    'berries',
    'root_vegetables',
    'mushrooms',
    'spices',
    'grains',
    'nuts',
  }.contains(categoryId.toLowerCase());
}

List<String> allowedUnitsForCategory(String? categoryId) {
  return [getFixedUnitForCategory(categoryId)];
}

/// Category name display without redundant prefixes (matching column names).
String categoryDisplayName(String categoryId, String fallbackName) {
  return switch (categoryId.toLowerCase()) {
    'vegetables' => 'Vegetables',
    'fruits' => 'Fruits',
    'berries' => 'Berries',
    'root_vegetables' => 'Root Vegetables',
    'mushrooms' => 'Mushrooms',
    'herbs' => 'Herbs',
    'spices' => 'Spices',
    'grains' => 'Grains',
    'nuts' => 'Nuts',
    'eggs' => 'Eggs',
    'honey' => 'Honey',
    'dairy' => 'Dairy',
    _ => fallbackName.isNotEmpty ? fallbackName : categoryId,
  };
}

String unitDisplayName(String unit) {
  return switch (unit) {
    'kg' => 'Kilogram (kg)',
    'g' => 'Grams (g)',
    'L' => 'Liters (L)',
    'tray' => 'Tray (10 eggs)',
    'box' => 'Box',
    'bunch' => 'Bunch',
    'bottle' => 'Bottle',
    'bag' => 'Bag',
    'jar' => 'Jar',
    _ => unit,
  };
}
