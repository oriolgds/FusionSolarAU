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

  Future<SolarData> getCurrentData({
    String? stationCode,
    bool forceRefresh = false,
  }) async {
    try {
      _log.i(
        '=== Starting getCurrentData for station: $stationCode (forceRefresh: $forceRefresh) ===',
      );
      
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

      // Si es force refresh, verificar si el caché es antiguo antes de decidir
      if (forceRefresh) {
        _log.d('Force refresh requested - checking cache age');
        final shouldFetchFromApi = await _shouldFetchFromApiOnForceRefresh(
          stationCode,
        );
        if (!shouldFetchFromApi) {
          _log.i(
            'Cache is recent (< 5 min), using cached data even with force refresh',
          );
          final cachedData = await _getCachedDayStatistics(stationCode);
          if (cachedData != null) {
            return cachedData;
          }
        }
      }

      // Primero intentar obtener datos del caché (solo si no es force refresh o caché es muy antiguo)
      if (!forceRefresh) {
        _log.d('Checking cached data for station: $stationCode');
        final cachedData = await _getCachedDayStatistics(stationCode);
        if (cachedData != null) {
          _log.i('Using cached day statistics for station: $stationCode');
          _log.d(
            'Cached data - dailyProduction: ${cachedData.dailyProduction}, dailyConsumption: ${cachedData.dailyConsumption}',
          );
          return cachedData;
        }
      }

      // Si no hay datos en caché o están desactualizados, verificar si podemos hacer fetch
      _log.d(
        'No valid cached data found or force refresh, checking if can fetch from API',
      );
      final canFetch = await _canFetchDayStatistics(stationCode);
      _log.i('Can fetch from API: $canFetch');
      if (!canFetch && !forceRefresh) {
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

      // Verificar si la tabla existe antes de hacer la consulta
      _log.d('Attempting to query solar_daily_data table...');
      
      final result = await _supabase
          .from('solar_daily_data')
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

      // Verificar si los datos no son demasiado antiguos (máximo 10 minutos para mejor UX)
      final fetchedAt = DateTime.tryParse(result['fetched_at']);
      if (fetchedAt == null) {
        _log.w('Invalid fetched_at timestamp in cached data');
        return null;
      }

      final age = DateTime.now().difference(fetchedAt);
      _log.d('Cached data age: ${age.inMinutes} minutes');
      
      // Permitir datos más antiguos, pero marcarlos como tales
      if (age > const Duration(minutes: 30)) {
        _log.d(
          'Cached data very old (${age.inMinutes} min), but still using it',
        );
      }

      // Convertir usando el nuevo mapeo de campos
      final mappedData = {
        'day_power': result['day_power'],
        'month_power': result['month_power'],
        'total_power': result['total_power'],
        'day_use_energy': result['day_use_energy'],
        'day_on_grid_energy': result['day_on_grid_energy'],
        'day_income': result['day_income'],
        'total_income': result['total_income'],
        'real_health_state': result['health_state'],
      };

      final solarData = SolarData.fromFusionSolarApi(mappedData);
      _log.i('Successfully loaded cached data - dailyProduction: ${solarData.dailyProduction}');
      return solarData;
    } catch (e) {
      _log.e('Error getting cached day statistics: $e');
      // En lugar de devolver null, devolver datos vacíos si hay error de BD
      _log.w(
        'Database error encountered, skipping cache and continuing with API fetch',
      );
      return null;
    }
  }

  /// Verifica si se puede hacer fetch de estadísticas
  Future<bool> _canFetchDayStatistics(String stationCode) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final today = DateTime.now().toIso8601String().split('T')[0];
      
      _log.d('Checking fetch permissions for station: $stationCode');
      
      final result = await _supabase
          .from('solar_daily_data')
          .select('next_fetch_allowed, fetched_at')
          .eq('user_id', user.id)
          .eq('station_code', stationCode)
          .eq('data_date', today)
          .maybeSingle();

      if (result == null) {
        _log.i(
          'First time fetching for station $stationCode today - allowing fetch',
        );
        return true;
      }

      final nextAllowedFetch = DateTime.tryParse(result['next_fetch_allowed']);
      if (nextAllowedFetch == null) return true;

      final canFetch = DateTime.now().isAfter(nextAllowedFetch);
      _log.d('Next allowed fetch: $nextAllowedFetch, can fetch: $canFetch');
      return canFetch;
    } catch (e) {
      _log.e('Error checking fetch permission: $e');
      // Si hay error de BD, permitir el fetch para no bloquear la funcionalidad
      _log.w(
        'Database error in fetch permission check, allowing fetch to proceed',
      );
      return true;
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

  /// Guarda las estadísticas del día en el caché optimizado
  Future<void> _saveDayStatisticsToCache(String stationCode, Map<String, dynamic> dataItemMap) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _log.w('No authenticated user, skipping cache save');
        return;
      }

      final now = DateTime.now();
      final today = now.toIso8601String().split('T')[0];
      final nextFetch = now.add(const Duration(minutes: 5));

      final dataToSave = {
        'user_id': user.id,
        'station_code': stationCode,
        'data_date': today,
        'day_power': double.tryParse(dataItemMap['day_power']?.toString() ?? '0') ?? 0.0,
        'month_power': double.tryParse(dataItemMap['month_power']?.toString() ?? '0') ?? 0.0,
        'total_power': double.tryParse(dataItemMap['total_power']?.toString() ?? '0') ?? 0.0,
        'day_use_energy': double.tryParse(dataItemMap['day_use_energy']?.toString() ?? '0') ?? 0.0,
        'day_on_grid_energy': double.tryParse(dataItemMap['day_on_grid_energy']?.toString() ?? '0') ?? 0.0,
        'day_income': double.tryParse(dataItemMap['day_income']?.toString() ?? '0') ?? 0.0,
        'total_income': double.tryParse(dataItemMap['total_income']?.toString() ?? '0') ?? 0.0,
        'health_state':
            int.tryParse(dataItemMap['real_health_state']?.toString() ?? '3') ??
            3,
        'fetched_at': now.toIso8601String(),
        'next_fetch_allowed': nextFetch.toIso8601String(),
      };

      _log.d('Attempting to save data to cache: $dataToSave');

      await _supabase
          .from('solar_daily_data')
          .upsert(dataToSave, onConflict: 'user_id,station_code,data_date');

      _log.i(
        'Day statistics saved to optimized cache for station: $stationCode',
      );
    } catch (e) {
      _log.e('Error saving day statistics to cache: $e');
      // No relanzar el error, solo loggearlo
      _log.w('Cache save failed, but continuing with operation...');
    }
  }

  /// Obtiene datos de fallback mejorado
  Future<SolarData> _getFallbackData(String stationCode) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _log.w('No authenticated user for fallback data');
        return SolarData.noData();
      }

      _log.d('Attempting to get fallback data from cache...');

      // Buscar los datos más recientes (incluso de días anteriores)
      final result = await _supabase
          .from('solar_daily_data')
          .select()
          .eq('user_id', user.id)
          .eq('station_code', stationCode)
          .order('data_date', ascending: false)
          .order('fetched_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (result != null) {
        _log.i(
          'Using fallback cached data for station: $stationCode from date: ${result['data_date']}',
        );

        final mappedData = {
          'day_power': result['day_power'],
          'month_power': result['month_power'],
          'total_power': result['total_power'],
          'day_use_energy': result['day_use_energy'],
          'day_on_grid_energy': result['day_on_grid_energy'],
          'day_income': result['day_income'],
          'total_income': result['total_income'],
          'real_health_state': result['health_state'],
        };

        final solarData = SolarData.fromFusionSolarApi(mappedData);
        _log.d('Fallback data - dailyProduction: ${solarData.dailyProduction}');
        return solarData;
      } else {
        _log.w('No fallback data available in cache');
      }
    } catch (e) {
      _log.e('Error getting fallback data: $e');
      _log.w('Database error in fallback, returning empty data');
    }

    _log.i('Returning empty SolarData as final fallback');
    return SolarData.noData();
  }

  /// Actualiza metadatos de fetch para rate limiting
  Future<void> _updateFetchMetadata(String stationCode) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      final nextFetch = now.add(const Duration(minutes: 5));

      await _supabase
          .from('solar_daily_data')
          .update({'next_fetch_allowed': nextFetch.toIso8601String()})
          .eq('user_id', user.id)
          .eq('station_code', stationCode)
          .eq('data_date', now.toIso8601String().split('T')[0]);

      _log.d('Updated fetch metadata for station: $stationCode');
    } catch (e) {
      _log.e('Error updating fetch metadata', error: e);
    }
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
      _log.e('Error obteniendo datos históricos', error: e);
      return [];
    }
  }

  /// Verifica si debe hacer fetch desde la API en un force refresh
  /// Solo hace fetch si los datos en caché tienen más de 5 minutos
  Future<bool> _shouldFetchFromApiOnForceRefresh(String stationCode) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return true;

      final today = DateTime.now().toIso8601String().split('T')[0];

      _log.d('Checking cache age for force refresh...');

      final result = await _supabase
          .from('solar_daily_data')
          .select('fetched_at')
          .eq('user_id', user.id)
          .eq('station_code', stationCode)
          .eq('data_date', today)
          .maybeSingle();

      if (result == null) {
        _log.i('No cached data found - should fetch from API');
        return true;
      }

      final fetchedAt = DateTime.tryParse(result['fetched_at']);
      if (fetchedAt == null) {
        _log.w('Invalid fetched_at timestamp - should fetch from API');
        return true;
      }

      final age = DateTime.now().difference(fetchedAt);
      final shouldFetch = age > const Duration(minutes: 5);

      _log.i('Cache age: ${age.inMinutes} minutes, should fetch: $shouldFetch');
      return shouldFetch;
    } catch (e) {
      _log.e('Error checking cache age for force refresh: $e');
      // En caso de error, intentar fetch para no bloquear funcionalidad
      _log.w('Database error in cache age check, allowing fetch to proceed');
      return true;
    }
  }
}
