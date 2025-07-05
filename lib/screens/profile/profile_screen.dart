import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/solar_data_provider.dart';
import '../../providers/device_provider.dart';
import '../../providers/automation_provider.dart';
import 'fusion_solar_config_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final user = authProvider.currentUser;
          if (user == null) {
            return const Center(child: Text('Usuario no autenticado'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Información del usuario
                _buildUserInfo(context, user),

                const SizedBox(height: 24),

                // Estadísticas de la aplicación
                _buildAppStats(context),

                const SizedBox(height: 24),

                // Configuración
                _buildSettings(context),

                const SizedBox(height: 24),

                // Información de la aplicación
                _buildAppInfo(context),

                const SizedBox(height: 24),

                // Botón de cerrar sesión
                _buildSignOutButton(context, authProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserInfo(BuildContext context, user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(context).colorScheme.primary,
              backgroundImage:
                  user.userMetadata != null &&
                      user.userMetadata['avatar_url'] != null
                  ? NetworkImage(user.userMetadata['avatar_url'])
                  : null,
              child:
                  user.userMetadata == null ||
                      user.userMetadata['avatar_url'] == null
                  ? Text(
                      user.userMetadata != null &&
                              user.userMetadata['full_name'] != null &&
                              user.userMetadata['full_name'].isNotEmpty
                          ? user.userMetadata['full_name'][0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              user.userMetadata != null &&
                      user.userMetadata['full_name'] != null
                  ? user.userMetadata['full_name']
                  : 'Sin nombre',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              user.email ?? '',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            // Puedes agregar más campos si los tienes en user.userMetadata
          ],
        ),
      ),
    );
  }

  Widget _buildAppStats(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estadísticas de la App',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Consumer3<SolarDataProvider, DeviceProvider, AutomationProvider>(
              builder: (context, solarProvider, deviceProvider, automationProvider, _) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Dispositivos',
                            '${deviceProvider.devices.length}',
                            Icons.devices,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Reglas Activas',
                            '${automationProvider.enabledRules.length}',
                            Icons.auto_awesome,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Producción Total',
                            '${solarProvider.currentData?.totalProduction.toStringAsFixed(0) ?? "0"} kWh',
                            Icons.solar_power,
                            Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Ahorro Estimado',
                            '\$${solarProvider.todaysSavings.toStringAsFixed(0)}',
                            Icons.savings,
                            Colors.purple,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSettings(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.solar_power),
            title: const Text('Configuración FusionSolar'),
            subtitle: const Text('Conectar con tu sistema solar'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const FusionSolarConfigScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Configuración'),
            subtitle: const Text('Ajustes de la aplicación'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Configuración disponible en próxima actualización',
                  ),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notificaciones'),
            subtitle: const Text('Gestionar alertas y notificaciones'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Configuración de notificaciones disponible pronto',
                  ),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Privacidad y Seguridad'),
            subtitle: const Text('Configuración de datos y permisos'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Configuración de privacidad disponible pronto',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAppInfo(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Acerca de FusionSolarAU'),
            subtitle: const Text('Versión 1.0.0'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'FusionSolarAU',
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(
                  Icons.solar_power,
                  size: 48,
                  color: Colors.green,
                ),
                children: const [
                  Text(
                    'Automatización Inteligente con Google Home y Fusion Solar.\n\n'
                    'Optimiza el uso de tu energía solar conectando tus dispositivos '
                    'inteligentes con tu instalación fotovoltaica.',
                  ),
                ],
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Ayuda y Soporte'),
            subtitle: const Text('Centro de ayuda y contacto'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Centro de ayuda disponible pronto'),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.feedback),
            title: const Text('Enviar Comentarios'),
            subtitle: const Text('Comparte tu experiencia'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sistema de comentarios disponible pronto'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSignOutButton(BuildContext context, AuthProvider authProvider) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Cerrar Sesión'),
              content: const Text(
                '¿Estás seguro de que quieres cerrar sesión?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Cerrar Sesión'),
                ),
              ],
            ),
          );

          if (confirmed == true) {
            await authProvider.signOut();
          }
        },
        icon: const Icon(Icons.logout),
        label: const Text('Cerrar Sesión'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
