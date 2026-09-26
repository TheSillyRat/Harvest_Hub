import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'farmer_stock_screen.dart';

class FarmerProfileScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigate;
  const FarmerProfileScreen({super.key, this.onNavigate});

  @override
  State<FarmerProfileScreen> createState() => _FarmerProfileScreenState();
}

class _FarmerProfileScreenState extends State<FarmerProfileScreen> {
  FarmerProfile? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = context.read<AuthController>().user;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('farmers')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        if (mounted) {
          setState(() {
            _profile = FarmerProfile.fromMap(doc.data()!, id: doc.id);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _profile = FarmerProfile(
              uid: user.uid,
              userId: user.uid,
              businessName: 'My Farm Store',
              description: '',
              area: '',
              rating: 5.0,
              isActive: true,
              createdAt: user.createdAt,
              avatarUrl: user.avatarUrl,
            );
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openEditProfile(AppUser user) async {
    final updated = await openPage<bool>(
      context,
      FarmerEditProfileScreen(
        user: user,
        initialProfile: _profile,
      ),
    );
    if (updated == true) {
      _loadProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final user = authController.user;

    if (user == null) {
      return const EmptyView(message: 'Not logged in');
    }

    if (_isLoading) {
      return const LoadingView();
    }

    final businessName = _profile?.businessName.isNotEmpty == true
        ? _profile!.businessName
        : 'Farm Storefront';
    final avatarUrl = _profile?.avatarUrl.isNotEmpty == true
        ? _profile!.avatarUrl
        : user.avatarUrl;
    final area = _profile?.area ?? '';
    final rating = _profile?.rating ?? 5.0;

    final productsStream = ProductService().streamByFarmer(user.uid);

    return Scaffold(
      backgroundColor: HhColors.bg,
      body: StreamBuilder<List<Product>>(
        stream: productsStream,
        builder: (context, snapshot) {
          final products = snapshot.data ?? [];
          final outOfStockCount =
              products.where((p) => p.stockQty == 0).length;

          return SingleChildScrollView(
            child: Column(
              children: [
                // ==========================================
                // UPPER HALF: Personal & Farm Information Card
                // ==========================================
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        HhColors.primaryDark,
                        HhColors.primary,
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    children: [
                      // Farm Avatar with Edit Overlay
                      Center(
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 2.5,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 46,
                                backgroundColor: HhColors.sageLight,
                                child: avatarUrl.isNotEmpty
                                    ? ClipOval(
                                        child: SizedBox(
                                          width: 92,
                                          height: 92,
                                          child: ProductImage(avatarUrl),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.storefront_rounded,
                                        size: 46,
                                        color: HhColors.primary,
                                      ),
                              ),
                            ),
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: InkWell(
                                onTap: () => _openEditProfile(user),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: HhColors.accent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.2),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 14,
                                    color: HhColors.primaryDark,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Storefront / Business Name
                      Text(
                        businessName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Farmer Name & Verified Tag
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            user.name,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: HhColors.accent.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: HhColors.accent,
                                width: 0.8,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified,
                                    size: 11, color: HhColors.accent),
                                SizedBox(width: 3),
                                Text(
                                  'Verified Farmer',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: HhColors.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Detailed Info Container
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildInfoRow(
                              icon: Icons.location_on_outlined,
                              text: user.address.isNotEmpty
                                  ? user.address
                                  : 'No farm address provided',
                            ),
                            const Divider(
                              color: Colors.white12,
                              height: 14,
                            ),
                            _buildInfoRow(
                              icon: Icons.phone_outlined,
                              text: user.phone.isNotEmpty
                                  ? user.phone
                                  : 'No phone number',
                            ),
                            const Divider(
                              color: Colors.white12,
                              height: 14,
                            ),
                            _buildInfoRow(
                              icon: Icons.email_outlined,
                              text: user.email,
                            ),
                            if (area.isNotEmpty) ...[
                              const Divider(
                                color: Colors.white12,
                                height: 14,
                              ),
                              _buildInfoRow(
                                icon: Icons.landscape_outlined,
                                text: 'Area: $area',
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Quick Stats Strip
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildQuickStat(
                            value: '${products.length}',
                            label: 'Crops Listed',
                          ),
                          Container(
                            height: 24,
                            width: 1,
                            color: Colors.white24,
                          ),
                          _buildQuickStat(
                            value: '${rating.toStringAsFixed(1)} ★',
                            label: 'Store Rating',
                          ),
                          Container(
                            height: 24,
                            width: 1,
                            color: Colors.white24,
                          ),
                          _buildQuickStat(
                            value: 'Active',
                            label: 'Market Status',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ==========================================
                // LOWER HALF: Business Navigation Actions
                // ==========================================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section Header
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Text(
                          'Business & Operations',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: HhColors.text,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ⭐️ HIGHLIGHTED HERO BUTTON: Stock Management
                      _buildStockManagementHeroButton(outOfStockCount),

                      const SizedBox(height: 12),

                      // Action Button: Edit Profile
                      _buildNavigationTile(
                        icon: Icons.edit_note_rounded,
                        iconColor: const Color(0xFF1976D2),
                        iconBgColor: const Color(0xFFE3F2FD),
                        title: 'Manage Farmer Profile',
                        subtitle: 'Update shop name, avatar, and farm address',
                        onTap: () => _openEditProfile(user),
                      ),
                      const SizedBox(height: 10),

                      // Action Button: My Products Catalog
                      _buildNavigationTile(
                        icon: Icons.inventory_2_outlined,
                        iconColor: const Color(0xFF2E7D32),
                        iconBgColor: const Color(0xFFE8F5E9),
                        title: 'Product Catalog',
                        subtitle:
                            'Manage crop details, pricing, and descriptions',
                        onTap: () => widget.onNavigate?.call(1),
                      ),
                      const SizedBox(height: 10),

                      // Action Button: Orders & Fulfillment
                      _buildNavigationTile(
                        icon: Icons.receipt_long_outlined,
                        iconColor: const Color(0xFFF57C00),
                        iconBgColor: const Color(0xFFFFF3E0),
                        title: 'Orders & Fulfillment',
                        subtitle: 'Review incoming customer pickup orders',
                        onTap: () => widget.onNavigate?.call(2),
                      ),
                      const SizedBox(height: 10),

                      // Action Button: Reports & Analytics
                      _buildNavigationTile(
                        icon: Icons.bar_chart_rounded,
                        iconColor: const Color(0xFF7B1FA2),
                        iconBgColor: const Color(0xFFF3E5F5),
                        title: 'Sales & Revenue Reports',
                        subtitle: 'Track monthly sales and crop performance',
                        onTap: () => widget.onNavigate?.call(3),
                      ),
                      const SizedBox(height: 10),

                      // Action Button: Log Out
                      _buildNavigationTile(
                        icon: Icons.logout_rounded,
                        iconColor: HhColors.danger,
                        iconBgColor: HhColors.danger.withValues(alpha: 0.1),
                        title: 'Sign Out',
                        subtitle: 'Log out from your farmer account',
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Confirm Sign Out'),
                              content: const Text(
                                'Are you sure you want to log out from HarvestHub?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: HhColors.danger,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Log Out'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true && mounted) {
                            await authController.logout();
                          }
                        },
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.8)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStat({required String value, required String label}) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }

  /// ⭐️ PROMINENT HIGHLIGHTED BUTTON: Stock Management
  Widget _buildStockManagementHeroButton(int outOfStockCount) {
    return InkWell(
      onTap: () {
        final user = context.read<AuthController>().user;
        openPage(
          context,
          FarmerStockManagementScreen(farmerId: user?.uid),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2E7D32),
              Color(0xFF1B5E20),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon Container
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.warehouse_rounded,
                size: 28,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 14),

            // Texts
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Stock Management',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (outOfStockCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: HhColors.danger,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$outOfStockCount Empty',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Quick inventory updates & stock level control',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),

            // Arrow
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.18)),
      ),
      color: Colors.white,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: HhColors.text,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: HhColors.muted),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: HhColors.muted,
        ),
        onTap: onTap,
      ),
    );
  }
}

/// ============================================================
/// FARMER EDIT PROFILE SCREEN (Manage farmer profile)
/// Features:
/// - Edit shop name (businessName)
/// - Change avatar (ImagePicker & presets)
/// - Edit address
/// - Dirty checking with English confirmation dialog on back
/// - Success & failure notifications
/// ============================================================
class FarmerEditProfileScreen extends StatefulWidget {
  final AppUser user;
  final FarmerProfile? initialProfile;

  const FarmerEditProfileScreen({
    super.key,
    required this.user,
    this.initialProfile,
  });

  @override
  State<FarmerEditProfileScreen> createState() =>
      _FarmerEditProfileScreenState();
}

class _FarmerEditProfileScreenState extends State<FarmerEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _businessNameController;
  late final TextEditingController _addressController;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _areaController;

  String _currentAvatarUrl = '';
  File? _pickedAvatarFile;
  bool _busy = false;

  // Initial snapshot to compare dirty state
  late final String _initialBusinessName;
  late final String _initialAddress;
  late final String _initialName;
  late final String _initialPhone;
  late final String _initialDescription;
  late final String _initialArea;
  late final String _initialAvatarUrl;

  @override
  void initState() {
    super.initState();
    _initialBusinessName = widget.initialProfile?.businessName ?? '';
    _initialAddress = widget.user.address;
    _initialName = widget.user.name;
    _initialPhone = widget.user.phone;
    _initialDescription = widget.initialProfile?.description ?? '';
    _initialArea = widget.initialProfile?.area ?? '';
    _initialAvatarUrl = widget.initialProfile?.avatarUrl.isNotEmpty == true
        ? widget.initialProfile!.avatarUrl
        : widget.user.avatarUrl;

    _businessNameController =
        TextEditingController(text: _initialBusinessName);
    _addressController = TextEditingController(text: _initialAddress);
    _nameController = TextEditingController(text: _initialName);
    _phoneController = TextEditingController(text: _initialPhone);
    _descriptionController =
        TextEditingController(text: _initialDescription);
    _areaController = TextEditingController(text: _initialArea);
    _currentAvatarUrl = _initialAvatarUrl;
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _addressController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  bool _hasUnsavedChanges() {
    return _pickedAvatarFile != null ||
        _currentAvatarUrl != _initialAvatarUrl ||
        _businessNameController.text.trim() != _initialBusinessName.trim() ||
        _addressController.text.trim() != _initialAddress.trim() ||
        _nameController.text.trim() != _initialName.trim() ||
        _phoneController.text.trim() != _initialPhone.trim() ||
        _descriptionController.text.trim() != _initialDescription.trim() ||
        _areaController.text.trim() != _initialArea.trim();
  }

  /// English confirmation dialog when user attempts to exit with unsaved changes.
  Future<bool> _confirmDiscardChanges() async {
    if (!_hasUnsavedChanges()) return true;

    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
          'Are you sure you want to discard your changes? Any unsaved information will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Editing'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: HhColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return discard == true;
  }

  Future<void> _pickAvatarFromGallery() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _pickedAvatarFile = File(picked.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick image: $e'),
            backgroundColor: HhColors.danger,
          ),
        );
      }
    }
  }

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Change Farm Avatar',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: HhColors.text,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: HhColors.primary),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAvatarFromGallery();
                },
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Or select a fresh farm preset:',
                    style: TextStyle(
                      fontSize: 12,
                      color: HhColors.text.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 72,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildPresetAvatar(
                      'https://images.unsplash.com/photo-1500937386664-56d1dfef3854?w=400',
                      'Organic Field',
                    ),
                    const SizedBox(width: 12),
                    _buildPresetAvatar(
                      'https://images.unsplash.com/photo-1542838132-92c53300491e?w=400',
                      'Vegetables',
                    ),
                    const SizedBox(width: 12),
                    _buildPresetAvatar(
                      'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=400',
                      'Berry Farm',
                    ),
                    const SizedBox(width: 12),
                    _buildPresetAvatar(
                      'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=400',
                      'Dairy Farm',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetAvatar(String url, String label) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentAvatarUrl = url;
          _pickedAvatarFile = null;
        });
        Navigator.pop(context);
      },
      child: Tooltip(
        message: label,
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _currentAvatarUrl == url
                  ? HhColors.primary
                  : Colors.grey.withValues(alpha: 0.3),
              width: _currentAvatarUrl == url ? 3 : 1,
            ),
          ),
          child: ClipOval(
            child: ProductImage(url),
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);

    try {
      String finalAvatarUrl = _currentAvatarUrl;

      final authController = context.read<AuthController>();

      // Upload newly picked avatar if present
      if (_pickedAvatarFile != null) {
        final storage = StorageService();
        finalAvatarUrl = await storage.uploadAvatar(
          widget.user.uid,
          _pickedAvatarFile!,
        );
      }
      if (!mounted) return;

      final success = await authController.updateFarmerProfile(
        businessName: _businessNameController.text.trim(),
        address: _addressController.text.trim(),
        avatarUrl: finalAvatarUrl,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        description: _descriptionController.text.trim(),
        area: _areaController.text.trim(),
      );

      if (success) {
        if (mounted) {
          // Success notification
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Color(0xFF2E7D32),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          // Failure notification
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to update profile: ${authController.errorMessage ?? 'Unknown error'}',
              ),
              backgroundColor: HhColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        // Failure notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: HhColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _confirmDiscardChanges();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: HhColors.bg,
        appBar: AppBar(
          title: const Text(
            'Edit Farm Profile',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () async {
              final shouldPop = await _confirmDiscardChanges();
              if (shouldPop && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar Picker Section
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: HhColors.primary.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 48,
                              backgroundColor: HhColors.sageLight,
                              child: _pickedAvatarFile != null
                                  ? ClipOval(
                                      child: Image.file(
                                        _pickedAvatarFile!,
                                        width: 96,
                                        height: 96,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : (_currentAvatarUrl.isNotEmpty
                                      ? ClipOval(
                                          child: SizedBox(
                                            width: 96,
                                            height: 96,
                                            child: ProductImage(
                                                _currentAvatarUrl),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.storefront_rounded,
                                          size: 48,
                                          color: HhColors.primary,
                                        )),
                            ),
                          ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: InkWell(
                              onTap: _showAvatarOptions,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: HhColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _showAvatarOptions,
                        icon: const Icon(Icons.add_photo_alternate_outlined,
                            size: 18),
                        label: const Text('Change Avatar'),
                        style: TextButton.styleFrom(
                          foregroundColor: HhColors.primary,
                          textStyle:
                              const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Form Fields
                const Text(
                  'Store & Farm Information',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: HhColors.text,
                  ),
                ),
                const SizedBox(height: 12),

                // Shop / Storefront Name
                PillTextField(
                  controller: _businessNameController,
                  label: 'Storefront / Farm Name',
                  hint: 'e.g. Green Valley Farm',
                  icon: Icons.storefront_outlined,
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Please enter storefront name'
                      : null,
                ),
                const SizedBox(height: 14),

                // Farm Address
                PillTextField(
                  controller: _addressController,
                  label: 'Farm Contact & Pickup Address',
                  hint: 'e.g. 123 Farm Road, Da Lat, Lam Dong',
                  icon: Icons.location_on_outlined,
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Please enter farm address'
                      : null,
                ),
                const SizedBox(height: 14),

                // Farm Area / Region
                PillTextField(
                  controller: _areaController,
                  label: 'Area / Region',
                  hint: 'e.g. Da Lat, Lam Dong',
                  icon: Icons.landscape_outlined,
                ),
                const SizedBox(height: 14),

                // Farm Description
                PillTextField(
                  controller: _descriptionController,
                  label: 'Farm Description',
                  hint:
                      'Describe your farming methods, organic certifications...',
                  icon: Icons.description_outlined,
                ),
                const SizedBox(height: 20),

                const Text(
                  'Personal Information',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: HhColors.text,
                  ),
                ),
                const SizedBox(height: 12),

                // Full Name
                PillTextField(
                  controller: _nameController,
                  label: 'Farmer Full Name',
                  hint: 'e.g. John Farmer',
                  icon: Icons.person_outline,
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Please enter your name'
                      : null,
                ),
                const SizedBox(height: 14),

                // Phone
                PillTextField(
                  controller: _phoneController,
                  label: 'Contact Phone Number',
                  hint: '+84 912 345 678',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: phoneValidator,
                ),
                const SizedBox(height: 28),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HhColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 2,
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Save Profile',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
