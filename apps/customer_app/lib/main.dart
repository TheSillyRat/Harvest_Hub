import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'screens/home_landing_tab.dart';
import 'screens/marketplace_screen.dart';
import 'screens/cart_sheet.dart';
import 'screens/farmers_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/in_app_notification_banner.dart';
import 'location/customer_location.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {
    const demoOptions = FirebaseOptions(
      apiKey: 'AIzaSyDemoKeyForTestingOnly123456789',
      appId: '1:123456789012:web:abcdef1234567890',
      messagingSenderId: '123456789012',
      projectId: 'demo-harvesthub',
      storageBucket: 'demo-harvesthub.appspot.com',
    );
    try {
      await Firebase.initializeApp(options: demoOptions);
    } catch (_) {}
  }
  final prefsService = await PreferencesService.getInstance();
  runApp(CustomerApp(preferencesService: prefsService));
}

class CustomerApp extends StatelessWidget {
  final PreferencesService? preferencesService;

  const CustomerApp({super.key, this.preferencesService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>(
          create: (_) => AuthController(),
        ),
        ChangeNotifierProxyProvider<AuthController, CartController>(
          create: (_) => CartController(),
          update: (_, auth, cart) =>
              (cart ?? CartController())..bind(auth.user?.uid),
        ),
        ChangeNotifierProxyProvider<AuthController, SavedItemsController>(
          create: (_) => SavedItemsController(),
          update: (_, auth, saved) => (saved ?? SavedItemsController())
            ..bind(
                auth.user?.role == Roles.customer && auth.user?.isActive == true
                    ? auth.user!.uid
                    : null),
        ),
      ],
      child: MaterialApp(
        title: 'HarvestHub Customer App',
        debugShowCheckedModeBanner: false,
        theme: harvestHubTheme(),
        home: CustomerAuthWrapper(preferencesService: preferencesService),
      ),
    );
  }
}

class CustomerAuthWrapper extends StatefulWidget {
  final PreferencesService? preferencesService;

  const CustomerAuthWrapper({super.key, this.preferencesService});

  @override
  State<CustomerAuthWrapper> createState() => _CustomerAuthWrapperState();
}

class _CustomerAuthWrapperState extends State<CustomerAuthWrapper> {
  PreferencesService? _prefs;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    final prefs = widget.preferencesService ?? await PreferencesService.getInstance();
    _prefs = prefs;
    if (!mounted) return;
    final auth = context.read<AuthController>();

    if (auth.user == null && _prefs!.rememberMe) {
      final email = _prefs!.savedEmail;
      final password = _prefs!.savedPassword;
      if (email != null &&
          email.isNotEmpty &&
          password != null &&
          password.isNotEmpty) {
        await auth.login(email, password, Roles.customer);
      }
    }

