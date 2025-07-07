import 'package:flutter/material.dart';
import 'dart:async';
import '../models/solar_data.dart';
import '../services/fusion_solar_service.dart';
import 'package:logger/logger.dart';

class SolarDataProvider extends ChangeNotifier {
  final FusionSolarService _fusionSolarService = FusionSolarService();
  final Logger _log = Logger();

  SolarData? _currentData;
  bool _isLoading = false;
  String? _error;
  Timer? _dataTimer;
  String? _selectedStationCode;
  DateTime? _lastSuccessfulFetch;

  SolarData? get currentData => _currentData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  SolarDataProvider() {
    _log.i('SolarDataProvider initialized');
    _initializeData();
  }

  void setSelectedStationCode(String? stationCode) {
    if (_selectedStationCode != stationCode) {
      _log.i('Station code changed from $_selectedStationCode to $stationCode');
      _selectedStationCode = stationCode;
      
      // Resetear el timestamp del último fetch para permitir fetch inmediato
      _lastSuccessfulFetch = null;
      
      // Refrescar datos inmediatamente cuando cambia la estación seleccionada
      refreshData(forceRefresh: true);
    }
  }

  Future<void> _initializeData() async {
    _log.i('Initializing solar data...');
    await refreshData();
    _startDataTimer();
  }

  void _startDataTimer() {
    _dataTimer?.cancel();
    // Cambiar a 5 minutos para respetar el límite de la API
    _dataTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _log.d('Timer triggered - refreshing data automatically');
      refreshData();
    });
    _log.i('Data timer started with 5-minute intervals');
  }

  Future<void> refreshData({bool forceRefresh = false}) async {
    try {
      _log.i('Starting data refresh for station: $_selectedStationCode');
      _setLoading(true);
      _setError(null);

      // Si no es un refresh forzado, verificar si es muy pronto desde el último fetch exitoso
      if (!forceRefresh && _lastSuccessfulFetch != null) {
        final timeSinceLastFetch = DateTime.now().difference(_lastSuccessfulFetch!);
        _log.d('Time since last fetch: ${timeSinceLastFetch.inMinutes} minutes');
        if (timeSinceLastFetch < const Duration(minutes: 5)) {
          _log.w('Skipping fetch - too soon since last successful fetch');
          _setLoading(false);
          return; // No hacer fetch si es muy pronto
        }
      }

      _log.d('Calling FusionSolarService.getCurrentData()');
      final data = await _fusionSolarService.getCurrentData(
        stationCode: _selectedStationCode,
      );
      
      _log.i('Received data from service: ${data != null ? 'SUCCESS' : 'NULL'}');
      if (data != null) {
        _log.d('Data details - currentPower: ${data.currentPower}, dailyProduction: ${data.dailyProduction}, dailyConsumption: ${data.dailyConsumption}');
        _log.d('Income data - dailyIncome: ${data.dailyIncome}, totalIncome: ${data.totalIncome}');
        _log.d('Health state: ${data.healthState} (${data.healthStateText})');
      }
      
      _currentData = data;
      
      // Solo actualizar el timestamp si obtuvimos datos reales
      if (data != null && (data.dailyProduction > 0 || data.dailyConsumption > 0 || data.dailyIncome != null && data.dailyIncome! > 0)) {
        _lastSuccessfulFetch = DateTime.now();
        _log.i('Updated last successful fetch timestamp');
      }
      
      _setLoading(false);
      _log.i('Data refresh completed successfully');
      notifyListeners();
    } catch (e) {
      _log.e('Error during data refresh', error: e);
      _setError('Error al obtener datos solares: $e');
      _setLoading(false);
    }
  }

  Future<List<SolarData>> getHistoricalData({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      return await _fusionSolarService.getHistoricalData(
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      debugPrint('Error getting historical data: $e');
      return [];
    }
  }

  double get currentExcessPercentage {
    if (_currentData == null || _currentData!.currentPower == 0) {
      _log.d('Current excess percentage: 0 (no data or no power)');
      return 0;
    }
    final percentage = (_currentData!.currentExcess / _currentData!.currentPower) * 100;
    _log.d('Current excess percentage: $percentage%');
    return percentage;
  }

  bool get hasSignificantExcess {
    final hasExcess = _currentData?.currentExcess != null && 
           _currentData!.currentExcess > 1.0; // Más de 1kW de excedente
    _log.d('Has significant excess (>1kW): $hasExcess (current: ${_currentData?.currentExcess ?? 0}kW)');
    return hasExcess;
  }

  double get todaysSavings {
    if (_currentData == null) {
      _log.d('Todays savings: 0 (no data)');
      return 0;
    }
    
    // Si no tenemos datos reales o si son valores por defecto, devolver 0
    if (_currentData!.dailyProduction <= 0) {
      _log.d('Todays savings: 0 (no daily production)');
      return 0;
    }
    
    // Usar el ingreso diario real si está disponible, sino calcular estimado
    if (_currentData!.dailyIncome != null && _currentData!.dailyIncome! > 0) {
      _log.d('Todays savings from dailyIncome: €${_currentData!.dailyIncome!}');
      return _currentData!.dailyIncome!;
    }
    
    // Calcular ahorro aproximado (precio promedio de electricidad en Europa)
    const double electricityPrice = 0.25; // EUR por kWh
    final estimatedSavings = _currentData!.dailyProduction * electricityPrice;
    _log.d('Todays savings estimated: €$estimatedSavings (${_currentData!.dailyProduction} kWh * €$electricityPrice)');
    return estimatedSavings;
  }

  void _setLoading(bool loading) {
    _log.d('Setting loading state: $loading');
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _log.d('Setting error state: $error');
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _log.i('SolarDataProvider disposed');
    _dataTimer?.cancel();
    super.dispose();
  }
}
