import 'dart:async';
import 'dart:math';
import '../models/solar_data.dart';

class FusionSolarService {
  // En una implementación real, aquí tendríamos la integración con la API de Fusion Solar
  // Por ahora, simularemos datos realistas
  
  final Random _random = Random();

  Future<SolarData> getCurrentData() async {
    // Simular llamada a la API
    await Future.delayed(const Duration(milliseconds: 800));

    final now = DateTime.now();
    final hour = now.hour;
    
    // Simular patrones realistas de generación solar
    double currentPower = 0;
    if (hour >= 6 && hour <= 18) {
      // Simular curva solar durante el día
      final solarFactor = _calculateSolarFactor(hour);
      currentPower = 5.0 * solarFactor + _random.nextDouble() * 2.0;
    }

    // Simular consumo base más variaciones
    final baseConsumption = 2.0 + _random.nextDouble() * 1.5;
    final currentConsumption = baseConsumption + _getTimeBasedConsumption(hour);

    return SolarData(
      currentPower: currentPower,
      dailyProduction: _calculateDailyProduction(now),
      monthlyProduction: 450.0 + _random.nextDouble() * 100.0,
      totalProduction: 12500.0 + _random.nextDouble() * 500.0,
      currentConsumption: currentConsumption,
      dailyConsumption: 25.0 + _random.nextDouble() * 10.0,
      currentExcess: currentPower - currentConsumption,
      batteryLevel: 75.0 + _random.nextDouble() * 20.0,
      isProducing: currentPower > 0.1,
      timestamp: now,
    );
  }

  Future<List<SolarData>> getHistoricalData({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    await Future.delayed(const Duration(seconds: 1));
    
    final data = <SolarData>[];
    var currentDate = startDate;
    
    while (currentDate.isBefore(endDate)) {
      // Generar datos históricos simulados
      data.add(SolarData(
        currentPower: 0, // Los datos históricos no incluyen potencia instantánea
        dailyProduction: 15.0 + _random.nextDouble() * 25.0,
        monthlyProduction: 0,
        totalProduction: 0,
        currentConsumption: 0,
        dailyConsumption: 20.0 + _random.nextDouble() * 15.0,
        currentExcess: 0,
        batteryLevel: 50.0 + _random.nextDouble() * 40.0,
        isProducing: false,
        timestamp: currentDate,
      ));
      
      currentDate = currentDate.add(const Duration(days: 1));
    }
    
    return data;
  }

  double _calculateSolarFactor(int hour) {
    // Simular curva solar realista
    if (hour < 6 || hour > 18) return 0;
    
    const peakHour = 12;
    final distanceFromPeak = (hour - peakHour).abs();
    const maxDistance = 6;
    
    return 1 - (distanceFromPeak / maxDistance);
  }

  double _getTimeBasedConsumption(int hour) {
    // Simular patrones de consumo típicos
    if (hour >= 7 && hour <= 9) return 1.5; // Mañana
    if (hour >= 18 && hour <= 22) return 2.0; // Noche
    return 0.5; // Resto del día
  }

  double _calculateDailyProduction(DateTime date) {
    final hour = date.hour;
    if (hour < 19) {
      // Si aún no ha terminado el día, calcular producción parcial
      final completedHours = hour - 6; // Asumiendo que la producción empieza a las 6 AM
      if (completedHours <= 0) return 0;
      
      const totalDayProduction = 30.0;
      final factor = completedHours / 12.0; // 12 horas de producción
      return totalDayProduction * factor + _random.nextDouble() * 5.0;
    }
    
    // Día completo
    return 25.0 + _random.nextDouble() * 15.0;
  }
}
