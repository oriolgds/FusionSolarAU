import 'package:flutter/material.dart';
import 'dart:async';
import '../services/inverter_real_time_service.dart';
import 'package:logger/logger.dart';

class InverterRealTimeProvider extends ChangeNotifier {
  final InverterRealTimeService _service = InverterRealTimeService();
  final Logger _log = Logger();

  InverterRealTimeData? _currentData;
  bool _isLoading = false;
  String? _error;
  Timer? _refreshTimer;
  String? _currentStationCode;

  InverterRealTimeData? get currentData => _currentData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Getters para acceso directo a los datos
  double get activePower => _currentData?.activePower ?? 0.0;
  double get temperature => _currentData?.temperature ?? 0.0;
  double get efficiency => _currentData?.efficiency ?? 0.0;
  bool get hasData => _currentData != null;

  InverterRealTimeProvider() {
    _log.i('InverterRealTimeProvider initialized');
  }

  /// Establece el código de estación y comienza a obtener datos
  void setStationCode(String? stationCode) {
    if (_currentStationCode != stationCode) {
      _log.i('🔧 PROVIDER: Station code changed from $_currentStationCode to $stationCode');
      _currentStationCode = stationCode;

      // Cancelar el timer anterior
      _refreshTimer?.cancel();

      if (stationCode != null && stationCode.isNotEmpty) {
        _log.i('🔧 PROVIDER: Setting up data fetch for station: $stationCode');
        // Obtener datos inmediatamente
        refreshData();
        // Configurar timer para refrescar cada 5 minutos
        _startRefreshTimer();
      } else {
        _log.w('🔧 PROVIDER: Clearing data (no station code)');
        // Limpiar datos si no hay estación
        _currentData = null;
        _error = null;
        notifyListeners();
      }
    }
  }

  /// Inicia el timer para refrescar datos cada 5 minutos
  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_currentStationCode != null) {
        refreshData();
      }
    });
    _log.i('Started refresh timer for real-time data (5 minute intervals)');
  }

  /// Refresca los datos de la estación actual
  Future<void> refreshData({bool forceRefresh = false}) async {
    if (_currentStationCode == null || _currentStationCode!.isEmpty) {
      _log.w('🔧 INVERTER: Cannot refresh data - no station code set');
      return;
    }

    _setLoading(true);
    _setError(null);

    try {
      _log.i('🔧 INVERTER: Starting refresh for station: $_currentStationCode (forceRefresh: $forceRefresh)');

      final data = await _service.getRealTimeData(
        stationCode: _currentStationCode!,
        forceRefresh: forceRefresh,
      );

      _log.i('🔧 INVERTER: Service returned data: ${data != null}');

      if (data != null) {
        _currentData = data;
        _log.i(
          '🔧 INVERTER: ✅ Successfully updated real-time data: ${data.activePower}kW, ${data.temperature}°C, ${data.efficiency}%',
        );
      } else {
        final errorMsg = 'No se pudieron obtener datos del inversor';
        _setError(errorMsg);
        _log.w('🔧 INVERTER: ❌ $errorMsg - Service returned null');
      }
    } catch (e, stackTrace) {
      final errorMsg = 'Error obteniendo datos en tiempo real: $e';
      _setError(errorMsg);
      _log.e('🔧 INVERTER: ❌ Exception during refresh', error: e, stackTrace: stackTrace);
    } finally {
      _setLoading(false);
      _log.i('🔧 INVERTER: Refresh completed (loading: false)');
    }
  }

  /// Fuerza el refresco de datos ignorando el caché
  Future<void> forceRefresh() async {
    _log.i('Force refreshing real-time data');
    await refreshData(forceRefresh: true);
  }

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setError(String? error) {
    if (_error != error) {
      _error = error;
      notifyListeners();
    }
  }

  void clearError() {
    _setError(null);
  }

  @override
  void dispose() {
    _log.i('InverterRealTimeProvider disposed');
    _refreshTimer?.cancel();
    super.dispose();
  }
}
