import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'fusion_solar_oauth_service.dart';

/// Modelo para datos del medidor
class MeterData {
  final double activePower; // kW (convertido desde W)
  final double meterVoltage; // V
  final double meterCurrent; // A
  final double gridFrequency; // Hz
  final int meterStatus;
  final DateTime timestamp;
  final DateTime? fetchedAt;

  const MeterData({
    required this.activePower,
    required this.meterVoltage,
    required this.meterCurrent,
    required this.gridFrequency,
    required this.meterStatus,
    required this.timestamp,
    this.fetchedAt,
  });

  factory MeterData.fromJson(Map<String, dynamic> json) {
    return MeterData(
      activePower: (json['active_power'] ?? 0.0).toDouble(),
      meterVoltage: (json['meter_voltage'] ?? 0.0).toDouble(),
      meterCurrent: (json['meter_current'] ?? 0.0).toDouble(),
      gridFrequency: (json['grid_frequency'] ?? 0.0).toDouble(),
      meterStatus: (json['meter_status'] ?? 0).toInt(),
      timestamp: DateTime.parse(json['created_at']),
      fetchedAt: json['fetched_at'] != null ? DateTime.parse(json['fetched_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'active_power': activePower,
      'meter_voltage': meterVoltage,
      'meter_current': meterCurrent,
      'grid_frequency': gridFrequency,
      'meter_status': meterStatus,
      'created_at': timestamp.toIso8601String(),
      'fetched_at': fetchedAt?.toIso8601String(),
    };
  }

  /// Crea una instancia desde la respuesta de la API
  factory MeterData.fromApiResponse(Map<String, dynamic> response) {
    try {
      if (response['success'] == true && response['data'] is List && response['data'].isNotEmpty) {
        final deviceData = response['data'][0];
        if (deviceData != null && deviceData['dataItemMap'] != null) {
          final dataItemMap = deviceData['dataItemMap'] as Map<String, dynamic>;
          
          final now = DateTime.now();
          return MeterData(
            activePower: (dataItemMap['active_power'] ?? 0.0).toDouble() / 1000.0, // Convertir W a kW
            meterVoltage: (dataItemMap['meter_u'] ?? 0.0).toDouble(),
            meterCurrent: (dataItemMap['meter_i'] ?? 0.0).toDouble(),
            gridFrequency: (dataItemMap['grid_frequency'] ?? 0.0).toDouble(),
            meterStatus: (dataItemMap['meter_status'] ?? 0).toInt(),
            timestamp: now,
            fetchedAt: now,
          );
        }
      }
      throw Exception('Formato de respuesta inválido: ${response.toString()}');
    } catch (e) {
      throw Exception('Error parseando respuesta del medidor: $e');
    }
  }
}

/// Servicio para manejar datos del medidor con cacheo optimizado
class MeterService {
  final FusionSolarOAuthService _oauthService = FusionSolarOAuthService();
  final SupabaseClient _supabase = Supabase.instance.client;
  final Logger _log = Logger();

  static const String _deviceListEndpoint = '/thirdData/getDevList';
  static const String _deviceRealKpiEndpoint = '/thirdData/getDevRealKpi';
  static const int _meterTypeId = 47;

  /// Obtiene datos del medidor para la estación especificada
  Future<MeterData?> getMeterData({
    required String stationCode,
    bool forceRefresh = false,
  }) async {
    try {
      _log.i('🔧 METER: Getting meter data for $stationCode (force: $forceRefresh)');

      final user = _supabase.auth.currentUser;
      if (user == null) {
        _log.w('🔧 METER: ❌ No authenticated user found');
        return null;
      }

      final String normalizedCode = stationCode.startsWith('NE=') 
          ? stationCode 
          : stationCode.replaceAll(RegExp(r'[^0-9]'), '');

      // 1. Primero verificar caché en Supabase
      final cachedData = await _getCachedMeterData(stationCode, allowOlder: false);
      if (cachedData != null && !forceRefresh) {
        _log.i('🔧 METER: ✅ Using fresh cached data');
        return cachedData;
      }

      // 2. Si no hay caché válido, hacer fetch de la API
      _log.i('🔧 METER: No valid cache, fetching from API');
      
      // Obtener device DN del medidor
      final deviceDn = await _getMeterDeviceDn(stationCode);
      if (deviceDn == null) {
        _log.w('🔧 METER: ❌ No meter device DN found');
        return null;
      }

      // 3. Hacer fetch de datos del medidor desde la API
      final meterData = await _fetchMeterData(deviceDn);
      if (meterData != null) {
        // 4. Guardar en caché y devolver
        await _saveMeterDataToCache(stationCode, deviceDn, meterData);
        _log.i('🔧 METER: ✅ Successfully fetched and cached meter data');
        return meterData;
      }

      // 5. Si falla la API, devolver null para mostrar error
      _log.w('🔧 METER: API failed, returning null to show error');
      return null;
    } catch (e, stackTrace) {
      _log.e('🔧 METER: ❌ Exception in getMeterData', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Obtiene el device DN del medidor
  Future<String?> _getMeterDeviceDn(String stationCode) async {
    final String normalizedCode = stationCode.startsWith('NE=') 
        ? stationCode 
        : stationCode.replaceAll(RegExp(r'[^0-9]'), '');
    
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      // Buscar en caché primero
      final cached = await _supabase
          .from('device_cache')
          .select('dev_dn, updated_at')
          .eq('user_id', user.id)
          .eq('station_code', normalizedCode)
          .eq('device_type', 'meter')
          .maybeSingle();

      if (cached != null) {
        final updatedAt = DateTime.parse(cached['updated_at']);
        if (DateTime.now().difference(updatedAt).inDays < 7) {
          return cached['dev_dn'];
        }
      }

      // Hacer fetch de la lista de dispositivos
      final json = await _oauthService.handleApiCall(
        _deviceListEndpoint,
        method: 'POST',
        body: {'stationCodes': normalizedCode},
      );

      if (json != null && json['success'] == true && json['data'] is List) {
        final devices = json['data'] as List;

        for (final device in devices) {
          if (device['devTypeId'] == _meterTypeId && device['devDn'] != null) {
            final deviceDn = device['devDn'] as String;

            // Guardar en caché
            await _supabase.from('device_cache').upsert(
              {
                'user_id': user.id,
                'station_code': normalizedCode,
                'dev_dn': deviceDn,
                'device_type': 'meter',
                'updated_at': DateTime.now().toIso8601String(),
              },
              onConflict: 'user_id,station_code,device_type'
            );

            return deviceDn;
          }
        }
      }

      return null;
    } catch (e) {
      _log.e('🔧 METER: ❌ Exception getting meter device DN', error: e);
      return null;
    }
  }

  /// Hace fetch de datos del medidor
  Future<MeterData?> _fetchMeterData(String deviceDn) async {
    try {
      _log.i('🔧 METER: Making API call for device: $deviceDn');
      final json = await _oauthService.handleApiCall(
        _deviceRealKpiEndpoint,
        method: 'POST',
        body: {'devTypeId': _meterTypeId, 'devIds': deviceDn},
      );

      _log.i('🔧 METER: API response: ${json != null}');
      if (json != null) {
        _log.d('🔧 METER: Response data: $json');
        return MeterData.fromApiResponse(json);
      }

      _log.w('🔧 METER: API returned null response');
      return null;
    } catch (e) {
      _log.e('🔧 METER: ❌ Exception fetching meter data', error: e);
      return null;
    }
  }

  /// Obtiene datos del medidor desde caché
  Future<MeterData?> _getCachedMeterData(String stationCode, {bool allowOlder = false}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;
      
      final String normalizedCode = stationCode.startsWith('NE=') 
          ? stationCode 
          : stationCode.replaceAll(RegExp(r'[^0-9]'), '');

      final result = await _supabase
          .from('real_time_data')
          .select()
          .eq('user_id', user.id)
          .eq('station_code', normalizedCode)
          .eq('device_type', 'meter')
          .maybeSingle();

      if (result == null) return null;

      if (!allowOlder && result['next_fetch_allowed'] != null) {
        final nextAllowed = DateTime.parse(result['next_fetch_allowed']);
        if (DateTime.now().isBefore(nextAllowed)) {
          return MeterData.fromJson(result);
        }
        return null;
      }
      
      return MeterData.fromJson(result);
    } catch (e) {
      _log.e('🔧 METER: ❌ Error getting cached data', error: e);
      return null;
    }
  }

  /// Guarda datos del medidor en caché
  Future<void> _saveMeterDataToCache(String stationCode, String deviceDn, MeterData data) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      
      final String normalizedCode = stationCode.startsWith('NE=') 
          ? stationCode 
          : stationCode.replaceAll(RegExp(r'[^0-9]'), '');

      final now = DateTime.now();
      final nextFetch = now.add(const Duration(minutes: 10));

      await _supabase.from('real_time_data').upsert(
        {
          'user_id': user.id,
          'station_code': normalizedCode,
          'dev_dn': deviceDn,
          'device_type': 'meter',
          'active_power': data.activePower,
          'meter_voltage': data.meterVoltage,
          'meter_current': data.meterCurrent,
          'grid_frequency': data.gridFrequency,
          'meter_status': data.meterStatus,
          'created_at': now.toIso8601String(),
          'fetched_at': now.toIso8601String(),
          'next_fetch_allowed': nextFetch.toIso8601String(),
        },
        onConflict: 'user_id,station_code,device_type'
      );
    } catch (e) {
      _log.e('Error saving meter data to cache', error: e);
    }
  }
}