from fastapi import APIRouter, File, Form, HTTPException, UploadFile, status

from app.repositories.history_repository import HistoryRepository
from app.schemas.estimation import (
    CalibrationRequest,
    CalibrationSummaryResponse,
    CalibrationScenarioSummary,
    EstimateRequest,
    EstimateResponse,
    EstimationRecord,
    ImageAnalysisResponse,
    ImageVolumeEstimateResponse,
)
from app.services.cv_service import ComputerVisionSupportService
from app.services.estimation_service import EstimationService

router = APIRouter(prefix="/estimates", tags=["estimates"])

estimation_service = EstimationService()
history_repository = HistoryRepository()
cv_support_service = ComputerVisionSupportService()


@router.post("", response_model=EstimateResponse, status_code=status.HTTP_201_CREATED)
def create_estimate(payload: EstimateRequest) -> EstimateResponse:
    try:
        calibration_summary = history_repository.get_calibration_summary(
            waste_type=payload.waste_type.value,
            volume_method=payload.volume_method.value,
            calibration_context=payload.calibration_context,
        )
        result = estimation_service.estimate(
            payload,
            calibration_multiplier=calibration_summary["applied_multiplier"],
            calibration_sample_count=calibration_summary["applied_sample_count"],
            calibration_scope=calibration_summary["applied_scope"],
            calibration_context_label=calibration_summary["applied_context_label"],
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    stored_record = history_repository.save_estimation(payload, result)
    return EstimateResponse(result=result, record=EstimationRecord.model_validate(stored_record))


@router.post("/analyze-image", response_model=ImageAnalysisResponse)
async def analyze_image(
    file: UploadFile = File(...),
    content_description: str | None = Form(default=None),
) -> ImageAnalysisResponse:
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Envie um arquivo de imagem valido.",
        )

    file_bytes = await file.read()
    if not file_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="O arquivo enviado esta vazio.",
        )

    try:
        return cv_support_service.analyze_uploaded_image(
            filename=file.filename or "imagem-sem-nome",
            content_type=file.content_type,
            file_bytes=file_bytes,
            content_description=content_description,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc


@router.post("/estimate-volume", response_model=ImageVolumeEstimateResponse)
async def estimate_volume_from_image(
    file: UploadFile = File(...),
    ruler_point_a_x: float = Form(...),
    ruler_point_a_y: float = Form(...),
    ruler_point_b_x: float = Form(...),
    ruler_point_b_y: float = Form(...),
    reference_length_m: float = Form(default=1.0),
) -> ImageVolumeEstimateResponse:
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Envie um arquivo de imagem valido.",
        )

    file_bytes = await file.read()
    if not file_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="O arquivo enviado esta vazio.",
        )

    try:
        return cv_support_service.estimate_volume_from_ruler(
            filename=file.filename or "imagem-sem-nome",
            content_type=file.content_type,
            file_bytes=file_bytes,
            ruler_point_a=(ruler_point_a_x, ruler_point_a_y),
            ruler_point_b=(ruler_point_b_x, ruler_point_b_y),
            reference_length_m=reference_length_m,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc


@router.get("/history", response_model=list[EstimationRecord])
def list_history() -> list[EstimationRecord]:
    records = history_repository.list_estimations()
    return [EstimationRecord.model_validate(record) for record in records]


@router.get("/history/{record_id}", response_model=EstimationRecord)
def get_history_item(record_id: str) -> EstimationRecord:
    try:
        record = history_repository.get_by_id(record_id)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    return EstimationRecord.model_validate(record)


@router.post("/history/{record_id}/calibrate", response_model=EstimationRecord)
def calibrate_history_item(record_id: str, payload: CalibrationRequest) -> EstimationRecord:
    try:
        record = history_repository.save_calibration(
            record_id=record_id,
            actual_mass_kg=payload.actual_mass_kg,
            notes=payload.notes,
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    return EstimationRecord.model_validate(record)


@router.get("/calibration-summary", response_model=CalibrationSummaryResponse)
def get_calibration_summary(
    waste_type: str,
    volume_method: str,
    calibration_context: str | None = None,
) -> CalibrationSummaryResponse:
    summary = history_repository.get_calibration_summary(
        waste_type=waste_type,
        volume_method=volume_method,
        calibration_context=calibration_context,
    )
    return CalibrationSummaryResponse(
        waste_type=waste_type,
        volume_method=volume_method,
        requested_context=summary["requested_context"],
        applied_scope=summary["applied_scope"],
        applied_multiplier=summary["applied_multiplier"],
        applied_sample_count=summary["applied_sample_count"],
        applied_context_label=summary["applied_context_label"],
        total_calibrated_samples=summary["total_calibrated_samples"],
        total_outlier_count=summary["total_outlier_count"],
        scenario_summaries=[
            CalibrationScenarioSummary(**item) for item in summary["scenario_summaries"]
        ],
    )
