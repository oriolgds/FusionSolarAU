import 'package:equatable/equatable.dart';

enum AutomationTrigger {
  excessEnergy,      // Cuando hay excedente de energía
  lowProduction,     // Cuando la producción es baja
  timeOfDay,         // En un horario específico
  weatherCondition,  // Según condiciones meteorológicas
  batteryLevel,      // Según nivel de batería
  manualTrigger,     // Activación manual
}

enum AutomationAction {
  turnOn,           // Encender dispositivo
  turnOff,          // Apagar dispositivo
  setTemperature,   // Establecer temperatura
  setBrightness,    // Establecer brillo
  startProgram,     // Iniciar programa (lavadora, etc.)
  sendNotification, // Enviar notificación
}

class AutomationCondition extends Equatable {
  final AutomationTrigger trigger;
  final Map<String, dynamic> parameters;

  const AutomationCondition({
    required this.trigger,
    required this.parameters,
  });

  factory AutomationCondition.fromJson(Map<String, dynamic> json) {
    return AutomationCondition(
      trigger: AutomationTrigger.values.firstWhere(
        (e) => e.toString().split('.').last == json['trigger'],
        orElse: () => AutomationTrigger.manualTrigger,
      ),
      parameters: Map<String, dynamic>.from(json['parameters'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trigger': trigger.toString().split('.').last,
      'parameters': parameters,
    };
  }

  @override
  List<Object?> get props => [trigger, parameters];
}

class AutomationRule extends Equatable {
  final String id;
  final String name;
  final String description;
  final bool isEnabled;
  final List<AutomationCondition> conditions;
  final List<DeviceAction> actions;
  final DateTime createdAt;
  final DateTime lastTriggered;
  final int timesTriggered;
  final int priority; // 1-10, 10 = más alta prioridad

  const AutomationRule({
    required this.id,
    required this.name,
    required this.description,
    required this.isEnabled,
    required this.conditions,
    required this.actions,
    required this.createdAt,
    required this.lastTriggered,
    required this.timesTriggered,
    required this.priority,
  });

  factory AutomationRule.fromJson(Map<String, dynamic> json) {
    return AutomationRule(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      isEnabled: json['isEnabled'] ?? true,
      conditions: (json['conditions'] as List<dynamic>?)
              ?.map((e) => AutomationCondition.fromJson(e))
              .toList() ??
          [],
      actions: (json['actions'] as List<dynamic>?)
              ?.map((e) => DeviceAction.fromJson(e))
              .toList() ??
          [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        json['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
      lastTriggered: DateTime.fromMillisecondsSinceEpoch(
        json['lastTriggered'] ?? 0,
      ),
      timesTriggered: json['timesTriggered'] ?? 0,
      priority: json['priority'] ?? 5,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'isEnabled': isEnabled,
      'conditions': conditions.map((e) => e.toJson()).toList(),
      'actions': actions.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastTriggered': lastTriggered.millisecondsSinceEpoch,
      'timesTriggered': timesTriggered,
      'priority': priority,
    };
  }

  AutomationRule copyWith({
    String? id,
    String? name,
    String? description,
    bool? isEnabled,
    List<AutomationCondition>? conditions,
    List<DeviceAction>? actions,
    DateTime? createdAt,
    DateTime? lastTriggered,
    int? timesTriggered,
    int? priority,
  }) {
    return AutomationRule(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isEnabled: isEnabled ?? this.isEnabled,
      conditions: conditions ?? this.conditions,
      actions: actions ?? this.actions,
      createdAt: createdAt ?? this.createdAt,
      lastTriggered: lastTriggered ?? this.lastTriggered,
      timesTriggered: timesTriggered ?? this.timesTriggered,
      priority: priority ?? this.priority,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        isEnabled,
        conditions,
        actions,
        createdAt,
        lastTriggered,
        timesTriggered,
        priority,
      ];
}

class DeviceAction extends Equatable {
  final String deviceId;
  final AutomationAction action;
  final Map<String, dynamic> parameters;
  final Duration? delay; // Retraso antes de ejecutar la acción

  const DeviceAction({
    required this.deviceId,
    required this.action,
    required this.parameters,
    this.delay,
  });

  factory DeviceAction.fromJson(Map<String, dynamic> json) {
    return DeviceAction(
      deviceId: json['deviceId'] ?? '',
      action: AutomationAction.values.firstWhere(
        (e) => e.toString().split('.').last == json['action'],
        orElse: () => AutomationAction.turnOn,
      ),
      parameters: Map<String, dynamic>.from(json['parameters'] ?? {}),
      delay: json['delaySeconds'] != null
          ? Duration(seconds: json['delaySeconds'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'action': action.toString().split('.').last,
      'parameters': parameters,
      'delaySeconds': delay?.inSeconds,
    };
  }

  @override
  List<Object?> get props => [deviceId, action, parameters, delay];
}