    if (mounted) {
      setState(() {
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();

    if (!_initialized && authController.isLoading) {
      return const Scaffold(
        backgroundColor: HhColors.bg,
        body: Center(
          child: SproutLoadingIndicator(size: 140),
        ),
      );
    }

    if (authController.user != null) {
      return const CustomerHomeScreen();
    }

    if (_prefs?.hasSeenOnboarding == true) {
      return const CustomerAuthScreen(initialIsSignUp: false);
    }

    return const RetroOnboardingScreen(
      loginScreen: CustomerAuthScreen(initialIsSignUp: false),
      signUpScreen: CustomerAuthScreen(initialIsSignUp: true),
    );
  }
}

class CustomerAuthScreen extends StatefulWidget {
  final bool initialIsSignUp;

  const CustomerAuthScreen({
    super.key,
    this.initialIsSignUp = false,
  });

  @override
  State<CustomerAuthScreen> createState() => _CustomerAuthScreenState();
}

class _CustomerAuthScreenState extends State<CustomerAuthScreen> {
  late bool _isSignUp;
  bool _obscurePassword = true;
  bool _rememberMe = true;
  PreferencesService? _prefs;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialIsSignUp;
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    _prefs = await PreferencesService.getInstance();
    if (mounted) {
      setState(() {
        _rememberMe = _prefs!.rememberMe;
        if (_prefs!.savedEmail != null && _prefs!.savedEmail!.isNotEmpty) {
          _emailController.text = _prefs!.savedEmail!;
        }
        if (_rememberMe &&
            _prefs!.savedPassword != null &&
            _prefs!.savedPassword!.isNotEmpty) {
          _passwordController.text = _prefs!.savedPassword!;
        }
      });
    }
  }

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
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please check your email and password.'),
          backgroundColor: HhColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final controller = context.read<AuthController>();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    final success = await controller.login(
      email,
      password,
      Roles.customer,
    );

    if (success) {
      final prefs = _prefs ?? await PreferencesService.getInstance();
      await prefs.saveAuthCredentials(
        email: email,
        password: password,
        remember: _rememberMe,
      );
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(controller.errorMessage ?? 'Sign in failed. Please verify your credentials.'),
          backgroundColor: HhColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _submitRegister() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all required fields.'),
          backgroundColor: HhColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final controller = context.read<AuthController>();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    final success = await controller.registerCustomer(
      name: _nameController.text.trim(),
      email: email,
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      password: password,
    );

    if (success) {
      final prefs = _prefs ?? await PreferencesService.getInstance();
      await prefs.saveAuthCredentials(
        email: email,
        password: password,
        remember: _rememberMe,
      );
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(controller.errorMessage ?? 'Registration failed. Please try again.'),
          backgroundColor: HhColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();

    if (authController.user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    }

    return Scaffold(
      backgroundColor: HhColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: HhColors.text,
                ),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
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
                    'Sign in with your credentials to manage your produce orders.',
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
                    label: 'Full Name or Trading Entity',
                    hint: 'Green Field Organic Ltd.',
                    icon: Icons.business_outlined,
                    validator: (val) => val == null || val.trim().isEmpty ? 'Enter full name' : null,
                  ),
                  const SizedBox(height: 16),
                ],
                PillTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  hint: 'trader@farmtrade.market',
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
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            _isSignUp ? 'Create Trading Account' : 'Sign In',
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
                        text: _isSignUp ? 'Already have a trading account? ' : "Don't have an account? ",
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

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _currentIndex = 2;
  bool _filterOpen = false;
  final CustomerLocation _location = CustomerLocation();
  AppNotification? _activeInAppNotification;

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
  }

  @override
  void dispose() {
    NotificationService.instance.onInAppNotificationReceived = null;
    _location.dispose();
    super.dispose();
  }

