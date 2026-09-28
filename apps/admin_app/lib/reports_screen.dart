import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:intl/intl.dart';
import 'delayed_logs_screen.dart';
import 'reports_models.dart';
import 'reports_service.dart';

enum FarmerSortBy {
  likes,
  rating,
  revenue,
  orders,
}

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final ReportsService _reportsService = ReportsService();
  late Future<RawReportsPayload> _payloadFuture;
  DateTimeRange? _selectedDateRange;
  FarmerSortBy _farmerSort = FarmerSortBy.orders;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _payloadFuture = _reportsService.fetchRawData();
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: HhColors.primary,
              onPrimary: Colors.white,
              onSurface: HhColors.text,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
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
      body: FutureBuilder<RawReportsPayload>(
        future: _payloadFuture,
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

          final payload = snapshot.data;
          if (payload == null) {
            return const Center(child: Text('No report data available'));
          }

          final data = _reportsService.processReportData(
            payload.orders,
            payload.farmers,
            dateRange: _selectedDateRange,
            farmerLikesMap: payload.farmerLikesMap,
            logs: payload.logs,
          );

          final sortedFarmers = List<FarmerActivity>.from(data.topFarmers);
          switch (_farmerSort) {
            case FarmerSortBy.likes:
              sortedFarmers.sort((a, b) {
                final c = b.likesCount.compareTo(a.likesCount);
                if (c != 0) return c;
                return b.rating.compareTo(a.rating);
              });
              break;
            case FarmerSortBy.rating:
              sortedFarmers.sort((a, b) {
                final c = b.rating.compareTo(a.rating);
                if (c != 0) return c;
                return b.orderCount.compareTo(a.orderCount);
              });
              break;
            case FarmerSortBy.revenue:
              sortedFarmers.sort((a, b) {
                final c = b.revenue.compareTo(a.revenue);
                if (c != 0) return c;
                return b.orderCount.compareTo(a.orderCount);
              });
              break;
            case FarmerSortBy.orders:
              sortedFarmers.sort((a, b) {
                final c = b.orderCount.compareTo(a.orderCount);
                if (c != 0) return c;
                return b.revenue.compareTo(a.revenue);
              });
              break;
          }

          final top5Farmers = sortedFarmers.take(5).toList();

          return RefreshIndicator(
            onRefresh: () async => _loadData(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildDateRangeBar(),
                const SizedBox(height: 16),
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
                _buildFarmersHeader(),
                const SizedBox(height: 12),
                _buildFarmersList(top5Farmers),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Farmer Delay Rates (12h)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.receipt_long, size: 16),
                      label: const Text('All Logs'),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AdminDelayedLogsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildDelayStatsList(data.delayedFarmers),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateRangeBar() {
    final hasRange = _selectedDateRange != null;
    final dateFormat = DateFormat('dd/MM/yyyy');
    final label = hasRange
        ? '${dateFormat.format(_selectedDateRange!.start)} - ${dateFormat.format(_selectedDateRange!.end)}'
        : 'All Time (Select custom date range)';

    return InkWell(
      onTap: _pickDateRange,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasRange
                ? HhColors.primary
                : HhColors.text.withValues(alpha: 0.12),
            width: hasRange ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.date_range_rounded,
              size: 20,
              color: hasRange ? HhColors.primary : HhColors.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: hasRange ? FontWeight.bold : FontWeight.w500,
                  color: hasRange ? HhColors.primary : HhColors.text,
                ),
              ),
            ),
            if (hasRange)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDateRange = null;
                  });
                },
                child: const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: HhColors.muted,
                  ),
                ),
              )
            else
              const Icon(
                Icons.arrow_drop_down_rounded,
                color: HhColors.muted,
              ),
          ],
        ),
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
        _buildStatCard(
            'Total Orders', '${summary.totalOrders}', Icons.receipt_long),
        _buildStatCard('Total Revenue',
            '\$${(summary.totalRevenue / 100).toStringAsFixed(2)}', Icons.attach_money),
        _buildStatCard(
            'Completed', '${summary.completedOrders}', Icons.check_circle),
        _buildStatCard(
            'Active Farmers', '${summary.activeFarmersCount}', Icons.agriculture),
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
                Text(title,
                    style: const TextStyle(fontSize: 13, color: HhColors.muted)),
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
            final double ratio =
                totalRevenue > 0 ? (market.revenue / totalRevenue) : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(market.marketName,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('\$${(market.revenue / 100).toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: HhColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${market.orderCount} orders',
                          style: const TextStyle(
                              fontSize: 12, color: HhColors.muted)),
                      Text('${(ratio * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                              fontSize: 12, color: HhColors.muted)),
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

  Widget _buildFarmersHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Most Active Farmers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: HhColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Top 5',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: HhColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildSortChip(FarmerSortBy.likes, 'Likes ❤️'),
              _buildSortChip(FarmerSortBy.rating, 'Rating ⭐'),
              _buildSortChip(FarmerSortBy.revenue, 'Revenue 💰'),
              _buildSortChip(FarmerSortBy.orders, 'Orders 🛒'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSortChip(FarmerSortBy sort, String label) {
    final isSelected = _farmerSort == sort;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: HhColors.primary.withValues(alpha: 0.15),
        checkmarkColor: HhColors.primary,
        showCheckmark: false,
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? HhColors.primary : HhColors.text,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected
                ? HhColors.primary
                : HhColors.text.withValues(alpha: 0.1),
          ),
        ),
        onSelected: (_) {
          setState(() {
            _farmerSort = sort;
          });
        },
      ),
    );
  }

  Widget _buildFarmersList(List<FarmerActivity> farmers) {
    if (farmers.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No farmer activity in this period'),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: farmers.length,
      itemBuilder: (context, index) {
        final farmer = farmers[index];
        Color rankColor;
        if (index == 0) {
          rankColor = const Color(0xFFD4AF37);
        } else if (index == 1) {
          rankColor = const Color(0xFF8E8E93);
        } else if (index == 2) {
          rankColor = const Color(0xFFCD7F32);
        } else {
          rankColor = HhColors.primary;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: index == 0
                  ? const Color(0xFFD4AF37).withValues(alpha: 0.4)
                  : HhColors.text.withValues(alpha: 0.08),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: rankColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '#${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: rankColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        farmer.businessName.isNotEmpty
                            ? farmer.businessName
                            : farmer.farmerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: HhColors.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 13, color: HhColors.muted),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              farmer.area.isNotEmpty ? farmer.area : 'Other',
                              style: const TextStyle(
                                  fontSize: 12, color: HhColors.muted),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.star_rounded,
                              size: 14, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            farmer.rating > 0
                                ? farmer.rating.toStringAsFixed(1)
                                : '5.0',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: HhColors.text,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.favorite_rounded,
                              size: 13, color: Colors.redAccent),
                          const SizedBox(width: 2),
                          Text(
                            '${farmer.likesCount}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: HhColors.text,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${(farmer.revenue / 100).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: HhColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${farmer.orderCount} orders',
                      style:
                          const TextStyle(fontSize: 12, color: HhColors.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDelayStatsList(List<FarmerDelayStat> stats) {
    if (stats.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No farmer delay data recorded.'),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.length > 5 ? 5 : stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        Color badgeColor;
        if (stat.delayedCount == 0) {
          badgeColor = Colors.green;
        } else if (stat.delayRate >= 20.0) {
          badgeColor = Colors.red;
        } else if (stat.delayRate >= 10.0) {
          badgeColor = Colors.orange;
        } else {
          badgeColor = Colors.amber.shade800;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: stat.delayedCount > 0
                  ? badgeColor.withValues(alpha: 0.3)
                  : Colors.grey.shade200,
            ),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: badgeColor.withValues(alpha: 0.12),
              child: Text(
                '#${index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: badgeColor,
                ),
              ),
            ),
            title: Text(
              stat.businessName.isNotEmpty ? stat.businessName : stat.farmerName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${stat.delayedCount} delayed / ${stat.totalOrders} total orders',
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${stat.delayRate.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: badgeColor,
                ),
              ),
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AdminDelayedLogsScreen(
                    initialFarmerId: stat.farmerId,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
