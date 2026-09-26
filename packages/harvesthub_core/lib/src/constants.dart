class Roles {
  static const customer = 'customer';
  static const farmer = 'farmer';
  static const admin = 'admin';
}

class OrderStatus {
  static const pending = 'Pending';
  static const confirmed = 'Confirmed';
  static const readyForPickup = 'ReadyForPickup';
  static const completed = 'Completed';
  static const cancelled = 'Cancelled';
  static const next = {
    pending: confirmed,
    confirmed: readyForPickup,
    readyForPickup: completed
  };
  static const labels = {
    pending: 'Pending',
    confirmed: 'Confirmed',
    readyForPickup: 'Ready for Pickup',
    completed: 'Completed',
    cancelled: 'Cancelled'
  };
  static String labelVi(String s) => labels[s] ?? s;
  static bool canCancel(String s) => s == pending || s == confirmed;
}

const pickupSlots = {
  'morning_07_10': 'Morning 7:00–10:00',
  'afternoon_15_18': 'Afternoon 15:00–18:00'
};
const productUnits = ['kg', 'g', 'L', 'pack', 'bunch'];
const simulationNotice = 'Simulated order — no real payment required';
const pickupNotice = 'Pickup at farm hub — no home delivery';

const categoryUnits = {
  'fruits': ['kg', 'g'],
  'vegetables': ['kg', 'g'],
  'tubers': ['kg', 'g'],
  'grains': ['kg', 'g'],
  'nuts': ['kg', 'g'],
  'seeds': ['kg', 'g'],
  'dairy': ['L'],
  'honey': ['L'],
  'poultry': ['pack'],
  'herbs': ['bunch', 'g'],
  'spices': ['g', 'pack'],
  'flowers': ['bunch'],
  'organic': ['kg', 'g'],
};

List<String> allowedUnitsForCategory(String? categoryId) {
  if (categoryId == null || !categoryUnits.containsKey(categoryId)) {
    return ['kg'];
  }
  return categoryUnits[categoryId]!;
}

String categoryDisplayName(String categoryId, String fallbackName) {
  return switch (categoryId.toLowerCase()) {
    'fruits' => 'Fruits',
    'vegetables' => 'Vegetables',
    'tubers' => 'Root Vegetables',
    'grains' => 'Grains',
    'nuts' => 'Nuts',
    'seeds' => 'Seeds',
    'dairy' => 'Dairy',
    'honey' => 'Honey',
    'poultry' => 'Eggs & Poultry',
    'herbs' => 'Herbs',
    'spices' => 'Spices',
    'flowers' => 'Flowers',
    'organic' => 'Organic Products',
    _ => fallbackName,
  };
}

String unitDisplayName(String unit) {
  return switch (unit) {
    'kg' => 'Kilogram (kg)',
    'g' => 'Grams (g)',
    'L' => 'Liters (L)',
    'pack' => 'Pack / Tray',
    'bunch' => 'Bunch',
    _ => unit,
  };
}
