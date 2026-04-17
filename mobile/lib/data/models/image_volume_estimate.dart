class ImageVolumeEstimateMetrics {
  const ImageVolumeEstimateMetrics({
    required this.widthPx,
    required this.heightPx,
    required this.pixelsPerMeter,
    required this.foregroundAreaPx,
    required this.coverageRatio,
  });

  final int widthPx;
  final int heightPx;
  final double pixelsPerMeter;
  final int foregroundAreaPx;
  final double coverageRatio;

  factory ImageVolumeEstimateMetrics.fromJson(Map<String, dynamic> json) {
    return ImageVolumeEstimateMetrics(
      widthPx: json['width_px'] as int,
      heightPx: json['height_px'] as int,
      pixelsPerMeter: (json['pixels_per_meter'] as num).toDouble(),
      foregroundAreaPx: json['foreground_area_px'] as int,
      coverageRatio: (json['coverage_ratio'] as num).toDouble(),
    );
  }
}

class ImageVolumeEstimateResponse {
  const ImageVolumeEstimateResponse({
    required this.filename,
    required this.contentType,
    required this.estimatedVolumeM3,
    required this.estimatedLengthM,
    required this.estimatedHeightM,
    required this.estimatedDepthM,
    required this.confidenceScore,
    required this.confidenceLabel,
    required this.rationale,
    required this.metrics,
    required this.disclaimer,
  });

  final String filename;
  final String? contentType;
  final double estimatedVolumeM3;
  final double estimatedLengthM;
  final double estimatedHeightM;
  final double estimatedDepthM;
  final double confidenceScore;
  final String confidenceLabel;
  final String rationale;
  final ImageVolumeEstimateMetrics metrics;
  final String disclaimer;

  factory ImageVolumeEstimateResponse.fromJson(Map<String, dynamic> json) {
    return ImageVolumeEstimateResponse(
      filename: json['filename'] as String,
      contentType: json['content_type'] as String?,
      estimatedVolumeM3: (json['estimated_volume_m3'] as num).toDouble(),
      estimatedLengthM: (json['estimated_length_m'] as num).toDouble(),
      estimatedHeightM: (json['estimated_height_m'] as num).toDouble(),
      estimatedDepthM: (json['estimated_depth_m'] as num).toDouble(),
      confidenceScore: (json['confidence_score'] as num).toDouble(),
      confidenceLabel: json['confidence_label'] as String,
      rationale: json['rationale'] as String,
      metrics: ImageVolumeEstimateMetrics.fromJson(
        json['metrics'] as Map<String, dynamic>,
      ),
      disclaimer: json['disclaimer'] as String,
    );
  }
}
