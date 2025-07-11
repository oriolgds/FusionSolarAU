import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'fusion_solar_oauth_service.dart';

/// Modelo para datos en tiempo real del inversor
class InverterRealTimeData {
  final double activePower; // kW
  final double temperature; // °C
  final double efficiency; // %
  final DateTime timestamp;

  const InverterRealTimeData({
    required this.activePower,
    required this.temperature,
    required this.efficiency,
    required this.timestamp,
  });

  factory InverterRealTimeData.fromJson(Map<String, dynamic> json) {
    return InverterRealTimeData(
      activePower: (json['active_power'] ?? 0.0).toDouble(),
      temperature: (json['temperature'] ?? 0.0).toDouble(),
      efficiency: (json['efficiency'] ?? 0.0).toDouble(),
      timestamp: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'active_power': activePower,
      'temperature': temperature,
      'efficiency': efficiency,
      'created_at': timestamp.toIso8601String(),
    };
  }

  /// Crea una instancia desde la respuesta de la API de FusionSolar
  factory InverterRealTimeData.fromFusionSolarApi(
    Map<String, dynamic> dataItemMap,
  ) {
    return InverterRealTimeData(
      activePower: (dataItemMap['active_power'] ?? 0.0).toDouble(),
      temperature: (dataItemMap['temperature'] ?? 0.0).toDouble(),
      efficiency: (dataItemMap['efficiency'] ?? 0.0).toDouble(),
      timestamp: DateTime.now(),
    );
  }
}

/// Servicio para manejar datos en tiempo real del inversor con cacheo optimizado
class InverterRealTimeService {
  final FusionSolarOAuthService _oauthService = FusionSolarOAuthService();
  final SupabaseClient _supabase = Supabase.instance.client;
  final Logger _log = Logger();

  static const String _deviceListEndpoint = '/thirdData/getDevList';
  static const String _deviceRealKpiEndpoint = '/thirdData/getDevRealKpi';
  static const int _residentialInverterTypeId = 38;

