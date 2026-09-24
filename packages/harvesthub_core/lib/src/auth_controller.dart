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
      _errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('StateError: ', '');
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
      _errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('StateError: ', '');
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
      _errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('StateError: ', '');
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
