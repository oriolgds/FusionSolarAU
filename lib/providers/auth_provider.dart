import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class AuthProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _supabase.auth.currentUser != null;
  User? get currentUser => _supabase.auth.currentUser;

  // Iniciar sesión con Google usando google_sign_in y luego Supabase
  Future<bool?> signInWithGoogle() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Usar la instancia singleton y authenticate()
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize();
      final account = await googleSignIn.authenticate();
      // La comprobación de null ya no es necesaria
      final auth = account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        _isLoading = false;
        _errorMessage = 'No se pudo obtener el idToken de Google.';
        notifyListeners();
        return false;
      }
      // Autenticar con Supabase usando el idToken
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      _isLoading = false;
      notifyListeners();
      return response.user != null;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Cerrar sesión
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Obtener el usuario actual
  User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  // Verificar si el usuario está autenticado
  Stream<AuthState> authStateChanges() {
    return _supabase.auth.onAuthStateChange;
  }

  // Verificar si la sesión del usuario sigue siendo válida
  Future<bool> isUserSessionValid() async {
    try {
      if (!isAuthenticated) return false;
      
      // Obtener la sesión actual
      final session = _supabase.auth.currentSession;
      if (session == null) return false;
      
      // Verificar si el token ha expirado
      if (session.expiresAt != null) {
        final expiryDate = DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
        if (expiryDate.isBefore(DateTime.now())) {
          await _supabase.auth.signOut();
          return false;
        }
      } else {
        // Si no hay fecha de expiración, asumimos que la sesión no es válida
        await _supabase.auth.signOut();
        return false;
      }
      
      // Verificar con el servidor si el usuario sigue siendo válido
      final user = _supabase.auth.currentUser;
      if (user == null) return false;
      
      // Aquí puedes agregar más validaciones, por ejemplo:
      // - Verificar si el usuario está bloqueado en tu base de datos
      // - Verificar permisos, etc.
      
      return true;
    } catch (e) {
      debugPrint('Error verificando sesión: $e');
      await _supabase.auth.signOut();
      return false;
    }
  }
}
