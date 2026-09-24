import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:harvesthub_core/harvesthub_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const CustomerApp());
}

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthController>(
      create: (_) => AuthController(),
      child: MaterialApp(
        title: 'HarvestHub Customer App',
        debugShowCheckedModeBanner: false,
        theme: harvestHubTheme(),
        home: const CustomerAuthWrapper(),
      ),
    );
  }
}

class CustomerAuthWrapper extends StatelessWidget {
  const CustomerAuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();

    if (authController.user != null) {
      return const CustomerHomeScreen();
    }
    return const CustomerAuthScreen();
  }
}

class CustomerAuthScreen extends StatefulWidget {
  const CustomerAuthScreen({super.key});

  @override
  State<CustomerAuthScreen> createState() => _CustomerAuthScreenState();
}

class _CustomerAuthScreenState extends State<CustomerAuthScreen> {
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _rememberMe = true;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = context.read<AuthController>();
    final success = await controller.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      Roles.customer,
    );

    if (!success && mounted && controller.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(controller.errorMessage!),
          backgroundColor: HhColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _submitRegister() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = context.read<AuthController>();
    final success = await controller.registerCustomer(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (!success && mounted && controller.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(controller.errorMessage!),
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('HarvestHub Customer'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 12.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BadgeChip(
                  label: _isSignUp ? 'JOIN HARVEST NETWORK' : 'SECURE TRADING PORTAL',
                  icon: Icons.shield_outlined,
                ),
                const SizedBox(height: 18),
                Text(
                  _isSignUp ? 'Cultivate Your\nFresh Produce Account' : 'Welcome Back\nTo HarvestHub',
                  style: const TextStyle(
                    fontSize: 32,
                    height: 1.15,
                    fontWeight: FontWeight.bold,
                    color: HhColors.text,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _isSignUp
                      ? 'Create your verified buyer account to order fresh produce directly from local farmers.'
                      : 'Sign in to access your orders, saved items, and fresh farm harvests.',
                  style: TextStyle(
                    fontSize: 14.5,
                    color: HhColors.text.withValues(alpha: 0.72),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 28),
                if (_isSignUp) ...[
                  PillTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    hint: 'John Smith',
                    icon: Icons.person_outline,
                    validator: (val) => val == null || val.trim().isEmpty ? 'Enter full name' : null,
                  ),
                  const SizedBox(height: 16),
                ],
                PillTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  hint: 'customer@harvesthub.app',
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) => val == null || !val.contains('@') ? 'Enter valid email' : null,
                ),
                const SizedBox(height: 16),
                if (_isSignUp) ...[
                  PillTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    hint: '+84 901 234 567',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (val) => val == null || val.trim().isEmpty ? 'Enter phone number' : null,
                  ),
                  const SizedBox(height: 16),
                  PillTextField(
                    controller: _addressController,
                    label: 'Pickup / Delivery Address',
                    hint: '123 Green Valley Road, Da Lat',
                    icon: Icons.home_outlined,
                    validator: (val) => val == null || val.trim().isEmpty ? 'Enter address' : null,
                  ),
                  const SizedBox(height: 16),
                ],
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
                  validator: (val) => val == null || val.length < 6 ? 'Password must be at least 6 chars' : null,
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _rememberMe = !_rememberMe;
                        });
                      },
                      child: Row(
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: _rememberMe,
                              activeColor: HhColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              onChanged: (val) {
                                setState(() {
                                  _rememberMe = val ?? false;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Remember me',
                            style: TextStyle(
                              fontSize: 13,
                              color: HhColors.text.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: authController.isLoading ? null : (_isSignUp ? _submitRegister : _submitLogin),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HhColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 2,
                    ),
                    child: authController.isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            _isSignUp ? 'Create Customer Account' : 'Sign In To Account',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 28),
                Center(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isSignUp = !_isSignUp;
                      });
                    },
                    child: RichText(
                      text: TextSpan(
                        text: _isSignUp ? 'Already have a customer account? ' : "Don't have an account? ",
                        style: TextStyle(
                          fontSize: 14,
                          color: HhColors.text.withValues(alpha: 0.7),
                        ),
                        children: [
                          TextSpan(
                            text: _isSignUp ? 'Log in' : 'Sign up',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: HhColors.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final user = authController.user;

    return Scaffold(
      backgroundColor: HhColors.bg,
      appBar: AppBar(
        title: const Text('Customer Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => authController.logout(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: HhColors.primary,
                        child: Icon(Icons.person, color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? 'Customer User',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            user?.email ?? '',
                            style: const TextStyle(color: HhColors.muted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  ListTile(
                    leading: const Icon(Icons.phone_outlined),
                    title: const Text('Phone Number'),
                    subtitle: Text(user?.phone ?? 'Not specified'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: const Text('Address'),
                    subtitle: Text(user?.address ?? 'Not specified'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: const Text('Account Role'),
                    subtitle: Text(user?.role.toUpperCase() ?? 'CUSTOMER'),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => authController.logout(),
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign Out'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HhColors.danger,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
