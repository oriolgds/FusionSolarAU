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
    // No inicializar datos automáticamente, esperar a que se establezca el código de estación
  }

  void setSelectedStationCode(String? stationCode) {
    if (_selectedStationCode != stationCode) {
      _log.i('Station code changed from $_selectedStationCode to $stationCode');
      _selectedStationCode = stationCode;
      
      // Resetear el timestamp del último fetch para permitir fetch inmediato
      _lastSuccessfulFetch = null;
      
      // Solo inicializar datos si tenemos un código válido
      if (stationCode != null && stationCode.isNotEmpty) {
        _initializeDataForStation();
      } else {
        // Si no hay código, limpiar datos y parar el timer
        _currentData = null;
        _dataTimer?.cancel();
        notifyListeners();
      }
    }
  }

  Future<void> _initializeDataForStation() async {
    _log.i('Initializing solar data for station: $_selectedStationCode');
    await refreshData();
    _startDataTimer();
  }

  void _startDataTimer() {
    _dataTimer?.cancel();
    // Cambiar a 5 minutos para respetar el límite de la API
    _dataTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_selectedStationCode != null && _selectedStationCode!.isNotEmpty) {
        _log.d('Timer triggered - refreshing data automatically');
        refreshData();
      }
    });
    _log.i('Data timer started with 5-minute intervals');
  }

  Future<void> refreshData({bool forceRefresh = false}) async {
    try {
      _log.i(
        'Starting data refresh for station: $_selectedStationCode (forceRefresh: $forceRefresh)',
      );
      _setLoading(true);
      _setError(null);

      // Si no hay estación seleccionada, no hacer nada
      if (_selectedStationCode == null || _selectedStationCode!.isEmpty) {
        _log.w('No station code available for refresh');
        _setLoading(false);
        return;
      }

      // Si no es un refresh forzado, verificar límites de tiempo más flexibles
      if (!forceRefresh && _lastSuccessfulFetch != null) {
        final timeSinceLastFetch = DateTime.now().difference(_lastSuccessfulFetch!);
        _log.d('Time since last fetch: ${timeSinceLastFetch.inMinutes} minutes');
        if (timeSinceLastFetch < const Duration(minutes: 3)) {
          _log.w('Skipping fetch - too soon since last successful fetch');
          _setLoading(false);
          return;
        }
      }

      _log.d(
        'Calling FusionSolarService.getCurrentData() with forceRefresh: $forceRefresh',
      );
      final data = await _fusionSolarService.getCurrentData(
        stationCode: _selectedStationCode,
        forceRefresh: forceRefresh,
      );
      
      _log.i('Received data from service: ${data != null ? 'SUCCESS' : 'NULL'}');
      if (data != null) {
        _log.d('Data details - currentPower: ${data.currentPower}, dailyProduction: ${data.dailyProduction}, dailyConsumption: ${data.dailyConsumption}');
        _log.d('Income data - dailyIncome: ${data.dailyIncome}, totalIncome: ${data.totalIncome}');
        _log.d('Health state: ${data.healthState} (${data.healthStateText})');
        
        _currentData = data;
        
        // Solo actualizar timestamp si obtuvimos datos válidos
        if (_isValidData(data)) {
          _lastSuccessfulFetch = DateTime.now();
          _log.i('Updated last successful fetch timestamp');
        }
      } else {
        _log.w('No data received from service');
        // Si no hay configuración válida, limpiar todos los datos
        _currentData = SolarData.noData();
        _lastSuccessfulFetch = null;
      }
      
      _setLoading(false);
      _log.i('Data refresh completed successfully');
    } catch (e) {
      _log.e('Error during data refresh', error: e);
      
      // Mejorar el mensaje de error basado en el tipo de excepción
      String errorMessage = 'Error al obtener datos solares';
      if (e.toString().contains('solar_daily_data')) {
        errorMessage =
            'Error de configuración de base de datos. Contacta al administrador.';
      } else if (e.toString().contains('JWT')) {
        errorMessage = 'Sesión expirada. Por favor, inicia sesión nuevamente.';
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        errorMessage = 'Error de conexión. Verifica tu conexión a internet.';
      } else if (e.toString().contains('No valid OAuth config')) {
        errorMessage =
            'Configuración de FusionSolar requerida. Ve a Perfil > Configuración FusionSolar.';
        // Limpiar datos cuando no hay configuración
        _currentData = SolarData.noData();
        _lastSuccessfulFetch = null;
      }

      _setError(errorMessage);
      _setLoading(false);
      
      // Si no hay datos previos, establecer datos vacíos
      if (_currentData == null) {
        _currentData = SolarData.noData();
      }
    }

    // Siempre notificar listeners al final
    notifyListeners();
  }

  /// Fuerza la recarga de datos desde la API, ignorando el caché si es antiguo
  Future<void> forceRefreshData() async {
    _log.i('Force refreshing data for station: $_selectedStationCode');
    await refreshData(forceRefresh: true);
  }

  /// Verifica si los datos son válidos y no son solo valores por defecto
  bool _isValidData(SolarData data) {
    return data.dailyProduction > 0 ||
        data.dailyConsumption > 0 ||
        (data.dailyIncome != null && data.dailyIncome! > 0) ||
        (data.totalIncome != null && data.totalIncome! > 0);
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
