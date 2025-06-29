import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:async/async.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  GoogleSignIn signIn = GoogleSignIn.instance;
  bool _isLoading = false;
  String? _errorMessage;

  // Agregar variables para clientId y serverClientId
  final String? clientId;
  final String? serverClientId;

  AuthProvider({this.clientId, this.serverClientId}) {
    _initializeGoogleSignIn();
  }

  // Inicializar GoogleSignIn con clientId y serverClientId
  void _initializeGoogleSignIn() {
    signIn.initialize(clientId: clientId, serverClientId: serverClientId).then((
      _,
    ) {
      signIn.authenticationEvents
          .listen(_handleAuthenticationEvent)
          .onError(_handleAuthenticationError);

      if (_auth.currentUser == null) {
        signIn.attemptLightweightAuthentication();
      }
    }).ignore();
  }

  // Manejar eventos de autenticación
  void _handleAuthenticationEvent(GoogleSignInAuthenticationEvent event) {
    // Manejar el evento de autenticación
    notifyListeners();
  }

  // Manejar errores de autenticación
  void _handleAuthenticationError(Object error) {
    _errorMessage = error.toString();
    notifyListeners();
  }

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

      UserCredential userCredential;

      if (kIsWeb) {
        // Web: usar signInWithPopup
        final googleProvider = GoogleAuthProvider();
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        // Móvil/desktop: usar GoogleSignIn
        final GoogleSignInAccount? googleUser = await signIn.authenticate();
        if (googleUser == null) {
          _isLoading = false;
          notifyListeners();
          return null;
        }
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        userCredential = await _auth.signInWithCredential(credential);
      }

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
      await signIn.signOut();
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
