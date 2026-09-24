import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models.dart';
import 'services.dart';
import 'theme.dart';
import 'widgets.dart';
import 'shared_screens.dart';

class AuthController extends ChangeNotifier {
  final String role;
  final AuthService service;
  AppUser? user;
  String? error;
  bool loading = true;
  bool submitting = false;
  StreamSubscription<User?>? _auth;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profile;
  AuthController(this.role) : service = AuthService() {
    _auth = service.authStateChanges().listen((u) async {
      if (submitting) return;
      if (u == null) {
        await _profile?.cancel();
        user = null;
        loading = false;
        notifyListeners();
      } else {
        await _load(u.uid);
      }
    }, onError: (Object e) {
      error = errorMessage(e);
      loading = false;
      notifyListeners();
    });
  }
  Future<void> _load(String uid) async {
    try {
      final value = await service.readUser(uid);
      service.requireRole(value, role);
      user = value;
      await _profile?.cancel();
      _profile = service.db.collection('users').doc(uid).snapshots().listen(
          (doc) async {
        if (!doc.exists) {
          await logout();
          return;
        }
        final updated = AppUser.fromMap(doc.data()!, id: uid);
        try {
          service.requireRole(updated, role);
          user = updated;
          notifyListeners();
        } catch (e) {
          error = errorMessage(e);
          await logout();
        }
      }, onError: (Object e) {
        error = errorMessage(e);
        notifyListeners();
      });
    } catch (e) {
      error = errorMessage(e);
      await service.logout();
      user = null;
    }
    loading = false;
    notifyListeners();
  }

  Future<void> authenticate(
      Future<AppUser> Function(AuthService) action) async {
    submitting = true;
    error = null;
    notifyListeners();
    try {
      final value = await action(service);
      service.requireRole(value, role);
      await _load(value.uid);
    } catch (e) {
      error = errorMessage(e);
      await service.logout();
      user = null;
    } finally {
      submitting = false;
      loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _profile?.cancel();
    _profile = null;
    await service.logout();
    user = null;
    notifyListeners();
  }

  void clearError() {
    error = null;
  }

  @override
  void dispose() {
    _auth?.cancel();
    _profile?.cancel();
    super.dispose();
  }
}

class CartController extends ChangeNotifier {
  final CartService service = CartService();
  String? uid;
  List<CartItem> items = [];
  Object? error;
  StreamSubscription<List<CartItem>>? _subscription;
  int get quantity =>
      items.fold(0, (runningTotal, item) => runningTotal + item.qty);
  int get total =>
      items.fold(0, (runningTotal, item) => runningTotal + item.subtotal);
  void bind(String? value) {
    if (value == uid) return;
    _subscription?.cancel();
    uid = value;
    items = [];
    error = null;
    if (value != null) {
      _subscription = service.stream(value).listen((data) {
        items = data;
        error = null;
        notifyListeners();
      }, onError: (Object e) {
        error = e;
        notifyListeners();
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

Future<void> bootstrap({required String role, required Widget home}) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    const emulator = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
    const demoOptions = FirebaseOptions(
      apiKey: 'AIzaSyDemoKeyForTestingOnly123456789',
      appId: '1:123456789012:web:abcdef1234567890',
      messagingSenderId: '123456789012',
      projectId: 'demo-harvesthub',
      storageBucket: 'demo-harvesthub.appspot.com',
    );

    if (emulator) {
      try {
        await Firebase.initializeApp(options: demoOptions);
      } catch (_) {}
      const envHost = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: '');
      final host = envHost.isNotEmpty ? envHost : (kIsWeb ? 'localhost' : '10.0.2.2');
      try {
        await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      } catch (_) {}
      try {
        FirebaseFirestore.instance.useFirestoreEmulator(host, 8180);
        FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
      } catch (_) {}
      try {
        await FirebaseStorage.instance.useStorageEmulator(host, 9199);
      } catch (_) {}
    } else {
      try {
        await Firebase.initializeApp();
      } catch (_) {
        try {
          await Firebase.initializeApp(options: demoOptions);
        } catch (_) {}
      }
    }
    runApp(ChangeNotifierProvider(
        create: (_) => AuthController(role),
        child: MaterialApp(
            title: 'HarvestHub',
            debugShowCheckedModeBanner: false,
            theme: harvestHubTheme(),
            home: AuthGate(role: role, home: home))));
  } catch (e, stack) {
    debugPrint('Firebase bootstrap error: $e\n$stack');
    runApp(MaterialApp(
        theme: harvestHubTheme(),
        home: Scaffold(
            appBar: AppBar(title: const Text('HarvestHub')),
            body: EmptyView(
                message:
                    'Chưa kết nối được Firebase ($e). Kiểm tra google-services.json và hướng dẫn firebase/SETUP.md, sau đó khởi động lại ứng dụng.'))));
  }
}

class AuthGate extends StatelessWidget {
  final String role;
  final Widget home;
  const AuthGate({super.key, required this.role, required this.home});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (auth.error != null) {
      final message = auth.error!;
      auth.clearError();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) showError(context, message);
      });
    }
    if (auth.loading) return const Scaffold(body: LoadingView());
    // A nested navigator is discarded on logout, removing every authenticated route.
    return Navigator(
        key: ValueKey(auth.user?.uid ?? 'signed-out'),
        onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) =>
                auth.user == null ? LoginScreen(role: role) : home));
  }
}

