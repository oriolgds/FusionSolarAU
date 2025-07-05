import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class FusionSolarOAuthService {
  static const String _authBaseUrl = 'https://oauth2.fusionsolar.huawei.com';

  final SupabaseClient _supabase = Supabase.instance.client;

  
  /// Refresca el token de acceso usando el refresh token
  Future<Map<String, dynamic>?> refreshAccessToken() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final userData = await _supabase
          .from('users')
          .select(
            'fusion_solar_refresh_token, fusion_solar_client_id, fusion_solar_client_secret',
          )
          .eq('id', user.id)
          .maybeSingle();

      if (userData == null || userData['fusion_solar_refresh_token'] == null) {
        return null;
      }

      final response = await http.post(
        Uri.parse('$_authBaseUrl/rest/dp/uidm/oauth2/v1/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': userData['fusion_solar_refresh_token'],
          'client_id': userData['fusion_solar_client_id'],
          'client_secret': userData['fusion_solar_client_secret'],
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        await _updateTokensInDatabase(data);
        return data;
      } else {
        throw Exception('Error al refrescar token: ${response.body}');
      }
    } catch (e) {
      print('Error refrescando token: $e');
      return null;
    }
  }

  /// Obtiene un token de acceso válido (refresca si es necesario)
  Future<String?> getValidAccessToken() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final userData = await _supabase
          .from('users')
          .select('fusion_solar_access_token, fusion_solar_token_expires_at')
          .eq('id', user.id)
          .maybeSingle();

      if (userData == null || userData['fusion_solar_access_token'] == null) {
        return null;
      }

      // Verificar si el token ha expirado
      final expiresAt = DateTime.parse(
        userData['fusion_solar_token_expires_at'],
      );
      final now = DateTime.now();

      if (now.isAfter(expiresAt.subtract(const Duration(minutes: 5)))) {
        // Token expira en 5 minutos o menos, refrescar
        final refreshResult = await refreshAccessToken();
        return refreshResult?['access_token'];
      }

      return userData['fusion_solar_access_token'];
    } catch (e) {
      print('Error obteniendo token válido: $e');
      return null;
    }
  }

  /// Login API de FusionSolar (Account Access)
  Future<String?> loginWithAccount(String username, String password) async {
    final url = Uri.parse('https://eu5.fusionsolar.huawei.com/thirdData/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userName': username,
        'systemCode': password,
      }),
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true) {
        // Buscar el XSRF-TOKEN en las cookies
        String? xsrfToken;
        final setCookie = response.headers['set-cookie'];
        if (setCookie != null) {
          final cookies = setCookie.split(';');
          for (final cookie in cookies) {
            if (cookie.trim().startsWith('XSRF-TOKEN=')) {
              xsrfToken = cookie.trim().substring('XSRF-TOKEN='.length);
              break;
            }
          }
        }
        if (xsrfToken == null) {
          throw Exception('No se encontró el XSRF-TOKEN en las cookies');
        }
        // Guardar en Supabase
        final user = _supabase.auth.currentUser;
        if (user != null) {
          await _supabase.from('users').update({
            'fusion_solar_api_username': username,
            'fusion_solar_api_password': password,
            'fusion_solar_xsrf_token': xsrfToken,
            'fusion_solar_xsrf_token_expires_at': DateTime.now().add(const Duration(minutes: 30)).toIso8601String(),
          }).eq('id', user.id);
        }
        return xsrfToken;
      } else {
        throw Exception(body['message'] ?? 'Login fallido');
      }
    } else {
      throw Exception('Error HTTP ${response.statusCode}');
    }
  }

  /// Logout API de FusionSolar
  Future<void> logoutFusionSolar(String xsrfToken) async {
    final url = Uri.parse('https://eu5.fusionsolar.huawei.com/thirdData/logout');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'xsrfToken': xsrfToken}),
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true) {
        // Limpiar datos en Supabase
        final user = _supabase.auth.currentUser;
        if (user != null) {
          await _supabase.from('users').update({
            'fusion_solar_xsrf_token': null,
            'fusion_solar_xsrf_token_expires_at': null,
                'fusion_solar_api_username': null,
                'fusion_solar_api_password': null,
          }).eq('id', user.id);
        }
      } else {
        throw Exception(body['message'] ?? 'Logout fallido');
      }
    } else {
      throw Exception('Error HTTP ${response.statusCode}');
    }
  }

  /// Verifica si el usuario tiene configuración válida (token no expirado)
  Future<bool> hasValidOAuthConfig() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;
    final data = await _supabase.from('users').select().eq('id', user.id).single();
    final token = data['fusion_solar_xsrf_token'];
    final expiresAt = data['fusion_solar_xsrf_token_expires_at'];
    if (token == null || expiresAt == null) return false;
    final expiry = DateTime.tryParse(expiresAt);
    if (expiry == null) return false;
    return DateTime.now().isBefore(expiry);
  }

  /// Verifica si el usuario tiene alguna configuración de OAuth, aunque sea inválida
  Future<bool> hasAnyOAuthConfig() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;
      
      final data = await _supabase
          .from('users')
          .select('fusion_solar_xsrf_token, fusion_solar_api_username')
          .eq('id', user.id)
          .single();
          
      // Verificar si hay algún dato de configuración presente
      return data['fusion_solar_xsrf_token'] != null || 
             data['fusion_solar_api_username'] != null;
    } catch (e) {
      // Si hay algún error al consultar, asumimos que no hay configuración
      return false;
    }
  }

  /// Hace una petición autenticada a la API de FusionSolar
  Future<http.Response> authenticatedRequest(
    String endpoint, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('No autenticado');
    final data = await _supabase.from('users').select().eq('id', user.id).single();
    final xsrfToken = data['fusion_solar_xsrf_token'];
    if (xsrfToken == null) throw Exception('No hay sesión activa de FusionSolar');
    final url = Uri.parse('https://eu5.fusionsolar.huawei.com$endpoint');
    final headers = {
      'Content-Type': 'application/json',
      'Cookie': 'XSRF-TOKEN=$xsrfToken',
    };
    switch (method.toUpperCase()) {
      case 'POST':
        return await http.post(url, headers: headers, body: body != null ? jsonEncode(body) : null);
      case 'PUT':
        return await http.put(url, headers: headers, body: body != null ? jsonEncode(body) : null);
      case 'DELETE':
        return await http.delete(url, headers: headers);
      default:
        return await http.get(url, headers: headers);
    }
  }

  /// Devuelve el XSRF-TOKEN actual del usuario autenticado en Supabase
  Future<String?> getCurrentXsrfToken() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    final data = await _supabase.from('users').select().eq('id', user.id).single();
    return data['fusion_solar_xsrf_token'] as String?;
  }

  /// Actualiza los tokens en la base de datos
  Future<void> _updateTokensInDatabase(Map<String, dynamic> tokenData) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final expiresIn = tokenData['expires_in'] as int? ?? 3600;
      final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

      await _supabase
          .from('users')
          .update({
            'fusion_solar_access_token': tokenData['access_token'],
            'fusion_solar_refresh_token': tokenData['refresh_token'],
            'fusion_solar_token_expires_at': expiresAt.toIso8601String(),
          })
          .eq('id', user.id);
    } catch (e) {
      throw Exception('Error actualizando tokens: $e');
    }
  }
}
