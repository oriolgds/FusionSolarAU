import 'package:supabase_flutter/supabase_flutter.dart';

class OnboardingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Verifica si el usuario ya ha visto el onboarding
  Future<bool> hasSeenOnboarding() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return false;
      }
      final response = await _supabase
          .from('user_onboarding')
          .select('has_seen_onboarding')
          .eq('id', user.id)
          .maybeSingle();
      if (response == null) {
        return false;
      }
      return response['has_seen_onboarding'] == true;
    } catch (e) {
      // Si hay un error, mostramos el onboarding por seguridad
      return false;
    }
  }

  /// Marca que el usuario ha visto el onboarding
  Future<void> markOnboardingAsSeen() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        print('Usuario no autenticado, no se puede guardar onboarding.');
        return;
      }
      await _supabase.from('user_onboarding').upsert({
        'id': user.id,
        'has_seen_onboarding': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      print('Onboarding guardado correctamente en Supabase.');
    } catch (e) {
      print('Error al guardar estado de onboarding: $e');
    }
  }
}
