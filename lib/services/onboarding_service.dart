import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OnboardingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Verifica si el usuario ya ha visto el onboarding
  Future<bool> hasSeenOnboarding() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }

      final docSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!docSnapshot.exists) {
        return false;
      }

      return docSnapshot.data()?['hasSeenOnboarding'] ?? false;
    } catch (e) {
      // Si hay un error, mostramos el onboarding por seguridad
      return false;
    }
  }

  /// Marca que el usuario ha visto el onboarding
  Future<void> markOnboardingAsSeen() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('Usuario no autenticado, no se puede guardar onboarding.');
        return;
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set({
        'hasSeenOnboarding': true,
        'onboardingCompletedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('Onboarding guardado correctamente en Firestore.');
    } catch (e) {
      print('Error al guardar el estado del onboarding: $e');
      rethrow;
    }
  }
}
