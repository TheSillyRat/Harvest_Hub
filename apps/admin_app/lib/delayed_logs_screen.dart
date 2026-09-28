import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:intl/intl.dart';
import 'reports_models.dart';
import 'reports_service.dart';

class AdminDelayedLogsScreen extends StatefulWidget {
  final String? initialFarmerId;

  const AdminDelayedLogsScreen({
    super.key,
    this.initialFarmerId,
  });

  @override
  State<AdminDelayedLogsScreen> createState() => _AdminDelayedLogsScreenState();
}

class _AdminDelayedLogsScreenState extends State<AdminDelayedLogsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ReportsService _reportsService = ReportsService();
  late Future<PlatformReportData> _reportFuture;

  String? _selectedFarmerId;
  String? _selectedFarmerName;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedFarmerId = widget.initialFarmerId;
    if (_selectedFarmerId != null && _selectedFarmerId!.isNotEmpty) {
      _tabController.index = 1;
    }
    _loadReport();
  }

  void _loadReport() {
    setState(() {
      _reportFuture = _reportsService.fetchReportData();
    });
  }

  Future<void> _runOverdueCheck() async {
    setState(() => _isChecking = true);
    try {
      final cancelled =
          await OrderService().checkAndCancelOverduePendingOrders();
      _loadReport();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              cancelled.isEmpty
                  ? 'Checked: No pending orders exceeded 12 hours.'
                  : 'Processed: ${cancelled.length} overdue orders auto-cancelled and restocked.',
            ),
            backgroundColor:
                cancelled.isEmpty ? HhColors.primary : HhColors.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HhColors.bg,
      appBar: AppBar(
        title: const Text('Delayed Orders & Logs'),
        actions: [
          IconButton(
            icon: _isChecking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync_rounded),
            tooltip: 'Scan Overdue Orders (12h)',
            onPressed: _isChecking ? null : _runOverdueCheck,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reload',
            onPressed: _loadReport,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: HhColors.accent,
          indicatorWeight: 3,
          tabs: const [
            Tab(
              icon: Icon(Icons.leaderboard_outlined, size: 20),
              text: 'Delay Rates',
            ),
            Tab(
              icon: Icon(Icons.receipt_long_outlined, size: 20),
              text: 'Audit Logs',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStatisticsTab(),
          _buildAuditLogsTab(),
        ],
      ),
    );
  }

  Widget _buildStatisticsTab() {
    return FutureBuilder<PlatformReportData>(
      future: _reportFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: HhColors.primary),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading delay statistics: ${snapshot.error}'),
          );
        }

        final data = snapshot.data ?? PlatformReportData.empty();
        final stats = data.delayedFarmers;

        final totalDelayed =
            stats.fold<int>(0, (prev, s) => prev + s.delayedCount);
        final totalOrders =
            stats.fold<int>(0, (prev, s) => prev + s.totalOrders);
        final avgRate =
            totalOrders > 0 ? (totalDelayed / totalOrders) * 100 : 0.0;
        final affectedFarmers = stats.where((s) => s.delayedCount > 0).length;

        final filteredStats = stats.where((s) {
          if (_searchQuery.isEmpty) return true;
          final q = _searchQuery.toLowerCase();
          return s.businessName.toLowerCase().contains(q) ||
              s.farmerName.toLowerCase().contains(q) ||
              s.area.toLowerCase().contains(q);
        }).toList();

        return RefreshIndicator(
          onRefresh: () async => _loadReport(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'Delayed Orders',
                      '$totalDelayed',
                      Icons.timer_off_outlined,
                      Colors.red,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      'Avg Delay Rate',
                      '${avgRate.toStringAsFixed(1)}%',
                      Icons.percent_rounded,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      'Delayed Stalls',
                      '$affectedFarmers / ${stats.length}',
                      Icons.storefront_outlined,
                      HhColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search farmer by name or area...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Farmers Ranked by Delay Rate',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: HhColors.text,
                    ),
                  ),
                  Text(
                    '${filteredStats.length} farmers',
                    style: const TextStyle(
                      fontSize: 12,
                      color: HhColors.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (filteredStats.isEmpty)
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('No farmer delay records found.'),
                    ),
                  ),
                )
              else
                ...filteredStats.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final stat = entry.value;
                  return _buildFarmerDelayCard(idx + 1, stat);
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                color: HhColors.muted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFarmerDelayCard(int rank, FarmerDelayStat stat) {
    Color rateColor;
    if (stat.delayedCount == 0) {
      rateColor = Colors.green;
    } else if (stat.delayRate >= 20.0) {
      rateColor = Colors.red;
    } else if (stat.delayRate >= 10.0) {
      rateColor = Colors.orange;
    } else {
      rateColor = Colors.amber.shade800;
    }

    final double progress =
        stat.totalOrders > 0 ? (stat.delayedCount / stat.totalOrders) : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: stat.delayedCount > 0
              ? rateColor.withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: rank <= 3
                      ? rateColor.withValues(alpha: 0.15)
                      : Colors.grey.shade200,
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: rank <= 3 ? rateColor : HhColors.text,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stat.businessName.isNotEmpty
                            ? stat.businessName
                            : stat.farmerName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        stat.area.isNotEmpty ? stat.area : 'Local Hub',
                        style: const TextStyle(
                          fontSize: 12,
                          color: HhColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: rateColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${stat.delayRate.toStringAsFixed(1)}% DELAY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: rateColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: Colors.grey.shade200,
                color: rateColor,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${stat.delayedCount} delayed out of ${stat.totalOrders} total orders',
                  style: const TextStyle(
                    fontSize: 12,
                    color: HhColors.text,
                  ),
                ),
                if (stat.delayedCount > 0)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 14),
                    label: const Text('View Logs',
                        style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      setState(() {
                        _selectedFarmerId = stat.farmerId;
                        _selectedFarmerName = stat.businessName.isNotEmpty
                            ? stat.businessName
                            : stat.farmerName;
                        _tabController.animateTo(1);
                      });
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditLogsTab() {
    return Column(
      children: [
        if (_selectedFarmerId != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: HhColors.primary.withValues(alpha: 0.08),
            child: Row(
              children: [
                const Icon(Icons.filter_alt_outlined,
                    size: 16, color: HhColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Filtered by Farmer: ${_selectedFarmerName ?? _selectedFarmerId}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: HhColors.primary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedFarmerId = null;
                      _selectedFarmerName = null;
                    });
                  },
                  child: const Text('Clear Filter',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        Expanded(
          child: StreamBuilder<List<DelayedOrderLog>>(
            stream: OrderService()
                .streamDelayedOrderLogs(farmerId: _selectedFarmerId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: HhColors.primary),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error loading logs: ${snapshot.error}'),
                );
              }

              final logs = snapshot.data ?? [];
              if (logs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_outlined,
                          size: 56,
                          color: Colors.green.shade400,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No Delayed Orders',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _selectedFarmerId != null
                              ? 'This farmer has zero auto-cancelled timeout orders.'
                              : 'All pending orders on the platform were confirmed in time.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: HhColors.muted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: logs.length,
                itemBuilder: (context, idx) {
                  final log = logs[idx];
                  return _buildLogCard(log);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLogCard(DelayedOrderLog log) {
    final shortId =
        log.orderId.length > 8 ? log.orderId.substring(0, 8) : log.orderId;
    final createdStr =
        DateFormat('dd/MM/yyyy HH:mm').format(log.createdAt);
    final cancelledStr =
        DateFormat('dd/MM/yyyy HH:mm').format(log.cancelledAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.red.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.timer_off_outlined,
                        size: 16,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '#$shortId',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: HhColors.text,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'AUTO-CANCELLED (+12H)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Farmer Stall',
                        style: TextStyle(fontSize: 11, color: HhColors.muted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        log.farmerName.isNotEmpty
                            ? log.farmerName
                            : log.farmerId,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Customer',
                        style: TextStyle(fontSize: 11, color: HhColors.muted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        log.customerName.isNotEmpty
                            ? log.customerName
                            : log.customerId,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Order Placed',
                        style: TextStyle(fontSize: 11, color: HhColors.muted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        createdStr,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cancelled Time',
                        style: TextStyle(fontSize: 11, color: HhColors.muted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cancelledStr,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${log.itemCount} items · \$${(log.total / 100).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: HhColors.primary,
                  ),
                ),
                Text(
                  log.reason,
                  style: const TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: HhColors.muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
