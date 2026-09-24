import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_core/harvesthub_core.dart';

void main() {
  test('FAQ normalizes Vietnamese casing, accents and punctuation', () {
    expect(FaqService.normalize('BẢO QUẢN CÀ CHUA?'), 'bao quan ca chua');
    expect(FaqService().answer('BẢO QUẢN CÀ CHUA?'), contains('ngăn mát'));
    expect(FaqService().answer('Lợi ích rau chân vịt'), contains('folate'));
    expect(FaqService().answer('Có giao hàng không?'), contains('không hỗ trợ vận chuyển'));
    expect(FaqService().answer('Thanh toán thế nào?'), contains('không trừ tiền thật'));
  });
  test('FAQ has at least 20 topics and matches whole words', () {
    expect(FaqService.rules.length, greaterThanOrEqualTo(20));
    expect(FaqService().answer('camera'), FaqService.fallback);
    expect(FaqService().answer('xyz'), FaqService.fallback);
    expect(FaqService().answer('rau mùa hè'), contains('Mướp'));
  });
}
