import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class DataProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  bool _isLoading = false;
  String? _error;
  Timer? _refreshTimer;
  
  // Solar data
  Map<String, dynamic>? _solarData;
  Map<String, dynamic>? _realTimeData;
  
  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasData => _solarData != null;
  bool get hasRealTimeData => _realTimeData != null;
  
  // Solar data getters
  double get dailyProduction => _solarData?['day_power']?.toDouble() ?? 0.0;
  double get monthlyProduction => _solarData?['month_power']?.toDouble() ?? 0.0;
  double get totalProduction => _solarData?['total_power']?.toDouble() ?? 0.0;
  double get dailyConsumption => _solarData?['day_use_energy']?.toDouble() ?? 0.0;
  double get dailyIncome => _solarData?['day_income']?.toDouble() ?? 0.0;
  double get totalIncome => _solarData?['total_income']?.toDouble() ?? 0.0;
  double get dailyExportedEnergy => _solarData?['day_on_grid_energy']?.toDouble() ?? 0.0;
  int get healthState => _solarData?['health_state']?.toInt() ?? 3;
  
  // Real-time data getters
  double get activePower => _realTimeData?['inverter_power']?.toDouble() ?? 0.0;
  double get temperature => _realTimeData?['temperature']?.toDouble() ?? 0.0;
  double get efficiency => _realTimeData?['efficiency']?.toDouble() ?? 0.0;
  double get meterPower => _realTimeData?['meter_power']?.toDouble() ?? 0.0;
  
  // Computed values
  double get currentPower => activePower;
  double get currentConsumption => activePower - meterPower;
  double get gridPower => meterPower; // Positive = consuming, negative = exporting
  double get currentExcess => -meterPower; // Negative grid power = excess (exporting)
  bool get isProducing => currentPower > 0.1;
  
  DataProvider() {
    _startRefreshTimer();
    refreshData();
  }
  
  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 10), (_) => refreshData());
  }
  
  Future<void> refreshData() async {
    _setLoading(true);
    _setError(null);
    
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _setError('Usuario no autenticado');
        return;
      }
      
      // Get first available station
      final plants = await _supabase
          .from('plants')
          .select('stationCode')
          .eq('user_id', user.id)
          .limit(1);
      
      if (plants.isEmpty) {
        _setError('No hay plantas configuradas');
        return;
      }
      
      final stationCode = plants.first['stationCode'];
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      // Fetch solar data
      _solarData = await _supabase
          .from('solar_daily_data')
          .select()
          .eq('user_id', user.id)
          .eq('station_code', stationCode)
          .eq('data_date', today)
          .maybeSingle();
      
      // Fetch real-time data
      final realTimeResults = await _supabase
          .from('real_time_data')
          .select()
          .eq('user_id', user.id)
          .eq('station_code', stationCode);
      
      // Process real-time data - combine inverter and meter data
      if (realTimeResults.isNotEmpty) {
        final inverterData = realTimeResults.where(
          (item) => item['device_type'] == 'inverter'
        ).isNotEmpty ? realTimeResults.where(
          (item) => item['device_type'] == 'inverter'
        ).first : null;
        
        final meterData = realTimeResults.where(
          (item) => item['device_type'] == 'meter'
        ).isNotEmpty ? realTimeResults.where(
          (item) => item['device_type'] == 'meter'
        ).first : null;
        
        _realTimeData = {
          'inverter_power': inverterData?['active_power'] ?? 0.0,
          'temperature': inverterData?['temperature'] ?? 0.0,
          'efficiency': inverterData?['efficiency'] ?? 0.0,
          'meter_power': meterData?['active_power'] ?? 0.0,
        };
      } else {
        _realTimeData = null;
      }
      
    } catch (e) {
      _setError('Error al obtener datos: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}