import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:provider/provider.dart';

import 'orders_screen.dart';
import 'products_screen.dart';
import 'reports_screen.dart';

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
                        'packages/harvesthub_core/assets/images/Admin_Logo.jpg',
                        width: 46,
                        height: 46,
                        fit: BoxFit.cover,
                        color: HhColors.bg,
                        colorBlendMode: BlendMode.multiply,
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

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final user = authController.user;

    return Scaffold(
      backgroundColor: HhColors.bg,
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'packages/harvesthub_core/assets/images/Admin_Logo.jpg',
                width: 46,
                height: 46,
                fit: BoxFit.cover,
                color: HhColors.bg,
                colorBlendMode: BlendMode.multiply,
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
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
            onPressed: () => authController.logout(),
          ),
        ],
      ),
      body: SingleChildScrollView(
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
                        'packages/harvesthub_core/assets/images/Admin_Logo.jpg',
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        color: HhColors.bg,
                        colorBlendMode: BlendMode.multiply,
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
            const SizedBox(height: 24),
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
