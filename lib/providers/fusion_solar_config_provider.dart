import 'package:flutter/material.dart';
import '../services/fusion_solar_oauth_service.dart';

class FusionSolarConfigProvider extends ChangeNotifier {
  final FusionSolarOAuthService _oauthService = FusionSolarOAuthService();
  
  bool _hasValidConfig = false;
  bool _isLoading = false;
  String? _error;

  bool get hasValidConfig => _hasValidConfig;
  bool get isLoading => _isLoading;
  String? get error => _error;

  FusionSolarConfigProvider() {
    _checkConfiguration();
  }

  Future<void> _checkConfiguration() async {
    _setLoading(true);
    try {
      final hasConfig = await _oauthService.hasValidOAuthConfig();
      _hasValidConfig = hasConfig;
      _setError(null);
    } catch (e) {
      _setError('Error verificando configuración: $e');
      _hasValidConfig = false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> loginWithCredentials(String username, String password) async {
    _setLoading(true);
    _setError(null);
    
    try {
      final token = await _oauthService.loginWithAccount(username, password);
      if (token != null) {
        _hasValidConfig = true;
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _setError('No se pudo obtener el token de sesión');
        return false;
      }
    } catch (e) {
      _setError('Error al iniciar sesión: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> logout() async {
    _setLoading(true);
    _setError(null);
    
    try {
      final token = await _oauthService.getCurrentXsrfToken();
      if (token != null && token.isNotEmpty) {
        await _oauthService.logoutFusionSolar(token);
      } else {
        // Si no hay token, aún así actualizar el estado local
        print('No XSRF token found, but updating local state');
      }
      
      _hasValidConfig = false;
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      print('Logout error: $e');

      // Incluso si hay error, marcar como desconectado localmente
      _hasValidConfig = false;

      // Solo mostrar error si no es un problema de red o token expirado
      if (!e.toString().toLowerCase().contains('network') &&
          !e.toString().toLowerCase().contains('token') &&
          !e.toString().toLowerCase().contains('expired')) {
        _setError('Error cerrando sesión: $e');
      }
      
      _setLoading(false);
      return true; // Devolver true porque se limpió la sesión local
    }
  }

  Future<void> refreshConfiguration() async {
    await _checkConfiguration();
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
