import 'package:equatable/equatable.dart';

enum DeviceType {
  light,
  switch_,
  thermostat,
  outlet,
  fan,
  speaker,
  display,
  camera,
  lock,
  vacuum,
  washer,
  dryer,
  dishwasher,
  oven,
  airConditioner,
  heater,
  charger, // Para cargadores de vehículos eléctricos
  other,
}

enum DeviceStatus {
  online,
  offline,
  error,
  updating,
}

class SmartDevice extends Equatable {
  final String id;
  final String name;
  final String roomName;
  final DeviceType type;
  final DeviceStatus status;
  final bool isOn;
  final double powerConsumption; // Watts actuales
  final Map<String, dynamic> traits; // Características específicas del dispositivo
  final DateTime lastUpdated;
  final bool canBeAutomated; // Si puede ser controlado por automatización
  final int priority; // Prioridad para automatización (1-10, 10 = más alta)

  const SmartDevice({
    required this.id,
    required this.name,
    required this.roomName,
    required this.type,
    required this.status,
    required this.isOn,
    required this.powerConsumption,
    required this.traits,
    required this.lastUpdated,
    required this.canBeAutomated,
    required this.priority,
  });

  factory SmartDevice.fromJson(Map<String, dynamic> json) {
    return SmartDevice(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      roomName: json['roomName'] ?? '',
      type: DeviceType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => DeviceType.other,
      ),
      status: DeviceStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => DeviceStatus.offline,
      ),
      isOn: json['isOn'] ?? false,
      powerConsumption: (json['powerConsumption'] ?? 0.0).toDouble(),
      traits: Map<String, dynamic>.from(json['traits'] ?? {}),
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(
        json['lastUpdated'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
      canBeAutomated: json['canBeAutomated'] ?? true,
      priority: json['priority'] ?? 5,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'roomName': roomName,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'isOn': isOn,
      'powerConsumption': powerConsumption,
      'traits': traits,
      'lastUpdated': lastUpdated.millisecondsSinceEpoch,
      'canBeAutomated': canBeAutomated,
      'priority': priority,
    };
  }

  SmartDevice copyWith({
    String? id,
    String? name,
    String? roomName,
    DeviceType? type,
    DeviceStatus? status,
    bool? isOn,
    double? powerConsumption,
    Map<String, dynamic>? traits,
    DateTime? lastUpdated,
    bool? canBeAutomated,
    int? priority,
  }) {
    return SmartDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      roomName: roomName ?? this.roomName,
      type: type ?? this.type,
      status: status ?? this.status,
      isOn: isOn ?? this.isOn,
      powerConsumption: powerConsumption ?? this.powerConsumption,
      traits: traits ?? this.traits,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      canBeAutomated: canBeAutomated ?? this.canBeAutomated,
      priority: priority ?? this.priority,
    );
  }

  // Métodos de utilidad
  String get typeDisplayName {
    switch (type) {
      case DeviceType.light:
        return 'Luz';
      case DeviceType.switch_:
        return 'Interruptor';
      case DeviceType.thermostat:
        return 'Termostato';
      case DeviceType.outlet:
        return 'Enchufe';
      case DeviceType.fan:
        return 'Ventilador';
      case DeviceType.speaker:
        return 'Altavoz';
      case DeviceType.display:
        return 'Pantalla';
      case DeviceType.camera:
        return 'Cámara';
      case DeviceType.lock:
        return 'Cerradura';
      case DeviceType.vacuum:
        return 'Aspiradora';
      case DeviceType.washer:
        return 'Lavadora';
      case DeviceType.dryer:
        return 'Secadora';
      case DeviceType.dishwasher:
        return 'Lavavajillas';
      case DeviceType.oven:
        return 'Horno';
      case DeviceType.airConditioner:
        return 'Aire Acondicionado';
      case DeviceType.heater:
        return 'Calefactor';
      case DeviceType.charger:
        return 'Cargador VE';
      case DeviceType.other:
        return 'Otro';
    }
  }

  bool get isHighPowerDevice {
    return [
      DeviceType.washer,
      DeviceType.dryer,
      DeviceType.dishwasher,
      DeviceType.oven,
      DeviceType.airConditioner,
      DeviceType.heater,
      DeviceType.charger,
    ].contains(type);
  }

  @override
  List<Object?> get props => [
        id,
        name,
        roomName,
        type,
        status,
        isOn,
        powerConsumption,
        traits,
        lastUpdated,
        canBeAutomated,
        priority,
      ];
}
