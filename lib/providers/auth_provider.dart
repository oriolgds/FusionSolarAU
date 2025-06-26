import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/userinfo.profile',
    ],
  );

  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AuthProvider() {
    _loadUserFromStorage();
  }

  Future<void> _loadUserFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');
      if (userJson != null) {
        // En una implementación real, aquí deberías verificar si el token sigue siendo válido
        // y si el usuario aún está autenticado con Google
        _user = User.fromJson({
          'id': prefs.getString('user_id') ?? '',
          'email': prefs.getString('user_email') ?? '',
          'displayName': prefs.getString('user_name') ?? '',
          'photoUrl': prefs.getString('user_photo'),
          'lastLogin': DateTime.now().millisecondsSinceEpoch,
          'preferences': {},
        });
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading user from storage: $e');
    }
  }

  Future<bool> signInWithGoogle() async {
    try {
      _setLoading(true);
      _setError(null);

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _setLoading(false);
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // En una implementación real, aquí enviarías el token a tu backend
      // para verificarlo y obtener/crear el usuario en tu sistema
      // Ejemplo: await _authService.validateToken(googleAuth.accessToken);
      
      
      _user = User(
        id: googleUser.id,
        email: googleUser.email,
        displayName: googleUser.displayName ?? 'Usuario',
        photoUrl: googleUser.photoUrl,
        lastLogin: DateTime.now(),
        preferences: {},
      );

      await _saveUserToStorage();
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Error al iniciar sesión: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _clearUserFromStorage();
      _user = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  Future<void> _saveUserToStorage() async {
    if (_user != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', _user!.id);
      await prefs.setString('user_email', _user!.email);
      await prefs.setString('user_name', _user!.displayName);
      if (_user!.photoUrl != null) {
        await prefs.setString('user_photo', _user!.photoUrl!);
      }
    }
  }

  Future<void> _clearUserFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    await prefs.remove('user_name');
    await prefs.remove('user_photo');
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
