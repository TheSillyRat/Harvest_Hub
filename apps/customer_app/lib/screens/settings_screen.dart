import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:harvesthub_core/harvesthub_core.dart';

class CustomerSettingsScreen extends StatefulWidget {
  const CustomerSettingsScreen({super.key});

  @override
  State<CustomerSettingsScreen> createState() => _CustomerSettingsScreenState();
}

class _CustomerSettingsScreenState extends State<CustomerSettingsScreen> {
  PreferencesService? _prefs;
  bool _loading = true;

  bool _orderNotifications = true;
  bool _harvestAlerts = true;
  bool _promoAlerts = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await PreferencesService.getInstance();
    if (mounted) {
      setState(() {
        _prefs = prefs;
        _orderNotifications = prefs.orderNotificationsEnabled;
        _harvestAlerts = prefs.harvestAlertsEnabled;
        _promoAlerts = prefs.promoAlertsEnabled;
        _loading = false;
      });
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: HhColors.text,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HhColors.text.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  void _showPolicyDialog(String title, String content) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.78,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: HhColors.text,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  content,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.6,
                    color: HhColors.text,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HhColors.bg,
      appBar: AppBar(
        backgroundColor: HhColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: HhColors.text,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              children: [
                // NOTIFICATIONS
                _buildSectionHeader('Notifications'),
                _buildCard([
                  SwitchListTile(
                    value: _orderNotifications,
                    activeThumbColor: HhColors.primary,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    title: const Text(
                      'Order status updates',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Alerts when orders are confirmed, packed, and ready',
                      style: TextStyle(fontSize: 12, color: HhColors.muted),
                    ),
                    onChanged: (val) async {
                      setState(() => _orderNotifications = val);
                      await _prefs?.setOrderNotificationsEnabled(val);
                    },
                  ),
                  const Divider(height: 1, indent: 14, endIndent: 14),
                  SwitchListTile(
                    value: _harvestAlerts,
                    activeThumbColor: HhColors.primary,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    title: const Text(
                      'Farm harvest alerts',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Fresh harvest alerts from your followed farms',
                      style: TextStyle(fontSize: 12, color: HhColors.muted),
                    ),
                    onChanged: (val) async {
                      setState(() => _harvestAlerts = val);
                      await _prefs?.setHarvestAlertsEnabled(val);
                    },
                  ),
                  const Divider(height: 1, indent: 14, endIndent: 14),
                  SwitchListTile(
                    value: _promoAlerts,
                    activeThumbColor: HhColors.primary,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    title: const Text(
                      'Promotions & seasonal deals',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Exclusive seasonal discounts and weekend crop sales',
                      style: TextStyle(fontSize: 12, color: HhColors.muted),
                    ),
                    onChanged: (val) async {
                      setState(() => _promoAlerts = val);
                      await _prefs?.setPromoAlertsEnabled(val);
                    },
                  ),
                ]),

                // POLICIES & LEGAL
                _buildSectionHeader('Policies & Terms'),
                _buildCard([
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    leading: const Icon(Icons.privacy_tip_outlined,
                        color: HhColors.primary, size: 22),
                    title: const Text(
                      'Privacy Policy',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'How we protect and secure your personal data',
                      style: TextStyle(fontSize: 12, color: HhColors.muted),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => _showPolicyDialog(
                      'Privacy Policy',
                      '1. Information Collection & Usage\nHarvestHub collects basic account information (name, phone number, address) solely to facilitate fresh farm-to-table deliveries and pickup operations.\n\n2. Data Security & Storage\nAll user information is securely encrypted and stored using industry-standard cloud protocols. We never sell your personal information to third parties.\n\n3. Location Services\nLocation data is only accessed when permission is granted to identify nearby organic farms and calculate accurate delivery distances.\n\n4. Your Rights\nYou can request data export or account closure at any time through our customer support team.',
                    ),
                  ),
                  const Divider(height: 1, indent: 52),
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    leading: const Icon(Icons.description_outlined,
                        color: HhColors.primary, size: 22),
                    title: const Text(
                      'Terms of Service',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'User obligations, orders and marketplace conduct',
                      style: TextStyle(fontSize: 12, color: HhColors.muted),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => _showPolicyDialog(
                      'Terms of Service',
                      '1. HarvestHub Marketplace Platform\nHarvestHub operates as a direct bridge connecting local agricultural farms with conscious consumers.\n\n2. Order Fulfillment & Payments\nOrders are prepared fresh by partner farms upon confirmation. In COD (Cash on Delivery) mode, payment is made upon receipt of the produce.\n\n3. Reviews & Ratings Policy\nTo maintain verified authenticity, product reviews can only be submitted after completed orders containing the respective product. Farm reviews require at least one placed order.\n\n4. Pricing Transparency\nPrices shown include all farm-direct crop values without hidden platform markups.',
                    ),
                  ),
                  const Divider(height: 1, indent: 52),
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    leading: const Icon(Icons.verified_user_outlined,
                        color: HhColors.primary, size: 22),
                    title: const Text(
                      'Fresh Quality Guarantee',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      '100% freshness guarantee and return guidelines',
                      style: TextStyle(fontSize: 12, color: HhColors.muted),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => _showPolicyDialog(
                      'Fresh Quality Guarantee & Returns',
                      '1. 100% Farm Fresh Commitment\nEvery crop listed on HarvestHub is harvested directly from local sustainable farms.\n\n2. On-Delivery Inspection\nCustomers are encouraged to inspect produce upon arrival. If items are damaged, wilted, or not as described, you may refuse the item on the spot with zero penalty.\n\n3. Refund & Replacement Window\nWithin 24 hours of delivery, if any item does not meet high freshness standards, reach out via the in-app support or hotline for immediate compensation or farm replacement.',
                    ),
                  ),
                ]),

                // HELP & SUPPORT
                _buildSectionHeader('Help & Support'),
                _buildCard([
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    leading: const Icon(Icons.help_outline_rounded,
                        color: HhColors.primary, size: 22),
                    title: const Text(
                      'Frequently Asked Questions',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Answers about placing orders, farms & delivery',
                      style: TextStyle(fontSize: 12, color: HhColors.muted),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => _showPolicyDialog(
                      'Frequently Asked Questions (FAQ)',
                      'Q: How fresh is the produce?\nA: Most crops are harvested on the day of delivery or the evening before to preserve maximum crispness, aroma, and nutrients.\n\nQ: Can I combine produce from multiple farms?\nA: Yes! HarvestHub supports multi-farm baskets. During checkout, each farm\'s order is grouped cleanly with its own pickup/delivery schedule.\n\nQ: How do I review a product?\nA: To ensure honest reviews, you can write a review once you have completed an order containing that produce.',
                    ),
                  ),
                  const Divider(height: 1, indent: 52),
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    leading: const Icon(Icons.phone_in_talk_outlined,
                        color: HhColors.primary, size: 22),
                    title: const Text(
                      'Support Hotline',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      '1900 6868 (Daily 7:00 AM - 9:00 PM)',
                      style: TextStyle(fontSize: 12, color: HhColors.muted),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final uri = Uri.parse('tel:19006868');
                      try {
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        } else {
                          await Clipboard.setData(
                              const ClipboardData(text: '19006868'));
                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Copied hotline 1900 6868'),
                              ),
                            );
                          }
                        }
                      } catch (_) {}
                    },
                  ),
                ]),

                // ABOUT
                _buildSectionHeader('App Information'),
                _buildCard([
                  const ListTile(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    leading: Icon(Icons.eco_rounded,
                        color: HhColors.primary, size: 22),
                    title: Text(
                      'HarvestHub Marketplace',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Version 1.0.0 • TechWiz Fresh Produce Initiative',
                      style: TextStyle(fontSize: 12, color: HhColors.muted),
                    ),
                  ),
                ]),
              ],
            ),
    );
  }
}