  void _openCartSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CustomerCartSheet(
        onOrderPlaced: () {
          Navigator.pop(ctx);
          setState(() => _currentIndex = 3);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final cart = context.watch<CartController>();
    final user = authController.user;

    final screens = [
      MarketplaceScreen(
        location: _location,
        onOpenCart: _openCartSheet,
        onOpenOrders: () => setState(() => _currentIndex = 3),
        onOpenProfile: () => setState(() => _currentIndex = 4),
        onFilterVisible: (open) {
          if (_filterOpen == open) return;
          setState(() => _filterOpen = open);
        },
      ),
      FarmersScreen(location: _location),
      CustomerHomeLandingTab(
        location: _location,
        onNavigateTab: (idx) => setState(() => _currentIndex = idx),
        onSelectCategory: (_) {},
      ),
      _buildOrdersScreen(),
      CustomerProfileScreen(
        user: user,
        auth: authController,
        onOrders: () => setState(() => _currentIndex = 3),
      ),
    ];

    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final systemBottom = MediaQuery.viewPaddingOf(context).bottom;
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: HhColors.bg,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            IndexedStack(
              index: _currentIndex,
              children: screens,
            ),
            if (_activeInAppNotification != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: InAppNotificationBanner(
                  notification: _activeInAppNotification!,
                  userId: user?.uid ?? 'customer_1',
                  onDismiss: () {
                    if (mounted) {
                      setState(() {
                        _activeInAppNotification = null;
                      });
                    }
                  },
                ),
              ),
            if (!_filterOpen && !keyboardOpen)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildFloatingBottomNav(),
                    ),
                    Container(height: systemBottom, color: Colors.black),
                  ],
                ),
              ),
            if (!_filterOpen && !keyboardOpen)
              Positioned(
                right: 18,
                bottom: 85 + systemBottom,
                child: _buildFloatingCartButton(cart),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingCartButton(CartController cart) {
    return GestureDetector(
      onTap: _openCartSheet,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: HhColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: HhColors.primary.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            SvgPicture.asset(
              'packages/harvesthub_core/assets/images/CartIcon.svg',
              width: 26,
              height: 26,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
            if (cart.itemCount > 0)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: HhColors.danger,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Center(
                    child: Text(
                      '${cart.itemCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingBottomNav() {
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(34),
        border: Border.all(
          color: HhColors.text.withValues(alpha: 0.08),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: HhColors.text.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.grid_view_rounded, Icons.grid_view_outlined, 'Products'),
          _buildNavItem(1, Icons.storefront_rounded, Icons.storefront_outlined, 'Farmers'),
          _buildHomeNavItem(2, Icons.home_rounded, Icons.home_outlined, 'Home'),
          _buildNavItem(3, Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'Orders'),
          _buildNavItem(4, Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
        ],
      ),
    );
  }

  Widget _buildHomeNavItem(
      int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: isSelected ? HhColors.primary : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSelected ? activeIcon : inactiveIcon,
                color: isSelected ? Colors.white : HhColors.text.withValues(alpha: 0.55),
                size: 26,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected ? HhColors.primary : HhColors.text.withValues(alpha: 0.55),
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
      int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isSelected = _currentIndex == index;

    final color = isSelected ? HhColors.primary : HhColors.text.withValues(alpha: 0.55);
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 54,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: color,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildOrdersScreen() {
    return CustomerOrdersScreenView(
      onStartShopping: () => setState(() => _currentIndex = 0),
    );
  }

}

class CustomerOrdersScreenView extends StatefulWidget {
  final VoidCallback onStartShopping;

  const CustomerOrdersScreenView({
    super.key,
    required this.onStartShopping,
  });

  @override
  State<CustomerOrdersScreenView> createState() => _CustomerOrdersScreenViewState();
}

class _CustomerOrdersScreenViewState extends State<CustomerOrdersScreenView> {
  final OrderService _orderService = OrderService();
  String _selectedStatusFilter = 'All';

  void _showOrderTrackingDetails(FarmOrder order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OrderTrackingSheet(order: order),
    );
  }

  Future<void> _cancelOrder(FarmOrder order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Direct Order'),
        content: Text('Are you sure you want to cancel order #${order.id.length > 8 ? order.id.substring(0, 8) : order.id}? Stock will be restocked automatically.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Order'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: HhColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _orderService.cancel(order.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Order cancelled and inventory restocked.'),
              backgroundColor: HhColors.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not cancel order: ${e.toString().replaceAll('Exception: ', '').replaceAll('StateError: ', '')}'),
              backgroundColor: HhColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final uid = authController.user?.uid ?? '';

    return Scaffold(
      backgroundColor: HhColors.bg,
      appBar: AppBar(
        title: const Text(
          'Your Direct Orders',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: HhColors.text,
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          _buildFilterChips(),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<List<FarmOrder>>(
              stream: _orderService.streamByCustomer(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(
                    child: SproutLoadingIndicator(size: 100),
                  );
                }

                List<FarmOrder> orders = snapshot.data ?? [];

                if (_selectedStatusFilter != 'All') {

                  orders = orders.where((o) {
                    if (_selectedStatusFilter == 'Pending') return o.status == OrderStatus.pending;
                    if (_selectedStatusFilter == 'Confirmed') return o.status == OrderStatus.confirmed;
                    if (_selectedStatusFilter == 'Ready') return o.status == OrderStatus.readyForPickup;
                    if (_selectedStatusFilter == 'Completed') return o.status == OrderStatus.completed;
                    if (_selectedStatusFilter == 'Cancelled') return o.status == OrderStatus.cancelled;
                    return true;
                  }).toList();
                }

                if (orders.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: HhColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              size: 40,
                              color: HhColors.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No ${_selectedStatusFilter == 'All' ? '' : _selectedStatusFilter.toLowerCase()} orders found',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: HhColors.text,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Browse farm produce and place your order directly with local farmers.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: HhColors.text.withValues(alpha: 0.65),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: widget.onStartShopping,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: HhColors.primary,
                              foregroundColor: HhColors.bg,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: const Text('Start Shopping'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return _buildOrderCard(order);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['All', 'Pending', 'Confirmed', 'Ready', 'Completed', 'Cancelled'];
    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedStatusFilter == filter;
          return ChoiceChip(
            label: Text(filter),
            selected: isSelected,
            selectedColor: HhColors.primary,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : HhColors.text,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 12.5,
            ),
            side: BorderSide(
              color: isSelected ? HhColors.primary : HhColors.text.withValues(alpha: 0.12),
            ),
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  _selectedStatusFilter = filter;
                });
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(FarmOrder order) {
    final statusColor = _getStatusColor(order.status);
    final statusLabel = _getStatusLabel(order.status);
    final canCancel = OrderStatus.canCancel(order.status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: HhColors.text.withValues(alpha: 0.08),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: HhColors.text.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.storefront_rounded, size: 18, color: HhColors.primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        order.farmerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: HhColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Order #${order.id.length > 8 ? order.id.substring(0, 8) : order.id}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: HhColors.text.withValues(alpha: 0.6),
                ),
              ),
              const Spacer(),
              Text(
                '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year} ${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: HhColors.muted,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          ...order.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '• ${item.name} × ${item.qty} ${item.unit}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: HhColors.text,
                      ),
                    ),
                    Text(
                      '\$${(item.subtotal / 100).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: HhColors.text,
                      ),
                    ),
                  ],
                ),
              )),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Total',
                    style: TextStyle(
                      fontSize: 11,
                      color: HhColors.muted,
                    ),
                  ),
                  Text(
                    '\$${(order.total / 100).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: HhColors.primary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (canCancel)
                    OutlinedButton(
                      onPressed: () => _cancelOrder(order),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: HhColors.danger,
                        side: BorderSide(color: HhColors.danger.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontSize: 12.5)),
                    ),
                  if (canCancel) const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showOrderTrackingDetails(order),
                    icon: const Icon(Icons.timeline_rounded, size: 16),
                    label: const Text('Track Order', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HhColors.primary,
                      foregroundColor: HhColors.bg,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange.shade800;
      case OrderStatus.confirmed:
        return Colors.blue.shade700;
      case OrderStatus.readyForPickup:
        return Colors.purple.shade700;
      case OrderStatus.completed:
        return HhColors.primary;
      case OrderStatus.cancelled:
        return HhColors.danger;
      default:
        return HhColors.primary;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending Confirmation';
      case OrderStatus.confirmed:
        return 'Farm Confirmed';
      case OrderStatus.readyForPickup:
        return 'Ready for Pickup';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
      default:
        return status;
    }
  }

  List<FarmOrder> _getDemoOrders(String uid) {
    final now = DateTime.now();
    return [
      FarmOrder(
        id: 'ord_demo_101',
        customerId: uid,
        customerName: 'Customer',
        customerPhone: '+84 901 234 567',
        farmerId: 'farmer_1',
        farmerName: 'Green Valley Organic Farm',
        items: const [
          OrderItem(
            productId: 'prod_1',
            name: 'Heirloom Vine Tomatoes',
            price: 450,
            unit: 'kg',
            imageUrl: '',
            qty: 2,
            subtotal: 900,
          ),
          OrderItem(
            productId: 'prod_3',
            name: 'Crisp Butterhead Lettuce',
            price: 350,
            unit: 'head',
            imageUrl: '',
            qty: 1,
            subtotal: 350,
          ),
        ],
        address: '123 Green Valley Road, Da Lat',
        pickupSlot: 'morning_07_10',
        pickupDate: now,
        total: 1250,
        status: OrderStatus.pending,
        createdAt: now.subtract(const Duration(minutes: 45)),
        updatedAt: now.subtract(const Duration(minutes: 45)),
      ),
      FarmOrder(
        id: 'ord_demo_102',
        customerId: uid,
        customerName: 'Customer',
        customerPhone: '+84 901 234 567',
        farmerId: 'farmer_2',
        farmerName: 'Highland Orchard',
        items: const [
          OrderItem(
            productId: 'prod_2',
            name: 'Honeycrisp Apples',
            price: 620,
            unit: 'kg',
            imageUrl: '',
            qty: 3,
            subtotal: 1860,
          ),
        ],
        address: '123 Green Valley Road, Da Lat',
        pickupSlot: 'afternoon_15_18',
        pickupDate: now.subtract(const Duration(days: 1)),
        total: 1860,
        status: OrderStatus.completed,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(hours: 18)),
      ),
    ];
  }
}

