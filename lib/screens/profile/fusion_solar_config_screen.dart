import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/fusion_solar_oauth_service.dart';
import '../../providers/fusion_solar_config_provider.dart';

class FusionSolarConfigScreen extends StatefulWidget {
  final VoidCallback? onConfigUpdated;
  final Widget? child;
  
  const FusionSolarConfigScreen({
    super.key,
    this.onConfigUpdated,
    this.child,
  });

  @override
  State<FusionSolarConfigScreen> createState() =>
      _FusionSolarConfigScreenState();
}

class _FusionSolarConfigScreenState extends State<FusionSolarConfigScreen> {
  final FusionSolarOAuthService _oauthService = FusionSolarOAuthService();
  final _clientIdController = TextEditingController();
  final _clientSecretController = TextEditingController();

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
      final hasConfig = await _oauthService.hasValidOAuthConfig();
      setState(() {
        _hasValidConfig = hasConfig;
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
    // If we have a child, use it (for the not configured screen)
    if (widget.child != null) {
      return widget.child!;
    }
    
    // Otherwise show the full configuration screen
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
                        : 'Es necesario configurar OAuth para obtener datos reales',
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
              '1. Solicita tu usuario y contraseña de Northbound a la empresa que te instalo las placas solares.\n\n'
              '2. Introduce tus credenciales abajo y autoriza la aplicación.',
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
              controller: _clientIdController,
              decoration: const InputDecoration(
                labelText: 'Usuario API',
                border: OutlineInputBorder(),
                helperText: 'Nombre de usuario de la cuenta API de FusionSolar',
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _clientSecretController,
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
                onPressed: _isLoading ? null : _loginWithFusionSolar,
                icon: const Icon(Icons.login),
                label: const Text('Iniciar sesión en FusionSolar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loginWithFusionSolar() async {
    final username = _clientIdController.text.trim();
    final password = _clientSecretController.text.trim();
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor introduce usuario y contraseña')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final xsrfToken = await _oauthService.loginWithAccount(username, password);
      setState(() => _isLoading = false);
      if (xsrfToken != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Inicio de sesión correcto!'), backgroundColor: Colors.green),
        );
        await _checkCurrentConfig();
        
        // Notificar al provider de configuración
        if (mounted) {
          context.read<FusionSolarConfigProvider>().onConfigurationUpdated(
            true,
          );
        }
        
        // Notify parent that configuration was updated
        if (widget.onConfigUpdated != null) {
          widget.onConfigUpdated!();
        }
        // Notificar que se ha configurado correctamente
        Navigator.of(context).pop(true);
      } else {
        throw Exception('No se pudo obtener el token de sesión');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al iniciar sesión: $e')),
        );
      }
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
              'Sesión activa FusionSolar',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            const ListTile(
              leading: Icon(Icons.check_circle, color: Colors.green),
              title: Text('Sesión activa'),
              subtitle: Text('La app puede acceder a los datos de FusionSolar'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _logoutFusionSolar,
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar sesión FusionSolar'),
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

  Future<void> _logoutFusionSolar() async {
    setState(() => _isLoading = true);
    try {
      final xsrfToken = await _oauthService.getCurrentXsrfToken();
      if (xsrfToken == null) throw Exception('No hay sesión activa');
      await _oauthService.logoutFusionSolar(xsrfToken);
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesión FusionSolar cerrada'), backgroundColor: Colors.green),
        );
        await _checkCurrentConfig();
        
        // Notificar al provider de configuración
        context.read<FusionSolarConfigProvider>().onConfigurationUpdated(false);
        
        // Notify parent that configuration was updated
        if (widget.onConfigUpdated != null) {
          widget.onConfigUpdated!();
        }
        // Regresar a la pantalla anterior
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cerrando sesión: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _clientIdController.dispose();
    _clientSecretController.dispose();
    super.dispose();
  }
}
