import 'dart:async';
import 'dart:math';
import '../models/automation_rule.dart';
import '../models/solar_data.dart';

class AutomationService {
  final Random _random = Random();

  Future<List<AutomationRule>> getRules() async {
    // Simular carga de reglas desde almacenamiento local o backend
    await Future.delayed(const Duration(milliseconds: 500));

    return [
      AutomationRule(
        id: 'rule_excess_energy_washer',
        name: 'Excedente → Lavadora',
        description: 'Activa la lavadora cuando hay excedente de energía solar',
        isEnabled: true,
        conditions: [
          AutomationCondition(
            trigger: AutomationTrigger.excessEnergy,
            parameters: {'minimumExcess': 2.0}, // 2kW mínimo
          ),
        ],
        actions: [
          DeviceAction(
            deviceId: 'washer_laundry',
            action: AutomationAction.startProgram,
            parameters: {'program': 'eco'},
          ),
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        lastTriggered: DateTime.now().subtract(const Duration(hours: 6)),
        timesTriggered: 12,
        priority: 9,
      ),
      AutomationRule(
        id: 'rule_excess_energy_ev',
        name: 'Excedente → Cargador VE',
        description: 'Inicia carga del vehículo eléctrico con excedente solar',
        isEnabled: true,
        conditions: [
          AutomationCondition(
            trigger: AutomationTrigger.excessEnergy,
            parameters: {'minimumExcess': 3.0}, // 3kW mínimo
          ),
        ],
        actions: [
          DeviceAction(
            deviceId: 'ev_charger_garage',
            action: AutomationAction.turnOn,
            parameters: {'chargingRate': 'solar'},
          ),
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        lastTriggered: DateTime.now().subtract(const Duration(hours: 2)),
        timesTriggered: 25,
        priority: 10,
      ),
      AutomationRule(
        id: 'rule_low_production_ac',
        name: 'Poca Producción → Apagar AC',
        description: 'Apaga aire acondicionado cuando la producción solar es baja',
        isEnabled: true,
        conditions: [
          AutomationCondition(
            trigger: AutomationTrigger.lowProduction,
            parameters: {'maxProduction': 1.0}, // Menos de 1kW
          ),
        ],
        actions: [
          DeviceAction(
            deviceId: 'ac_bedroom',
            action: AutomationAction.turnOff,
            parameters: {},
          ),
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        lastTriggered: DateTime.now().subtract(const Duration(days: 1)),
        timesTriggered: 8,
        priority: 6,
      ),
      AutomationRule(
        id: 'rule_time_dishwasher',
        name: 'Horario → Lavavajillas',
        description: 'Activa lavavajillas a las 14:00 si hay sol',
        isEnabled: false,
        conditions: [
          AutomationCondition(
            trigger: AutomationTrigger.timeOfDay,
            parameters: {'hour': 14, 'minute': 0},
          ),
          AutomationCondition(
            trigger: AutomationTrigger.excessEnergy,
            parameters: {'minimumExcess': 1.5},
          ),
        ],
        actions: [
          DeviceAction(
            deviceId: 'dishwasher_kitchen',
            action: AutomationAction.startProgram,
            parameters: {'program': 'normal'},
          ),
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
        lastTriggered: DateTime.now().subtract(const Duration(days: 2)),
        timesTriggered: 15,
        priority: 7,
      ),
    ];
  }

  Future<bool> saveRule(AutomationRule rule) async {
    // Simular guardado de regla
    await Future.delayed(const Duration(milliseconds: 300));
    return _random.nextDouble() > 0.05; // 95% de éxito
  }

  Future<bool> deleteRule(String ruleId) async {
    // Simular eliminación de regla
    await Future.delayed(const Duration(milliseconds: 200));
    return _random.nextDouble() > 0.02; // 98% de éxito
  }

  Future<bool> evaluateRule(AutomationRule rule) async {
    // Esta función evaluaría las condiciones de la regla contra el estado actual
    // Por ahora, simularemos evaluación aleatoria
    await Future.delayed(const Duration(milliseconds: 50));
    
    // Simular que las reglas se activan ocasionalmente
    return _random.nextDouble() > 0.95; // 5% de probabilidad de activación
  }

  Future<bool> executeRule(AutomationRule rule) async {
    // Esta función ejecutaría las acciones de la regla
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Simular ejecución exitosa la mayoría de las veces
    return _random.nextDouble() > 0.10; // 90% de éxito
  }

  bool evaluateExcessEnergyCondition(
    AutomationCondition condition,
    SolarData solarData,
  ) {
    final minimumExcess = (condition.parameters['minimumExcess'] ?? 0.0)
        .toDouble();
    final currentExcess = solarData.currentExcess;
    return currentExcess >= minimumExcess;
  }

  bool evaluateLowProductionCondition(
    AutomationCondition condition,
    SolarData solarData,
  ) {
    final maxProduction = (condition.parameters['maxProduction'] ?? 0.0)
        .toDouble();
    final currentPower = solarData.currentPower;
    return currentPower <= maxProduction;
  }

  bool evaluateTimeOfDayCondition(AutomationCondition condition) {
    final now = DateTime.now();
    final targetHour = (condition.parameters['hour'] ?? 0) as int;
    final targetMinute = (condition.parameters['minute'] ?? 0) as int;
    
    return now.hour == targetHour && now.minute == targetMinute;
  }

  bool evaluateBatteryLevelCondition(
    AutomationCondition condition,
    SolarData solarData,
  ) {
    final targetLevel = (condition.parameters['batteryLevel'] ?? 0.0)
        .toDouble();
    final operator = condition.parameters['operator'] ?? 'gte';
    final currentLevel = solarData.batteryLevel;
    
    switch (operator) {
      case 'gte':
        return currentLevel >= targetLevel;
      case 'lte':
        return currentLevel <= targetLevel;
      case 'eq':
        return (currentLevel - targetLevel).abs() < 0.1; // Tolerancia del 0.1%
      default:
        return false;
    }
  }
}