class OrderTrackingSheet extends StatelessWidget {
  final FarmOrder order;

  const OrderTrackingSheet({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final steps = [
      (title: 'Order Placed', subtitle: 'Order submitted to farm escrow', icon: Icons.shopping_bag_outlined, isDone: true),
      (title: 'Farm Confirmed', subtitle: 'Farmer prepared harvested crops', icon: Icons.agriculture_outlined, isDone: order.status == OrderStatus.confirmed || order.status == OrderStatus.readyForPickup || order.status == OrderStatus.completed),
      (title: 'Ready for Pickup', subtitle: 'Packaged at farm distribution hub', icon: Icons.storefront_outlined, isDone: order.status == OrderStatus.readyForPickup || order.status == OrderStatus.completed),
      (title: 'Completed', subtitle: 'Order collected and settled', icon: Icons.check_circle_outline_rounded, isDone: order.status == OrderStatus.completed),
    ];

    final isCancelled = order.status == OrderStatus.cancelled;

    return Container(
      decoration: const BoxDecoration(
        color: HhColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: HhColors.text.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order.id.length > 8 ? order.id.substring(0, 8) : order.id}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: HhColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.farmerName,
                      style: const TextStyle(
                        fontSize: 13,
                        color: HhColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (isCancelled)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: HhColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: HhColors.danger.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.cancel_outlined, color: HhColors.danger),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This order was cancelled. Stock has been refunded to farm inventory.',
                        style: TextStyle(
                          color: HhColors.danger,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: List.generate(steps.length, (index) {
                  final step = steps[index];
                  final isLast = index == steps.length - 1;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: step.isDone ? HhColors.primary : Colors.white,
                              border: Border.all(
                                color: step.isDone ? HhColors.primary : HhColors.text.withValues(alpha: 0.2),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              step.icon,
                              size: 18,
                              color: step.isDone ? Colors.white : HhColors.text.withValues(alpha: 0.4),
                            ),
                          ),
                          if (!isLast)
                            Container(
                              width: 2,
                              height: 38,
                              color: step.isDone ? HhColors.primary : HhColors.text.withValues(alpha: 0.15),
                            ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                step.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: step.isDone ? HhColors.text : HhColors.text.withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                step.subtitle,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: HhColors.text.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: HhColors.text.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: HhColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Delivery Contact Address',
                          style: TextStyle(fontSize: 11, color: HhColors.muted),
                        ),
                        Text(
                          order.address.isNotEmpty ? order.address : 'Green Valley Station Pickup',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: HhColors.text),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
