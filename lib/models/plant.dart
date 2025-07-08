import 'package:equatable/equatable.dart';

/// Modelo que representa una planta/estación de FusionSolar obtenida de la API
class Plant extends Equatable {
  final String stationCode;
  final String stationName;
  final String? stationAddr;
  final String? stationLinkman;
  final String? linkmanPho;
  final double? capacity;
  final int? aidType;
  final String? buildState;
  final String? combineType;

  const Plant({
    required this.stationCode,
    required this.stationName,
    this.stationAddr,
    this.stationLinkman,
    this.linkmanPho,
    this.capacity,
    this.aidType,
    this.buildState,
    this.combineType,
  });

  factory Plant.fromJson(Map<String, dynamic> json) {
    return Plant(
      stationCode: json['stationCode'] as String,
      stationName: json['stationName'] as String,
      stationAddr: json['stationAddr'] as String?,
      stationLinkman: json['stationLinkman'] as String?,
      linkmanPho: json['linkmanPho'] as String?,
      capacity: (json['capacity'] as num?)?.toDouble(),
      aidType: json['aidType'] as int?,
      buildState: json['buildState'] as String?,
      combineType: json['combineType'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stationCode': stationCode,
      'stationName': stationName,
      'stationAddr': stationAddr,
      'stationLinkman': stationLinkman,
      'linkmanPho': linkmanPho,
      'capacity': capacity,
      'aidType': aidType,
      'buildState': buildState,
      'combineType': combineType,
    };
  }

  @override
  List<Object?> get props => [
        stationCode,
        stationName,
        stationAddr,
        stationLinkman,
        linkmanPho,
        capacity,
        aidType,
        buildState,
        combineType,
      ];
}
