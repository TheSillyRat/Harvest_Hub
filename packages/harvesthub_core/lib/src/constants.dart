class Roles {
  static const customer = 'customer';
  static const farmer = 'farmer';
  static const admin = 'admin';
}

class OrderStatus {
  static const pending = 'Pending';
  static const confirmed = 'Confirmed';
  static const readyForPickup = 'Ready for Pickup';
  static const completed = 'Completed';
  static const cancelled = 'Cancelled';
  static const next = {
    pending: confirmed,
    confirmed: readyForPickup,
    readyForPickup: completed,
    'ReadyForPickup': completed,
  };
  static const labels = {
    pending: 'Pending',
    confirmed: 'Confirmed',
    readyForPickup: 'Ready for Pickup',
    'ReadyForPickup': 'Ready for Pickup',
    completed: 'Completed',
    cancelled: 'Cancelled'
  };
  static String label(String s) => labels[s] ?? s;
  static String labelVi(String s) => labels[s] ?? s;
  static bool canCancel(String s) => s == pending || s == confirmed;
}

const pickupSlots = {
  'morning_07_10': 'Morning 07:00–10:00',
  'afternoon_15_18': 'Afternoon 15:00–18:00'
};
const productUnits = ['kg', 'bunch', 'bottle', 'bundle', 'crate', 'box', 'head', 'jar'];
const simulationNotice = 'Simulated order — no real payment processed';
const pickupNotice = 'Pick up at local market hub — delivery not supported';
