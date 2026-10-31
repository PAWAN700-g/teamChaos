import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  StreamSubscription<UserProfile?>? _authSubscription;

  AuthStatus _status = AuthStatus.initial;
  UserProfile? _userProfile;
  String? _errorMessage;

  AuthProvider({required AuthService authService})
      // ignore: prefer_initializing_formals
      : _authService = authService {
    _init();
  }

  AuthStatus get status => _status;
  UserProfile? get userProfile => _userProfile;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated && _userProfile != null;
  bool get isLoading => _status == AuthStatus.loading;

  void _init() {
    _status = AuthStatus.loading;
    notifyListeners();

    _authSubscription = _authService.authStateChanges.listen(
      (profile) {
        if (profile != null) {
          _userProfile = profile;
          _status = AuthStatus.authenticated;
          _errorMessage = null;
        } else {
          _userProfile = null;
          _status = AuthStatus.unauthenticated;
        }
        notifyListeners();
      },
      onError: (err) {
        _status = AuthStatus.error;
        _errorMessage = err.toString();
        notifyListeners();
      },
    );
  }

  Future<bool> signIn({required String email, required String password}) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final profile = await _authService.signIn(email: email, password: password);
      _userProfile = profile;
      _status = AuthStatus.authenticated;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _cleanErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final profile = await _authService.register(
        email: email,
        password: password,
        displayName: displayName,
        role: role,
      );
      _userProfile = profile;
      _status = AuthStatus.authenticated;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _cleanErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      await _authService.signOut();
      _userProfile = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    if (_status == AuthStatus.error) {
      _status = _userProfile != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  String _cleanErrorMessage(dynamic error) {
    final str = error.toString();
    if (str.startsWith('Exception: ')) {
      return str.substring(11);
    }
    return str;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
