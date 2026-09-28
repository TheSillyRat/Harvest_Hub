import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../location/customer_location.dart';

class MultiShopCheckoutScreen extends StatefulWidget {
  final List<CartItem> selectedItems;
  final CustomerLocation? location;
  final VoidCallback? onOrderPlaced;

  const MultiShopCheckoutScreen({
    super.key,
    required this.selectedItems,
    this.location,
    this.onOrderPlaced,
  });

  @override
  State<MultiShopCheckoutScreen> createState() =>
      _MultiShopCheckoutScreenState();
}

class _MultiShopCheckoutScreenState extends State<MultiShopCheckoutScreen> {
  bool _isSubmitting = false;
  final Map<String, String> _shopSlots = {};
  final Map<String, String> _shopDateChoice = {};
  final Map<String, Map<String, dynamic>> _farmerProfiles = {};
  bool _fetchingProfiles = false;

  @override
  void initState() {
    super.initState();
    final farmerIds = widget.selectedItems.map((i) => i.farmerId).toSet();
    for (final id in farmerIds) {
      _shopSlots[id] = 'morning_07_10';
      _shopDateChoice[id] = 'today';
    }
    _loadFarmerProfiles(farmerIds);
  }

  void _loadFarmerProfiles(Set<String> farmerIds) {
    if (_fetchingProfiles) return;
    _fetchingProfiles = true;
    Future.microtask(() async {
      try {
        for (final id in farmerIds) {
          final doc = await FirebaseFirestore.instance
              .collection('farmers')
              .doc(id)
              .get();
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            _farmerProfiles[id] = data;
            _initializeShopSelection(id, data);
          }
        }
        if (mounted) setState(() {});
      } catch (_) {
      } finally {
        _fetchingProfiles = false;
      }
    });
  }

  void _initializeShopSelection(String farmerId, Map<String, dynamic> profile) {
    final operatingHours =
        profile['operatingHours'] as String? ?? '07:00 - 18:00';
    final operatingDays = profile['operatingDays'] is List
        ? List<String>.from(profile['operatingDays'])
        : null;
    final operatingSlots = profile['operatingSlots'] as List<dynamic>?;

    final schedule = FarmerScheduleStatus.calculate(
      operatingDays: operatingDays,
      operatingHours: operatingHours,
    );

    final allSlots = FarmerScheduleStatus.getSlotsForOperatingHours(
      operatingHours,
      operatingSlots: operatingSlots,
    );

    final availableToday = allSlots
        .where((s) => FarmerScheduleStatus.isSlotAvailableToday(s))
        .toList();

    if (schedule.isOpenToday && availableToday.isNotEmpty) {
      _shopDateChoice[farmerId] = 'today';
      _shopSlots[farmerId] = availableToday.first;
    } else if (schedule.isOpenTomorrow && allSlots.isNotEmpty) {
      _shopDateChoice[farmerId] = 'tomorrow';
      _shopSlots[farmerId] = allSlots.first;
    } else if (allSlots.isNotEmpty) {
      _shopDateChoice[farmerId] = 'today';
      _shopSlots[farmerId] = allSlots.first;
    }
  }

  Map<String, List<CartItem>> _groupByFarmer(List<CartItem> items) {
    final map = <String, List<CartItem>>{};
    for (final item in items) {
      map.putIfAbsent(item.farmerId, () => []).add(item);
    }
    return map;
  }

  Future<void> _handleConfirmOrder(CartController cart) async {
    if (widget.selectedItems.isEmpty || _isSubmitting) return;

    final groups = _groupByFarmer(widget.selectedItems);
    for (final entry in groups.entries) {
      if (entry.value.length > 8) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${entry.value.first.farmerName} has ${entry.value.length} items. Maximum 8 items allowed per order.',
            ),
            backgroundColor: HhColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final shopDates = <String, DateTime>{};

    for (final entry in groups.entries) {
      final farmerId = entry.key;
      final choice = _shopDateChoice[farmerId] ?? 'today';
      final effectiveDate = choice == 'tomorrow' ? tomorrow : today;
      shopDates[farmerId] = effectiveDate;

      final slot = _shopSlots[farmerId];
      if (slot == null || slot.trim().isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please select an available pickup window for ${entry.value.first.farmerName}.',
            ),
            backgroundColor: HhColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _isSubmitting = true;
    });

    try {
      final authController = context.read<AuthController>();
      final uid = authController.user?.uid ?? 'customer_1';
      final orderService = OrderService();

      final notifService = NotificationService.instance;
      if (!notifService.hasPromptedPermission) {
        await notifService.requestPermission();
      }
      if (!mounted) return;

      final defaultSlot = _shopSlots.values.firstWhere(
        (s) => s.isNotEmpty,
        orElse: () => 'morning_07_10',
      );

      final orderIds = await orderService.placeOrders(
        uid,
        List<CartItem>.from(widget.selectedItems),
        'Green Valley Hub, West Market Station',
        defaultSlot,
        shopSlots: _shopSlots,
        shopDates: shopDates,
      );

      // Remove purchased items from cart
      for (final item in widget.selectedItems) {
        await cart.removeItem(item.productId);
      }

      // Send notifications
      try {
        await notifService.sendNotification(
          userId: uid,
          title: '🌱 Orders Placed Successfully',
          body:
              '${orderIds.length} orders submitted for in-person farm pickup.',
          type: 'order_placed',
          targetId: orderIds.isNotEmpty ? orderIds.first : null,
        );
      } catch (_) {}

      if (mounted) {
        final count = orderIds.length;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '$count ${count > 1 ? 'orders' : 'order'} placed successfully for in-person pickup!',
            ),
            backgroundColor: HhColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Pop back to root or trigger order placed callback
        navigator.pop(true);
        widget.onOrderPlaced?.call();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Could not place order: ${e.toString()}'),
            backgroundColor: HhColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();
    final authController = context.watch<AuthController>();
    final farmerGroups = _groupByFarmer(widget.selectedItems);

    final totalAmount = widget.selectedItems
        .fold<int>(0, (total, i) => total + (i.price * i.qty));
    final totalQuantity =
        widget.selectedItems.fold<int>(0, (total, i) => total + i.qty);

    return Scaffold(
      backgroundColor: HhColors.bg,
      appBar: AppBar(
        title: const Text(
          'Checkout',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: HhColors.text,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          children: [
            // 1. Header Section: Collector Information
            _buildCollectorInfoHeader(context, authController),

            // 2. Body Section: Multi-Shop Grouped Cards
            ...farmerGroups.entries.map((entry) {
              return _buildShopCard(
                context: context,
                farmerId: entry.key,
                items: entry.value,
              );
            }),
          ],
        ),
      ),
      // 3. Footer Section: Persistent Sticky Action Bar
      bottomNavigationBar: _buildStickyActionBar(
        context: context,
        cart: cart,
        totalQuantity: totalQuantity,
        totalAmount: totalAmount,
        farmerCount: farmerGroups.length,
      ),
    );
  }

  Widget _buildCollectorInfoHeader(BuildContext context, AuthController auth) {
    final user = auth.user;
    final name = (user?.name != null && user!.name.isNotEmpty)
        ? user.name
        : 'HarvestHub Customer';
    final phone = (user?.phone != null && user!.phone.isNotEmpty)
        ? user.phone
        : '+1 (555) 234-5678';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: HhColors.text.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: HhColors.text.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: HhColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_pin_rounded,
                    size: 18, color: HhColors.primary),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Collector Information',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: HhColors.text,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: HhColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Verified',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: HhColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.badge_outlined, size: 16, color: HhColors.muted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: HhColors.text,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.phone_iphone_rounded,
                  size: 16, color: HhColors.muted),
              const SizedBox(width: 6),
              Text(
                phone,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: HhColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: HhColors.sageLight.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 14, color: HhColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Contact details are used for order verification at pickup',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: HhColors.text.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopCard({
    required BuildContext context,
    required String farmerId,
    required List<CartItem> items,
  }) {
    final farmerName = items.first.farmerName.isNotEmpty
        ? items.first.farmerName
        : 'Local Farm';
    final groupSubtotal =
        items.fold<int>(0, (total, item) => total + (item.price * item.qty));
    final hasTooManyItems = items.length > 8;

    final profile = _farmerProfiles[farmerId];
    final marketName = (profile?['marketName'] ??
        profile?['businessName'] ??
        'Green Valley Farmers Market') as String;
    final marketAddress = (profile?['address'] ??
        profile?['farmAddress'] ??
        'Stall #4, 120 Harvest Way, Farm District') as String;
    final operatingHours =
        (profile?['operatingHours'] ?? '07:00 - 18:00') as String;
    final operatingDays = profile?['operatingDays'] is List
        ? List<String>.from(profile!['operatingDays'])
        : null;
    final operatingSlots = profile?['operatingSlots'] as List<dynamic>?;
    final scheduleStatus = FarmerScheduleStatus.calculate(
      operatingDays: operatingDays,
      operatingHours: operatingHours,
    );

    final allSlots = FarmerScheduleStatus.getSlotsForOperatingHours(
      operatingHours,
      operatingSlots: operatingSlots,
    );

    final now = DateTime.now();
    final todaySlots = allSlots
        .where((s) => FarmerScheduleStatus.isSlotAvailableToday(s, now: now))
        .toList();

    final canOrderToday = scheduleStatus.isOpenToday && todaySlots.isNotEmpty;
    final canOrderTomorrow = scheduleStatus.isOpenTomorrow;

    var selectedDateChoice = _shopDateChoice[farmerId];
    if (selectedDateChoice == null) {
      if (canOrderToday) {
        selectedDateChoice = 'today';
      } else if (canOrderTomorrow) {
        selectedDateChoice = 'tomorrow';
      } else {
        selectedDateChoice = 'today';
      }
      _shopDateChoice[farmerId] = selectedDateChoice;
    } else if (selectedDateChoice == 'today' && !canOrderToday && canOrderTomorrow) {
      selectedDateChoice = 'tomorrow';
      _shopDateChoice[farmerId] = selectedDateChoice;
    }

    final isDateTomorrow = selectedDateChoice == 'tomorrow';
    final activeSlots = isDateTomorrow ? allSlots : todaySlots;

    var selectedSlot = _shopSlots[farmerId];
    if (selectedSlot == null || !activeSlots.contains(selectedSlot)) {
      if (activeSlots.isNotEmpty) {
        selectedSlot = activeSlots.first;
        _shopSlots[farmerId] = selectedSlot;
      }
    }

    double lat = 37.7749;
    double lng = -122.4194;
    final pickupPoint = profile?['pickupLocation'];
    if (pickupPoint is GeoPoint) {
      lat = pickupPoint.latitude;
      lng = pickupPoint.longitude;
    }

    String distanceText = '2.4 km away';
    final userPos = widget.location?.position;
    if (userPos != null) {
      final meters = Geolocator.distanceBetween(
          userPos.latitude, userPos.longitude, lat, lng);
      if (meters < 1000) {
        distanceText = '${meters.round()} m away';
      } else {
        distanceText = '${(meters / 1000).toStringAsFixed(1)} km away';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasTooManyItems
              ? HhColors.danger.withValues(alpha: 0.5)
              : HhColors.text.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: HhColors.text.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: HhColors.sageLight.withValues(alpha: 0.35),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: HhColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    size: 18,
                    color: HhColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          farmerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: HhColors.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(Icons.verified,
                          size: 16, color: HhColors.primary),
                    ],
                  ),
                ),
                Text(
                  '${items.length} item${items.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: HhColors.text.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.grey.shade50,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 18, color: HhColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => MapLauncher.openDirections(
                      latitude: lat,
                      longitude: lng,
                      address: marketAddress,
                      label: farmerName,
                      context: context,
                    ),
                    borderRadius: BorderRadius.circular(6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          marketName,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: HhColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          marketAddress,
                          style: const TextStyle(
                            fontSize: 12,
                            color: HhColors.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: scheduleStatus.badgeColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    scheduleStatus.isOpenToday
                                        ? Icons.check_circle_rounded
                                        : Icons.schedule_rounded,
                                    size: 11,
                                    color: scheduleStatus.textColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    scheduleStatus.statusBadge,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: scheduleStatus.textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: HhColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.access_time_rounded,
                                      size: 11, color: HhColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    operatingHours,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: HhColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              distanceText,
                              style: TextStyle(
                                fontSize: 11,
                                color: HhColors.text.withValues(alpha: 0.6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Directions in Google Maps',
                  icon: const Icon(Icons.directions_rounded,
                      color: HhColors.primary, size: 24),
                  onPressed: () => MapLauncher.openDirections(
                    latitude: lat,
                    longitude: lng,
                    address: marketAddress,
                    label: farmerName,
                    context: context,
                  ),
                ),
              ],
            ),
          ),

          if (!scheduleStatus.isOpenToday)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              color: const Color(0xFFFFF3E0),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Color(0xFFE65100), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$farmerName is closed today. Orders placed will be prepared for pickup (${scheduleStatus.nextOpenText}).',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFBF360C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (hasTooManyItems)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: HhColors.danger.withValues(alpha: 0.08),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: HhColors.danger, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Max 8 items allowed per farm in one order. Please remove extra items.',
                      style: TextStyle(
                        fontSize: 12,
                        color: HhColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Product Items List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              children: items.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: ProductImage(
                          item.imageUrl,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            width: 52,
                            height: 52,
                            color: HhColors.sageLight,
                            child: const Icon(
                              Icons.agriculture_rounded,
                              color: HhColors.primary,
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
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: HhColors.text,
                              ),
                            ),
                            Text(
                              '\$${(item.price / 100).toStringAsFixed(2)} / ${item.unit}  •  Qty: ${item.qty}',
                              style: TextStyle(
                                fontSize: 12,
                                color: HhColors.text.withValues(alpha: 0.65),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '\$${((item.price * item.qty) / 100).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: HhColors.primary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_outlined,
                        size: 15, color: HhColors.primary),
                    const SizedBox(width: 6),
                    const Text(
                      'Pickup Date:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: HhColors.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (scheduleStatus.isOpenToday)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          checkmarkColor: Colors.white,
                          label: Text(
                            todaySlots.isEmpty
                                ? 'Today (${DateFormat('dd/MM').format(now)}) · Passed'
                                : 'Today (${DateFormat('dd/MM').format(now)})',
                            style: const TextStyle(fontSize: 11),
                          ),
                          selected: selectedDateChoice == 'today',
                          selectedColor: HhColors.primary,
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(
                            color: selectedDateChoice == 'today'
                                ? Colors.white
                                : (todaySlots.isEmpty
                                    ? HhColors.muted
                                    : HhColors.text),
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: todaySlots.isEmpty
                              ? null
                              : (val) {
                                  if (val) {
                                    setState(() {
                                      _shopDateChoice[farmerId] = 'today';
                                      if (todaySlots.isNotEmpty) {
                                        _shopSlots[farmerId] = todaySlots.first;
                                      }
                                    });
                                  }
                                },
                        ),
                      ),
                    if (canOrderTomorrow)
                      ChoiceChip(
                        visualDensity: VisualDensity.compact,
                        checkmarkColor: Colors.white,
                        label: Text(
                          'Tomorrow (${DateFormat('dd/MM').format(now.add(const Duration(days: 1)))})',
                          style: const TextStyle(fontSize: 11),
                        ),
                        selected: selectedDateChoice == 'tomorrow',
                        selectedColor: HhColors.primary,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: selectedDateChoice == 'tomorrow'
                              ? Colors.white
                              : HhColors.text,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _shopDateChoice[farmerId] = 'tomorrow';
                              if (allSlots.isNotEmpty) {
                                _shopSlots[farmerId] = allSlots.first;
                              }
                            });
                          }
                        },
                      ),
                  ],
                ),
                if (!canOrderToday && !canOrderTomorrow)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '$farmerName is closed today and tomorrow (${scheduleStatus.nextOpenText}).',
                      style: const TextStyle(
                        fontSize: 11,
                        color: HhColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else if (scheduleStatus.isOpenToday &&
                    todaySlots.isEmpty &&
                    canOrderTomorrow &&
                    selectedDateChoice == 'tomorrow')
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Today\'s pickup slots have closed. Showing slots for tomorrow.',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded,
                        size: 15, color: HhColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Pickup Window for $farmerName (Required):',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: HhColors.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (activeSlots.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      todaySlots.isEmpty && selectedDateChoice == 'today'
                          ? 'No more pickup windows remaining today.'
                          : 'No pickup windows available.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: HhColors.muted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: activeSlots.map((slot) {
                      final isSelected = selectedSlot == slot;
                      return ChoiceChip(
                        visualDensity: VisualDensity.compact,
                        checkmarkColor: Colors.white,
                        label: Text(slot, style: const TextStyle(fontSize: 11)),
                        selected: isSelected,
                        selectedColor: HhColors.primary,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : HhColors.text,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setState(() => _shopSlots[farmerId] = slot);
                          }
                        },
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),

          // Shop Subtotal Calculation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(9)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Shop Subtotal (${items.length} produce item${items.length > 1 ? 's' : ''}):',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: HhColors.text.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  '\$${(groupSubtotal / 100).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: HhColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyActionBar({
    required BuildContext context,
    required CartController cart,
    required int totalQuantity,
    required int totalAmount,
    required int farmerCount,
  }) {
    final hasLimitViolation = _groupByFarmer(widget.selectedItems)
        .values
        .any((items) => items.length > 8);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: HhColors.text.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total ($totalQuantity items from $farmerCount farm${farmerCount > 1 ? 's' : ''}):',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: HhColors.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.storefront_outlined,
                            size: 13, color: HhColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Self-Pickup only',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: HhColors.text.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  '\$${(totalAmount / 100).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: HhColors.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isSubmitting || hasLimitViolation)
                    ? null
                    : () => _handleConfirmOrder(cart),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HhColors.primary,
                  foregroundColor: HhColors.bg,
                  disabledBackgroundColor:
                      HhColors.muted.withValues(alpha: 0.3),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            hasLimitViolation
                                ? 'Reduce items to checkout'
                                : 'Confirm Order',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (!hasLimitViolation) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
