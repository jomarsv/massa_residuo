import cv2
import numpy as np

from app.models.enums import WasteType
from app.services.cv_service import ComputerVisionSupportService


def test_analyze_uploaded_image_returns_metrics_and_suggestion():
    image = np.zeros((64, 64, 3), dtype=np.uint8)
    image[:, :] = (40, 180, 40)
    success, encoded = cv2.imencode(".jpg", image)
    assert success

    service = ComputerVisionSupportService()
    result = service.analyze_uploaded_image(
        filename="green.jpg",
        content_type="image/jpeg",
        file_bytes=encoded.tobytes(),
    )

    assert result.metrics.width_px == 64
    assert result.metrics.height_px == 64
    assert result.suggestion.suggested_waste_type == WasteType.ORGANIC
    assert result.suggestion.suggested_volume_method.value == "estimativa_assistida_imagem"


def test_analyze_uploaded_image_prioritizes_user_description():
    image = np.zeros((64, 64, 3), dtype=np.uint8)
    image[:, :] = (180, 180, 180)
    success, encoded = cv2.imencode(".jpg", image)
    assert success

    service = ComputerVisionSupportService()
    result = service.analyze_uploaded_image(
        filename="bags.jpg",
        content_type="image/jpeg",
        file_bytes=encoded.tobytes(),
        content_description="Folhas, galhos e restos de poda em sacos.",
    )

    assert result.suggestion.suggested_waste_type == WasteType.ORGANIC
    assert result.suggestion.used_user_context is True
    assert result.suggestion.context_summary is not None
    assert result.suggestion.confidence_score >= 0.58
