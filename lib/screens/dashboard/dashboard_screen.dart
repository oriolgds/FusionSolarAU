import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/solar_data_provider.dart';
import '../../providers/device_provider.dart';
import '../../providers/automation_provider.dart';
import '../../providers/inverter_real_time_provider.dart';
import '../../providers/meter_provider.dart';
import '../../models/solar_data.dart';
import '../../services/fusion_solar_oauth_service.dart';
import '../../providers/plant_provider.dart';
import 'fusion_solar_not_configured_screen.dart';
import 'package:logger/logger.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FusionSolarOAuthService _oauthService = FusionSolarOAuthService();
  final Logger _log = Logger();
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
            _setupDataSync();
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

  void _setupDataSync() {
    final plantProvider = context.read<PlantProvider>();
    final solarProvider = context.read<SolarDataProvider>();
    final inverterProvider = context.read<InverterRealTimeProvider>();
    final meterProvider = context.read<MeterProvider>();

    // Si ya hay plantas cargadas, configurar inmediatamente
    if (plantProvider.plants.isNotEmpty) {
      final selectedCode =
          plantProvider.selectedStationCode ??
          plantProvider.plants.first.stationCode;
      solarProvider.setSelectedStationCode(selectedCode);
      inverterProvider.setStationCode(selectedCode);
      meterProvider.setStationCode(selectedCode);
      if (plantProvider.selectedStationCode == null) {
        plantProvider.setSelectedStationCode(selectedCode);
      }
    }

    // Refrescar dispositivos
    context.read<DeviceProvider>().refreshDevices();
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
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Setup data sync and load plants first
      final plantProvider = Provider.of<PlantProvider>(context, listen: false);
      await plantProvider.fetchPlants();
      
      // Then continue with regular setup
      _setupDataSync();
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
                  _refreshAllData();
                },
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAllData,
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
                      onPressed: () => _refreshAllData(),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              );
            }

            final solarData = solarProvider.currentData;
            if (solarData == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No hay datos disponibles',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _refreshAllData(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return _buildDashboard(context, solarData);
          },
        ),
      ),
    );
  }

  // Nuevo método para refrescar todos los datos
  Future<void> _refreshAllData() async {
    // Refrescar plantas primero
    final plantProvider = Provider.of<PlantProvider>(context, listen: false);
    await plantProvider.fetchPlants();
    
    // Luego refrescar datos solares, datos en tiempo real y dispositivos
    final solarProvider = Provider.of<SolarDataProvider>(context, listen: false);
    final inverterProvider = Provider.of<InverterRealTimeProvider>(
      context,
      listen: false,
    );
    final meterProvider = Provider.of<MeterProvider>(context, listen: false);

    await Future.wait([
      solarProvider.forceRefreshData(),
      inverterProvider.forceRefresh(),
      meterProvider.forceRefresh(),
      Provider.of<DeviceProvider>(context, listen: false).refreshDevices(),
    ]);
  }

  Widget _buildDashboard(BuildContext context, SolarData solarData) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selector moderno de plantas
          _buildModernPlantSelector(),

          const SizedBox(height: 28),

          // Datos en tiempo real del inversor
          _buildInverterRealTimeCard(),

          const SizedBox(height: 20),

          // Datos del medidor (potencia de red)
          _buildMeterCard(),

          const SizedBox(height: 20),
          
          // Tarjetas principales de energía
          Row(
            children: [
              Expanded(
                child: _buildSolarProductionCard(solarData),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildEnergyConsumptionCard(solarData),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Estado de automatización
          _buildAutomationStatusCard(),
          
          const SizedBox(height: 20),
          
          // Acciones rápidas
          _buildQuickActionsCard(),
          
          const SizedBox(height: 20),
          
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
          // Si solo hay una planta, notificar a los providers
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final solarProvider = context.read<SolarDataProvider>();
            final inverterProvider = context.read<InverterRealTimeProvider>();
            final meterProvider = context.read<MeterProvider>();
            final plantCode = plantProvider.plants.first.stationCode;
            solarProvider.setSelectedStationCode(plantCode);
            inverterProvider.setStationCode(plantCode);
            meterProvider.setStationCode(plantCode);

            // Asegurar que el plant provider también tenga seleccionada la planta
            if (plantProvider.selectedStationCode != plantCode) {
              plantProvider.setSelectedStationCode(plantCode);
            }
          });
          
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
                        // Primero establecer en plant provider
                        plantProvider.setSelectedStationCode(plant.stationCode);
                        
                        // Luego notificar a los providers de datos
                        final solarProvider = context.read<SolarDataProvider>();
                        final inverterProvider = context
                            .read<InverterRealTimeProvider>();
                        final meterProvider = context.read<MeterProvider>();
                        solarProvider.setSelectedStationCode(plant.stationCode);
                        inverterProvider.setStationCode(plant.stationCode);
                        meterProvider.setStationCode(plant.stationCode);

                        // Refrescar dispositivos para la nueva planta
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
    _log.d('Building stats section with data: ${solarData.toJson()}');
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.analytics,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estadísticas de Hoy',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // Mostrar estado de salud si está disponible
                      if (solarData.healthState != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              _getHealthIcon(solarData.healthState!),
                              color: solarData.healthStateColor,
                              size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            solarData.healthStateText,
                            style: TextStyle(
                              color: solarData.healthStateColor,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      // Mostrar fecha de última actualización
                      const SizedBox(height: 4),
                      Consumer<SolarDataProvider>(
                        builder: (context, provider, _) {
                          return Row(
                            children: [
                              Icon(Icons.update, size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(
                                'Actualizado: ${_formatTimestamp(provider.currentData?.timestamp ?? DateTime.now())}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
              ]),
              
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildStatsGrid(context, solarData),
            
            // Mostrar información adicional si está disponible
            if (solarData.totalIncome != null) ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.green.withOpacity(0.1),
                      Colors.green.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.savings, color: Colors.green, size: 28),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ingresos Totales',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '€${solarData.totalIncome!.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, SolarData solarData) {
    final bool hasRealData = solarData.dailyProduction > 0 || solarData.dailyConsumption > 0;
    _log.d('Stats grid - hasRealData: $hasRealData, dailyProduction: ${solarData.dailyProduction}, dailyConsumption: ${solarData.dailyConsumption}');
  
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatItem(
                context,
                'Producción Diaria',
                hasRealData ? '${solarData.dailyProduction.toStringAsFixed(1)} kWh' : '--',
                Icons.wb_sunny,
                hasRealData ? Colors.orange : Colors.grey,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatItem(
                context,
                'Consumo Diario',
                hasRealData ? '${solarData.dailyConsumption.toStringAsFixed(1)} kWh' : '--',
                Icons.flash_on,
                hasRealData ? Colors.blue : Colors.grey,
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
                solarData.dailyOnGridEnergy != null ? 'Energía a Red' : 'Excedente',
                hasRealData ? (solarData.dailyOnGridEnergy != null 
                    ? '${solarData.dailyOnGridEnergy!.toStringAsFixed(1)} kWh'
                    : '${solarData.currentExcess.toStringAsFixed(2)} kW') : '--',
                Icons.battery_charging_full,
                hasRealData ? (solarData.currentExcess > 0 ? Colors.green : Colors.grey) : Colors.grey,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatItem(
                context,
                solarData.dailyIncome != null ? 'Ingresos Hoy' : 'Batería',
                hasRealData ? (solarData.dailyIncome != null 
                    ? '€${solarData.dailyIncome!.toStringAsFixed(2)}'
                    : '${solarData.batteryLevel.toStringAsFixed(0)}%') : '--',
                solarData.dailyIncome != null ? Icons.euro : Icons.battery_full,
                hasRealData ? Colors.green : Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }

  IconData _getHealthIcon(int healthState) {
    switch (healthState) {
      case 1:
        return Icons.link_off;
      case 2:
        return Icons.warning;
      case 3:
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }

  Widget _buildSolarProductionCard(SolarData solarData) {
    final bool hasRealData = solarData.currentPower > 0 || solarData.dailyProduction > 0;
  
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.wb_sunny, color: Colors.orange, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Producción Solar',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        hasRealData ? (solarData.isProducing ? 'Produciendo energía' : 'Sin producción') : 'Sin datos disponibles',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              hasRealData ? '${solarData.currentPower.toStringAsFixed(2)} kW' : '--',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: hasRealData ? Colors.orange : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: Colors.orange.withOpacity(0.2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: hasRealData ? (solarData.currentPower / 10.0).clamp(0.0, 1.0) : 0.0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: Colors.orange,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnergyConsumptionCard(SolarData solarData) {
    final bool hasRealData = solarData.currentConsumption > 0 || solarData.dailyConsumption > 0;
  
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.flash_on, color: Colors.blue, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Consumo Actual',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Consumer<DeviceProvider>(
                        builder: (context, provider, _) {
                          final activeDevices = provider.onlineDevices.where((d) => d.isOn).length;
                          return Text(
                            hasRealData ? '$activeDevices dispositivos activos' : 'Sin datos disponibles',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              hasRealData ? '${solarData.currentConsumption.toStringAsFixed(2)} kW' : '--',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: hasRealData ? Colors.blue : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: Colors.blue.withOpacity(0.2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: hasRealData ? (solarData.currentConsumption / 8.0).clamp(0.0, 1.0) : 0.0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: Colors.blue,
                  ),
                ),
              ),
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
        
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: provider.isAutomationEnabled 
                        ? Colors.green.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: provider.isAutomationEnabled ? Colors.green : Colors.grey,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Automatización',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        provider.isAutomationEnabled 
                            ? 'Activa ($enabledRules de $totalRules reglas)'
                            : 'Desactivada',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: provider.isAutomationEnabled,
                  onChanged: (_) => provider.toggleAutomation(),
                  activeColor: Colors.green,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.flash_auto,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Acciones Rápidas',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInverterRealTimeCard() {
    return Consumer<InverterRealTimeProvider>(
      builder: (context, inverterProvider, _) {
        final hasData = inverterProvider.hasData;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.withOpacity(0.1),
                Colors.blue.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.blue.withOpacity(0.2), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.memory,
                      color: Colors.blue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Datos del Inversor en Tiempo Real',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: hasData && !inverterProvider.isLoading
                                    ? Colors.green
                                    : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              inverterProvider.isLoading
                                  ? 'Obteniendo datos...'
                                  : hasData
                                  ? 'Datos actualizados'
                                  : 'Sin datos disponibles',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (inverterProvider.isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              if (inverterProvider.error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          inverterProvider.error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _buildRealTimeDataItem(
                        'Potencia Activa',
                        hasData
                            ? '${inverterProvider.activePower.toStringAsFixed(3)} kW'
                            : '--',
                        Icons.flash_on,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildRealTimeDataItem(
                        'Temperatura',
                        hasData
                            ? '${inverterProvider.temperature.toStringAsFixed(1)}°C'
                            : '--',
                        Icons.thermostat,
                        Colors.red,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildRealTimeDataItem(
                        'Eficiencia',
                        hasData
                            ? '${inverterProvider.efficiency.toStringAsFixed(1)}%'
                            : '--',
                        Icons.speed,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
              if (hasData) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.update, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      'Última actualización: ${_formatTimestamp(inverterProvider.lastUpdated ?? inverterProvider.currentData!.timestamp)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRealTimeDataItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMeterCard() {
    return Consumer<MeterProvider>(
      builder: (context, meterProvider, _) {
        final hasData = meterProvider.hasData;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.purple.withOpacity(0.1),
                Colors.purple.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.purple.withOpacity(0.2), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.electrical_services,
                      color: Colors.purple,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Potencia de Red',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: hasData && !meterProvider.isLoading
                                    ? Colors.green
                                    : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              meterProvider.isLoading
                                  ? 'Obteniendo datos...'
                                  : hasData
                                  ? (meterProvider.gridPower > 0 
                                      ? 'Consumiendo de red' 
                                      : 'Exportando a red')
                                  : 'Sin datos disponibles',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (meterProvider.isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              if (meterProvider.error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          meterProvider.error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _buildRealTimeDataItem(
                        'Potencia Red',
                        hasData
                            ? '${meterProvider.gridPower.toStringAsFixed(3)} kW'
                            : '--',
                        meterProvider.gridPower > 0 ? Icons.call_received : Icons.call_made,
                        meterProvider.gridPower > 0 ? Colors.red : Colors.green,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildRealTimeDataItem(
                        'Voltaje',
                        hasData
                            ? '${meterProvider.meterVoltage.toStringAsFixed(1)} V'
                            : '--',
                        Icons.bolt,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildRealTimeDataItem(
                        'Frecuencia',
                        hasData
                            ? '${meterProvider.gridFrequency.toStringAsFixed(2)} Hz'
                            : '--',
                        Icons.waves,
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
              if (hasData) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.update, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      'Última actualización: ${_formatTimestamp(meterProvider.lastUpdated ?? meterProvider.currentData!.timestamp)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Hace unos segundos';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours}h ${difference.inMinutes % 60}min';
    } else {
      return '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}
