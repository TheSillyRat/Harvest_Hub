class PlatformSummary {
  final int totalOrders;
  final int totalRevenue;
  final int completedOrders;
  final int cancelledOrders;
  final int activeFarmersCount;

  const PlatformSummary({
    required this.totalOrders,
    required this.totalRevenue,
    required this.completedOrders,
    required this.cancelledOrders,
    required this.activeFarmersCount,
  });

  factory PlatformSummary.empty() {
    return const PlatformSummary(
      totalOrders: 0,
      totalRevenue: 0,
      completedOrders: 0,
      cancelledOrders: 0,
      activeFarmersCount: 0,
    );
  }
}

class MarketRevenue {
  final String marketName;
  final int orderCount;
  final int revenue;

  const MarketRevenue({
    required this.marketName,
    required this.orderCount,
    required this.revenue,
  });
}

class FarmerActivity {
  final String farmerId;
  final String farmerName;
  final String businessName;
  final String area;
  final int orderCount;
  final int revenue;

  const FarmerActivity({
    required this.farmerId,
    required this.farmerName,
    required this.businessName,
    required this.area,
    required this.orderCount,
    required this.revenue,
  });
}

class PlatformReportData {
  final PlatformSummary summary;
  final List<MarketRevenue> marketRevenues;
  final List<FarmerActivity> topFarmers;

  const PlatformReportData({
    required this.summary,
    required this.marketRevenues,
    required this.topFarmers,
  });

  factory PlatformReportData.empty() {
    return PlatformReportData(
      summary: PlatformSummary.empty(),
      marketRevenues: const [],
      topFarmers: const [],
    );
  }
}
