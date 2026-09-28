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

  static const int _statsPageSize = 10;
  int _statsCurrentPage = 1;

  static const int _logsPageSize = 10;
  int _logsCurrentPage = 1;
  final TextEditingController _logsSearchController = TextEditingController();
  String _logsSearchQuery = '';

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
                  ? 'Checked: No pending orders overdue past pickup window.'
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
    _logsSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HhColors.bg,
      appBar: AppBar(
        title: const Text(
          'Delayed Orders & Logs',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: _isChecking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: HhColors.primary,
                    ),
                  )
                : const Icon(Icons.sync_rounded),
            tooltip: 'Scan Overdue Orders',
            onPressed: _isChecking ? null : _runOverdueCheck,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reload',
            onPressed: _loadReport,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: HhColors.primary,
              unselectedLabelColor: HhColors.muted,
              indicatorColor: HhColors.primary,
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              tabs: const [
                Tab(
                  height: 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.leaderboard_outlined, size: 18),
                      SizedBox(width: 6),
                      Text('Delay Rates'),
                    ],
                  ),
                ),
                Tab(
                  height: 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 18),
                      SizedBox(width: 6),
                      Text('Audit Logs'),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
          if (s.delayedCount <= 0 || s.delayRate <= 0) return false;
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
                            setState(() {
                              _searchQuery = '';
                              _statsCurrentPage = 1;
                            });
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
                onChanged: (val) => setState(() {
                  _searchQuery = val.trim();
                  _statsCurrentPage = 1;
                }),
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
                    '${filteredStats.length} delayed farmers',
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
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        _searchQuery.isNotEmpty
                            ? 'No delayed farmers matched "$_searchQuery".'
                            : 'No farmers currently have delayed orders.',
                        style: const TextStyle(color: HhColors.muted),
                      ),
                    ),
                  ),
                )
              else ...[
                ...() {
                  final totalStats = filteredStats.length;
                  final totalStatsPages = (totalStats / _statsPageSize).ceil().clamp(1, double.infinity).toInt();
                  final currentStatsPage = _statsCurrentPage.clamp(1, totalStatsPages);
                  final startIndex = (currentStatsPage - 1) * _statsPageSize;
                  final pagedStats = filteredStats.skip(startIndex).take(_statsPageSize).toList();
                  return [
                    ...pagedStats.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final stat = entry.value;
                      final rank = startIndex + idx + 1;
                      return _buildFarmerDelayCard(rank, stat);
                    }),
                    _buildPaginationBar(
                      currentPage: currentStatsPage,
                      totalPages: totalStatsPages,
                      totalItems: totalStats,
                      startIndex: startIndex,
                      pageSize: _statsPageSize,
                      itemLabel: 'farmers',
                      onPageChanged: (newPage) {
                        setState(() {
                          _statsCurrentPage = newPage;
                        });
                      },
                    ),
                  ];
                }(),
              ],
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
                        _logsCurrentPage = 1;
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _logsSearchController,
            decoration: InputDecoration(
              hintText: 'Search order #, farmer, customer...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _logsSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _logsSearchController.clear();
                        setState(() {
                          _logsSearchQuery = '';
                          _logsCurrentPage = 1;
                        });
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
            onChanged: (val) => setState(() {
              _logsSearchQuery = val.trim();
              _logsCurrentPage = 1;
            }),
          ),
        ),
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
                      _logsCurrentPage = 1;
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
              final filteredLogs = logs.where((log) {
                if (_logsSearchQuery.isEmpty) return true;
                final q = _logsSearchQuery.toLowerCase();
                return log.orderId.toLowerCase().contains(q) ||
                    log.farmerName.toLowerCase().contains(q) ||
                    log.customerName.toLowerCase().contains(q) ||
                    log.reason.toLowerCase().contains(q);
              }).toList();

              if (filteredLogs.isEmpty) {
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
                        Text(
                          _logsSearchQuery.isNotEmpty
                              ? 'No Matching Audit Logs'
                              : 'No Delayed Orders',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _logsSearchQuery.isNotEmpty
                              ? 'No timeout logs matched "$_logsSearchQuery".'
                              : (_selectedFarmerId != null
                                  ? 'This farmer has zero auto-cancelled timeout orders.'
                                  : 'All pending orders on the platform were confirmed in time.'),
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

              final totalLogs = filteredLogs.length;
              final totalLogsPages = (totalLogs / _logsPageSize).ceil().clamp(1, double.infinity).toInt();
              final currentLogsPage = _logsCurrentPage.clamp(1, totalLogsPages);
              final startIndex = (currentLogsPage - 1) * _logsPageSize;
              final pagedLogs = filteredLogs.skip(startIndex).take(_logsPageSize).toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ...pagedLogs.map((log) => _buildLogCard(log)),
                  _buildPaginationBar(
                    currentPage: currentLogsPage,
                    totalPages: totalLogsPages,
                    totalItems: totalLogs,
                    startIndex: startIndex,
                    pageSize: _logsPageSize,
                    itemLabel: 'logs',
                    onPageChanged: (newPage) {
                      setState(() {
                        _logsCurrentPage = newPage;
                      });
                    },
                  ),
                ],
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
                    'AUTO-CANCELLED (TIMEOUT)',
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
                  log.reason.contains('12 hours') || log.reason.isEmpty
                      ? 'Unconfirmed after pickup window ended'
                      : log.reason,
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

  Widget _buildPaginationBar({
    required int currentPage,
    required int totalPages,
    required int totalItems,
    required int startIndex,
    required int pageSize,
    required String itemLabel,
    required ValueChanged<int> onPageChanged,
  }) {
    if (totalItems <= pageSize) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            'Showing all $totalItems $itemLabel',
            style: const TextStyle(fontSize: 12, color: HhColors.muted),
          ),
        ),
      );
    }

    final int startDisplay = startIndex + 1;
    final int endDisplay = (startIndex + pageSize).clamp(1, totalItems);

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$startDisplay-$endDisplay of $totalItems $itemLabel',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: HhColors.muted,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.first_page_rounded, size: 20),
                tooltip: 'First Page',
                visualDensity: VisualDensity.compact,
                onPressed: currentPage > 1 ? () => onPageChanged(1) : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                tooltip: 'Previous Page',
                visualDensity: VisualDensity.compact,
                onPressed: currentPage > 1
                    ? () => onPageChanged(currentPage - 1)
                    : null,
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: HhColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Page $currentPage / $totalPages',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: HhColors.primary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                tooltip: 'Next Page',
                visualDensity: VisualDensity.compact,
                onPressed: currentPage < totalPages
                    ? () => onPageChanged(currentPage + 1)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.last_page_rounded, size: 20),
                tooltip: 'Last Page',
                visualDensity: VisualDensity.compact,
                onPressed: currentPage < totalPages
                    ? () => onPageChanged(totalPages)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
