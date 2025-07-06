import 'dart:async';
import 'dart:convert';
import 'dart:math';
import '../models/solar_data.dart';
import '../providers/plant_provider.dart';
import 'fusion_solar_oauth_service.dart';

class FusionSolarService {
  final FusionSolarOAuthService _oauthService = FusionSolarOAuthService();
  final Random _random = Random();

  Future<SolarData> getCurrentData({String? stationCode}) async {
    try {
      // Verificar si hay configuración OAuth válida
      final hasValidConfig = await _oauthService.hasValidOAuthConfig();

      if (!hasValidConfig) {
        // Si no hay configuración válida, devolver objeto con valores vacíos
        return SolarData.noData();
      }

      // Si no se proporciona stationCode, usar datos vacíos
      if (stationCode == null || stationCode.isEmpty) {
        print('No station code provided, returning empty data');
        return SolarData.noData();
      }

      // Intentar obtener datos reales de FusionSolar usando la API de tiempo real
      final data = await _oauthService.handleApiCall(
        '/thirdData/getStationRealKpi',
        method: 'POST',
        body: {
          'stationCodes': stationCode,
        },
      );

      if (data != null && data['success'] == true && data['data'] is List) {
        final List<dynamic> stations = data['data'];
        if (stations.isNotEmpty) {
          final stationData = stations.first as Map<String, dynamic>;
          final dataItemMap = stationData['dataItemMap'] as Map<String, dynamic>;
          return SolarData.fromFusionSolarApi(dataItemMap);
        } else {
          print('No station data returned from API');
          return SolarData.noData();
        }
      } else {
        print(
          'Error obteniendo datos reales: ${data?['message'] ?? 'Unknown error'}',
        );
        // Devolver objeto con valores vacíos en caso de error
        return SolarData.noData();
      }
    } catch (e) {
      print('Error en getCurrentData: $e');
      // Devolver objeto con valores vacíos en caso de error
      return SolarData.noData();
    }
  }

  Future<List<SolarData>> getHistoricalData({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final hasValidConfig = await _oauthService.hasValidOAuthConfig();

      if (!hasValidConfig) {
        // Devolver lista vacía si no hay configuración válida
        return [];
      }

      // Aquí implementarías la llamada real a la API histórica
      // Por ahora, devolver lista vacía ya que no tenemos datos reales
      return [];
    } catch (e) {
      print('Error obteniendo datos históricos: $e');
      return [];
    }
  }

  SolarData _getSimulatedData() {
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
      dailyIncome: _random.nextDouble() * 12.0, // Explícitamente en euros
      totalIncome: 2100.0 + _random.nextDouble() * 400.0, // Explícitamente en euros
      dailyOnGridEnergy: _random.nextDouble() * 20.0,
      healthState: 3, // Saludable por defecto
    );
  }

  List<SolarData> _getSimulatedHistoricalData(
    DateTime startDate,
    DateTime endDate,
  ) {
    final data = <SolarData>[];
    var currentDate = startDate;

    while (currentDate.isBefore(endDate)) {
      // Generar datos históricos simulados
      data.add(
        SolarData(
          currentPower:
              0, // Los datos históricos no incluyen potencia instantánea
          dailyProduction: 15.0 + _random.nextDouble() * 25.0,
          monthlyProduction: 0,
          totalProduction: 0,
          currentConsumption: 0,
          dailyConsumption: 20.0 + _random.nextDouble() * 15.0,
          currentExcess: 0,
          batteryLevel: 50.0 + _random.nextDouble() * 40.0,
          isProducing: false,
          timestamp: currentDate,
          dailyIncome: _random.nextDouble() * 15.0, // Explícitamente en euros
          totalIncome: 0,
          dailyOnGridEnergy: 15.0 + _random.nextDouble() * 20.0,
          healthState: 3,
        ),
      );

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
      final completedHours =
          hour - 6; // Asumiendo que la producción empieza a las 6 AM
      if (completedHours <= 0) return 0;

      const totalDayProduction = 30.0;
      final factor = completedHours / 12.0; // 12 horas de producción
      return totalDayProduction * factor + _random.nextDouble() * 5.0;
    }

    // Día completo
    return 25.0 + _random.nextDouble() * 15.0;
  }
}
