import 'dart:async';
import 'dart:convert';
import 'dart:math';
import '../models/solar_data.dart';
import '../providers/plant_provider.dart';
import 'fusion_solar_oauth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';

class FusionSolarService {
  final FusionSolarOAuthService _oauthService = FusionSolarOAuthService();
  final Random _random = Random();
  final SupabaseClient _supabase = Supabase.instance.client;
  final Logger _log = Logger();

  Future<SolarData> getCurrentData({String? stationCode}) async {
    try {
      _log.i('=== Starting getCurrentData for station: $stationCode ===');
      
      // Verificar si hay configuración OAuth válida
      final hasValidConfig = await _oauthService.hasValidOAuthConfig();
      _log.i('OAuth config valid: $hasValidConfig');

      if (!hasValidConfig) {
        _log.w('No valid OAuth config - returning empty data');
        return SolarData.noData();
      }

      if (stationCode == null || stationCode.isEmpty) {
        _log.w('No station code provided, returning empty data');
        return SolarData.noData();
      }

      // Primero intentar obtener datos del caché
      _log.d('Checking cached data for station: $stationCode');
      final cachedData = await _getCachedDayStatistics(stationCode);
      if (cachedData != null) {
        _log.i('Using cached day statistics for station: $stationCode');
        _log.d('Cached data - dailyProduction: ${cachedData.dailyProduction}, dailyConsumption: ${cachedData.dailyConsumption}');
        return cachedData;
      }

      // Si no hay datos en caché o están desactualizados, verificar si podemos hacer fetch
      _log.d('No valid cached data found, checking if can fetch from API');
      final canFetch = await _canFetchDayStatistics(stationCode);
      _log.i('Can fetch from API: $canFetch');
      if (!canFetch) {
        _log.w('Cannot fetch day statistics yet, using fallback data');
        final fallbackData = await _getFallbackData(stationCode);
        _log.d('Fallback data - dailyProduction: ${fallbackData.dailyProduction}, dailyConsumption: ${fallbackData.dailyConsumption}');
        return fallbackData;
      }

      // Esperar a que el token XSRF esté disponible
      _log.d('Waiting for valid XSRF token...');
      await _waitForValidToken();

      // Intentar obtener datos reales de FusionSolar
      _log.i('Fetching fresh data from FusionSolar API');
      final data = await _fetchAndCacheDayStatistics(stationCode);
      if (data != null) {
        _log.i('Successfully fetched fresh data from API');
        _log.d('Fresh data - dailyProduction: ${data.dailyProduction}, dailyConsumption: ${data.dailyConsumption}');
        return data;
      }

      // Si falla, devolver datos de fallback
      _log.w('API fetch failed, using fallback data');
      final fallbackData = await _getFallbackData(stationCode);
      _log.d('Final fallback data - dailyProduction: ${fallbackData.dailyProduction}, dailyConsumption: ${fallbackData.dailyConsumption}');
      return fallbackData;
    } catch (e) {
      _log.e('Error in getCurrentData', error: e);
      return SolarData.noData();
    }
  }

  /// Espera hasta que haya un token XSRF válido disponible
  Future<void> _waitForValidToken() async {
    int attempts = 0;
    const maxAttempts = 10;
    const delayBetweenAttempts = Duration(seconds: 1);

    while (attempts < maxAttempts) {
      final token = await _oauthService.getCurrentXsrfToken();
      if (token != null && token.isNotEmpty) {
        _log.i('Valid XSRF token available');
        return;
      }

      _log.w('Waiting for valid XSRF token, attempt ${attempts + 1}/$maxAttempts');
      await Future.delayed(delayBetweenAttempts);
      attempts++;
    }

    throw Exception('Could not obtain valid XSRF token after $maxAttempts attempts');
  }

