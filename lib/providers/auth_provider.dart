import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      final auth = await account.authentication;
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
}
