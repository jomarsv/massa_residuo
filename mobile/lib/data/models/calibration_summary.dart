class CalibrationScenarioSummaryModel {
  const CalibrationScenarioSummaryModel({
    required this.label,
    this.calibrationContext,
    required this.sampleCount,
    required this.medianMultiplier,
    required this.minMultiplier,
    required this.maxMultiplier,
    required this.outlierCount,
  });

  final String label;
  final String? calibrationContext;
  final int sampleCount;
  final double medianMultiplier;
  final double minMultiplier;
  final double maxMultiplier;
  final int outlierCount;

  factory CalibrationScenarioSummaryModel.fromJson(Map<String, dynamic> json) {
    return CalibrationScenarioSummaryModel(
      label: json['label'] as String,
      calibrationContext: json['calibration_context'] as String?,
      sampleCount: (json['sample_count'] as num).toInt(),
      medianMultiplier: (json['median_multiplier'] as num).toDouble(),
      minMultiplier: (json['min_multiplier'] as num).toDouble(),
      maxMultiplier: (json['max_multiplier'] as num).toDouble(),
      outlierCount: (json['outlier_count'] as num).toInt(),
    );
  }
}

class CalibrationSummaryModel {
  const CalibrationSummaryModel({
    required this.wasteType,
    required this.volumeMethod,
    this.requestedContext,
    required this.appliedScope,
    required this.appliedMultiplier,
    required this.appliedSampleCount,
    this.appliedContextLabel,
    required this.totalCalibratedSamples,
    required this.totalOutlierCount,
    required this.scenarioSummaries,
  });

  final String wasteType;
  final String volumeMethod;
  final String? requestedContext;
  final String appliedScope;
  final double appliedMultiplier;
  final int appliedSampleCount;
  final String? appliedContextLabel;
  final int totalCalibratedSamples;
  final int totalOutlierCount;
  final List<CalibrationScenarioSummaryModel> scenarioSummaries;

  factory CalibrationSummaryModel.fromJson(Map<String, dynamic> json) {
    return CalibrationSummaryModel(
      wasteType: json['waste_type'] as String,
      volumeMethod: json['volume_method'] as String,
      requestedContext: json['requested_context'] as String?,
      appliedScope: json['applied_scope'] as String,
      appliedMultiplier: (json['applied_multiplier'] as num).toDouble(),
      appliedSampleCount: (json['applied_sample_count'] as num).toInt(),
      appliedContextLabel: json['applied_context_label'] as String?,
      totalCalibratedSamples: (json['total_calibrated_samples'] as num).toInt(),
      totalOutlierCount: (json['total_outlier_count'] as num).toInt(),
      scenarioSummaries: (json['scenario_summaries'] as List<dynamic>)
          .map(
            (item) => CalibrationScenarioSummaryModel.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}
