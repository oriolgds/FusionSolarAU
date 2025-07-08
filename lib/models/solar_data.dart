import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class SolarData extends Equatable {
  final double currentPower; // kW - Potencia actual generada
  final double dailyProduction; // kWh - Producción del día (day_power)
  final double monthlyProduction; // kWh - Producción del mes (month_power)
  final double totalProduction; // kWh - Producción total (total_power)
  final double currentConsumption; // kW - Consumo actual
  final double dailyConsumption; // kWh - Consumo del día (day_use_energy)
  final double currentExcess; // kW - Excedente actual (positivo = exportando)
  final double batteryLevel; // % - Nivel de batería (si aplica)
  final bool isProducing; // Si está generando energía
  final DateTime timestamp;

  // Nuevos campos de la API real
  final double? dailyIncome; // Revenue today (day_income)
  final double? totalIncome; // Total revenue (total_income)
  final double? dailyOnGridEnergy; // Daily on-grid energy (day_on_grid_energy)
  final int? healthState; // Plant health status (real_health_state)

  const SolarData({
    required this.currentPower,
    required this.dailyProduction,
    required this.monthlyProduction,
    required this.totalProduction,
    required this.currentConsumption,
    required this.dailyConsumption,
    required this.currentExcess,
    required this.batteryLevel,
    required this.isProducing,
    required this.timestamp,
    this.dailyIncome,
    this.totalIncome,
    this.dailyOnGridEnergy,
    this.healthState,
  });

  factory SolarData.fromJson(Map<String, dynamic> json) {
    return SolarData(
      currentPower: (json['currentPower'] ?? 0.0).toDouble(),
      dailyProduction: (json['dailyProduction'] ?? 0.0).toDouble(),
      monthlyProduction: (json['monthlyProduction'] ?? 0.0).toDouble(),
      totalProduction: (json['totalProduction'] ?? 0.0).toDouble(),
      currentConsumption: (json['currentConsumption'] ?? 0.0).toDouble(),
      dailyConsumption: (json['dailyConsumption'] ?? 0.0).toDouble(),
      currentExcess: (json['currentExcess'] ?? 0.0).toDouble(),
      batteryLevel: (json['batteryLevel'] ?? 0.0).toDouble(),
      isProducing: json['isProducing'] ?? false,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        json['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
      dailyIncome: json['dailyIncome']?.toDouble(),
      totalIncome: json['totalIncome']?.toDouble(),
      dailyOnGridEnergy: json['dailyOnGridEnergy']?.toDouble(),
      healthState: json['healthState']?.toInt(),
    );
  }

  /// Factory constructor para crear desde la API de FusionSolar
  factory SolarData.fromFusionSolarApi(Map<String, dynamic> dataItemMap) {
    final now = DateTime.now();

    final dayPower =
        double.tryParse(dataItemMap['day_power']?.toString() ?? '0') ?? 0.0;
    final monthPower =
        double.tryParse(dataItemMap['month_power']?.toString() ?? '0') ?? 0.0;
    final totalPower =
        double.tryParse(dataItemMap['total_power']?.toString() ?? '0') ?? 0.0;
    final dayUseEnergy =
        double.tryParse(dataItemMap['day_use_energy']?.toString() ?? '0') ?? 0.0;
    final dayOnGridEnergy =
        double.tryParse(dataItemMap['day_on_grid_energy']?.toString() ?? '0') ?? 0.0;
    final dayIncome =
        double.tryParse(dataItemMap['day_income']?.toString() ?? '0') ?? 0.0;
    final totalIncome =
        double.tryParse(dataItemMap['total_income']?.toString() ?? '0') ?? 0.0;
    final healthState =
        int.tryParse(dataItemMap['real_health_state']?.toString() ?? '3') ?? 3;

    // Calcular potencia actual estimada basada en la hora del día
    double currentPower = 0.0;
    final hour = now.hour;
    if (hour >= 6 && hour <= 18 && dayPower > 0) {
      // Estimar potencia actual basada en la producción diaria y la hora
      final solarFactor = _calculateSolarFactor(hour);
      currentPower = (dayPower / 8.0) * solarFactor; // Asumiendo 8 horas promedio de sol
    }

    // Estimar consumo actual (simplificado)
    final currentConsumption = dayUseEnergy > 0 ? dayUseEnergy / 24.0 : 2.0;

    return SolarData(
      currentPower: currentPower,
      dailyProduction: dayPower,
      monthlyProduction: monthPower,
      totalProduction: totalPower,
      currentConsumption: currentConsumption,
      dailyConsumption: dayUseEnergy,
      currentExcess: currentPower - currentConsumption,
      batteryLevel: 75.0, // No disponible en la API, usar valor por defecto
      isProducing: currentPower > 0.1,
      timestamp: now,
      dailyIncome: dayIncome,
      totalIncome: totalIncome,
      dailyOnGridEnergy: dayOnGridEnergy,
      healthState: healthState,
    );
  }

  static double _calculateSolarFactor(int hour) {
    // Simular curva solar realista
    if (hour < 6 || hour > 18) return 0;
    const peakHour = 12;
    final distanceFromPeak = (hour - peakHour).abs();
    const maxDistance = 6;
    return 1 - (distanceFromPeak / maxDistance);
  }

  Map<String, dynamic> toJson() {
    return {
      'currentPower': currentPower,
      'dailyProduction': dailyProduction,
      'monthlyProduction': monthlyProduction,
      'totalProduction': totalProduction,
      'currentConsumption': currentConsumption,
      'dailyConsumption': dailyConsumption,
      'currentExcess': currentExcess,
      'batteryLevel': batteryLevel,
      'isProducing': isProducing,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'dailyIncome': dailyIncome,
      'totalIncome': totalIncome,
      'dailyOnGridEnergy': dailyOnGridEnergy,
      'healthState': healthState,
    };
  }

  SolarData copyWith({
    double? currentPower,
    double? dailyProduction,
    double? monthlyProduction,
    double? totalProduction,
    double? currentConsumption,
    double? dailyConsumption,
    double? currentExcess,
    double? batteryLevel,
    bool? isProducing,
    DateTime? timestamp,
    double? dailyIncome,
    double? totalIncome,
    double? dailyOnGridEnergy,
    int? healthState,
  }) {
    return SolarData(
      currentPower: currentPower ?? this.currentPower,
      dailyProduction: dailyProduction ?? this.dailyProduction,
      monthlyProduction: monthlyProduction ?? this.monthlyProduction,
      totalProduction: totalProduction ?? this.totalProduction,
      currentConsumption: currentConsumption ?? this.currentConsumption,
      dailyConsumption: dailyConsumption ?? this.dailyConsumption,
      currentExcess: currentExcess ?? this.currentExcess,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isProducing: isProducing ?? this.isProducing,
      timestamp: timestamp ?? this.timestamp,
      dailyIncome: dailyIncome ?? this.dailyIncome,
      totalIncome: totalIncome ?? this.totalIncome,
      dailyOnGridEnergy: dailyOnGridEnergy ?? this.dailyOnGridEnergy,
      healthState: healthState ?? this.healthState,
    );
  }

  /// Obtiene el estado de salud como texto legible
  String get healthStateText {
    switch (healthState) {
      case 1:
        return 'Desconectado';
      case 2:
        return 'Con fallas';
      case 3:
        return 'Saludable';
      default:
        return 'Desconocido';
    }
  }

  /// Obtiene el color asociado al estado de salud
  Color get healthStateColor {
    switch (healthState) {
      case 1:
        return Colors.grey;
      case 2:
        return Colors.red;
      case 3:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // Constructor que crea una instancia con valores vacíos (sin datos)
  factory SolarData.noData() {
    return SolarData(
      currentPower: 0,
      dailyProduction: 0,
      monthlyProduction: 0,
      totalProduction: 0,
      currentConsumption: 0,
      dailyConsumption: 0,
      currentExcess: 0,
      batteryLevel: 0,
      isProducing: false,
      timestamp: DateTime.now(),
      dailyIncome: 0,
      totalIncome: 0,
      dailyOnGridEnergy: 0,
      healthState: 0,
    );
  }

  @override
  List<Object?> get props => [
        currentPower,
        dailyProduction,
        monthlyProduction,
        totalProduction,
        currentConsumption,
        dailyConsumption,
        currentExcess,
        batteryLevel,
        isProducing,
        timestamp,
        dailyIncome,
        totalIncome,
        dailyOnGridEnergy,
        healthState,
      ];
}
