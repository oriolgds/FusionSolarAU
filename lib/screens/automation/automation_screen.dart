import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/automation_provider.dart';
import '../../models/automation_rule.dart';

class AutomationScreen extends StatefulWidget {
  const AutomationScreen({super.key});

  @override
  State<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends State<AutomationScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Automatización'),
        actions: [
          Consumer<AutomationProvider>(
            builder: (context, provider, _) {
              return Switch(
                value: provider.isAutomationEnabled,
                onChanged: (_) => provider.toggleAutomation(),
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Consumer<AutomationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.rules.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
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
                    'Error al cargar reglas',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    provider.error!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Recargar reglas
                      provider.clearError();
                    },
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Estadísticas generales
              _buildStatsCard(provider),
              
              // Lista de reglas
              Expanded(
                child: provider.rules.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: provider.rules.length,
                        itemBuilder: (context, index) {
                          final rule = provider.rules[index];
                          return _buildRuleCard(context, rule, provider);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddRuleDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatsCard(AutomationProvider provider) {
    final enabledRules = provider.enabledRules.length;
    final totalRules = provider.rules.length;
    final totalTriggers = provider.totalTriggersToday;

    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Reglas Activas',
                  '$enabledRules de $totalRules',
                  Icons.auto_awesome,
                  Colors.green,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey[300],
              ),
              Expanded(
                child: _buildStatItem(
                  'Activaciones Hoy',
                  '$totalTriggers',
                  Icons.play_arrow,
                  Colors.blue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRuleCard(BuildContext context, AutomationRule rule, AutomationProvider provider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rule.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (rule.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          rule.description,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Switch(
                  value: rule.isEnabled,
                  onChanged: (value) => provider.toggleRule(rule.id),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Condiciones
            Wrap(
              spacing: 8,
              children: rule.conditions.map((condition) {
                return Chip(
                  label: Text(_getConditionLabel(condition)),
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  side: BorderSide(color: Colors.blue.withOpacity(0.3)),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 8),
            
            // Acciones
            Wrap(
              spacing: 8,
              children: rule.actions.map((action) {
                return Chip(
                  label: Text(_getActionLabel(action)),
                  backgroundColor: Colors.green.withOpacity(0.1),
                  side: BorderSide(color: Colors.green.withOpacity(0.3)),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 12),
            
            // Estadísticas de la regla
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Última activación: ${_formatLastTriggered(rule.lastTriggered)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${rule.timesTriggered} veces',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.orange,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No hay reglas de automatización',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Crea tu primera regla para automatizar tus dispositivos',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddRuleDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Crear Regla'),
          ),
        ],
      ),
    );
  }

  String _getConditionLabel(AutomationCondition condition) {
    switch (condition.trigger) {
      case AutomationTrigger.excessEnergy:
        final minimum = condition.parameters['minimumExcess'] ?? 0;
        return 'Excedente > ${minimum}kW';
      case AutomationTrigger.lowProduction:
        final max = condition.parameters['maxProduction'] ?? 0;
        return 'Producción < ${max}kW';
      case AutomationTrigger.timeOfDay:
        final hour = condition.parameters['hour'] ?? 0;
        return 'A las ${hour}:00';
      case AutomationTrigger.batteryLevel:
        final level = condition.parameters['batteryLevel'] ?? 0;
        return 'Batería ${level}%';
      case AutomationTrigger.weatherCondition:
        return 'Condición meteorológica';
      case AutomationTrigger.manualTrigger:
        return 'Activación manual';
    }
  }

  String _getActionLabel(DeviceAction action) {
    switch (action.action) {
      case AutomationAction.turnOn:
        return 'Encender dispositivo';
      case AutomationAction.turnOff:
        return 'Apagar dispositivo';
      case AutomationAction.setTemperature:
        final temp = action.parameters['temperature'] ?? 0;
        return 'Temperatura ${temp}°C';
      case AutomationAction.setBrightness:
        final brightness = action.parameters['brightness'] ?? 0;
        return 'Brillo ${brightness}%';
      case AutomationAction.startProgram:
        final program = action.parameters['program'] ?? 'desconocido';
        return 'Programa: $program';
      case AutomationAction.sendNotification:
        return 'Enviar notificación';
    }
  }

  String _formatLastTriggered(DateTime? lastTriggered) {
    if (lastTriggered == null) {
      return 'Nunca';
    }
    
    final now = DateTime.now();
    final difference = now.difference(lastTriggered);
    
    if (difference.inDays > 0) {
      return 'Hace ${difference.inDays} días';
    } else if (difference.inHours > 0) {
      return 'Hace ${difference.inHours} horas';
    } else if (difference.inMinutes > 0) {
      return 'Hace ${difference.inMinutes} minutos';
    } else {
      return 'Hace unos segundos';
    }
  }

  void _showAddRuleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear Nueva Regla'),
        content: const Text(
          'La funcionalidad de crear reglas personalizadas estará disponible en una próxima actualización.\n\n'
          'Por ahora puedes usar las reglas predefinidas que se cargan automáticamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}
