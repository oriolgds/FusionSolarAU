import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class DataProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  bool _isLoading = false;
  String? _error;
  Timer? _refreshTimer;
  
  // Data
  Map<String, dynamic>? _solarData;
  Map<String, dynamic>? _inverterData;
  Map<String, dynamic>? _meterData;
  
  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasData => _solarData != null;
  bool get hasRealTimeData => _inverterData != null || _meterData != null;
  
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
  double get activePower => _inverterData?['active_power']?.toDouble() ?? 0.0;
  double get temperature => _inverterData?['temperature']?.toDouble() ?? 0.0;
  double get efficiency => _inverterData?['efficiency']?.toDouble() ?? 0.0;
  double get meterPower => _meterData?['active_power']?.toDouble() ?? 0.0;
  
  // Computed values
  double get currentPower => activePower;
  double get currentConsumption => activePower - meterPower;
  double get gridPower => meterPower;
  double get currentExcess => -meterPower;
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
      
      // Fetch solar data (unique per user)
      _solarData = await _supabase
          .from('solar_daily_data')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      
      // Fetch inverter data
      _inverterData = await _supabase
          .from('inverter_data')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      
      // Fetch meter data
      _meterData = await _supabase
          .from('meter_data')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      
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