  /// Obtiene estadísticas del día desde el caché de Supabase
  Future<SolarData?> _getCachedDayStatistics(String stationCode) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _log.w('No authenticated user for cache lookup');
        return null;
      }

      final today = DateTime.now().toIso8601String().split('T')[0];
      _log.d('Looking for cached data for date: $today');

      final result = await _supabase
          .from('day_statistics')
          .select()
          .eq('user_id', user.id)
          .eq('station_code', stationCode)
          .eq('data_date', today)
          .maybeSingle();

      if (result == null) {
        _log.d('No cached data found for today');
        return null;
      }

      _log.d('Found cached data: $result');

      // Verificar si los datos no son demasiado antiguos (máximo 6 minutos)
      final fetchedAt = DateTime.tryParse(result['fetched_at']);
      if (fetchedAt == null) {
        _log.w('Invalid fetched_at timestamp in cached data');
        return null;
      }

      final age = DateTime.now().difference(fetchedAt);
      _log.d('Cached data age: ${age.inMinutes} minutes');
      
      if (age > const Duration(minutes: 6)) {
        _log.d('Cached data too old (${age.inMinutes} min), ignoring');
        return null;
      }

      final solarData = SolarData.fromFusionSolarApi(result);
      _log.i('Successfully loaded cached data - dailyProduction: ${solarData.dailyProduction}');
      return solarData;
    } catch (e) {
      _log.e('Error getting cached day statistics', error: e);
      return null;
    }
  }

  /// Verifica si se puede hacer fetch de estadísticas (respeta límite de 5 minutos)
  /// Con excepción para primera consulta de una estación nueva
  Future<bool> _canFetchDayStatistics(String stationCode) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final meta = await _supabase
          .from('day_statistics_fetch_meta')
          .select('next_allowed_fetch, last_fetch_at')
          .eq('user_id', user.id)
          .eq('station_code', stationCode)
          .maybeSingle();

      if (meta == null) {
        _log.i('First time fetching for station $stationCode - allowing fetch');
        return true; // Primera vez para esta estación
      }

      // Verificar si hay datos cacheados para hoy
      final today = DateTime.now().toIso8601String().split('T')[0];
      final cached = await _supabase
          .from('day_statistics')
          .select('id')
          .eq('user_id', user.id)
          .eq('station_code', stationCode)
          .eq('data_date', today)
          .maybeSingle();

      if (cached == null) {
        _log.i('No cached data for today for station $stationCode - allowing fetch');
        return true; // No hay datos para hoy, permitir fetch
      }

      final nextAllowedFetch = DateTime.tryParse(meta['next_allowed_fetch']);
      if (nextAllowedFetch == null) return true;

      final canFetch = DateTime.now().isAfter(nextAllowedFetch);
      _log.d('Next allowed fetch: $nextAllowedFetch, can fetch: $canFetch');
      return canFetch;
    } catch (e) {
      _log.e('Error checking fetch permission', error: e);
      return false; // En caso de error, no permitir fetch para evitar exceder límites
    }
  }

  /// Hace fetch de estadísticas y las guarda en caché
  Future<SolarData?> _fetchAndCacheDayStatistics(String stationCode) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _log.w('No authenticated user for API fetch');
        return null;
      }

      _log.i('Fetching day statistics from API for station: $stationCode');

      final data = await _oauthService.handleApiCall(
        '/thirdData/getStationRealKpi',
        method: 'POST',
        body: {
          'stationCodes': stationCode,
        },
      );

      _log.d('API response received: ${data != null ? 'SUCCESS' : 'NULL'}');
      if (data != null) {
        _log.d('API response details: success=${data['success']}, data type=${data['data']?.runtimeType}');
      }

      if (data != null && data['success'] == true && data['data'] is List) {
        final List<dynamic> stations = data['data'];
        _log.d('Number of stations in response: ${stations.length}');
        
        if (stations.isNotEmpty) {
          final stationData = stations.first as Map<String, dynamic>;
          _log.d('Station data keys: ${stationData.keys.toList()}');
          
          if (stationData.containsKey('dataItemMap')) {
            final dataItemMap = stationData['dataItemMap'] as Map<String, dynamic>;
            _log.d('DataItemMap keys: ${dataItemMap.keys.toList()}');
            _log.d('DataItemMap values: $dataItemMap');

            // Guardar en caché
            await _saveDayStatisticsToCache(stationCode, dataItemMap);

            // Actualizar metadata de fetch
            await _updateFetchMetadata(stationCode);

            final solarData = SolarData.fromFusionSolarApi(dataItemMap);
            _log.i('Successfully created SolarData from API - dailyProduction: ${solarData.dailyProduction}, dailyIncome: ${solarData.dailyIncome}');
            return solarData;
          } else {
            _log.e('Station data missing dataItemMap key');
          }
        } else {
          _log.e('Empty stations array in API response');
        }
      } else {
        _log.e('Invalid response from day statistics API - success: ${data?['success']}, data: ${data?['data']}');
      }

      return null;
    } catch (e) {
      _log.e('Error fetching day statistics from API', error: e);
      return null;
    }
  }

  /// Guarda las estadísticas del día en el caché de Supabase
  Future<void> _saveDayStatisticsToCache(String stationCode, Map<String, dynamic> dataItemMap) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      final today = now.toIso8601String().split('T')[0];

      await _supabase.from('day_statistics').upsert({
        'user_id': user.id,
        'station_code': stationCode,
        'day_power': double.tryParse(dataItemMap['day_power']?.toString() ?? '0') ?? 0.0,
        'month_power': double.tryParse(dataItemMap['month_power']?.toString() ?? '0') ?? 0.0,
        'total_power': double.tryParse(dataItemMap['total_power']?.toString() ?? '0') ?? 0.0,
        'day_use_energy': double.tryParse(dataItemMap['day_use_energy']?.toString() ?? '0') ?? 0.0,
        'day_on_grid_energy': double.tryParse(dataItemMap['day_on_grid_energy']?.toString() ?? '0') ?? 0.0,
        'day_income': double.tryParse(dataItemMap['day_income']?.toString() ?? '0') ?? 0.0,
        'total_income': double.tryParse(dataItemMap['total_income']?.toString() ?? '0') ?? 0.0,
        'real_health_state': int.tryParse(dataItemMap['real_health_state']?.toString() ?? '3') ?? 3,
        'fetched_at': now.toIso8601String(),
        'data_date': today,
      }, onConflict: 'user_id,station_code,data_date');

      _log.i('Day statistics saved to cache for station: $stationCode');
    } catch (e) {
      _log.e('Error saving day statistics to cache', error: e);
    }
  }

  /// Actualiza los metadatos de fetch
  Future<void> _updateFetchMetadata(String stationCode) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      final nextAllowedFetch = now.add(const Duration(minutes: 5));

      await _supabase.from('day_statistics_fetch_meta').upsert({
        'user_id': user.id,
        'station_code': stationCode,
        'last_fetch_at': now.toIso8601String(),
        'next_allowed_fetch': nextAllowedFetch.toIso8601String(),
        'fetch_count': 1, // Podrías incrementar esto si quieres llevar un contador
      }, onConflict: 'user_id,station_code');

      _log.i('Fetch metadata updated for station: $stationCode. Next fetch allowed at: $nextAllowedFetch');
    } catch (e) {
      _log.e('Error updating fetch metadata', error: e);
    }
  }

  /// Obtiene datos de fallback si no se pueden obtener datos reales
  Future<SolarData> _getFallbackData(String stationCode) async {
    // Intentar obtener los últimos datos disponibles del caché, aunque sean antiguos
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _log.w('No authenticated user for fallback data');
        return SolarData.noData();
      }

      final result = await _supabase
          .from('day_statistics')
          .select()
          .eq('user_id', user.id)
          .eq('station_code', stationCode)
          .order('fetched_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (result != null) {
        _log.i('Using fallback cached data for station: $stationCode');
        _log.d('Fallback data from: ${result['fetched_at']}');
        final solarData = SolarData.fromFusionSolarApi(result);
        _log.d('Fallback data - dailyProduction: ${solarData.dailyProduction}');
        return solarData;
      } else {
        _log.w('No fallback data available in cache');
      }
    } catch (e) {
      _log.e('Error getting fallback data', error: e);
    }

    _log.i('Returning empty SolarData as final fallback');
    return SolarData.noData();
  }

  Future<List<SolarData>> getHistoricalData({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final hasValidConfig = await _oauthService.hasValidOAuthConfig();

      if (!hasValidConfig) {
        // Devolver lista vacía si no hay configuración válida
        return [];
      }

      // Aquí implementarías la llamada real a la API histórica
      // Por ahora, devolver lista vacía ya que no tenemos datos reales
      return [];
    } catch (e) {
      print('Error obteniendo datos históricos: $e');
      return [];
    }
  }

  SolarData _getSimulatedData() {
    final now = DateTime.now();
    final hour = now.hour;

    // Simular patrones realistas de generación solar
    double currentPower = 0;
    if (hour >= 6 && hour <= 18) {
      // Simular curva solar durante el día
      final solarFactor = _calculateSolarFactor(hour);
      currentPower = 5.0 * solarFactor + _random.nextDouble() * 2.0;
    }

    // Simular consumo base más variaciones
    final baseConsumption = 2.0 + _random.nextDouble() * 1.5;
    final currentConsumption = baseConsumption + _getTimeBasedConsumption(hour);

    return SolarData(
      currentPower: currentPower,
      dailyProduction: _calculateDailyProduction(now),
      monthlyProduction: 450.0 + _random.nextDouble() * 100.0,
      totalProduction: 12500.0 + _random.nextDouble() * 500.0,
      currentConsumption: currentConsumption,
      dailyConsumption: 25.0 + _random.nextDouble() * 10.0,
      currentExcess: currentPower - currentConsumption,
      batteryLevel: 75.0 + _random.nextDouble() * 20.0,
      isProducing: currentPower > 0.1,
      timestamp: now,
      dailyIncome: _random.nextDouble() * 12.0, // Explícitamente en euros
      totalIncome: 2100.0 + _random.nextDouble() * 400.0, // Explícitamente en euros
      dailyOnGridEnergy: _random.nextDouble() * 20.0,
      healthState: 3, // Saludable por defecto
    );
  }

  List<SolarData> _getSimulatedHistoricalData(
    DateTime startDate,
    DateTime endDate,
  ) {
    final data = <SolarData>[];
    var currentDate = startDate;

    while (currentDate.isBefore(endDate)) {
      // Generar datos históricos simulados
      data.add(
        SolarData(
          currentPower:
              0, // Los datos históricos no incluyen potencia instantánea
          dailyProduction: 15.0 + _random.nextDouble() * 25.0,
          monthlyProduction: 0,
          totalProduction: 0,
          currentConsumption: 0,
          dailyConsumption: 20.0 + _random.nextDouble() * 15.0,
          currentExcess: 0,
          batteryLevel: 50.0 + _random.nextDouble() * 40.0,
          isProducing: false,
          timestamp: currentDate,
          dailyIncome: _random.nextDouble() * 15.0, // Explícitamente en euros
          totalIncome: 0,
          dailyOnGridEnergy: 15.0 + _random.nextDouble() * 20.0,
          healthState: 3,
        ),
      );

      currentDate = currentDate.add(const Duration(days: 1));
    }

    return data;
  }

  double _calculateSolarFactor(int hour) {
    // Simular curva solar realista
    if (hour < 6 || hour > 18) return 0;

    const peakHour = 12;
    final distanceFromPeak = (hour - peakHour).abs();
    const maxDistance = 6;

    return 1 - (distanceFromPeak / maxDistance);
  }

  double _getTimeBasedConsumption(int hour) {
    // Simular patrones de consumo típicos
    if (hour >= 7 && hour <= 9) return 1.5; // Mañana
    if (hour >= 18 && hour <= 22) return 2.0; // Noche
    return 0.5; // Resto del día
  }

  double _calculateDailyProduction(DateTime date) {
    final hour = date.hour;
    if (hour < 19) {
      // Si aún no ha terminado el día, calcular producción parcial
      final completedHours =
          hour - 6; // Asumiendo que la producción empieza a las 6 AM
      if (completedHours <= 0) return 0;

      const totalDayProduction = 30.0;
      final factor = completedHours / 12.0; // 12 horas de producción
      return totalDayProduction * factor + _random.nextDouble() * 5.0;
    }

    // Día completo
    return 25.0 + _random.nextDouble() * 15.0;
  }
}
