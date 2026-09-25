import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'models.dart';

class AuthController extends ChangeNotifier {
  final AuthService _authService;
  AppUser? _user;
  bool _isLoading = false;
  String? _errorMessage;

  AuthController({AuthService? authService})
      : _authService = authService ?? AuthService() {
    _init();
  }

  AppUser? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _init() {
    _authService.authStateChanges().listen((firebaseUser) async {
      if (firebaseUser == null) {
        _user = null;
        notifyListeners();
      } else {
        try {
          _user = await _authService.readUser(firebaseUser.uid);
        } catch (_) {
          _user = null;
        }
        notifyListeners();
      }
    });
  }

  String _formatAuthError(Object e) {
    final str = e.toString();
    if (str.contains('invalid-credential') ||
        str.contains('wrong-password') ||
        str.contains('user-not-found')) {
      return 'Incorrect email or password. Please verify and try again.';
    }
    if (str.contains('email-already-in-use')) {
      return 'This email is already registered. Please sign in instead.';
    }
    if (str.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    }
    if (str.contains('weak-password')) {
      return 'Password should be at least 6 characters.';
    }
    if (str.contains('network-request-failed')) {
      return 'Network connection failed. Please check your internet connection.';
    }
    if (str.contains('too-many-requests')) {
      return 'Too many attempts. Please try again later.';
    }
    if (str.contains('channel-error')) {
      return 'Please fill in both email and password.';
    }
    return str
        .replaceAll('Exception: ', '')
        .replaceAll('StateError: ', '')
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .trim();
  }

  Future<bool> login(String email, String password, String expectedRole) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final loggedInUser = await _authService.login(email, password);
      _authService.requireRole(loggedInUser, expectedRole);
      _user = loggedInUser;
      return true;
    } catch (e) {
      _errorMessage = _formatAuthError(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> registerCustomer({
    required String name,
    required String email,
    required String phone,
    required String address,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _user = await _authService.registerCustomer(
        name: name,
        email: email,
        phone: phone,
        address: address,
        password: password,
      );
      return true;
    } catch (e) {
      _errorMessage = e
          .toString()
          .replaceAll('Exception: ', '')
          .replaceAll('StateError: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> registerFarmer({
    required String name,
    required String email,
    required String phone,
    required String address,
    required String password,
    required String businessName,
    required String description,
    required String area,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _user = await _authService.registerFarmer(
        name: name,
        email: email,
        phone: phone,
        address: address,
        password: password,
        businessName: businessName,
        description: description,
        area: area,
      );
      return true;
    } catch (e) {
      _errorMessage = e
          .toString()
          .replaceAll('Exception: ', '')
          .replaceAll('StateError: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile({
    required String name,
    required String phone,
    required String address,
  }) async {
    if (_user == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _authService.updateProfile(
        _user!.uid,
        name: name,
        phone: phone,
        address: address,
      );
      _user = AppUser(
        uid: _user!.uid,
        name: name.trim(),
        email: _user!.email,
        phone: phone.trim(),
        address: address.trim(),
        role: _user!.role,
        isActive: _user!.isActive,
        createdAt: _user!.createdAt,
      );
      return true;
    } catch (e) {
      _errorMessage = e
          .toString()
          .replaceAll('Exception: ', '')
          .replaceAll('StateError: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _errorMessage = null;
    notifyListeners();
  }
}
