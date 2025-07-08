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
        
        // Guardar en Supabase con manejo de errores de duplicado
        final user = _supabase.auth.currentUser;
        if (user != null) {
          try {
            await _supabase
                .from('users')
                .update({
                  'fusion_solar_api_username': username,
                  'fusion_solar_api_password': password,
                  'fusion_solar_xsrf_token': xsrfToken,
                  'fusion_solar_xsrf_token_expires_at': DateTime.now()
                      .add(const Duration(minutes: 30))
                      .toIso8601String(),
                })
                .eq('id', user.id);
          } catch (e) {
            // Verificar si es un error de duplicado de username
            if (e.toString().contains('users_fusion_solar_username_unique') ||
                e.toString().contains('duplicate key value') ||
                e.toString().contains('already exists')) {
              throw Exception(
                'Este nombre de usuario de FusionSolar ya está siendo utilizado por otra cuenta. Por favor, contacta con tu instalador para obtener credenciales únicas.',
              );
            }
            rethrow;
          }
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
    try {
      final url = Uri.parse(
        'https://eu5.fusionsolar.huawei.com/thirdData/logout',
      );
      
      print(
        'Attempting logout with XSRF token: ${xsrfToken.substring(0, 10)}...',
      );
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'XSRF-TOKEN=$xsrfToken',
          'XSRF-TOKEN': xsrfToken,
        },
        body: jsonEncode({'xsrfToken': xsrfToken}),
      );
      
      print('Logout response status: ${response.statusCode}');
      print('Logout response body: ${response.body}');
      
      if (response.statusCode == 200) {
        Map<String, dynamic>? body;
        try {
          body = jsonDecode(response.body) as Map<String, dynamic>;
        } catch (e) {
          print('Error parsing logout response JSON: $e');
          // Si no se puede parsear la respuesta pero el status es 200,
          // asumir que el logout fue exitoso
          body = {'success': true};
        }

        // Verificar si el logout fue exitoso
        final isSuccess = body['success'] == true;
        print('Logout success status: $isSuccess');

        if (isSuccess) {
          // Limpiar datos en Supabase independientemente del resultado de la API
          await _clearFusionSolarSession();
        } else {
          // Incluso si la API dice que falló, limpiar la sesión local
          // porque el token puede estar ya expirado
          print(
            'API logout failed but clearing local session anyway. Message: ${body['message']}',
          );
          await _clearFusionSolarSession();

          // Solo lanzar excepción si hay un mensaje específico que indique un error real
          final message = body['message']?.toString() ?? 'Logout fallido';
          if (!message.toLowerCase().contains('token') &&
              !message.toLowerCase().contains('expired') &&
              !message.toLowerCase().contains('invalid')) {
            throw Exception(message);
          }
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Token ya expirado o inválido, limpiar sesión local
        print(
          'Token already expired/invalid (${response.statusCode}), clearing local session',
        );
        await _clearFusionSolarSession();
      } else {
        print('Unexpected HTTP status: ${response.statusCode}');
        // Para otros errores HTTP, aún intentar limpiar la sesión local
        await _clearFusionSolarSession();
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Error in logoutFusionSolar: $e');

      // Si es un error de red o conexión, aún limpiar la sesión local
      if (e.toString().contains('SocketException') ||
          e.toString().contains('HandshakeException') ||
          e.toString().contains('TimeoutException')) {
        print('Network error during logout, clearing local session anyway');
        await _clearFusionSolarSession();
        return; // No relanzar el error para errores de red
      }

      rethrow;
    }
  }

  /// Limpia la sesión de FusionSolar en Supabase
  Future<void> _clearFusionSolarSession() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase
            .from('users')
            .update({
              // Limpiar tokens XSRF
              'fusion_solar_xsrf_token': null,
              'fusion_solar_xsrf_token_expires_at': null,
              // Limpiar credenciales de la API para evitar re-login automático
              'fusion_solar_api_username': null,
              'fusion_solar_api_password': null,
            })
            .eq('id', user.id);
        print(
          'Successfully cleared all FusionSolar session data from Supabase',
        );
      }
    } catch (e) {
      print('Error clearing FusionSolar session data: $e');
      // No relanzar este error, ya que es solo limpieza local
    }
  }

  /// Verifica si el usuario tiene configuración válida (token no expirado)
  Future<bool> hasValidOAuthConfig() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;
    final data = await _supabase.from('users').select().eq('id', user.id).single();
    final token = data['fusion_solar_xsrf_token'];
    final expiresAt = data['fusion_solar_xsrf_token_expires_at'];
    if (token == null || expiresAt == null) {
      // No hay token, intentar login transparente
      final reloginOk = await _reloginUsingSavedCredentials();
      return reloginOk;
    }
    final expiry = DateTime.tryParse(expiresAt);
    if (expiry == null) return false;

    if (DateTime.now().isBefore(expiry)) {
      return true; // aún válido
    }

    // Token expirado: intentar re-login transparente
    final reloginOk = await _reloginUsingSavedCredentials();
    return reloginOk;
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
    final xsrfToken = data['fusion_solar_xsrf_token'] as String?;
    if (xsrfToken == null) throw Exception('No hay sesión activa de FusionSolar');
    final url = Uri.parse('https://eu5.fusionsolar.huawei.com$endpoint');
    final headers = {
      'Content-Type': 'application/json',
      'Cookie': 'XSRF-TOKEN=$xsrfToken',
      'XSRF-TOKEN': xsrfToken,
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

  /// Método de ayuda para realizar llamadas a la API y decodificar la respuesta JSON.
  /// Si se recibe un `failCode` 305 (USER_MUST_RELOGIN) intenta hacer login de nuevo
  /// usando las credenciales almacenadas en Supabase, actualiza el token y reintenta
  /// una sola vez la misma petición.
  Future<Map<String, dynamic>?> handleApiCall(
    String endpoint, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    int attempt = 0;
    while (attempt < 2) {
      try {
        final response = await authenticatedRequest(
          endpoint,
          method: method,
          body: body,
        );

        // Si la respuesta no es 200, probablemente el token es inválido o expiró
        if (response.statusCode != 200) {
          if (attempt == 0) {
            final reloginOk = await _reloginUsingSavedCredentials();
            if (!reloginOk) {
              print('HTTP ${response.statusCode} y relogin fallido');
              return null;
            }
            attempt++;
            continue; // repetir llamada
          }
          print('Error HTTP \\${response.statusCode}: \\${response.body}');
          return null;
        }

        Map<String, dynamic>? data;
        try {
          data = json.decode(response.body) as Map<String, dynamic>;
        } catch (_) {
          // Si no se pudo parsear como JSON, intentar relogin una vez
          if (attempt == 0) {
            final reloginOk = await _reloginUsingSavedCredentials();
            if (!reloginOk) return null;
            attempt++;
            continue;
          }
          return null;
        }

        // Revisar si el token expiró (failCode 305)
        if (data['success'] == false && data['failCode'] == 305) {
          if (attempt == 0) {
            final reloginOk = await _reloginUsingSavedCredentials();
            if (!reloginOk) return data;
            attempt++;
            continue;
          }
        }

        return data;
      } catch (e) {
        print('Error en handleApiCall: \\${e}');
        return null;
      }
    }
    return null; // No debería llegar aquí
  }

  /// Intenta hacer login nuevamente usando las credenciales guardadas en Supabase.
  /// Devuelve `true` si el login y la actualización del token tuvieron éxito.
  Future<bool> _reloginUsingSavedCredentials() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final userData = await _supabase
          .from('users')
          .select('fusion_solar_api_username, fusion_solar_api_password')
          .eq('id', user.id)
          .maybeSingle();

      if (userData == null || userData['fusion_solar_api_username'] == null || userData['fusion_solar_api_password'] == null) {
        return false;
      }

      final username = userData['fusion_solar_api_username'] as String;
      final password = userData['fusion_solar_api_password'] as String;

      final newToken = await loginWithAccount(username, password);

      if (newToken != null) {
        // Refrescar in-memory token por si otras partes lo leen inmediatamente
        await _supabase.from('users').update({
          'fusion_solar_xsrf_token': newToken,
          'fusion_solar_xsrf_token_expires_at': DateTime.now().add(const Duration(minutes: 30)).toIso8601String(),
        }).eq('id', user.id);
        return true;
      }
      return false;
    } catch (e) {
      print('Error en _reloginUsingSavedCredentials: \\${e}');
      return false;
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
