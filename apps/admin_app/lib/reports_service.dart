import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'reports_models.dart';

class RawReportsPayload {
  final List<FarmOrder> orders;
  final List<FarmerProfile> farmers;
  final Map<String, int> farmerLikesMap;
  final List<DelayedOrderLog> logs;

  const RawReportsPayload({
    required this.orders,
    required this.farmers,
    required this.farmerLikesMap,
    this.logs = const [],
  });
}

class ReportsService {
  final FirebaseFirestore _firestore;

  ReportsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<RawReportsPayload> fetchRawData() async {
    final ordersSnapshot = await _firestore.collection('orders').get();
    final farmersSnapshot = await _firestore.collection('farmers').get();
    final logsSnapshot = await _firestore.collection('delayed_order_logs').get();

    final orders = ordersSnapshot.docs
        .map((doc) => FarmOrder.fromMap(doc.data(), id: doc.id))
        .toList();

    final farmers = <FarmerProfile>[];
    final farmerLikesMap = <String, int>{};

    for (final doc in farmersSnapshot.docs) {
      final data = doc.data();
      final farmer = FarmerProfile.fromMap(data, id: doc.id);
      farmers.add(farmer);
      final likes = (data['followerCount'] ??
          data['followers'] ??
          data['likes'] ??
          0) as num;
      farmerLikesMap[doc.id] = likes.toInt();
    }

    final logs = logsSnapshot.docs
        .map((doc) => DelayedOrderLog.fromMap(doc.data(), id: doc.id))
        .toList();

    return RawReportsPayload(
      orders: orders,
      farmers: farmers,
      farmerLikesMap: farmerLikesMap,
      logs: logs,
    );
  }

  Future<PlatformReportData> fetchReportData({
    DateTimeRange? dateRange,
  }) async {
    final raw = await fetchRawData();
    return processReportData(
      raw.orders,
      raw.farmers,
      dateRange: dateRange,
      farmerLikesMap: raw.farmerLikesMap,
      logs: raw.logs,
    );
  }

  bool _isOrderInDateRange(DateTime orderDate, DateTimeRange? range) {
    if (range == null) return true;
    final start =
        DateTime(range.start.year, range.start.month, range.start.day);
    final end = DateTime(range.end.year, range.end.month, range.end.day, 23,
        59, 59, 999);
    return (orderDate.isAfter(start) || orderDate.isAtSameMomentAs(start)) &&
        (orderDate.isBefore(end) || orderDate.isAtSameMomentAs(end));
  }

  PlatformReportData processReportData(
    List<FarmOrder> orders,
    List<FarmerProfile> farmers, {
    DateTimeRange? dateRange,
    Map<String, int>? farmerLikesMap,
    List<DelayedOrderLog> logs = const [],
  }) {
    final filteredOrders = orders
        .where((o) => _isOrderInDateRange(o.createdAt, dateRange))
        .toList();

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

    for (final order in filteredOrders) {
      final isCancelled = order.status == OrderStatus.completed
          ? false
          : order.status == OrderStatus.cancelled;
      final isCompleted = order.status == OrderStatus.completed;

      final farmer = farmerMap[order.farmerId];
      final market =
          (farmer?.area.isNotEmpty == true) ? farmer!.area : 'Other';

      marketOrderCount[market] = (marketOrderCount[market] ?? 0) + 1;
      farmerOrderCount[order.farmerId] =
          (farmerOrderCount[order.farmerId] ?? 0) + 1;

      if (isCompleted) {
        completedOrders++;
        totalRevenue += order.total;
        marketRevenueMap[market] =
            (marketRevenueMap[market] ?? 0) + order.total;
        farmerRevenueMap[order.farmerId] =
            (farmerRevenueMap[order.farmerId] ?? 0) + order.total;
      }
      if (isCancelled) {
        cancelledOrders++;
      }
      if (order.farmerName.isNotEmpty) {
        farmerNameMap[order.farmerId] = order.farmerName;
      }
    }

    final activeFarmersCount = farmers.where((f) => f.isActive).length;

    final summary = PlatformSummary(
      totalOrders: filteredOrders.length,
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
          rating: farmer.rating,
          likesCount: farmerLikesMap?[farmer.uid] ?? 0,
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
            rating: 0.0,
            likesCount: 0,
          ),
        );
      }
    }

    farmerActivities.sort((a, b) {
      final orderCompare = b.orderCount.compareTo(a.orderCount);
      if (orderCompare != 0) return orderCompare;
      return b.revenue.compareTo(a.revenue);
    });

    final farmerDelayedCount = <String, int>{};
    for (final log in logs) {
      if (_isOrderInDateRange(log.createdAt, dateRange)) {
        farmerDelayedCount[log.farmerId] =
            (farmerDelayedCount[log.farmerId] ?? 0) + 1;
      }
    }
    for (final order in filteredOrders) {
      if (order.cancellationReason == 'auto_timeout_12h') {
        if (!logs.any((l) => l.orderId == order.id)) {
          farmerDelayedCount[order.farmerId] =
              (farmerDelayedCount[order.farmerId] ?? 0) + 1;
        }
      }
    }

    final delayedFarmers = <FarmerDelayStat>[];
    for (final farmer in farmers) {
      final total = farmerOrderCount[farmer.uid] ?? 0;
      final delayed = farmerDelayedCount[farmer.uid] ?? 0;
      final rate = total > 0 ? (delayed / total) * 100 : 0.0;
      delayedFarmers.add(
        FarmerDelayStat(
          farmerId: farmer.uid,
          farmerName: farmerNameMap[farmer.uid] ?? farmer.businessName,
          businessName: farmer.businessName,
          area: farmer.area,
          totalOrders: total,
          delayedCount: delayed,
          delayRate: rate,
        ),
      );
    }
    for (final fId in farmerOrderCount.keys) {
      if (!accountedFarmerIds.contains(fId)) {
        final total = farmerOrderCount[fId] ?? 0;
        final delayed = farmerDelayedCount[fId] ?? 0;
        final rate = total > 0 ? (delayed / total) * 100 : 0.0;
        delayedFarmers.add(
          FarmerDelayStat(
            farmerId: fId,
            farmerName: farmerNameMap[fId] ?? 'Unknown Farmer',
            businessName: farmerNameMap[fId] ?? 'Unknown Farm',
            area: 'Other',
            totalOrders: total,
            delayedCount: delayed,
            delayRate: rate,
          ),
        );
      }
    }

    delayedFarmers.sort((a, b) {
      final rateComp = b.delayRate.compareTo(a.delayRate);
      if (rateComp != 0) return rateComp;
      return b.delayedCount.compareTo(a.delayedCount);
    });

    return PlatformReportData(
      summary: summary,
      marketRevenues: marketRevenues,
      topFarmers: farmerActivities,
      delayedFarmers: delayedFarmers,
    );
  }
}
