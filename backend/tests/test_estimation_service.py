from app.models.enums import (
    CompactionCondition,
    HeterogeneityCondition,
    MoistureCondition,
    VolumeMethod,
    WasteType,
)
from app.schemas.estimation import EstimateRequest, KnownContainerInput, ManualDimensionsInput
from app.services.estimation_service import EstimationService


def test_estimate_with_known_container():
    service = EstimationService()
    payload = EstimateRequest(
        waste_type=WasteType.PLASTIC,
        volume_method=VolumeMethod.KNOWN_CONTAINER,
        moisture_condition=MoistureCondition.DRY,
        compaction_condition=CompactionCondition.LOOSE,
        heterogeneity_condition=HeterogeneityCondition.HOMOGENEOUS,
        known_container=KnownContainerInput(capacity_m3=1.0, fill_percentage=50),
    )

    result = service.estimate(payload)

    assert result.estimated_volume_m3 == 0.5
    assert result.density_kg_m3 == 45.0
    assert result.estimated_mass_kg == 22.5
    assert result.lower_bound_kg < result.estimated_mass_kg < result.upper_bound_kg


def test_estimate_with_manual_dimensions_and_factors():
    service = EstimationService()
    payload = EstimateRequest(
        waste_type=WasteType.ORGANIC,
        volume_method=VolumeMethod.MANUAL_DIMENSIONS,
        moisture_condition=MoistureCondition.WET,
        compaction_condition=CompactionCondition.COMPACTED,
        heterogeneity_condition=HeterogeneityCondition.MIXED,
        manual_dimensions=ManualDimensionsInput(length_m=1.0, width_m=0.5, height_m=0.4),
    )

    result = service.estimate(payload)

    assert result.estimated_volume_m3 == 0.2
    assert result.estimated_mass_kg == 127.51
    assert result.confidence_level == "media"


def test_estimate_with_image_assisted_volume_raises_clear_error():
    service = EstimationService()
    payload = EstimateRequest(
        waste_type=WasteType.ORGANIC,
        volume_method=VolumeMethod.IMAGE_ASSISTED,
        moisture_condition=MoistureCondition.DRY,
        compaction_condition=CompactionCondition.LOOSE,
        heterogeneity_condition=HeterogeneityCondition.HOMOGENEOUS,
    )

    try:
        service.estimate(payload)
    except ValueError as exc:
        assert "ainda nao calcula volume automaticamente" in str(exc)
    else:
        raise AssertionError("Era esperado erro para volume por imagem sem implementacao.")
