import 'package:harvesthub_core/harvesthub_core.dart';

String comparableProductKey(Product product) =>
    '${product.name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ')}|${product.unit.trim().toLowerCase()}';

/// Compares a listing with matching offers from other farmers only.
Map<String, double> marketAveragePrices(Iterable<Product> products) {
  final all = products.toList(growable: false);
  final totals = <String, int>{};
  final counts = <String, int>{};
  final farmerTotals = <String, Map<String, int>>{};
  final farmerCounts = <String, Map<String, int>>{};

  for (final product in all) {
    final key = comparableProductKey(product);
    totals.update(key, (sum) => sum + product.price,
        ifAbsent: () => product.price);
    counts.update(key, (count) => count + 1, ifAbsent: () => 1);
    farmerTotals.putIfAbsent(key, () => {}).update(
        product.farmerId, (sum) => sum + product.price,
        ifAbsent: () => product.price);
    farmerCounts
        .putIfAbsent(key, () => {})
        .update(product.farmerId, (count) => count + 1, ifAbsent: () => 1);
  }

  final averages = <String, double>{};
  for (final product in all) {
    final key = comparableProductKey(product);
    final competitors = counts[key]! - farmerCounts[key]![product.farmerId]!;
    if (competitors > 0) {
      final total = totals[key]! - farmerTotals[key]![product.farmerId]!;
      averages[product.id] = total / competitors;
    }
  }
  return averages;
}
