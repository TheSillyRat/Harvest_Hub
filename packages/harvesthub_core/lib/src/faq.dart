class FaqService {
  static const greeting =
      'Xin chào, mình trả lời về dinh dưỡng, bảo quản và mùa vụ nông sản. Bạn hỏi thử nhé.';
  static const fallback =
      'Mình chưa rõ. Bạn thử: vitamin C, bảo quản cà chua, rau mùa hè, lợi ích rau bina, salad khỏe.';
  static const rules = <List<String>, String>{
    ['giao hang', 'ship']:
        'HarvestHub không hỗ trợ vận chuyển. Nhận tại điểm bán theo khung giờ.',
    ['thanh toan', 'payment']: 'Đặt hàng chỉ mô phỏng, không trừ tiền thật.',
    [
      'huy don'
    ]: 'Bạn có thể hủy đơn khi Chờ xác nhận hoặc Đã xác nhận. Tồn kho sẽ được hoàn lại.',
    ['khung gio', 'nhan hang']:
        'Chọn Sáng 7:00–10:00 hoặc Chiều 15:00–18:00 khi đặt hàng.',
    [
      'het hang',
      'ton kho',
      'ton'
    ]: 'Hết hàng thì chọn nông dân khác hoặc đợi restock. App không giao hàng.',
    [
      'ca chua',
      'bao quan ca'
    ]: 'Để nhiệt độ phòng nếu xanh; đã chín để ngăn mát, đừng rửa trước khi cất.',
    ['vitamin c', 'cam', 'oi']: 'Ổi, cam, ớt chuông, kiwi giàu vitamin C.',
    ['mua he']: 'Mướp, bầu, dưa leo, rau dền là những lựa chọn mùa hè.',
    ['mua dong']: 'Bắp cải, su hào, cà rốt, su su thường phù hợp mùa đông.',
    ['bina', 'rau chan vit']:
        'Rau bina có sắt và folate. Có thể xào nhanh hoặc dùng trong smoothie.',
    ['salad']: 'Thử dưa leo, cà chua bi, xà lách, rau thơm cùng dầu olive.',
    ['sua']: 'Bảo quản lạnh 2–4°C, dùng trước hạn và theo hướng dẫn trên nhãn.',
    ['trung']: 'Không rửa trước khi cất. Để ngăn mát.',
    ['gao']: 'Bảo quản gạo ở nơi khô, trong hộp kín.',
    ['chuoi']: 'Để chuối nơi thoáng mát, tránh nắng trực tiếp.',
    ['tao']: 'Giữ táo trong ngăn mát, tách riêng rau dễ héo.',
    ['rau thom', 'hung que']:
        'Loại lá hỏng, giữ rau khô ráo và bảo quản phù hợp từng loại.',
    ['ca rot']: 'Cắt phần lá, cho cà rốt vào ngăn rau củ của tủ lạnh.',
    ['khoai tay']: 'Giữ nơi khô, tối, thoáng. Không dùng củ xanh hoặc mọc mầm.',
    ['dua leo']: 'Bọc nhẹ dưa leo bằng giấy khô và để ngăn mát.',
    ['xa lach']: 'Giữ lá ráo nước trong hộp có giấy thấm, để ngăn mát.',
    ['huu co']: 'Kiểm tra thông tin nguồn gốc và chứng nhận từ người bán.',
    [
      'chat xo'
    ]: 'Rau, trái cây và ngũ cốc nguyên hạt bổ sung chất xơ trong chế độ ăn đa dạng.',
    ['rua rau']:
        'Rửa rau dưới nước sạch trước khi chế biến, tách bỏ phần dập hỏng.',
  };
  static String normalize(String value) {
    var s = value.toLowerCase();
    const accents = [
      'àáạảãâầấậẩẫăằắặẳẵ',
      'èéẹẻẽêềếệểễ',
      'ìíịỉĩ',
      'òóọỏõôồốộổỗơờớợởỡ',
      'ùúụủũưừứựửữ',
      'ỳýỵỷỹ',
      'đ'
    ];
    const replacements = ['a', 'e', 'i', 'o', 'u', 'y', 'd'];
    for (var i = 0; i < accents.length; i++) {
      for (final rune in accents[i].runes) {
        s = s.replaceAll(String.fromCharCode(rune), replacements[i]);
      }
    }
    return s
        .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String answer(String question) {
    final text = ' ${normalize(question)} ';
    for (final rule in rules.entries) {
      if (rule.key.any((key) => text.contains(' $key '))) return rule.value;
    }
    return fallback;
  }
}
