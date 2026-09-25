import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const FarmerApp());
}

class FarmerApp extends StatelessWidget {
  const FarmerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthController>(
      create: (_) => AuthController(),
      child: MaterialApp(
        title: 'HarvestHub Farmer App',
        debugShowCheckedModeBanner: false,
        theme: harvestHubTheme(),
        home: const FarmerAuthWrapper(),
      ),
    );
  }
}

class FarmerAuthWrapper extends StatelessWidget {
  const FarmerAuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();

    if (authController.user != null) {
      return const FarmerHomeScreen();
    }
    return const RetroOnboardingScreen(
      loginScreen: FarmerAuthScreen(initialIsSignUp: false),
      signUpScreen: FarmerAuthScreen(initialIsSignUp: true),
    );
  }
}

class FarmerAuthScreen extends StatefulWidget {
  final bool initialIsSignUp;

  const FarmerAuthScreen({
    super.key,
    this.initialIsSignUp = false,
  });

  @override
  State<FarmerAuthScreen> createState() => _FarmerAuthScreenState();
}

class _FarmerAuthScreenState extends State<FarmerAuthScreen> {
  late bool _isSignUp;
  bool _obscurePassword = true;
  bool _rememberMe = true;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  final _businessNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _areaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialIsSignUp;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _businessNameController.dispose();
    _descriptionController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = context.read<AuthController>();
    final success = await controller.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      Roles.farmer,
    );

    if (success) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } else if (mounted && controller.errorMessage != null) {
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
    final success = await controller.registerFarmer(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      password: _passwordController.text.trim(),
      businessName: _businessNameController.text.trim(),
      description: _descriptionController.text.trim(),
      area: _areaController.text.trim(),
    );

    if (success) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } else if (mounted && controller.errorMessage != null) {
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
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: HhColors.text,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 8.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isSignUp) ...[
                  const HarvestHubLogo(fontSize: 22, iconSize: 22),
                  const SizedBox(height: 14),
                  const Text(
                    'Register',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: HhColors.text,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else ...[
                  const HarvestHubLogo(fontSize: 22, iconSize: 22),
                  const SizedBox(height: 14),
                  const Text(
                    'Welcome Back',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: HhColors.text,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sign in to manage your farm store and orders.',
                    style: TextStyle(
                      fontSize: 14,
                      color: HhColors.text.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (_isSignUp) ...[
                  PillTextField(
                    controller: _nameController,
                    label: 'Farmer Full Name',
                    hint: 'Farmer Green',
                    icon: Icons.person_outline,
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'Enter full name'
                        : null,
                  ),
                  const SizedBox(height: 16),
                ],
                PillTextField(
                  controller: _emailController,
                  label: 'Farmer Email Address',
                  hint: 'farmer@harvesthub.app',
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) => val == null || !val.contains('@')
                      ? 'Enter valid email'
                      : null,
                ),
                const SizedBox(height: 16),
                if (_isSignUp) ...[
                  PillTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    hint: '+84 912 345 678',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'Enter phone number'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  PillTextField(
                    controller: _addressController,
                    label: 'Personal Address',
                    hint: '456 Farm Valley, Da Lat',
                    icon: Icons.home_outlined,
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'Enter personal address'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  PillTextField(
                    controller: _businessNameController,
                    label: 'Farm Store / Business Name',
                    hint: 'Green Field Organics',
                    icon: Icons.storefront_outlined,
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'Enter farm business name'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  PillTextField(
                    controller: _areaController,
                    label: 'Farm Area / Location',
                    hint: 'Da Lat, Lam Dong',
                    icon: Icons.location_city_outlined,
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'Enter farm area location'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  PillTextField(
                    controller: _descriptionController,
                    label: 'Farm Description',
                    hint: 'Specializing in fresh organic fruits and vegetables',
                    icon: Icons.description_outlined,
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'Enter farm description'
                        : null,
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
                  validator: (val) => val == null || val.length < 6
                      ? 'Password must be at least 6 chars'
                      : null,
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
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6)),
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
                    onPressed: authController.isLoading
                        ? null
                        : (_isSignUp ? _submitRegister : _submitLogin),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HhColors.primary,
                      foregroundColor: HhColors.bg,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 2,
                      shadowColor: HhColors.primary.withValues(alpha: 0.4),
                    ),
                    child: authController.isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            _isSignUp
                                ? 'Register Farmer Account'
                                : 'Sign In As Farmer',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isSignUp = !_isSignUp;
                      });
                    },
                    child: RichText(
                      text: TextSpan(
                        text: _isSignUp
                            ? 'Already registered a farm store? '
                            : "Don't have a farmer store account? ",
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

class FarmerHomeScreen extends StatelessWidget {
  const FarmerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final user = authController.user;

    return Scaffold(
      backgroundColor: HhColors.bg,
      appBar: AppBar(
        title: const Text('Farmer Dashboard'),
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                        child: Icon(Icons.agriculture,
                            color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? 'Farmer Store',
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              user?.email ?? '',
                              style: const TextStyle(color: HhColors.muted),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
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
                    title: const Text('Farm Address'),
                    subtitle: Text(user?.address ?? 'Not specified'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: const Text('Account Role'),
                    subtitle: Text(user?.role.toUpperCase() ?? 'FARMER'),
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
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
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
