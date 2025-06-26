import 'dart:async';
import 'dart:math';
import '../models/smart_device.dart';

class GoogleHomeService {
  // En una implementación real, aquí tendríamos la integración con Google Home API
  // Por ahora, simularemos dispositivos y funcionalidades
  
  final Random _random = Random();

  Future<List<SmartDevice>> getDevices() async {
    // Simular llamada a la API de Google Home
    await Future.delayed(const Duration(seconds: 1));

    return [
      SmartDevice(
        id: 'light_living_room',
        name: 'Luz Sala',
        roomName: 'Sala',
        type: DeviceType.light,
        status: DeviceStatus.online,
        isOn: _random.nextBool(),
        powerConsumption: 12.0,
        traits: {'brightness': 80, 'color': 'warm_white'},
        lastUpdated: DateTime.now(),
        canBeAutomated: true,
        priority: 3,
      ),
      SmartDevice(
        id: 'ac_bedroom',
        name: 'Aire Acondicionado',
        roomName: 'Dormitorio',
        type: DeviceType.airConditioner,
        status: DeviceStatus.online,
        isOn: false,
        powerConsumption: 2500.0,
        traits: {'temperature': 22, 'mode': 'cool'},
        lastUpdated: DateTime.now(),
        canBeAutomated: true,
        priority: 8,
      ),
      SmartDevice(
        id: 'washer_laundry',
        name: 'Lavadora',
        roomName: 'Lavadero',
        type: DeviceType.washer,
        status: DeviceStatus.online,
        isOn: false,
        powerConsumption: 1800.0,
        traits: {'program': 'eco', 'time_remaining': 0},
        lastUpdated: DateTime.now(),
        canBeAutomated: true,
        priority: 9,
      ),
      SmartDevice(
        id: 'dishwasher_kitchen',
        name: 'Lavavajillas',
        roomName: 'Cocina',
        type: DeviceType.dishwasher,
        status: DeviceStatus.online,
        isOn: false,
        powerConsumption: 1500.0,
        traits: {'program': 'normal', 'time_remaining': 0},
        lastUpdated: DateTime.now(),
        canBeAutomated: true,
        priority: 7,
      ),
      SmartDevice(
        id: 'ev_charger_garage',
        name: 'Cargador VE',
        roomName: 'Garaje',
        type: DeviceType.charger,
        status: DeviceStatus.online,
        isOn: false,
        powerConsumption: 7000.0,
        traits: {'charging_rate': 'max', 'battery_level': 65},
        lastUpdated: DateTime.now(),
        canBeAutomated: true,
        priority: 10,
      ),
      SmartDevice(
        id: 'thermostat_main',
        name: 'Termostato Principal',
        roomName: 'Pasillo',
        type: DeviceType.thermostat,
        status: DeviceStatus.online,
        isOn: true,
        powerConsumption: 50.0,
        traits: {'temperature': 21, 'target_temperature': 23, 'mode': 'heat'},
        lastUpdated: DateTime.now(),
        canBeAutomated: true,
        priority: 6,
      ),
      SmartDevice(
        id: 'lights_kitchen',
        name: 'Luces Cocina',
        roomName: 'Cocina',
        type: DeviceType.light,
        status: DeviceStatus.online,
        isOn: true,
        powerConsumption: 24.0,
        traits: {'brightness': 100, 'color': 'daylight'},
        lastUpdated: DateTime.now(),
        canBeAutomated: true,
        priority: 2,
      ),
      SmartDevice(
        id: 'fan_bedroom',
        name: 'Ventilador',
        roomName: 'Dormitorio',
        type: DeviceType.fan,
        status: DeviceStatus.online,
        isOn: false,
        powerConsumption: 75.0,
        traits: {'speed': 3, 'oscillating': true},
        lastUpdated: DateTime.now(),
        canBeAutomated: true,
        priority: 4,
      ),
    ];
  }

  Future<bool> toggleDevice(String deviceId, bool turnOn) async {
    // Simular llamada a la API para cambiar estado del dispositivo
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Simular éxito del 95% de las veces
    return _random.nextDouble() > 0.05;
  }

  Future<bool> setDeviceState(String deviceId, Map<String, dynamic> state) async {
    // Simular llamada a la API para establecer estado específico
    await Future.delayed(const Duration(milliseconds: 700));
    
    // Simular éxito del 90% de las veces
    return _random.nextDouble() > 0.10;
  }

  Future<bool> executeScene(String sceneId) async {
    // Simular ejecución de escena/rutina de Google Home
    await Future.delayed(const Duration(seconds: 1));
    
    return _random.nextDouble() > 0.05;
  }

  Future<List<String>> getAvailableScenes() async {
    // Simular obtención de escenas disponibles
    await Future.delayed(const Duration(milliseconds: 300));
    
    return [
      'Buenas noches',
      'Buenos días',
      'Modo ahorro',
      'Fuera de casa',
      'Película',
      'Cena romántica',
    ];
  }
}
