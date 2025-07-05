import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/solar_data_provider.dart';
import '../../providers/device_provider.dart';
import '../../providers/automation_provider.dart';
import '../../models/solar_data.dart';
import '../../services/fusion_solar_oauth_service.dart';
import '../../providers/plant_provider.dart';
import 'fusion_solar_not_configured_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FusionSolarOAuthService _oauthService = FusionSolarOAuthService();
  bool _isCheckingConfig = true;
  bool _hasValidConfig = false;

  @override
  void initState() {
    super.initState();
    _checkFusionSolarConfig();
  }

  Future<void> _checkFusionSolarConfig() async {
    setState(() => _isCheckingConfig = true);
    
    try {
      final hasConfig = await _oauthService.hasValidOAuthConfig();
      
      if (mounted) {
        setState(() {
          _hasValidConfig = hasConfig;
          _isCheckingConfig = false;
        });
        
        // Solo cargar datos si la configuración es válida
        if (hasConfig) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<SolarDataProvider>().refreshData();
            context.read<DeviceProvider>().refreshDevices();
          });
        }
      }
    } catch (e) {
      // Solo mostrar error si hay un problema real, no cuando la configuración no existe
      final hasConfig = await _oauthService.hasAnyOAuthConfig();
      if (mounted) {
        setState(() => _isCheckingConfig = false);
        if (hasConfig) {
          // Mostrar error solo si hay una configuración pero algo falla al verificarla
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al verificar la configuración de Fusion Solar'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recargar la configuración cuando volvemos a esta pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFusionSolarConfig();
    });
  }

  // This method is called when the user returns to the dashboard from the config screen
  Future<void> _handleConfigUpdated() async {
    // Re-check the configuration
    await _checkFusionSolarConfig();
    
    // If we now have a valid config, refresh the data
    if (_hasValidConfig && mounted) {
      // Add a small delay to ensure the UI has updated
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Refresh data
      await context.read<SolarDataProvider>().refreshData();
      await context.read<DeviceProvider>().refreshDevices();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingConfig) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasValidConfig) {
      return FusionSolarNotConfiguredScreen(
        onConfigured: _handleConfigUpdated,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('FusionSolarAU'),
        actions: [
          Consumer<SolarDataProvider>(
            builder: (context, provider, _) {
              return IconButton(
                icon: provider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed: provider.isLoading ? null : () {
                  provider.refreshData();
                  context.read<DeviceProvider>().refreshDevices();
                },
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<SolarDataProvider>().refreshData();
          await context.read<DeviceProvider>().refreshDevices();
        },
        child: Consumer<SolarDataProvider>(
          builder: (context, solarProvider, _) {
            if (solarProvider.isLoading && solarProvider.currentData == null) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (solarProvider.error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error al cargar datos',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      solarProvider.error!,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => solarProvider.refreshData(),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              );
            }

            final solarData = solarProvider.currentData;
            if (solarData == null) {
              return const Center(
                child: Text('No hay datos disponibles'),
              );
            }

            return _buildDashboard(context, solarData);
          },
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, SolarData solarData) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selector moderno de plantas
          _buildModernPlantSelector(),

          const SizedBox(height: 24),
          
          // Tarjetas principales de energía
          Row(
            children: [
              Expanded(
                child: _buildSolarProductionCard(solarData),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildEnergyConsumptionCard(solarData),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Estado de automatización
          _buildAutomationStatusCard(),
          
          const SizedBox(height: 16),
          
          // Acciones rápidas
          _buildQuickActionsCard(),
          
          const SizedBox(height: 16),
          
          // Estadísticas adicionales
          _buildStatsSection(context, solarData),
        ],
      ),
    );
  }

  Widget _buildModernPlantSelector() {
    return Consumer<PlantProvider>(
      builder: (context, plantProvider, _) {
        if (plantProvider.plants.isEmpty) {
          return const SizedBox.shrink();
        }

        if (plantProvider.plants.length == 1) {
          // Si solo hay una planta, mostrar una tarjeta informativa
          final plant = plantProvider.plants.first;
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.solar_power,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plant.stationName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (plant.capacity != null)
                        Text(
                          'Capacidad: ${plant.capacity!.toStringAsFixed(1)} kW',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      if (plant.stationAddr != null)
                        Text(
                          plant.stationAddr!,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          );
        }

        // Si hay múltiples plantas, mostrar selector horizontal
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'Selecciona tu instalación',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: plantProvider.plants.length,
                itemBuilder: (context, index) {
                  final plant = plantProvider.plants[index];
                  final isSelected =
                      plant.stationCode == plantProvider.selectedStationCode;

                  return GestureDetector(
                    onTap: () async {
                      if (!isSelected) {
                        plantProvider.setSelectedStationCode(plant.stationCode);
                        // Refrescar datos para la nueva planta
                        await context.read<SolarDataProvider>().refreshData();
                        await context.read<DeviceProvider>().refreshDevices();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 280,
                      margin: EdgeInsets.only(
                        right: index < plantProvider.plants.length - 1 ? 16 : 0,
                      ),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Theme.of(context).colorScheme.primary,
                                  Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.8),
                                ],
                              )
                            : null,
                        color: isSelected
                            ? null
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? Colors.transparent
                              : Theme.of(
                                  context,
                                ).colorScheme.outline.withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.3)
                                : Colors.black.withOpacity(0.05),
                            blurRadius: isSelected ? 12 : 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white.withOpacity(0.2)
                                      : Theme.of(
                                          context,
                                        ).colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.solar_power,
                                  color: isSelected
                                      ? Colors.white
                                      : Theme.of(context).colorScheme.primary,
                                  size: 20,
                                ),
                              ),
                              const Spacer(),
                              if (isSelected)
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            plant.stationName,
                            style: TextStyle(
                              color: isSelected ? Colors.white : null,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          if (plant.capacity != null)
                            Text(
                              '${plant.capacity!.toStringAsFixed(1)} kW',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white.withOpacity(0.9)
                                    : Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.color,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          const Spacer(),
                          if (plant.stationAddr != null)
                            Text(
                              plant.stationAddr!,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white.withOpacity(0.8)
                                    : Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.color
                                          ?.withOpacity(0.7),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatsSection(BuildContext context, SolarData solarData) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estadísticas de Hoy',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Producción Diaria',
                    '${solarData.dailyProduction.toStringAsFixed(1)} kWh',
                    Icons.wb_sunny,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Consumo Diario',
                    '${solarData.dailyConsumption.toStringAsFixed(1)} kWh',
                    Icons.flash_on,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Excedente',
                    '${solarData.currentExcess.toStringAsFixed(2)} kW',
                    Icons.battery_charging_full,
                    solarData.currentExcess > 0 ? Colors.green : Colors.grey,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Batería',
                    '${solarData.batteryLevel.toStringAsFixed(0)}%',
                    Icons.battery_full,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSolarProductionCard(SolarData solarData) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wb_sunny, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Producción Solar',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${solarData.currentPower.toStringAsFixed(2)} kW',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (solarData.currentPower / 10.0).clamp(0.0, 1.0),
              backgroundColor: Colors.orange.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
            ),
            const SizedBox(height: 8),
            Text(
              solarData.isProducing ? 'Produciendo energía' : 'Sin producción',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnergyConsumptionCard(SolarData solarData) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flash_on, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Consumo Actual',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${solarData.currentConsumption.toStringAsFixed(2)} kW',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (solarData.currentConsumption / 8.0).clamp(0.0, 1.0),
              backgroundColor: Colors.blue.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            const SizedBox(height: 8),
            Consumer<DeviceProvider>(
              builder: (context, provider, _) {
                final activeDevices = provider.onlineDevices.where((d) => d.isOn).length;
                return Text(
                  '$activeDevices dispositivos activos',
                  style: Theme.of(context).textTheme.bodySmall,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutomationStatusCard() {
    return Consumer<AutomationProvider>(
      builder: (context, provider, _) {
        final enabledRules = provider.enabledRules.length;
        final totalRules = provider.rules.length;
        
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: provider.isAutomationEnabled ? Colors.green : Colors.grey,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Automatización',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        provider.isAutomationEnabled 
                            ? 'Activa ($enabledRules de $totalRules reglas)'
                            : 'Desactivada',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: provider.isAutomationEnabled,
                  onChanged: (_) => provider.toggleAutomation(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Acciones Rápidas',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickActionButton(
                  icon: Icons.lightbulb,
                  label: 'Luces',
                  onTap: () {
                    // TODO: Implementar acción para luces
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Controlando luces...')),
                    );
                  },
                ),
                _buildQuickActionButton(
                  icon: Icons.ac_unit,
                  label: 'Clima',
                  onTap: () {
                    // TODO: Implementar acción para clima
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Controlando clima...')),
                    );
                  },
                ),
                _buildQuickActionButton(
                  icon: Icons.security,
                  label: 'Seguridad',
                  onTap: () {
                    // TODO: Implementar acción para seguridad
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Verificando seguridad...')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
