import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FusionSolarConfigScreen extends StatefulWidget {
  final VoidCallback? onConfigUpdated;
  
  const FusionSolarConfigScreen({
    super.key,
    this.onConfigUpdated,
  });

  @override
  State<FusionSolarConfigScreen> createState() =>
      _FusionSolarConfigScreenState();
}

class _FusionSolarConfigScreenState extends State<FusionSolarConfigScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _hasValidConfig = false;

  @override
  void initState() {
    super.initState();
    _checkCurrentConfig();
  }

  Future<void> _checkCurrentConfig() async {
    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _hasValidConfig = false;
          _isLoading = false;
        });
        return;
      }

      final result = await _supabase
          .from('users')
          .select('fusion_solar_api_username')
          .eq('id', user.id)
          .maybeSingle();

      setState(() {
        _hasValidConfig = result?['fusion_solar_api_username'] != null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error verificando configuración: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración FusionSolar')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusCard(),
                  const SizedBox(height: 16),
                  if (!_hasValidConfig) _buildInstructionsCard(),
                  const SizedBox(height: 16),
                  if (!_hasValidConfig) _buildConfigForm(),
                  if (_hasValidConfig) _buildActiveConfigCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              _hasValidConfig ? Icons.check_circle : Icons.warning,
              color: _hasValidConfig ? Colors.green : Colors.orange,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _hasValidConfig ? 'Configuración Activa' : 'Sin Configurar',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    _hasValidConfig
                        ? 'FusionSolar está conectado y funcionando'
                        : 'Es necesario configurar credenciales para obtener datos reales',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Instrucciones de Configuración',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              '1. Solicita tu usuario y contraseña de Northbound a la empresa que te instaló las placas solares.\n\n'
              '2. Introduce tus credenciales abajo.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Credenciales de FusionSolar',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Usuario API',
                border: OutlineInputBorder(),
                helperText: 'Nombre de usuario de la cuenta API de FusionSolar',
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Contraseña API',
                border: OutlineInputBorder(),
                helperText: 'Contraseña de la cuenta API de FusionSolar',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveCredentials,
                icon: const Icon(Icons.save),
                label: const Text('Guardar Credenciales'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveCredentials() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor introduce usuario y contraseña')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      // Validate credentials with FusionSolar API
      final response = await _validateCredentials(username, password);

      if (!response['success']) {
        throw Exception('Credenciales inválidas: ${response['message']}');
      }

      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      await _supabase.from('users').upsert({
        'id': user.id,
        'fusion_solar_api_username': username,
        'fusion_solar_api_password': password,
      });

      setState(() {
        _hasValidConfig = true;
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Credenciales guardadas!'),
            backgroundColor: Colors.green,
          ),
        );
        
        if (widget.onConfigUpdated != null) {
          widget.onConfigUpdated!();
        }
        
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
  
  Future<Map<String, dynamic>> _validateCredentials(
    String username,
    String password,
  ) async {
    try {
      final response = await _supabase.functions.invoke(
        'validate-credentials',
        body: {'userName': username, 'systemCode': password},
      );

      return response.data as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  Widget _buildActiveConfigCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configuración Activa',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            const ListTile(
              leading: Icon(Icons.check_circle, color: Colors.green),
              title: Text('Credenciales guardadas'),
              subtitle: Text(
                'El servidor puede acceder a los datos de FusionSolar',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _clearCredentials,
                    icon: const Icon(Icons.delete),
                    label: const Text('Eliminar Credenciales'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _clearCredentials() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      await _supabase
          .from('users')
          .update({
            'fusion_solar_api_username': null,
            'fusion_solar_api_password': null,
          })
          .eq('id', user.id);
      
      setState(() => _isLoading = false);
      if (mounted) {
        _usernameController.clear();
        _passwordController.clear();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Credenciales eliminadas'),
            backgroundColor: Colors.green,
          ),
        );
        await _checkCurrentConfig();
        if (widget.onConfigUpdated != null) {
          widget.onConfigUpdated!();
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
