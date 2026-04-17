from fastapi import APIRouter, HTTPException, status

from app.repositories.history_repository import HistoryRepository
from app.schemas.estimation import EstimateRequest, EstimateResponse, EstimationRecord
from app.services.estimation_service import EstimationService

router = APIRouter(prefix="/estimates", tags=["estimates"])

estimation_service = EstimationService()
history_repository = HistoryRepository()


@router.post("", response_model=EstimateResponse, status_code=status.HTTP_201_CREATED)
def create_estimate(payload: EstimateRequest) -> EstimateResponse:
    result = estimation_service.estimate(payload)
    stored_record = history_repository.save_estimation(payload, result)
    return EstimateResponse(result=result, record=EstimationRecord.model_validate(stored_record))


@router.get("/history", response_model=list[EstimationRecord])
def list_history() -> list[EstimationRecord]:
    records = history_repository.list_estimations()
    return [EstimationRecord.model_validate(record) for record in records]


@router.get("/history/{record_id}", response_model=EstimationRecord)
def get_history_item(record_id: int) -> EstimationRecord:
    try:
        record = history_repository.get_by_id(record_id)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    return EstimationRecord.model_validate(record)
