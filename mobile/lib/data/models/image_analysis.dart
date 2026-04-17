class ImageAnalysisMetrics {
  const ImageAnalysisMetrics({
    required this.widthPx,
    required this.heightPx,
    required this.meanBrightness,
    required this.meanSaturation,
    required this.edgeDensity,
  });

  final int widthPx;
  final int heightPx;
  final double meanBrightness;
  final double meanSaturation;
  final double edgeDensity;

  factory ImageAnalysisMetrics.fromJson(Map<String, dynamic> json) {
    return ImageAnalysisMetrics(
      widthPx: json['width_px'] as int,
      heightPx: json['height_px'] as int,
      meanBrightness: (json['mean_brightness'] as num).toDouble(),
      meanSaturation: (json['mean_saturation'] as num).toDouble(),
      edgeDensity: (json['edge_density'] as num).toDouble(),
    );
  }
}

class ImageAnalysisSuggestion {
  const ImageAnalysisSuggestion({
    required this.suggestedWasteType,
    required this.suggestedVolumeMethod,
    required this.confidenceScore,
    required this.confidenceLabel,
    required this.rationale,
    required this.usedUserContext,
    required this.contextSummary,
  });

  final String? suggestedWasteType;
  final String suggestedVolumeMethod;
  final double confidenceScore;
  final String confidenceLabel;
  final String rationale;
  final bool usedUserContext;
  final String? contextSummary;

  factory ImageAnalysisSuggestion.fromJson(Map<String, dynamic> json) {
    return ImageAnalysisSuggestion(
      suggestedWasteType: json['suggested_waste_type'] as String?,
      suggestedVolumeMethod: json['suggested_volume_method'] as String,
      confidenceScore: (json['confidence_score'] as num).toDouble(),
      confidenceLabel: json['confidence_label'] as String,
      rationale: json['rationale'] as String,
      usedUserContext: json['used_user_context'] as bool? ?? false,
      contextSummary: json['context_summary'] as String?,
    );
  }
}

class ImageAnalysisResponse {
  const ImageAnalysisResponse({
    required this.filename,
    required this.contentType,
    required this.metrics,
    required this.suggestion,
    required this.disclaimer,
  });

  final String filename;
  final String? contentType;
  final ImageAnalysisMetrics metrics;
  final ImageAnalysisSuggestion suggestion;
  final String disclaimer;

  factory ImageAnalysisResponse.fromJson(Map<String, dynamic> json) {
    return ImageAnalysisResponse(
      filename: json['filename'] as String,
      contentType: json['content_type'] as String?,
      metrics: ImageAnalysisMetrics.fromJson(
        json['metrics'] as Map<String, dynamic>,
      ),
      suggestion: ImageAnalysisSuggestion.fromJson(
        json['suggestion'] as Map<String, dynamic>,
      ),
      disclaimer: json['disclaimer'] as String,
    );
  }
}
