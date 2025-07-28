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
  final DateTime? fetchedAt; // Fecha de última actualización

  const InverterRealTimeData({
    required this.activePower,
    required this.temperature,
    required this.efficiency,
    required this.timestamp,
    this.fetchedAt,
  });

  factory InverterRealTimeData.fromJson(Map<String, dynamic> json) {
    return InverterRealTimeData(
      activePower: (json['active_power'] ?? 0.0).toDouble(),
      temperature: (json['temperature'] ?? 0.0).toDouble(),
      efficiency: (json['efficiency'] ?? 0.0).toDouble(),
      timestamp: DateTime.parse(json['created_at']),
      fetchedAt: json['fetched_at'] != null ? DateTime.parse(json['fetched_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'active_power': activePower,
      'temperature': temperature,
      'efficiency': efficiency,
      'created_at': timestamp.toIso8601String(),
      'fetched_at': fetchedAt?.toIso8601String(),
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
  
  /// Crea una instancia desde la respuesta completa de la API
  factory InverterRealTimeData.fromApiResponse(Map<String, dynamic> response) {
    if (response['success'] == true && response['data'] is List && response['data'].isNotEmpty) {
      final deviceData = response['data'][0];
      if (deviceData != null && deviceData['dataItemMap'] != null) {
        final dataItemMap = deviceData['dataItemMap'] as Map<String, dynamic>;
        
        // Extraer valores con manejo de tipos seguro
        double getDoubleValue(String key) {
          final value = dataItemMap[key];
          if (value == null) return 0.0;
          if (value is num) return value.toDouble();
          if (value is String) return double.tryParse(value) ?? 0.0;
          return 0.0;
        }
        
        // Usar los campos correctos del JSON proporcionado
        final now = DateTime.now();
        return InverterRealTimeData(
          activePower: getDoubleValue('active_power') > 0 ? 
                      getDoubleValue('active_power') : 
                      getDoubleValue('mppt_power'),
          temperature: getDoubleValue('temperature'),
          efficiency: getDoubleValue('efficiency'),
          timestamp: now,
          fetchedAt: now,
        );
      }
    }
    throw Exception('Formato de respuesta inválido');
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

      // Normalizar el código de estación
      final String normalizedCode = stationCode.startsWith('NE=') 
          ? stationCode 
          : stationCode.replaceAll(RegExp(r'[^0-9]'), '');

      // Verificar si hay datos en caché y si next_fetch_allowed es mayor que la fecha actual
      if (!forceRefresh) {
        final cacheResult = await _supabase
            .from('real_time_data')
            .select()
            .eq('user_id', user.id)
            .eq('station_code', normalizedCode)
            .maybeSingle();

        if (cacheResult != null && cacheResult['next_fetch_allowed'] != null) {
          final nextAllowed = DateTime.parse(cacheResult['next_fetch_allowed']);
          final now = DateTime.now();
          
          // Si next_fetch_allowed es mayor que la fecha actual, usar los datos en caché
          if (now.isBefore(nextAllowed)) {
            _log.i('🔧 SERVICE: ✅ Using cached data (next fetch at: $nextAllowed)');
            return InverterRealTimeData.fromJson(cacheResult);
          }
          _log.d('🔧 SERVICE: ⏰ Cache expired, fetching fresh data');
        } else {
          _log.d('🔧 SERVICE: No valid cached data found');
        }
      }

      // Obtener el device DN del inversor (con caché)
      final deviceDn = await _getInverterDeviceDn(stationCode);
      if (deviceDn == null) {
        _log.w('🔧 SERVICE: ❌ No inverter device DN found for station: $stationCode');
        return null;
      }
      _log.i('🔧 SERVICE: ✅ Found device DN: $deviceDn');

      // Hacer fetch de datos en tiempo real
      _log.i('🔧 SERVICE: 🌐 Making API call to fetch real-time data');
      final realTimeData = await _fetchRealTimeData(deviceDn);
      if (realTimeData != null) {
        // Guardar en caché con next_fetch_allowed a 10 minutos en el futuro
        await _saveRealTimeDataToCache(stationCode, deviceDn, realTimeData);
        _log.i('🔧 SERVICE: ✅ Successfully fetched and cached real-time data');
        return realTimeData;
      }

      // Si falla la petición a la API, devolver null para mostrar error
      _log.w('🔧 SERVICE: ⚠️ API call failed, returning null to show error');
      return null;
    } catch (e, stackTrace) {
      _log.e('🔧 SERVICE: ❌ Exception in getRealTimeData', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Obtiene el device DN del inversor residencial, con caché optimizado
  Future<String?> _getInverterDeviceDn(String stationCode) async {
    // Asegurar que el código de estación esté en el formato correcto
    // Si ya tiene el prefijo "NE=", usarlo tal cual, si no, extraer solo el número
    final String normalizedCode = stationCode.startsWith('NE=') 
        ? stationCode 
        : stationCode.replaceAll(RegExp(r'[^0-9]'), '');
    
    _log.i('🔧 SERVICE: Normalized station code: $normalizedCode from $stationCode');
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
          .eq('station_code', normalizedCode)
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
      _log.i('🔧 SERVICE: 🌐 Fetching device list for station: $normalizedCode');
      final json = await _oauthService.handleApiCall(
        _deviceListEndpoint,
        method: 'POST',
        body: {'stationCodes': normalizedCode},
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

            // Guardar/actualizar en caché con manejo explícito de conflictos
            await _supabase.from('device_cache').upsert(
              {
                'user_id': user.id,
                'station_code': normalizedCode,
                'dev_dn': deviceDn,
                'updated_at': DateTime.now().toIso8601String(),
              },
              onConflict: 'user_id,station_code'
            );

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

      if (json != null) {
        // Depurar las claves disponibles en el JSON
        if (json['data'] is List && json['data'].isNotEmpty && json['data'][0]['dataItemMap'] != null) {
          final dataItemMap = json['data'][0]['dataItemMap'] as Map<String, dynamic>;
          _log.i('🔧 SERVICE: Available keys in dataItemMap: ${dataItemMap.keys.join(', ')}');
          
          // Verificar si existen las claves específicas que necesitamos
          _log.i('🔧 SERVICE: active_power exists: ${dataItemMap.containsKey('active_power')}');
          _log.i('🔧 SERVICE: mppt_power exists: ${dataItemMap.containsKey('mppt_power')}');
          _log.i('🔧 SERVICE: temperature exists: ${dataItemMap.containsKey('temperature')}');
          _log.i('🔧 SERVICE: efficiency exists: ${dataItemMap.containsKey('efficiency')}');
        }
        
        try {
          // Usar el nuevo método factory para procesar la respuesta completa
          final realTimeData = InverterRealTimeData.fromApiResponse(json);
          _log.i('🔧 SERVICE: ✅ Parsed data - Power: ${realTimeData.activePower}kW, Temp: ${realTimeData.temperature}°C, Eff: ${realTimeData.efficiency}%');
          return realTimeData;
        } catch (e) {
          _log.w('🔧 SERVICE: ❌ Error parsing API response: $e');
        }
      } else {
        _log.w('🔧 SERVICE: ❌ Null API response');
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
      
      // Normalizar el código de estación
      final String normalizedCode = stationCode.startsWith('NE=') 
          ? stationCode 
          : stationCode.replaceAll(RegExp(r'[^0-9]'), '');

      _log.i('🔧 SERVICE: 🔍 Looking for cached data for station: $normalizedCode');

      // Consulta directa - solo un registro por usuario/estación
      final result = await _supabase
          .from('real_time_data')
          .select()
          .eq('user_id', user.id)
          .eq('station_code', normalizedCode)
          .maybeSingle();

      if (result == null) {
        _log.i('🔧 SERVICE: 📥 No cached data found');
        return null;
      }

      _log.i('🔧 SERVICE: ✅ Found cached data');
      
      // Si no permitimos datos antiguos, verificar next_fetch_allowed
      if (!allowOlder && result['next_fetch_allowed'] != null) {
        final nextAllowed = DateTime.parse(result['next_fetch_allowed']);
        final now = DateTime.now();
        
        // Si aún no es tiempo de hacer fetch, usar los datos en caché
        if (now.isBefore(nextAllowed)) {
          _log.i('🔧 SERVICE: ✅ Using cached data (next fetch at: $nextAllowed)');
          return InverterRealTimeData.fromJson(result);
        } else {
          _log.d('🔧 SERVICE: ⏰ Cache expired, need fresh data');
          return null;
        }
      }
      
      // Si allowOlder es true o no hay next_fetch_allowed, devolver los datos
      _log.i('🔧 SERVICE: ✅ Using cached data (allowOlder: $allowOlder)');
      return InverterRealTimeData.fromJson(result);
    } catch (e, stackTrace) {
      _log.e('🔧 SERVICE: ❌ Error getting cached data', error: e, stackTrace: stackTrace);
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
      
      // Normalizar el código de estación
      final String normalizedCode = stationCode.startsWith('NE=') 
          ? stationCode 
          : stationCode.replaceAll(RegExp(r'[^0-9]'), '');

      final now = DateTime.now();
      final nextFetch = now.add(const Duration(minutes: 10));

      _log.i('🔧 SERVICE: Saving real-time data for station: $normalizedCode');

      try {
        // Usar upsert con user_id y station_code como claves únicas
        // Esto reemplazará el registro anterior en lugar de crear uno nuevo
        await _supabase.from('real_time_data').upsert(
          {
            'user_id': user.id,
            'station_code': normalizedCode,
            'dev_dn': deviceDn,
            'active_power': data.activePower,
            'temperature': data.temperature,
            'efficiency': data.efficiency,
            'created_at': now.toIso8601String(),
            'fetched_at': now.toIso8601String(),
            'next_fetch_allowed': nextFetch.toIso8601String(),
          },
          onConflict: 'user_id,station_code'
        );
        _log.i('🔧 SERVICE: ✅ Successfully saved real-time data to cache');
      } catch (e) {
        _log.e('🔧 SERVICE: ❌ Error in upsert operation: $e');
        
        // Intentar insertar directamente si upsert falla
        try {
          // Primero eliminar cualquier registro existente
          await _supabase.from('real_time_data')
              .delete()
              .eq('user_id', user.id)
              .eq('station_code', normalizedCode);
          
          // Luego insertar el nuevo registro
          await _supabase.from('real_time_data').insert(
            {
              'user_id': user.id,
              'station_code': normalizedCode,
              'dev_dn': deviceDn,
              'active_power': data.activePower,
              'temperature': data.temperature,
              'efficiency': data.efficiency,
              'created_at': now.toIso8601String(),
              'fetched_at': now.toIso8601String(),
              'next_fetch_allowed': nextFetch.toIso8601String(),
            }
          );
          _log.i('🔧 SERVICE: ✅ Successfully saved data using delete+insert');
        } catch (insertError) {
          _log.e('🔧 SERVICE: ❌ Error in delete+insert operation: $insertError');
          rethrow;
        }
      }
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
      
      // Normalizar el código de estación
      final String normalizedCode = stationCode.startsWith('NE=') 
          ? stationCode 
          : stationCode.replaceAll(RegExp(r'[^0-9]'), '');

      final now = DateTime.now();

      // Verificar si hay un registro con next_fetch_allowed
      final result = await _supabase
          .from('real_time_data')
          .select('next_fetch_allowed')
          .eq('user_id', user.id)
          .eq('station_code', normalizedCode)
          .maybeSingle();

      if (result == null) {
        // No hay registro, se puede hacer fetch
        _log.d('No previous fetch record, can fetch: true');
        return true;
      }

      // Verificar si ya podemos hacer fetch
      if (result['next_fetch_allowed'] != null) {
        final nextAllowed = DateTime.parse(result['next_fetch_allowed']);
        final canFetch = now.isAfter(nextAllowed);
        _log.d('Next fetch allowed at: $nextAllowed, can fetch now: $canFetch');
        return canFetch;
      }
      
      return true;
    } catch (e) {
      _log.e('Error checking real-time data rate limit', error: e);
      return true; // En caso de error, permitir el fetch
    }
  }
}