import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/plant.dart';
import '../services/fusion_solar_oauth_service.dart';
import 'dart:convert';
import 'package:logger/logger.dart';

/// Provider encargado de gestionar las plantas (estaciones) del usuario.
///
/// Dado el límite de 24 llamadas diarias al endpoint `getStationList`, este
/// provider intenta primero cargar los datos desde Supabase. Si no hubiera
/// registros, realiza la petición a la API, persiste el resultado y notifica a
/// los escuchadores.
class PlantProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final FusionSolarOAuthService _oauthService = FusionSolarOAuthService();


  final Logger _log = Logger();

  List<Plant> _plants = [];
  bool _isLoading = false;
  Plant? _selectedPlant;

  List<Plant> get plants => _plants;
  bool get isLoading => _isLoading;
  Plant? get selectedPlant => _selectedPlant;
  String? get selectedStationCode => _selectedPlant?.stationCode;

  PlantProvider() {
    _loadPlants();
  }

  Future<void> _loadPlants() async {
    _setLoading(true);
    try {
      // 1. Intentar obtener de Supabase
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _log.w('No authenticated user, skipping plant load');
        return;
      }
      final data = await _supabase.from('plants').select().eq('user_id', user.id);
      if (data.isNotEmpty) {
        _plants = data.map((p) => Plant.fromJson(p)).toList();
        _log.i('Loaded ${_plants.length} plants from Supabase');
      }

      // 2. Verificar meta para decidir si llamar a la API
      bool shouldFetch = _plants.isEmpty;
      if (!shouldFetch) {
        final meta = await _supabase
            .from('plant_fetch_meta')
            .select('last_fetch_at')
            .eq('user_id', user.id)
            .maybeSingle();
        if (meta == null || meta['last_fetch_at'] == null) {
          shouldFetch = true;
        } else {
          final last = DateTime.tryParse(meta['last_fetch_at'] as String);
          if (last == null || DateTime.now().difference(last) > const Duration(hours: 1)) {
            shouldFetch = true;
          }
        }
      }

      if (shouldFetch) {
        await _fetchFromApiAndSave();
      }

      // Seleccionar la primera por defecto si no hay selección previa
      if (_plants.isNotEmpty && _selectedPlant == null) {
        _selectedPlant = _plants.first;
      }
    } catch (e) {
      debugPrint('Error cargando plantas: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _fetchFromApiAndSave() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _log.w('No authenticated user, cannot fetch plants');
        return;
      }
      final xsrfToken = await _oauthService.getCurrentXsrfToken();
      if (xsrfToken == null) return;

      final response = await _oauthService.authenticatedRequest(
        '/thirdData/getStationList',
        method: 'POST',
        body: const {},
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body) as Map<String, dynamic>;
        if (json['success'] == true && json['data'] is List) {
          final List<dynamic> stations = json['data'];
          _plants = stations.map((e) => Plant.fromJson(e as Map<String, dynamic>)).toList();
          // Guardamos en Supabase (upsert)
          for (final plant in _plants) {
            await _supabase.from('plants').upsert({
              ...plant.toJson(),
              'user_id': user.id,
              'fetched_at': DateTime.now().toIso8601String(),
            });
          }
          // Grabar última descarga
          await _supabase.from('plant_fetch_meta').upsert({
            'user_id': user.id,
            'last_fetch_at': DateTime.now().toIso8601String(),
          });
          _log.i('Fetched ${_plants.length} plants from API and saved to Supabase');
        }
      } else {
        _log.e('Error al solicitar lista de plantas: ${response.statusCode}');
      }
    } catch (e) {
      _log.e('Error fetchFromApiAndSave', error: e);
    }
  }

  void setSelectedStationCode(String code) {
    // Si la lista está vacía no podemos seleccionar ninguna estación
    if (_plants.isEmpty) return;

    // Busca la estación por su código; si no existe, selecciona la primera
    final match = _plants.firstWhere(
      (p) => p.stationCode == code,
      orElse: () => _plants.first,
    );

    _selectedPlant = match;
    notifyListeners();
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }
}
