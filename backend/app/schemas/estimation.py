from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.models.enums import (
    CompactionCondition,
    HeterogeneityCondition,
    MoistureCondition,
    VolumeMethod,
    WasteType,
)


class KnownContainerInput(BaseModel):
    capacity_m3: float = Field(..., gt=0, description="Capacidade total do recipiente em m3.")
    fill_percentage: float = Field(..., ge=0, le=100, description="Percentual preenchido do recipiente.")


class ManualDimensionsInput(BaseModel):
    length_m: float = Field(..., gt=0)
    width_m: float = Field(..., gt=0)
    height_m: float = Field(..., gt=0)


class ImageAssistedInput(BaseModel):
    image_path: Optional[str] = Field(default=None, description="Caminho local ou URI da imagem.")
    notes: Optional[str] = Field(default=None, max_length=500)
    estimated_volume_m3: Optional[float] = Field(default=None, gt=0)
    estimated_length_m: Optional[float] = Field(default=None, gt=0)
    estimated_height_m: Optional[float] = Field(default=None, gt=0)
    estimated_depth_m: Optional[float] = Field(default=None, gt=0)
    confidence_score: Optional[float] = Field(default=None, ge=0, le=1)


class RulerPoint(BaseModel):
    x: float = Field(..., ge=0, le=1)
    y: float = Field(..., ge=0, le=1)


class ImageVolumeEstimateMetrics(BaseModel):
    width_px: int
    height_px: int
    pixels_per_meter: float
    foreground_area_px: int
    coverage_ratio: float


class ImageVolumeEstimateResponse(BaseModel):
    filename: str
    content_type: Optional[str] = None
    estimated_volume_m3: float
    estimated_length_m: float
    estimated_height_m: float
    estimated_depth_m: float
    confidence_score: float
    confidence_label: str
    rationale: str
    metrics: ImageVolumeEstimateMetrics
    disclaimer: str


class ImageAnalysisMetrics(BaseModel):
    width_px: int
    height_px: int
    mean_brightness: float
    mean_saturation: float
    edge_density: float


class ImageAnalysisSuggestion(BaseModel):
    suggested_waste_type: Optional[WasteType] = None
    suggested_volume_method: VolumeMethod = VolumeMethod.IMAGE_ASSISTED
    confidence_score: float
    confidence_label: str
    rationale: str
    used_user_context: bool = False
    context_summary: Optional[str] = None


class ImageAnalysisResponse(BaseModel):
    filename: str
    content_type: Optional[str] = None
    metrics: ImageAnalysisMetrics
    suggestion: ImageAnalysisSuggestion
    disclaimer: str


class EstimateRequest(BaseModel):
    waste_type: WasteType
    volume_method: VolumeMethod
    moisture_condition: MoistureCondition
    compaction_condition: CompactionCondition
    heterogeneity_condition: HeterogeneityCondition = HeterogeneityCondition.HOMOGENEOUS
    known_container: Optional[KnownContainerInput] = None
    manual_dimensions: Optional[ManualDimensionsInput] = None
    image_assisted: Optional[ImageAssistedInput] = None
    content_description: Optional[str] = Field(default=None, max_length=300)
    notes: Optional[str] = Field(default=None, max_length=500)

    @model_validator(mode="after")
    def validate_volume_payload(self) -> "EstimateRequest":
        if self.volume_method == VolumeMethod.KNOWN_CONTAINER and not self.known_container:
            raise ValueError("known_container e obrigatorio para recipiente conhecido.")
        if self.volume_method == VolumeMethod.MANUAL_DIMENSIONS and not self.manual_dimensions:
            raise ValueError("manual_dimensions e obrigatorio para dimensoes manuais.")
        if self.volume_method == VolumeMethod.IMAGE_ASSISTED and not self.image_assisted:
            self.image_assisted = ImageAssistedInput()
        return self


class AppliedFactors(BaseModel):
    moisture_factor: float
    compaction_factor: float
    heterogeneity_factor: float


class EstimateResult(BaseModel):
    waste_type: WasteType
    volume_method: VolumeMethod
    estimated_volume_m3: float
    density_kg_m3: float
    applied_factors: AppliedFactors
    calibration_multiplier: float = 1.0
    estimated_mass_kg: float
    lower_bound_kg: float
    upper_bound_kg: float
    confidence_level: str
    disclaimer: str


class EstimationRecord(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str | int
    waste_type: WasteType
    volume_method: VolumeMethod
    estimated_volume_m3: float
    density_kg_m3: float
    estimated_mass_kg: float
    lower_bound_kg: float
    upper_bound_kg: float
    confidence_level: str
    created_at: datetime
    content_description: Optional[str] = None
    actual_mass_kg: Optional[float] = None
    calibration_notes: Optional[str] = None
    calibrated_at: Optional[datetime] = None
    notes: Optional[str] = None


class EstimateResponse(BaseModel):
    result: EstimateResult
    record: EstimationRecord


class CalibrationRequest(BaseModel):
    actual_mass_kg: float = Field(..., gt=0)
    notes: Optional[str] = Field(default=None, max_length=500)


class ReferenceDataResponse(BaseModel):
    waste_densities_kg_m3: dict[str, float]
    moisture_factors: dict[str, float]
    compaction_factors: dict[str, float]
    heterogeneity_factors: dict[str, float]
    supported_volume_methods: list[str]
