import 'estimation_record.dart';

class AppliedFactorsModel {
  const AppliedFactorsModel({
    required this.moistureFactor,
    required this.compactionFactor,
    required this.heterogeneityFactor,
  });

  final double moistureFactor;
  final double compactionFactor;
  final double heterogeneityFactor;

  factory AppliedFactorsModel.fromJson(Map<String, dynamic> json) {
    return AppliedFactorsModel(
      moistureFactor: (json['moisture_factor'] as num).toDouble(),
      compactionFactor: (json['compaction_factor'] as num).toDouble(),
      heterogeneityFactor: (json['heterogeneity_factor'] as num).toDouble(),
    );
  }
}

class EstimateResultModel {
  const EstimateResultModel({
    required this.wasteType,
    required this.volumeMethod,
    required this.estimatedVolumeM3,
    required this.densityKgM3,
    required this.appliedFactors,
    required this.calibrationMultiplier,
    required this.calibrationSampleCount,
    required this.calibrationScope,
    this.calibrationContextLabel,
    required this.estimatedMassKg,
    required this.lowerBoundKg,
    required this.upperBoundKg,
    required this.confidenceLevel,
    required this.disclaimer,
  });

  final String wasteType;
  final String volumeMethod;
  final double estimatedVolumeM3;
  final double densityKgM3;
  final AppliedFactorsModel appliedFactors;
  final double calibrationMultiplier;
  final int calibrationSampleCount;
  final String calibrationScope;
  final String? calibrationContextLabel;
  final double estimatedMassKg;
  final double lowerBoundKg;
  final double upperBoundKg;
  final String confidenceLevel;
  final String disclaimer;

  factory EstimateResultModel.fromJson(Map<String, dynamic> json) {
    return EstimateResultModel(
      wasteType: json['waste_type'] as String,
      volumeMethod: json['volume_method'] as String,
      estimatedVolumeM3: (json['estimated_volume_m3'] as num).toDouble(),
      densityKgM3: (json['density_kg_m3'] as num).toDouble(),
      appliedFactors: AppliedFactorsModel.fromJson(
        json['applied_factors'] as Map<String, dynamic>,
      ),
      calibrationMultiplier:
          (json['calibration_multiplier'] as num?)?.toDouble() ?? 1.0,
      calibrationSampleCount:
          (json['calibration_sample_count'] as num?)?.toInt() ?? 0,
      calibrationScope: json['calibration_scope'] as String? ?? 'nenhuma',
      calibrationContextLabel: json['calibration_context_label'] as String?,
      estimatedMassKg: (json['estimated_mass_kg'] as num).toDouble(),
      lowerBoundKg: (json['lower_bound_kg'] as num).toDouble(),
      upperBoundKg: (json['upper_bound_kg'] as num).toDouble(),
      confidenceLevel: json['confidence_level'] as String,
      disclaimer: json['disclaimer'] as String,
    );
  }
}

class EstimateResponseModel {
  const EstimateResponseModel({required this.result, required this.record});

  final EstimateResultModel result;
  final EstimationRecord record;

  factory EstimateResponseModel.fromJson(Map<String, dynamic> json) {
    return EstimateResponseModel(
      result: EstimateResultModel.fromJson(
        json['result'] as Map<String, dynamic>,
      ),
      record: EstimationRecord.fromJson(json['record'] as Map<String, dynamic>),
    );
  }
}
