import 'package:flutter/material.dart';
import 'dart:async';
import '../services/meter_service.dart';
import 'package:logger/logger.dart';

class MeterProvider extends ChangeNotifier {
  final MeterService _service = MeterService();
  final Logger _log = Logger();

  MeterData? _currentData;
  bool _isLoading = false;
  String? _error;
  Timer? _refreshTimer;
  String? _currentStationCode;

  MeterData? get currentData => _currentData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Getters para acceso directo a los datos
  double get gridPower => _currentData?.activePower ?? 0.0;
  double get meterVoltage => _currentData?.meterVoltage ?? 0.0;
  double get meterCurrent => _currentData?.meterCurrent ?? 0.0;
  double get gridFrequency => _currentData?.gridFrequency ?? 0.0;
  bool get hasData => _currentData != null;
  DateTime? get lastUpdated => _currentData?.fetchedAt;

  MeterProvider() {
    _log.i('MeterProvider initialized');
  }

  /// Establece el código de estación y comienza a obtener datos
  void setStationCode(String? stationCode) {
    if (_currentStationCode != stationCode) {
      _log.i('🔧 METER PROVIDER: Station code changed from $_currentStationCode to $stationCode');
      _currentStationCode = stationCode;

      _refreshTimer?.cancel();

      if (stationCode != null && stationCode.isNotEmpty) {
        _log.i('🔧 METER PROVIDER: Setting up data fetch for station: $stationCode');
        refreshData();
        _startRefreshTimer();
      } else {
        _log.w('🔧 METER PROVIDER: Clearing data (no station code)');
        _currentData = null;
        _error = null;
        notifyListeners();
      }
    }
  }

  /// Inicia el timer para refrescar datos cada 10 minutos
  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      if (_currentStationCode != null) {
        refreshData();
      }
    });
    _log.i('Started refresh timer for meter data (10 minute intervals)');
  }

  /// Refresca los datos de la estación actual
  Future<void> refreshData({bool forceRefresh = false}) async {
    if (_currentStationCode == null || _currentStationCode!.isEmpty) {
      _log.w('🔧 METER: Cannot refresh data - no station code set');
      return;
    }

    _setLoading(true);
    _setError(null);

    try {
      _log.i('🔧 METER: Starting refresh for station: $_currentStationCode (forceRefresh: $forceRefresh)');

      final data = await _service.getMeterData(
        stationCode: _currentStationCode!,
        forceRefresh: forceRefresh,
      );

      _log.i('🔧 METER: Service returned data: ${data != null}');

      if (data != null) {
        _currentData = data;
        _log.i('🔧 METER: ✅ Successfully updated meter data: ${data.activePower}kW from grid');
      } else {
        if (_currentData != null) {
          _log.w('🔧 METER: No se pudieron obtener nuevos datos, manteniendo datos anteriores');
        } else {
          final errorMsg = 'No se pudieron obtener datos del medidor';
          _setError(errorMsg);
          _log.w('🔧 METER: ❌ $errorMsg - Service returned null');
        }
      }
    } catch (e, stackTrace) {
      final errorMsg = 'Error obteniendo datos del medidor: $e';
      _setError(errorMsg);
      _log.e('🔧 METER: ❌ Exception during refresh', error: e, stackTrace: stackTrace);
    } finally {
      _setLoading(false);
      _log.i('🔧 METER: Refresh completed (loading: false)');
    }
  }

  /// Fuerza el refresco de datos ignorando el caché
  Future<void> forceRefresh() async {
    _log.i('Force refreshing meter data');
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
    _log.i('MeterProvider disposed');
    _refreshTimer?.cancel();
    super.dispose();
  }
}