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

  Future<void> checkConfiguration() async {
    _setLoading(true);
    _setError(null);

    try {
      final hasConfig = await _oauthService.hasValidOAuthConfig();
      _hasValidConfig = hasConfig;
    } catch (e) {
      _setError('Error verificando configuración: $e');
      _hasValidConfig = false;
    } finally {
      _setLoading(false);
    }
  }

  void onConfigurationUpdated(bool hasConfig) {
    _hasValidConfig = hasConfig;
    notifyListeners();
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
