import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:intl/intl.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'All';

  final List<String> _statusFilters = [
    'All',
    OrderStatus.pending,
    OrderStatus.confirmed,
    OrderStatus.readyForPickup,
    OrderStatus.completed,
    OrderStatus.cancelled,
  ];

  bool _isAscending = false;
  bool _isSearching = false;
  DateTime? _selectedDate;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
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
        _selectedDate = picked;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.readyForPickup:
        return Colors.teal;
      case OrderStatus.completed:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
      default:
        return HhColors.muted;
    }
  }

  void _showOrderDetails(BuildContext context, FarmOrder order) {

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${order.id.length > 8 ? order.id.substring(0, 8) : order.id}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: HhColors.text,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          _getStatusColor(order.status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      order.status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(order.status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Customer: ${order.customerName} (${order.customerPhone})',
                style: const TextStyle(fontSize: 14, color: HhColors.text),
              ),
              Text(
                'Farmer: ${order.farmerName}',
                style: const TextStyle(fontSize: 14, color: HhColors.text),
              ),
              Text(
                'Pickup Slot: ${order.pickupSlot == 'morning_07_10' ? 'Morning (07:00 - 10:00)' : order.pickupSlot == 'afternoon_15_18' ? 'Afternoon (15:00 - 18:00)' : order.pickupSlot}',
                style: TextStyle(
                  fontSize: 14,
                  color: HhColors.text.withValues(alpha: 0.8),
                ),
              ),
              if (order.isOverdueNoShow) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: HhColors.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: HhColors.danger.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: HhColors.danger, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No-Show Alert: Customer did not collect items within 12 hours of the pickup window.',
                          style: TextStyle(
                            color: HhColors.danger,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Divider(height: 24),
              const Text(
                'Order Items',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: order.items.length,
                  itemBuilder: (context, idx) {
                    final item = order.items[idx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${item.name} (${item.qty} ${item.unit})',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          Text(
                            '\$${(item.subtotal / 100).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Amount',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '\$${(order.total / 100).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: HhColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HhColors.text,
                    side: BorderSide(
                      color: HhColors.text.withValues(alpha: 0.2),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HhColors.bg,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(fontSize: 16, color: HhColors.text),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim().toLowerCase();
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Search customer, farmer, ID...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: HhColors.muted, fontSize: 14),
                ),
              )
            : const Text(
                'Order Management',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
        leading: _isSearching
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
              )
            : null,
        actions: [
          if (_isSearching)
            if (_searchQuery.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear_rounded, size: 20),
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
              )
            else
              const SizedBox.shrink()
          else
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedStatus != 'All'
                            ? HhColors.primary
                            : HhColors.text.withValues(alpha: 0.12),
                        width: _selectedStatus != 'All' ? 1.5 : 1,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedStatus,
                        isExpanded: true,
                        borderRadius: BorderRadius.circular(12),
                        icon: const Icon(
                          Icons.arrow_drop_down_rounded,
                          size: 20,
                          color: HhColors.muted,
                        ),
                        items: _statusFilters.map((status) {
                          final color = status == 'All'
                              ? HhColors.muted
                              : _getStatusColor(status);
                          return DropdownMenuItem<String>(
                            value: status,
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    status == 'All' ? 'All Status' : status,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: status == _selectedStatus
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: HhColors.text,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedStatus = val);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedDate != null
                            ? HhColors.primary
                            : HhColors.text.withValues(alpha: 0.12),
                        width: _selectedDate != null ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 15,
                          color: _selectedDate != null
                              ? HhColors.primary
                              : HhColors.muted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _selectedDate != null
                              ? DateFormat('dd/MM').format(_selectedDate!)
                              : 'All Dates',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _selectedDate != null
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: _selectedDate != null
                                ? HhColors.primary
                                : HhColors.text,
                          ),
                        ),
                        if (_selectedDate != null) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => setState(() => _selectedDate = null),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: HhColors.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => setState(() => _isAscending = !_isAscending),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: HhColors.text.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isAscending
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 16,
                          color: HhColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isAscending ? 'Old' : 'New',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: HhColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_selectedStatus != 'All' ||
                    _selectedDate != null ||
                    _searchQuery.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _selectedStatus = 'All';
                        _selectedDate = null;
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 40,
                      width: 36,
                      decoration: BoxDecoration(
                        color: HhColors.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.restart_alt_rounded,
                        size: 18,
                        color: HhColors.danger,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: SproutLoadingIndicator(size: 100),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                final orders = docs.map((doc) {
                  return FarmOrder.fromMap(
                    doc.data() as Map<String, dynamic>,
                    id: doc.id,
                  );
                }).where((o) {
                  final matchesSearch =
                      o.customerName.toLowerCase().contains(_searchQuery) ||
                          o.farmerName.toLowerCase().contains(_searchQuery) ||
                          o.id.toLowerCase().contains(_searchQuery);

                  if (!matchesSearch) return false;

                  if (_selectedStatus != 'All' && o.status != _selectedStatus) {
                    return false;
                  }

                  if (_selectedDate != null) {
                    final isSameDay = o.createdAt.year == _selectedDate!.year &&
                        o.createdAt.month == _selectedDate!.month &&
                        o.createdAt.day == _selectedDate!.day;
                    if (!isSameDay) return false;
                  }

                  return true;
                }).toList();

                orders.sort((a, b) {
                  final cmp = a.createdAt.compareTo(b.createdAt);
                  return _isAscending ? cmp : -cmp;
                });

                if (orders.isEmpty) {
                  return const Center(
                    child: Text(
                      'No orders found.',
                      style: TextStyle(color: HhColors.muted),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = orders[index];
                    return _OrderCard(
                      order: item,
                      statusColor: _getStatusColor(item.status),
                      onTap: () => _showOrderDetails(context, item),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final FarmOrder order;
  final Color statusColor;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: HhColors.text.withValues(alpha: 0.08),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '#${order.id.length > 8 ? order.id.substring(0, 8) : order.id}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: HhColors.primary,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (order.isOverdueNoShow) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: HhColors.danger.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: HhColors.danger.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 12,
                                color: HhColors.danger,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'NO-SHOW (+12H)',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: HhColors.danger,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          order.status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 16, color: HhColors.muted),
                  const SizedBox(width: 6),
                  Text(
                    'Buyer: ${order.customerName}',
                    style: const TextStyle(fontSize: 13, color: HhColors.text),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.storefront_outlined,
                      size: 16, color: HhColors.muted),
                  const SizedBox(width: 6),
                  Text(
                    'Farm: ${order.farmerName}',
                    style: const TextStyle(fontSize: 13, color: HhColors.text),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateFormat.format(order.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: HhColors.text.withValues(alpha: 0.6),
                    ),
                  ),
                  Text(
                    '\$${(order.total / 100).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: HhColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
