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
const productUnits = ['kg', 'bó', 'chai', 'nải', 'vỉ'];
const simulationNotice = 'Simulated order — no real payment required';
const pickupNotice = 'Pickup at farm hub — no home delivery';
