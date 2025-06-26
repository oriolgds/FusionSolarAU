import 'package:flutter/material.dart';
import '../models/smart_device.dart';
import '../services/google_home_service.dart';

class DeviceProvider extends ChangeNotifier {
  final GoogleHomeService _googleHomeService = GoogleHomeService();

  List<SmartDevice> _devices = [];
  bool _isLoading = false;
  String? _error;

  List<SmartDevice> get devices => _devices;
  bool get isLoading => _isLoading;
  String? get error => _error;

  DeviceProvider() {
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    try {
      _setLoading(true);
      _setError(null);

      final devices = await _googleHomeService.getDevices();
      _devices = devices;
      
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Error al cargar dispositivos: $e');
      _setLoading(false);
    }
  }

  Future<void> refreshDevices() async {
    await _loadDevices();
  }

  Future<bool> toggleDevice(String deviceId) async {
    try {
      final deviceIndex = _devices.indexWhere((d) => d.id == deviceId);
      if (deviceIndex == -1) return false;

      final device = _devices[deviceIndex];
      final success = await _googleHomeService.toggleDevice(deviceId, !device.isOn);
      
      if (success) {
        _devices[deviceIndex] = device.copyWith(
          isOn: !device.isOn,
          lastUpdated: DateTime.now(),
        );
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error toggling device: $e');
      return false;
    }
  }

  Future<bool> setDeviceState(String deviceId, Map<String, dynamic> state) async {
    try {
      final success = await _googleHomeService.setDeviceState(deviceId, state);
      
      if (success) {
        final deviceIndex = _devices.indexWhere((d) => d.id == deviceId);
        if (deviceIndex != -1) {
          final device = _devices[deviceIndex];
          _devices[deviceIndex] = device.copyWith(
            isOn: state['on'] ?? device.isOn,
            traits: {...device.traits, ...state},
            lastUpdated: DateTime.now(),
          );
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error setting device state: $e');
      return false;
    }
  }

  List<SmartDevice> get highPowerDevices {
    return _devices.where((device) => device.isHighPowerDevice).toList();
  }

  List<SmartDevice> get automatedDevices {
    return _devices.where((device) => device.canBeAutomated).toList();
  }

  List<SmartDevice> get onlineDevices {
    return _devices.where((device) => device.status == DeviceStatus.online).toList();
  }

  List<SmartDevice> getDevicesByRoom(String roomName) {
    return _devices.where((device) => device.roomName == roomName).toList();
  }

  List<SmartDevice> getDevicesByType(DeviceType type) {
    return _devices.where((device) => device.type == type).toList();
  }

  double get totalPowerConsumption {
    return _devices
        .where((device) => device.isOn && device.status == DeviceStatus.online)
        .fold(0.0, (sum, device) => sum + device.powerConsumption);
  }

  List<String> get uniqueRooms {
    final rooms = _devices.map((device) => device.roomName).toSet().toList();
    rooms.sort();
    return rooms;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