  /// Obtiene datos en tiempo real del inversor para la estación especificada
  ///
  /// [stationCode] - Código de la estación (ej: "NE=181814243")
  /// [forceRefresh] - Si true, ignora el caché y hace fetch directo de la API
  Future<InverterRealTimeData?> getRealTimeData({
    required String stationCode,
    bool forceRefresh = false,
  }) async {
    try {
      _log.i('🔧 SERVICE: Getting real-time data for $stationCode (force: $forceRefresh)');

      // Verificar que las tablas existen y que el usuario está autenticado
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _log.w('🔧 SERVICE: ❌ No authenticated user found');
        return null;
      }
      _log.i('🔧 SERVICE: ✅ User authenticated: ${user.id}');

      // 1. Verificar si tenemos datos recientes en caché (< 5 minutos)
      if (!forceRefresh) {
        final cachedData = await _getCachedRealTimeData(stationCode);
        if (cachedData != null) {
          _log.i('🔧 SERVICE: ✅ Returning cached data (age: fresh)');
          return cachedData;
        }
        _log.d('🔧 SERVICE: No fresh cached data found');
      }

      // 2. Obtener el device DN del inversor (con caché)
      final deviceDn = await _getInverterDeviceDn(stationCode);
      if (deviceDn == null) {
        _log.w('🔧 SERVICE: ❌ No inverter device DN found for station: $stationCode');
        return null;
      }
      _log.i('🔧 SERVICE: ✅ Found device DN: $deviceDn');

      // 3. Verificar si podemos hacer fetch de datos en tiempo real
      if (!forceRefresh && !await _canFetchRealTimeData(stationCode)) {
        _log.w('🔧 SERVICE: ⏰ Rate limited, returning old cached data');
        return await _getCachedRealTimeData(stationCode, allowOlder: true);
      }

      // 4. Hacer fetch de datos en tiempo real
      _log.i('🔧 SERVICE: 🌐 Making API call to fetch real-time data');
      final realTimeData = await _fetchRealTimeData(deviceDn);
      if (realTimeData != null) {
        // 5. Guardar en caché
        await _saveRealTimeDataToCache(stationCode, deviceDn, realTimeData);
        _log.i('🔧 SERVICE: ✅ Successfully fetched and cached real-time data');
        return realTimeData;
      }

      // 6. Si falla, devolver datos del caché aunque sean antiguos
      _log.w('🔧 SERVICE: ⚠️ API call failed, falling back to old cache');
      return await _getCachedRealTimeData(stationCode, allowOlder: true);
    } catch (e, stackTrace) {
      _log.e('🔧 SERVICE: ❌ Exception in getRealTimeData', error: e, stackTrace: stackTrace);
      return await _getCachedRealTimeData(stationCode, allowOlder: true);
    }
  }

  /// Obtiene el device DN del inversor residencial, con caché optimizado
  Future<String?> _getInverterDeviceDn(String stationCode) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _log.w('🔧 SERVICE: ❌ No authenticated user for device DN lookup');
        return null;
      }

      // Buscar en caché primero
      final cached = await _supabase
          .from('device_cache')
          .select('dev_dn, updated_at')
          .eq('user_id', user.id)
          .eq('station_code', stationCode)
          .maybeSingle();

      // Si hay caché y no es muy antiguo (< 7 días), usarlo
      if (cached != null) {
        final updatedAt = DateTime.parse(cached['updated_at']);
        if (DateTime.now().difference(updatedAt).inDays < 7) {
          _log.i('🔧 SERVICE: ✅ Using cached device DN: ${cached['dev_dn']}');
          return cached['dev_dn'];
        }
        _log.d('🔧 SERVICE: Cached device DN is old (>7 days), need fresh data');
      } else {
        _log.d('🔧 SERVICE: No cached device DN found');
      }

      // Verificar si podemos hacer fetch de device list
      if (!await _canFetchDeviceList()) {
        _log.w('🔧 SERVICE: ⏰ Cannot fetch device list (rate limited), using cached if available');
        return cached?['dev_dn'];
      }

      // Hacer fetch de la lista de dispositivos
      _log.i('🔧 SERVICE: 🌐 Fetching device list for station: $stationCode');
      final json = await _oauthService.handleApiCall(
        _deviceListEndpoint,
        method: 'POST',
        body: {'stationCodes': stationCode},
      );

      if (json != null && json['success'] == true && json['data'] is List) {
        final devices = json['data'] as List;
        _log.i('🔧 SERVICE: ✅ Received ${devices.length} devices from API');

        // Buscar el primer inversor residencial (devTypeId: 38)
        for (final device in devices) {
          _log.d('🔧 SERVICE: Checking device: ${device['devName']} (type: ${device['devTypeId']})');
          if (device['devTypeId'] == _residentialInverterTypeId &&
              device['devDn'] != null) {
            final deviceDn = device['devDn'] as String;

            // Guardar/actualizar en caché
            await _supabase.from('device_cache').upsert({
              'user_id': user.id,
              'station_code': stationCode,
              'dev_dn': deviceDn,
              'updated_at': DateTime.now().toIso8601String(),
            });

            _log.i('🔧 SERVICE: ✅ Found and cached inverter device DN: $deviceDn');
            return deviceDn;
          }
        }
        _log.w('🔧 SERVICE: ❌ No residential inverter (type 38) found in device list');
      } else {
        _log.w('🔧 SERVICE: ❌ Invalid response from device list API');
      }

      return null;
    } catch (e, stackTrace) {
      _log.e('🔧 SERVICE: ❌ Exception getting device DN', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Hace fetch de datos en tiempo real del inversor
  Future<InverterRealTimeData?> _fetchRealTimeData(String deviceDn) async {
    try {
      _log.i('🔧 SERVICE: 🌐 Making API call for real-time data: $deviceDn');

      final json = await _oauthService.handleApiCall(
        _deviceRealKpiEndpoint,
        method: 'POST',
        body: {'devTypeId': _residentialInverterTypeId, 'devIds': deviceDn},
      );

      _log.i('🔧 SERVICE: API response received: ${json != null}');

      if (json != null && json['success'] == true && json['data'] is List) {
        final data = json['data'] as List;
        _log.i('🔧 SERVICE: API data array length: ${data.length}');
        
        if (data.isNotEmpty && data[0]['dataItemMap'] != null) {
          final dataItemMap = data[0]['dataItemMap'] as Map<String, dynamic>;
          _log.i('🔧 SERVICE: ✅ Valid dataItemMap found with keys: ${dataItemMap.keys.join(', ')}');
          
          final realTimeData = InverterRealTimeData.fromFusionSolarApi(dataItemMap);
          _log.i('🔧 SERVICE: ✅ Parsed data - Power: ${realTimeData.activePower}kW, Temp: ${realTimeData.temperature}°C, Eff: ${realTimeData.efficiency}%');
          
          return realTimeData;
        } else {
          _log.w('🔧 SERVICE: ❌ Empty data array or missing dataItemMap');
        }
      } else {
        _log.w('🔧 SERVICE: ❌ Invalid API response - success: ${json?['success']}, data type: ${json?['data'].runtimeType}');
      }

      return null;
    } catch (e, stackTrace) {
      _log.e('🔧 SERVICE: ❌ Exception fetching real-time data', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Obtiene datos en tiempo real del caché
  Future<InverterRealTimeData?> _getCachedRealTimeData(
    String stationCode, {
    bool allowOlder = false,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _log.w('🔧 SERVICE: ❌ No user for cache lookup');
        return null;
      }

      _log.i('🔧 SERVICE: 🔍 Looking for cached data for station: $stationCode (allowOlder: $allowOlder)');

      final query = _supabase
          .from('real_time_data')
          .select()
          .eq('user_id', user.id)
          .eq('station_code', stationCode)
          .order('created_at', ascending: false)
          .limit(1);

      final result = await query.maybeSingle();
      if (result == null) {
        _log.i('🔧 SERVICE: 📭 No cached data found in database');
        return null;
      }

      _log.i('🔧 SERVICE: ✅ Found cached data entry');
      final createdAt = DateTime.parse(result['created_at']);
      final age = DateTime.now().difference(createdAt);

      // Si no permitimos datos antiguos y los datos tienen más de 5 minutos, no devolver
      if (!allowOlder && age.inMinutes >= 5) {
        _log.d('🔧 SERVICE: ⏰ Cached data too old: ${age.inMinutes} minutes');
        return null;
      }

      _log.i('🔧 SERVICE: ✅ Using cached real-time data (age: ${age.inMinutes} minutes)');
      return InverterRealTimeData.fromJson(result);
    } catch (e, stackTrace) {
      _log.e('🔧 SERVICE: ❌ Error getting cached real-time data', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Guarda datos en tiempo real en el caché
  Future<void> _saveRealTimeDataToCache(
    String stationCode,
    String deviceDn,
    InverterRealTimeData data,
  ) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('real_time_data').insert({
        'user_id': user.id,
        'station_code': stationCode,
        'dev_dn': deviceDn,
        'active_power': data.activePower,
        'temperature': data.temperature,
        'efficiency': data.efficiency,
        'created_at': data.timestamp.toIso8601String(),
      });

      _log.d('Saved real-time data to cache');
    } catch (e) {
      _log.e('Error saving real-time data to cache', error: e);
    }
  }

  /// Verifica si se puede hacer fetch de la lista de dispositivos (24 llamadas/día)
  Future<bool> _canFetchDeviceList() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final today = DateTime.now().toIso8601String().split('T')[0];

      // Contar llamadas hechas hoy
      final response = await _supabase
          .from('device_cache')
          .select('id')
          .eq('user_id', user.id)
          .gte('updated_at', '${today}T00:00:00Z');

      final count = response.length;
      final canFetch = count < 24;
      _log.d('Device list fetch count today: $count/24, can fetch: $canFetch');
      return canFetch;
    } catch (e) {
      _log.e('Error checking device list rate limit', error: e);
      return false;
    }
  }

  /// Verifica si se puede hacer fetch de datos en tiempo real (1 cada 5 minutos)
  Future<bool> _canFetchRealTimeData(String stationCode) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final fiveMinutesAgo = DateTime.now().subtract(
        const Duration(minutes: 5),
      );

      final result = await _supabase
          .from('real_time_data')
          .select('created_at')
          .eq('user_id', user.id)
          .eq('station_code', stationCode)
          .gte('created_at', fiveMinutesAgo.toIso8601String())
          .limit(1)
          .maybeSingle();

      final canFetch = result == null;
      _log.d('Can fetch real-time data: $canFetch');
      return canFetch;
    } catch (e) {
      _log.e('Error checking real-time data rate limit', error: e);
      return false;
    }
  }
}
