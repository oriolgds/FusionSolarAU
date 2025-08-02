import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/data_provider.dart';
import 'fusion_solar_not_configured_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _hasValidConfig = false;
          _isCheckingConfig = false;
        });
        return;
      }
      
      final result = await Supabase.instance.client
          .from('users')
          .select('fusion_solar_api_username')
          .eq('id', user.id)
          .maybeSingle();
      
      final hasConfig = result?['fusion_solar_api_username'] != null;
      
      if (mounted) {
        setState(() {
          _hasValidConfig = hasConfig;
          _isCheckingConfig = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCheckingConfig = false);
      }
    }
  }

  Future<void> _handleConfigUpdated() async {
    await _checkFusionSolarConfig();
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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.solar_power,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'FusionSolarAU',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Panel de Control',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          Consumer<DataProvider>(
            builder: (context, provider, _) {
              return Container(
                margin: const EdgeInsets.only(right: 16),
                child: IconButton.filledTonal(
                  icon: provider.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  onPressed: provider.isLoading ? null : provider.refreshData,
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<DataProvider>().refreshData(),
        child: Consumer<DataProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading && !provider.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text('Error al cargar datos', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(provider.error!, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: provider.refreshData,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              );
            }

            if (!provider.hasData) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text('No hay datos disponibles', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: provider.refreshData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Cargar datos'),
                    ),
                  ],
                ),
              );
            }

            return _buildDashboard(context, provider);
          },
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, DataProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Production and consumption cards
          Row(
            children: [
              Expanded(child: _buildProductionCard(context, provider)),
              const SizedBox(width: 20),
              Expanded(child: _buildConsumptionCard(context, provider)),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Real-time data card
          if (provider.hasRealTimeData) _buildRealTimeCard(context, provider),
          
          const SizedBox(height: 20),
          
          // Stats grid
          _buildStatsGrid(context, provider),
        ],
      ),
    );
  }

  Widget _buildProductionCard(BuildContext context, DataProvider provider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.wb_sunny, color: Colors.orange, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Producción Solar',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      provider.isProducing ? 'Produciendo energía' : 'Sin producción',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '${provider.currentPower.toStringAsFixed(2)} kW',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildConsumptionCard(BuildContext context, DataProvider provider) {
    return Container(
      padding: const EdgeInsets.all(24),
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
                child: const Icon(Icons.flash_on, color: Colors.blue, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Consumo Actual',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      provider.hasRealTimeData ? 'Tiempo real' : 'Estimado',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '${provider.currentConsumption.toStringAsFixed(2)} kW',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
            ),
          ),

        ],
      ),
    );
  }



  Widget _buildRealTimeCard(BuildContext context, DataProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green.withOpacity(0.1),
            Colors.green.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildDataItem(
                  provider.gridPower > 0 ? 'Excedente' : 'Importando',
                  '${provider.gridPower.abs().toStringAsFixed(1)} kW',
                  provider.gridPower > 0 ? Icons.upload : Icons.download,
                  provider.gridPower > 0 ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDataItem(
                  'Temperatura',
                  '${provider.temperature.toStringAsFixed(1)}°C',
                  Icons.thermostat,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDataItem(
                  'Eficiencia',
                  '${provider.efficiency.toStringAsFixed(1)}%',
                  Icons.speed,
                  Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataItem(String label, String value, IconData icon, Color color) {
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
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, DataProvider provider) {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estadísticas de Hoy',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Producción Diaria',
                  '${provider.dailyProduction.toStringAsFixed(1)} kWh',
                  Icons.wb_sunny,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                  'Consumo Diario',
                  '${provider.dailyConsumption.toStringAsFixed(1)} kWh',
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
                  'Ingresos Hoy',
                  '€${provider.dailyIncome.toStringAsFixed(2)}',
                  Icons.euro,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                  'Energía Exportada',
                  '${provider.dailyExportedEnergy.toStringAsFixed(1)} kWh',
                  Icons.upload,
                  provider.dailyExportedEnergy > 0 ? Colors.green : Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
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
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}