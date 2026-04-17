from app.config.settings import (
    COMPACTION_FACTORS,
    CONFIDENCE_LABEL_BY_METHOD,
    HETEROGENEITY_FACTORS,
    MOISTURE_FACTORS,
    UNCERTAINTY_MARGIN_BY_METHOD,
    WASTE_DENSITIES_KG_M3,
)
from app.models.enums import VolumeMethod
from app.schemas.estimation import AppliedFactors, EstimateRequest, EstimateResult
from app.services.cv_service import ComputerVisionSupportService


class EstimationService:
    def __init__(self) -> None:
        self.cv_support_service = ComputerVisionSupportService()

    def estimate(self, payload: EstimateRequest) -> EstimateResult:
        estimated_volume = self._estimate_volume(payload)
        density = WASTE_DENSITIES_KG_M3[payload.waste_type]
        moisture_factor = MOISTURE_FACTORS[payload.moisture_condition]
        compaction_factor = COMPACTION_FACTORS[payload.compaction_condition]
        heterogeneity_factor = HETEROGENEITY_FACTORS[payload.heterogeneity_condition]

        estimated_mass = estimated_volume * density * moisture_factor * compaction_factor * heterogeneity_factor
        uncertainty_margin = UNCERTAINTY_MARGIN_BY_METHOD[payload.volume_method.value]
        lower_bound = estimated_mass * (1 - uncertainty_margin)
        upper_bound = estimated_mass * (1 + uncertainty_margin)

        return EstimateResult(
            waste_type=payload.waste_type,
            volume_method=payload.volume_method,
            estimated_volume_m3=round(estimated_volume, 4),
            density_kg_m3=round(density, 2),
            applied_factors=AppliedFactors(
                moisture_factor=moisture_factor,
                compaction_factor=compaction_factor,
                heterogeneity_factor=heterogeneity_factor,
            ),
            estimated_mass_kg=round(estimated_mass, 2),
            lower_bound_kg=round(lower_bound, 2),
            upper_bound_kg=round(upper_bound, 2),
            confidence_level=CONFIDENCE_LABEL_BY_METHOD[payload.volume_method.value],
            disclaimer=(
                "Este resultado e uma estimativa tecnica baseada em volume aparente, "
                "densidade aparente e fatores configuraveis. Nao substitui pesagem real."
            ),
        )

    def _estimate_volume(self, payload: EstimateRequest) -> float:
        if payload.volume_method == VolumeMethod.KNOWN_CONTAINER:
            container = payload.known_container
            assert container is not None
            return container.capacity_m3 * (container.fill_percentage / 100.0)

        if payload.volume_method == VolumeMethod.MANUAL_DIMENSIONS:
            dimensions = payload.manual_dimensions
            assert dimensions is not None
            return dimensions.length_m * dimensions.width_m * dimensions.height_m

        image_assisted = payload.image_assisted
        if image_assisted and image_assisted.estimated_volume_m3:
            return image_assisted.estimated_volume_m3

        self.cv_support_service.analyze_image(payload.image_assisted)
        raise ValueError(
            "A estimativa assistida por imagem exige calibracao previa com a regua visivel. "
            "Marque os 2 pontos de 1 metro e gere o volume antes de calcular a massa."
        )
