import 'dart:async';

import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:provider/provider.dart';

import 'categories_screen.dart';
import 'orders_screen.dart';
import 'products_screen.dart';
import 'reports_screen.dart';
import 'users_screen.dart';

class LoginScreen extends StatefulWidget {
  final String role;

  const LoginScreen({
    super.key,
    this.role = Roles.admin,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final controller = context.read<AuthController>();
    final success = await controller.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      widget.role,
    );

    if (!success && mounted) {
      final message = controller.errorMessage ??
          'Login failed. Please check your credentials.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: HhColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();

    return Scaffold(
      backgroundColor: HhColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28.0, 24.0, 28.0, 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'packages/harvesthub_core/assets/images/Logo_HarvestHub.png',
                        width: 46,
                        height: 46,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: HhColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.spa_rounded,
                              size: 26,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    RichText(
                      text: const TextSpan(
                        text: 'Harvest',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                          color: HhColors.primary,
                        ),
                        children: [
                          TextSpan(
                            text: 'Hub',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: HhColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const Text(
                  'Administrator Portal',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: HhColors.text,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Centralized management system for marketplace oversight, user verification, product categories, and platform analytics.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: HhColors.text.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 36),
                PillTextField(
                  controller: _emailController,
                  label: 'Admin Email',
                  hint: 'admin@harvesthub.app',
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) {
                    if (val == null || !val.contains('@')) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                PillTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: '••••••••••••',
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                  obscureText: _obscurePassword,
                  onToggleVisibility: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  validator: (val) {
                    if (val == null || val.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: authController.isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HhColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: authController.isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CategoryForm extends StatefulWidget {
  final Category? category;
  const CategoryForm({super.key, this.category});
  @override
  State<CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<CategoryForm> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.category?.name);
  late final sort =
      TextEditingController(text: widget.category?.sortOrder.toString() ?? '0');
  late bool active = widget.category?.isActive ?? true;
  bool busy = false;
  @override
  void dispose() {
    name.dispose();
    sort.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text(widget.category == null ? 'Add Category' : 'Edit Category')),
      body: Form(
          key: form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            HhTextField(controller: name, label: 'Category Name'),
            HhTextField(
                controller: sort,
                label: 'Display Order',
                keyboardType: TextInputType.number,
                validator: nonNegativeInt),
            SwitchListTile(
                title: const Text('Is Active'),
                value: active,
                onChanged: (v) => setState(() => active = v)),
            HhButton(
                label: 'Save Category',
                busy: busy,
                onPressed: () async {
                  if (!form.currentState!.validate()) return;
                  setState(() => busy = true);
                  try {
                    await CategoryService().save(Category(
                        id: widget.category?.id ?? '',
                        name: name.text.trim(),
                        imageUrl: widget.category?.imageUrl ?? '',
                        sortOrder: int.parse(sort.text),
                        isActive: active));
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) showError(context, e);
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                }),
          ])));
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  AppNotification? _activeInAppNotification;
  bool _hasCheckedPendingOnLogin = false;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.onInAppNotificationReceived = (notification) {
      if (mounted) {
        setState(() {
          _activeInAppNotification = notification;
        });
      }
    };
    NotificationService.instance.onOpenNotificationHistory = () {
      if (mounted) {
        final uid = context.read<AuthController>().user?.uid ?? '';
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NotificationHistoryScreen(userId: uid),
          ),
        );
      }
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingFarmersOnLogin();
    });
  }

  void _checkPendingFarmersOnLogin() {
    if (_hasCheckedPendingOnLogin) return;
    _hasCheckedPendingOnLogin = true;
    UserAdminService().streamPendingFarmers().first.then((pendingList) {
      if (!mounted) return;
      if (pendingList.isNotEmpty) {
        _showPendingFarmersLoginDialog(pendingList);
      }
    }).catchError((_) {});
  }

  Future<void> _showPendingFarmersLoginDialog(List<AppUser> pendingFarmers) async {
    final count = pendingFarmers.length;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFB8892D).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.notification_important_rounded,
                color: Color(0xFFB8892D),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'New Farmer Registrations',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF4F5B2A),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              count == 1
                  ? 'There is 1 new farmer registration awaiting category verification and approval.'
                  : 'There are $count new farmer registrations awaiting category verification and approval.',
              style: const TextStyle(
                fontSize: 14,
                color: HhColors.text,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF4F5B2A).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF4F5B2A).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: Color(0xFF4F5B2A),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Farmer accounts require administrative approval before they can list products or log in.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Dismiss',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4F5B2A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      const AdminUsersScreen(initialFilter: 'Pending Approval'),
                ),
              );
            },
            icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
            label: const Text('Review Now'),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.read<AuthController>().user?.uid ?? '';
    if (uid.isNotEmpty) {
      NotificationService.instance.startListeningToUserNotifications(uid);
    }
  }

  @override
  void dispose() {
    NotificationService.instance.stopListeningToUserNotifications();
    NotificationService.instance.onInAppNotificationReceived = null;
    NotificationService.instance.onOpenNotificationHistory = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final user = authController.user;
    final uid = user?.uid ?? '';

    return Scaffold(
      backgroundColor: HhColors.bg,
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'packages/harvesthub_core/assets/images/Logo_HarvestHub.png',
                width: 46,
                height: 46,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: HhColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.spa_rounded,
                      size: 26,
                      color: Colors.white,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            RichText(
              text: const TextSpan(
                text: 'Harvest',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                  color: HhColors.primary,
                ),
                children: [
                  TextSpan(
                    text: 'Hub',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: HhColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          StreamBuilder<int>(
            stream: NotificationService.instance.streamUnreadCount(uid),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    tooltip: 'Notifications',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NotificationHistoryScreen(userId: uid),
                        ),
                      );
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
            onPressed: () => authController.logout(),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'packages/harvesthub_core/assets/images/Logo_HarvestHub.png',
                        width: 56,
                        height: 56,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const CircleAvatar(
                            radius: 28,
                            backgroundColor: HhColors.primary,
                            child: Icon(
                              Icons.admin_panel_settings,
                              color: Colors.white,
                              size: 32,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name.isNotEmpty == true
                                ? user!.name
                                : 'Administrator',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: HhColors.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? 'admin@harvesthub.app',
                            style: TextStyle(
                              fontSize: 14,
                              color: HhColors.text.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: HhColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'ROLE: ADMIN',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: HhColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const _PendingFarmersSection(),
            const SizedBox(height: 20),
            const Text(
              'Management Modules',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: HhColors.text,
              ),
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.95,
              children: [
                _DashboardCard(
                  title: 'Users',
                  subtitle: 'Manage accounts',
                  icon: Icons.people_alt_outlined,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AdminUsersScreen(),
                      ),
                    );
                  },
                ),
                _DashboardCard(
                  title: 'Categories',
                  subtitle: 'Product groups',
                  icon: Icons.category_outlined,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AdminCategoriesScreen(),
                      ),
                    );
                  },
                ),
                _DashboardCard(
                  title: 'Products',
                  subtitle: 'Platform catalog',
                  icon: Icons.inventory_2_outlined,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AdminProductsScreen(),
                      ),
                    );
                  },
                ),
                _DashboardCard(
                  title: 'Orders',
                  subtitle: 'Monitor trades',
                  icon: Icons.receipt_long_outlined,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AdminOrdersScreen(),
                      ),
                    );
                  },
                ),
                _DashboardCard(
                  title: 'Reports',
                  subtitle: 'System analytics',
                  icon: Icons.bar_chart_outlined,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AdminReportsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      if (_activeInAppNotification != null)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: InAppNotificationBanner(
            notification: _activeInAppNotification!,
            userId: uid,
            onDismiss: () {
              if (mounted) {
                setState(() {
                  _activeInAppNotification = null;
                });
              }
            },
          ),
        ),
    ],
  ),
);
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const _DashboardCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12.0,
            vertical: 12.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: HhColors.primary.withValues(alpha: 0.1),
                child: Icon(icon, color: HhColors.primary, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: HhColors.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: HhColors.text.withValues(alpha: 0.65),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingFarmersSection extends StatefulWidget {
  const _PendingFarmersSection();

  @override
  State<_PendingFarmersSection> createState() => _PendingFarmersSectionState();
}

class _PendingFarmersSectionState extends State<_PendingFarmersSection> {
  final UserAdminService _userAdminService = UserAdminService();
  final CategoryService _categoryService = CategoryService();
  final Set<String> _approvingUids = {};
  Map<String, String> _categoryNameMap = {
    for (final c in CategoryService.getFallbackCategories()) c.id: c.name,
  };
  StreamSubscription<List<Category>>? _categorySub;

  @override
  void initState() {
    super.initState();
    _categorySub = _categoryService.stream().listen((cats) {
      if (mounted) {
        setState(() {
          _categoryNameMap = {for (final c in cats) c.id: c.name};
        });
      }
    });
  }

  @override
  void dispose() {
    _categorySub?.cancel();
    super.dispose();
  }

  Future<void> _approve(AppUser farmer) async {
    setState(() => _approvingUids.add(farmer.uid));
    try {
      await _userAdminService.approveFarmer(uid: farmer.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Farmer account "${farmer.name.isNotEmpty ? farmer.name : farmer.email}" approved successfully!',
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF4F5B2A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve farmer: $e'),
            backgroundColor: HhColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _approvingUids.remove(farmer.uid));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: _userAdminService.streamPendingFarmers(),
      builder: (context, snapshot) {
        final pendingFarmers = snapshot.data ?? [];
        if (pendingFarmers.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF4F5B2A).withValues(alpha: 0.2),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F5B2A).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: Color(0xFF4F5B2A),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Pending Farmer Approvals',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4F5B2A),
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'No pending registrations awaiting approval. All farmer accounts are up to date.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.pending_actions_rounded,
                  color: Color(0xFFB8892D),
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Pending Farmer Approvals',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4F5B2A),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB8892D),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${pendingFarmers.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pendingFarmers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final farmer = pendingFarmers[index];
                final isApproving = _approvingUids.contains(farmer.uid);
                return _buildFarmerCard(farmer, isApproving);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildFarmerCard(AppUser farmer, bool isApproving) {
    final initials = farmer.name.isNotEmpty
        ? farmer.name
            .trim()
            .split(' ')
            .where((e) => e.isNotEmpty)
            .map((e) => e[0])
            .take(2)
            .join()
            .toUpperCase()
        : 'F';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFB8892D).withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF4F5B2A).withValues(alpha: 0.12),
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4F5B2A),
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      farmer.name.isNotEmpty ? farmer.name : 'New Farmer',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: HhColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.email_outlined,
                          size: 14,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            farmer.email,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (farmer.phone.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 14,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            farmer.phone,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (farmer.address.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              farmer.address,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFB8892D).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFB8892D).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.hourglass_top_rounded,
                      size: 12,
                      color: Color(0xFFB8892D),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Pending Approval',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB8892D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (farmer.registeredCategoryIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Registered Business Categories:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: farmer.registeredCategoryIds.map((catId) {
                final catName = categoryDisplayName(catId, _categoryNameMap[catId] ?? catId);
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F5B2A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF4F5B2A).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.eco_outlined,
                        size: 13,
                        color: Color(0xFF4F5B2A),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        catName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4F5B2A),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isApproving ? null : () => _approve(farmer),
              icon: isApproving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: Text(
                isApproving ? 'Approving Account...' : 'Approve Account',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F5B2A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

