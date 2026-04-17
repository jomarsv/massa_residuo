from fastapi import APIRouter, File, Form, HTTPException, UploadFile, status

from app.repositories.history_repository import HistoryRepository
from app.schemas.estimation import (
    CalibrationRequest,
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
        calibration_multiplier = history_repository.get_calibration_multiplier(
            payload.waste_type.value,
            payload.volume_method.value,
        )
        result = estimation_service.estimate(
            payload,
            calibration_multiplier=calibration_multiplier,
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
