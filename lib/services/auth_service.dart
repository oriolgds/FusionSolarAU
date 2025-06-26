import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Iniciar sesión con Google a través de Supabase
  Future<bool> signInWithGoogle() async {
    try {
      // Iniciar sesión en Supabase con OAuth de Google
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      return true;
    } catch (e) {
      developer.log('Error en signInWithGoogle', error: e);
      return false;
    }
  }

  // Cerrar sesión
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Obtener el usuario actual
  User? get currentUser => _supabase.auth.currentUser;

  // Escuchar cambios en el estado de autenticación
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Verificar si el usuario está autenticado
  bool isAuthenticated() {
    return _supabase.auth.currentUser != null;
  }
  
  // Obtener la sesión actual
  Session? get session => _supabase.auth.currentSession;
  
  // Obtener el ID del usuario actual
  String? get currentUserId => _supabase.auth.currentUser?.id;
}
