import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:harvesthub_core/harvesthub_core.dart';
import 'package:provider/provider.dart';

import 'admin_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthController>(
      create: (_) => AuthController(),
      child: MaterialApp(
        title: 'HarvestHub Admin',
        debugShowCheckedModeBanner: false,
        theme: harvestHubTheme(),
        home: const AdminAuthWrapper(),
      ),
    );
  }
}

class AdminAuthWrapper extends StatelessWidget {
  const AdminAuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();

    if (authController.isInitializing) {
      return Scaffold(
        backgroundColor: HhColors.bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const HarvestHubLogo(fontSize: 28, iconSize: 28),
              const SizedBox(height: 24),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: HhColors.primary,
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Authenticating...',
                style: TextStyle(
                  fontSize: 13,
                  color: HhColors.text.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (authController.user != null) {
      if (authController.user!.role == Roles.admin) {
        return const AdminDashboardScreen();
      }
      return Scaffold(
        backgroundColor: HhColors.bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.gpp_bad_rounded, size: 64, color: HhColors.danger),
                const SizedBox(height: 16),
                const Text(
                  'Access Denied',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: HhColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This account does not have administrator privileges.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: HhColors.muted),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => authController.logout(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HhColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const LoginScreen(role: Roles.admin);
  }
}
