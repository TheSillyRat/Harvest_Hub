import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:intl/intl.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final UserAdminService _userService = UserAdminService();

  static const int _pageSize = 15;
  final List<AppUser> _users = [];
  DocumentSnapshot? _lastDoc;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  String _searchQuery = '';
  String _selectedFilter = 'All'; // 'All', 'Customers', 'Farmers', 'Active', 'Deactivated'

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadUsers(isRefresh: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        !_isLoadingMore &&
        _hasMore) {
      _loadUsers(isRefresh: false);
    }
  }

  Future<void> _loadUsers({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _isLoading = true;
        _hasMore = true;
        _lastDoc = null;
      });
    } else {
      if (!_hasMore || _isLoadingMore) return;
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      String roleParam = 'All';
      String statusParam = 'All';

      if (_selectedFilter == 'Customers') {
        roleParam = 'Customers';
      } else if (_selectedFilter == 'Farmers') {
        roleParam = 'Farmers';
      } else if (_selectedFilter == 'Active') {
        statusParam = 'Active';
      } else if (_selectedFilter == 'Deactivated') {
        statusParam = 'Deactivated';
      }

      final result = await _userService.fetchUsersPage(
        limit: _pageSize,
        startAfter: isRefresh ? null : _lastDoc,
        role: roleParam,
        status: statusParam,
        searchQuery: _searchQuery,
      );

      if (!mounted) return;

      setState(() {
        if (isRefresh) {
          _users.clear();
          _users.addAll(result.users);
          _isLoading = false;
        } else {
          _users.addAll(result.users);
          _isLoadingMore = false;
        }
        _lastDoc = result.lastDoc;
        _hasMore = result.hasMore;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading users: $e'),
          backgroundColor: HhColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Open Deactivation Reason Dialog
  Future<void> _showDeactivateDialog(AppUser user) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.block_rounded, color: HhColors.danger, size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Deactivate User',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to deactivate "${user.name.isNotEmpty ? user.name : user.email}"?',
                style: const TextStyle(fontSize: 14, color: HhColors.text),
              ),
              const SizedBox(height: 8),
              const Text(
                'This user will immediately be blocked from accessing the platform. Please specify the reason below:',
                style: TextStyle(fontSize: 12, color: HhColors.muted),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Reason for deactivation *',
                  hintText: 'e.g. Terms violation, fraudulent activity, etc.',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.withValues(alpha: 0.05),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a valid deactivation reason';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: HhColors.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _userService.deactivateUser(
          uid: user.uid,
          reason: reasonController.text.trim(),
          role: user.role,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'User "${user.name.isNotEmpty ? user.name : user.email}" deactivated.',
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: HhColors.danger,
            ),
          );
          _loadUsers(isRefresh: true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to deactivate user: $e'),
              backgroundColor: HhColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  /// Open Reactivation Confirmation Dialog
  Future<void> _showActivateDialog(AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Reactivate User',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reactivate account for "${user.name.isNotEmpty ? user.name : user.email}"?',
              style: const TextStyle(fontSize: 14, color: HhColors.text),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.info_outline, color: Colors.green, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The user will be notified upon their next app session that their account has been reactivated successfully.',
                      style: TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reactivate'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _userService.activateUser(
          uid: user.uid,
          role: user.role,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'User "${user.name.isNotEmpty ? user.name : user.email}" reactivated successfully.',
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.green,
            ),
          );
          _loadUsers(isRefresh: true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to activate user: $e'),
              backgroundColor: HhColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  /// Open Detailed User Modal
  Future<void> _showUserDetails(AppUser user) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _UserDetailsSheet(
        user: user,
        userService: _userService,
        onStatusChanged: () {
          Navigator.pop(ctx);
          _loadUsers(isRefresh: true);
        },
        onDeactivate: () {
          Navigator.pop(ctx);
          _showDeactivateDialog(user);
        },
        onActivate: () {
          Navigator.pop(ctx);
          _showActivateDialog(user);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HhColors.bg,
      appBar: AppBar(
        title: const Text(
          'Platform Users Management',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh list',
            onPressed: () => _loadUsers(isRefresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(
                  color: HhColors.text.withValues(alpha: 0.1),
                ),
              ),
              child: TextField(
                controller: _searchController,
                onSubmitted: (val) {
                  setState(() {
                    _searchQuery = val.trim().toLowerCase();
                  });
                  _loadUsers(isRefresh: true);
                },
                decoration: InputDecoration(
                  hintText: 'Search by name, email, or phone...',
                  prefixIcon: const Icon(Icons.search, color: HhColors.primary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                            _loadUsers(isRefresh: true);
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                'All',
                'Customers',
                'Farmers',
                'Active',
                'Deactivated',
              ].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    selectedColor: HhColors.primary.withValues(alpha: 0.15),
                    checkmarkColor: HhColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? HhColors.primary : HhColors.text,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                      _loadUsers(isRefresh: true);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),

          // Users List
          Expanded(
            child: RefreshIndicator(
              color: HhColors.primary,
              onRefresh: () => _loadUsers(isRefresh: true),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: HhColors.primary),
                    )
                  : _users.isEmpty
                      ? const Center(
                          child: Text(
                            'No users found matching criteria.',
                            style: TextStyle(color: HhColors.muted),
                          ),
                        )
                      : ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: _users.length + (_hasMore ? 1 : 0),
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (index == _users.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: HhColors.primary,
                                    ),
                                  ),
                                ),
                              );
                            }

                            final user = _users[index];
                            return _UserCard(
                              user: user,
                              onTap: () => _showUserDetails(user),
                              onToggleStatus: () {
                                if (user.isActive) {
                                  _showDeactivateDialog(user);
                                } else {
                                  _showActivateDialog(user);
                                }
                              },
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// USER CARD WIDGET
/// ============================================================
class _UserCard extends StatelessWidget {
  final AppUser user;
  final VoidCallback onTap;
  final VoidCallback onToggleStatus;

  const _UserCard({
    required this.user,
    required this.onTap,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isFarmer = user.role == Roles.farmer;
    final isAdmin = user.role == Roles.admin;
    final isDeactivated = !user.isActive;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDeactivated
              ? Colors.red.withValues(alpha: 0.25)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      color: isDeactivated ? Colors.red.withValues(alpha: 0.02) : Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Role Avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: isAdmin
                        ? HhColors.primary
                        : (isFarmer ? Colors.teal : Colors.blueGrey),
                    child: Icon(
                      isAdmin
                          ? Icons.admin_panel_settings
                          : (isFarmer ? Icons.agriculture : Icons.person),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Name & Email
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name.isNotEmpty ? user.name : 'No Name Provided',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: HhColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style: TextStyle(
                            fontSize: 13,
                            color: HhColors.text.withValues(alpha: 0.7),
                          ),
                        ),
                        if (user.phone.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            user.phone,
                            style: const TextStyle(
                              fontSize: 12,
                              color: HhColors.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Status & Action
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: (user.isActive ? Colors.green : Colors.red)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          user.isActive ? 'Active' : 'Deactivated',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: user.isActive ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (!isAdmin)
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            user.isActive
                                ? Icons.block_rounded
                                : Icons.check_circle_outline_rounded,
                            color: user.isActive ? HhColors.danger : Colors.green,
                            size: 22,
                          ),
                          tooltip: user.isActive
                              ? 'Deactivate User'
                              : 'Reactivate User',
                          onPressed: onToggleStatus,
                        ),
                    ],
                  ),
                ],
              ),

              // Reason Callout if Deactivated
              if (isDeactivated && user.deactivationReason != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: Colors.red, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Reason: ${user.deactivationReason}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Role tag & tap to view hint
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: HhColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'ROLE: ${user.role.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: HhColors.primary,
                      ),
                    ),
                  ),
                  Row(
                    children: const [
                      Text(
                        'View Details',
                        style: TextStyle(
                          fontSize: 12,
                          color: HhColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: HhColors.primary,
                      ),
                    ],
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

/// ============================================================
/// USER DETAILS MODAL SHEET
/// ============================================================
class _UserDetailsSheet extends StatelessWidget {
  final AppUser user;
  final UserAdminService userService;
  final VoidCallback onStatusChanged;
  final VoidCallback onDeactivate;
  final VoidCallback onActivate;

  const _UserDetailsSheet({
    required this.user,
    required this.userService,
    required this.onStatusChanged,
    required this.onDeactivate,
    required this.onActivate,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final isFarmer = user.role == Roles.farmer;
    final isAdmin = user.role == Roles.admin;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: FutureBuilder<UserDetailResult>(
        future: userService.getUserDetails(user.uid),
        builder: (context, snapshot) {
          final detail = snapshot.data;
          final farmer = detail?.farmerProfile;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header with user photo and name
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: isAdmin
                          ? HhColors.primary
                          : (isFarmer ? Colors.teal : Colors.blueGrey),
                      child: Icon(
                        isAdmin
                            ? Icons.admin_panel_settings
                            : (isFarmer ? Icons.agriculture : Icons.person),
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name.isNotEmpty ? user.name : 'No Name',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: HhColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.email,
                            style: const TextStyle(
                              fontSize: 13,
                              color: HhColors.muted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: (user.isActive ? Colors.green : Colors.red)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              user.isActive ? 'Active' : 'Deactivated',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color:
                                    user.isActive ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),

                // Basic Details
                _buildInfoRow('User ID', user.uid),
                _buildInfoRow('Role', user.role.toUpperCase()),
                _buildInfoRow('Phone', user.phone.isNotEmpty ? user.phone : 'Not set'),
                _buildInfoRow('Address', user.address.isNotEmpty ? user.address : 'Not set'),
                _buildInfoRow(
                  'Created At',
                  user.createdAt.year > 2000
                      ? dateFormat.format(user.createdAt)
                      : 'N/A',
                ),

                // Deactivation details if deactivated
                if (!user.isActive && user.deactivationReason != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Deactivation Notice',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Reason: ${user.deactivationReason}',
                          style: const TextStyle(fontSize: 13, color: Colors.red),
                        ),
                        if (user.deactivatedAt != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Deactivated on: ${dateFormat.format(user.deactivatedAt!)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                // Farmer Farm Store details if farmer
                if (isFarmer && farmer != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Farm Store Details',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: HhColors.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow('Business Name', farmer.businessName),
                  _buildInfoRow('Area / Region', farmer.area),
                  _buildInfoRow('Rating', '${farmer.rating} ★'),
                  if (farmer.description.isNotEmpty)
                    _buildInfoRow('Description', farmer.description),
                ],

                const SizedBox(height: 24),

                // Action buttons
                if (!isAdmin) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            user.isActive ? HhColors.danger : Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(
                        user.isActive
                            ? Icons.block_rounded
                            : Icons.check_circle_outline_rounded,
                      ),
                      label: Text(
                        user.isActive
                            ? 'Deactivate User Account'
                            : 'Reactivate User Account',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: user.isActive ? onDeactivate : onActivate,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: HhColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: HhColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
