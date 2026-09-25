import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'reports_models.dart';

class ReportsService {
  final FirebaseFirestore _firestore;

  ReportsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<PlatformReportData> fetchReportData() async {
    final ordersSnapshot = await _firestore.collection('orders').get();
    final farmersSnapshot = await _firestore.collection('farmers').get();

    final orders = ordersSnapshot.docs
        .map((doc) => FarmOrder.fromMap(doc.data(), id: doc.id))
        .toList();

    final farmers = farmersSnapshot.docs
        .map((doc) => FarmerProfile.fromMap(doc.data(), id: doc.id))
        .toList();

    return processReportData(orders, farmers);
  }

  PlatformReportData processReportData(
    List<FarmOrder> orders,
    List<FarmerProfile> farmers,
  ) {
    final farmerMap = <String, FarmerProfile>{};
    for (final farmer in farmers) {
      farmerMap[farmer.uid] = farmer;
    }

    int totalRevenue = 0;
    int completedOrders = 0;
    int cancelledOrders = 0;

    final marketOrderCount = <String, int>{};
    final marketRevenueMap = <String, int>{};

    final farmerOrderCount = <String, int>{};
    final farmerRevenueMap = <String, int>{};
    final farmerNameMap = <String, String>{};

    for (final order in orders) {
      final isCancelled = order.status == OrderStatus.cancelled;
      final isCompleted = order.status == OrderStatus.completed;

      if (isCompleted) {
        completedOrders++;
      }
      if (isCancelled) {
        cancelledOrders++;
      }
      if (!isCancelled) {
        totalRevenue += order.total;
      }

      final farmer = farmerMap[order.farmerId];
      final market = (farmer?.area.isNotEmpty == true)
          ? farmer!.area
          : 'Other';

      marketOrderCount[market] = (marketOrderCount[market] ?? 0) + 1;
      if (!isCancelled) {
        marketRevenueMap[market] =
            (marketRevenueMap[market] ?? 0) + order.total;
      }

      farmerOrderCount[order.farmerId] =
          (farmerOrderCount[order.farmerId] ?? 0) + 1;
      if (!isCancelled) {
        farmerRevenueMap[order.farmerId] =
            (farmerRevenueMap[order.farmerId] ?? 0) + order.total;
      }
      if (order.farmerName.isNotEmpty) {
        farmerNameMap[order.farmerId] = order.farmerName;
      }
    }

    final activeFarmersCount = farmers.where((f) => f.isActive).length;

    final summary = PlatformSummary(
      totalOrders: orders.length,
      totalRevenue: totalRevenue,
      completedOrders: completedOrders,
      cancelledOrders: cancelledOrders,
      activeFarmersCount: activeFarmersCount,
    );

    final marketRevenues = marketOrderCount.keys.map((market) {
      return MarketRevenue(
        marketName: market,
        orderCount: marketOrderCount[market] ?? 0,
        revenue: marketRevenueMap[market] ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    final farmerActivities = <FarmerActivity>[];
    final accountedFarmerIds = <String>{};

    for (final farmer in farmers) {
      accountedFarmerIds.add(farmer.uid);
      farmerActivities.add(
        FarmerActivity(
          farmerId: farmer.uid,
          farmerName: farmerNameMap[farmer.uid] ?? farmer.businessName,
          businessName: farmer.businessName,
          area: farmer.area,
          orderCount: farmerOrderCount[farmer.uid] ?? 0,
          revenue: farmerRevenueMap[farmer.uid] ?? 0,
        ),
      );
    }

    for (final farmerId in farmerOrderCount.keys) {
      if (!accountedFarmerIds.contains(farmerId)) {
        farmerActivities.add(
          FarmerActivity(
            farmerId: farmerId,
            farmerName: farmerNameMap[farmerId] ?? 'Unknown Farmer',
            businessName: farmerNameMap[farmerId] ?? 'Unknown Farm',
            area: 'Other',
            orderCount: farmerOrderCount[farmerId] ?? 0,
            revenue: farmerRevenueMap[farmerId] ?? 0,
          ),
        );
      }
    }

    farmerActivities.sort((a, b) {
      final orderCompare = b.orderCount.compareTo(a.orderCount);
      if (orderCompare != 0) return orderCompare;
      return b.revenue.compareTo(a.revenue);
    });

    return PlatformReportData(
      summary: summary,
      marketRevenues: marketRevenues,
      topFarmers: farmerActivities,
    );
  }
}
