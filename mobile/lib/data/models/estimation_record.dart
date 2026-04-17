class EstimationRecord {
  const EstimationRecord({
    required this.id,
    required this.wasteType,
    required this.volumeMethod,
    required this.estimatedVolumeM3,
    required this.densityKgM3,
    required this.estimatedMassKg,
    required this.lowerBoundKg,
    required this.upperBoundKg,
    required this.confidenceLevel,
    required this.createdAt,
    this.contentDescription,
    this.notes,
  });

  final String id;
  final String wasteType;
  final String volumeMethod;
  final double estimatedVolumeM3;
  final double densityKgM3;
  final double estimatedMassKg;
  final double lowerBoundKg;
  final double upperBoundKg;
  final String confidenceLevel;
  final DateTime createdAt;
  final String? contentDescription;
  final String? notes;

  factory EstimationRecord.fromJson(Map<String, dynamic> json) {
    return EstimationRecord(
      id: json['id'].toString(),
      wasteType: json['waste_type'] as String,
      volumeMethod: json['volume_method'] as String,
      estimatedVolumeM3: (json['estimated_volume_m3'] as num).toDouble(),
      densityKgM3: (json['density_kg_m3'] as num).toDouble(),
      estimatedMassKg: (json['estimated_mass_kg'] as num).toDouble(),
      lowerBoundKg: (json['lower_bound_kg'] as num).toDouble(),
      upperBoundKg: (json['upper_bound_kg'] as num).toDouble(),
      confidenceLevel: json['confidence_level'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      contentDescription: json['content_description'] as String?,
      notes: json['notes'] as String?,
    );
  }
}
