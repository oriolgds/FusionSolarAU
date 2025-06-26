import 'package:equatable/equatable.dart';

class SolarData extends Equatable {
  final double currentPower; // kW - Potencia actual generada
  final double dailyProduction; // kWh - Producción del día
  final double monthlyProduction; // kWh - Producción del mes
  final double totalProduction; // kWh - Producción total
  final double currentConsumption; // kW - Consumo actual
  final double dailyConsumption; // kWh - Consumo del día
  final double currentExcess; // kW - Excedente actual (positivo = exportando)
  final double batteryLevel; // % - Nivel de batería (si aplica)
  final bool isProducing; // Si está generando energía
  final DateTime timestamp;

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
    );
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
      ];
}
