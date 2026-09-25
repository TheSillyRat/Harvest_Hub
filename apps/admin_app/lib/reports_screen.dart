import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'reports_models.dart';
import 'reports_service.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final ReportsService _reportsService = ReportsService();
  late Future<PlatformReportData> _reportFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _reportFuture = _reportsService.fetchReportData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HhColors.bg,
      appBar: AppBar(
        title: const Text('Platform Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: FutureBuilder<PlatformReportData>(
        future: _reportFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: HhColors.primary),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final data = snapshot.data ?? PlatformReportData.empty();

          return RefreshIndicator(
            onRefresh: () async => _loadData(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Overview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildOverviewGrid(data.summary),
                const SizedBox(height: 24),
                const Text(
                  'Revenue Across Markets',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildMarketList(data.marketRevenues, data.summary.totalRevenue),
                const SizedBox(height: 24),
                const Text(
                  'Most Active Farmers',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildFarmersList(data.topFarmers),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewGrid(PlatformSummary summary) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildStatCard('Total Orders', '${summary.totalOrders}', Icons.receipt_long),
        _buildStatCard('Total Revenue', '\$${(summary.totalRevenue / 100).toStringAsFixed(2)}', Icons.attach_money),
        _buildStatCard('Completed', '${summary.completedOrders}', Icons.check_circle),
        _buildStatCard('Active Farmers', '${summary.activeFarmersCount}', Icons.agriculture),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, color: HhColors.muted)),
                Icon(icon, size: 20, color: HhColors.primary),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketList(List<MarketRevenue> markets, int totalRevenue) {
    if (markets.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No market data available'),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: markets.map((market) {
            final double ratio = totalRevenue > 0 ? (market.revenue / totalRevenue) : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(market.marketName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('\$${(market.revenue / 100).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: HhColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${market.orderCount} orders', style: const TextStyle(fontSize: 12, color: HhColors.muted)),
                      Text('${(ratio * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, color: HhColors.muted)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: ratio,
                    backgroundColor: HhColors.sageLight,
                    color: HhColors.primary,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFarmersList(List<FarmerActivity> farmers) {
    if (farmers.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No farmer activity yet'),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: farmers.length,
      itemBuilder: (context, index) {
        final farmer = farmers[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: HhColors.sageLight,
              child: Text(
                '#${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: HhColors.primary),
              ),
            ),
            title: Text(
              farmer.businessName.isNotEmpty ? farmer.businessName : farmer.farmerName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(farmer.area.isNotEmpty ? farmer.area : 'Unknown'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${(farmer.revenue / 100).toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: HhColors.primary),
                ),
                Text(
                  '${farmer.orderCount} orders',
                  style: const TextStyle(fontSize: 12, color: HhColors.muted),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
