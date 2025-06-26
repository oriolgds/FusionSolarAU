import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart' as app_models;
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final SupabaseClient _supabase = Supabase.instance.client;
  
  app_models.User? _user;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<AuthState>? _authSubscription;

  app_models.User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AuthProvider() {
    _initAuth();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _initAuth() {
    // Escuchar cambios en el estado de autenticación
    _authSubscription = _supabase.auth.onAuthStateChange.listen((authState) async {
      final user = authState.session?.user;
      
      if (user != null) {
        // Usuario autenticado con Supabase
        _user = app_models.User(
          id: user.id,
          email: user.email ?? '',
          displayName: user.userMetadata?['full_name']?.toString() ?? 
                      user.userMetadata?['name']?.toString() ?? 
                      'Usuario',
          photoUrl: user.userMetadata?['avatar_url']?.toString(),
          lastLogin: DateTime.now(),
          preferences: {},
        );
        await _saveUserToStorage();
      } else {
        // Usuario no autenticado
        _user = null;
        await _clearUserFromStorage();
      }
      notifyListeners();
    });
    
    // Cargar usuario desde el almacenamiento local si existe
    _loadUserFromStorage();
  }

  // Nota: Ya no necesitamos cargar el usuario desde el almacenamiento local
  // ya que Firebase maneja la persistencia de la sesión automáticamente

  Future<bool> signInWithGoogle() async {
    try {
      _setLoading(true);
      _setError(null);

      // Iniciar sesión con Google a través de Supabase
      // La respuesta de Supabase se manejará a través del listener _authSubscription
      await _authService.signInWithGoogle();
      
      // Si llegamos aquí, la autenticación se inició correctamente
      // El estado real de la autenticación se actualizará a través del listener
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Error al iniciar sesión con Google: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _authService.signOut();
      _user = null;
      await _clearUserFromStorage();
      notifyListeners();
    } catch (e) {
      debugPrint('Error al cerrar sesión: $e');
      _setError('Error al cerrar sesión: $e');
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
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user');
      await prefs.remove('user_id');
      await prefs.remove('user_email');
      await prefs.remove('user_name');
      await prefs.remove('user_photo');
    } catch (e) {
      debugPrint('Error clearing user from storage: $e');
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    if (error != null) {
      // Opcional: Mostrar el error durante unos segundos y luego limpiarlo
      Future.delayed(const Duration(seconds: 5), () {
        _error = null;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  bool isUserAuthenticated() {
    return _authService.isAuthenticated();
  }
  
  Future<void> _loadUserFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      
      if (userId != null) {
        _user = app_models.User(
          id: userId,
          email: prefs.getString('user_email') ?? '',
          displayName: prefs.getString('user_name') ?? 'Usuario',
          photoUrl: prefs.getString('user_photo'),
          lastLogin: DateTime.now(),
          preferences: {},
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading user from storage: $e');
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
