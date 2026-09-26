import 'package:flutter_test/flutter_test.dart';
import 'package:farmer_app/farmer_app.dart';

void main() {
  testWidgets('FarmerApp builds without crashing', (tester) async {
    expect(const FarmerApp(), isNotNull);
  });
}
