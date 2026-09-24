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
    pending: 'Chờ xác nhận',
    confirmed: 'Đã xác nhận',
    readyForPickup: 'Sẵn sàng nhận',
    completed: 'Hoàn tất',
    cancelled: 'Đã hủy'
  };
  static String labelVi(String s) => labels[s] ?? s;
  static bool canCancel(String s) => s == pending || s == confirmed;
}

const pickupSlots = {
  'morning_07_10': 'Sáng 7:00–10:00',
  'afternoon_15_18': 'Chiều 15:00–18:00'
};
const productUnits = ['kg', 'bó', 'chai', 'nải', 'vỉ'];
const simulationNotice = 'Đặt hàng (mô phỏng) — không thanh toán thật';
const pickupNotice = 'Nhận tại điểm bán — không hỗ trợ giao hàng';
