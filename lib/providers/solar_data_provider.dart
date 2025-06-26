import 'package:flutter/material.dart';
import 'dart:async';
import '../models/solar_data.dart';
import '../services/fusion_solar_service.dart';

class SolarDataProvider extends ChangeNotifier {
  final FusionSolarService _fusionSolarService = FusionSolarService();

  SolarData? _currentData;
  bool _isLoading = false;
  String? _error;
  Timer? _dataTimer;

  SolarData? get currentData => _currentData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  SolarDataProvider() {
    _initializeData();
  }

  Future<void> _initializeData() async {
    await refreshData();
    _startDataTimer();
  }

  void _startDataTimer() {
    _dataTimer?.cancel();
    _dataTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      refreshData();
    });
  }

  Future<void> refreshData() async {
    try {
      _setLoading(true);
      _setError(null);

      final data = await _fusionSolarService.getCurrentData();
      _currentData = data;
      
      _setLoading(false);
      notifyListeners();
    } catch (e) {
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
    if (_currentData == null || _currentData!.currentPower == 0) return 0;
    return (_currentData!.currentExcess / _currentData!.currentPower) * 100;
  }

  bool get hasSignificantExcess {
    return _currentData?.currentExcess != null && 
           _currentData!.currentExcess > 1.0; // Más de 1kW de excedente
  }

  double get todaysSavings {
    if (_currentData == null) return 0;
    // Calcular ahorro aproximado (precio promedio de electricidad en Australia)
    const double electricityPrice = 0.30; // AUD por kWh
    return _currentData!.dailyProduction * electricityPrice;
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

  @override
  void dispose() {
    _dataTimer?.cancel();
    super.dispose();
  }
}
