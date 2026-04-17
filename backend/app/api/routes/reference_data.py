from fastapi import APIRouter

from app.config.settings import (
    COMPACTION_FACTORS,
    HETEROGENEITY_FACTORS,
    MOISTURE_FACTORS,
    WASTE_DENSITIES_KG_M3,
)
from app.models.enums import VolumeMethod
from app.schemas.estimation import ReferenceDataResponse

router = APIRouter(prefix="/reference-data", tags=["reference-data"])


@router.get("", response_model=ReferenceDataResponse)
def get_reference_data() -> ReferenceDataResponse:
    return ReferenceDataResponse(
        waste_densities_kg_m3={key.value: value for key, value in WASTE_DENSITIES_KG_M3.items()},
        moisture_factors={key.value: value for key, value in MOISTURE_FACTORS.items()},
        compaction_factors={key.value: value for key, value in COMPACTION_FACTORS.items()},
        heterogeneity_factors={key.value: value for key, value in HETEROGENEITY_FACTORS.items()},
        supported_volume_methods=[item.value for item in VolumeMethod],
    )
