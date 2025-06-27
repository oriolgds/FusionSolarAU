import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  
  bool _isLoading = false;
  String? _errorMessage;
  
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _auth.currentUser != null;
  String? get errorMessage => _errorMessage;
  User? get currentUser => _auth.currentUser;
  
  // Iniciar sesión con Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      
      // Iniciar el flujo de autenticación con Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return null;
      }
      
      // Obtener los detalles de autenticación
      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;
      
      // Crear una credencial
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      // Iniciar sesión en Firebase con la credencial de Google
      final UserCredential userCredential = 
          await _auth.signInWithCredential(credential);
      
      _isLoading = false;
      notifyListeners();
      
      return userCredential;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }
  
  // Cerrar sesión
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }
  
  // Obtener el usuario actual
  User? getCurrentUser() {
    return _auth.currentUser;
  }
  
  // Verificar si el usuario está autenticado
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }
}
