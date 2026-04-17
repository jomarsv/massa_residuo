import cv2
import numpy as np

from app.models.enums import VolumeMethod, WasteType
from app.schemas.estimation import (
    ImageAnalysisMetrics,
    ImageAnalysisResponse,
    ImageAnalysisSuggestion,
    ImageAssistedInput,
)


class ComputerVisionSupportService:
    """Servico inicial para futura integracao de classificacao e segmentacao."""

    def analyze_image(self, payload: ImageAssistedInput | None) -> dict:
        image_path = payload.image_path if payload else None
        return {
            "status": "not_implemented",
            "image_path": image_path,
            "message": (
                "A analise assistida por imagem ainda nao estima volume automaticamente. "
                "O modulo foi preparado para futura integracao com OpenCV, YOLO ou TensorFlow Lite."
            ),
        }

    def analyze_uploaded_image(
        self,
        *,
        filename: str,
        content_type: str | None,
        file_bytes: bytes,
    ) -> ImageAnalysisResponse:
        image_array = np.frombuffer(file_bytes, dtype=np.uint8)
        image = cv2.imdecode(image_array, cv2.IMREAD_COLOR)
        if image is None:
            raise ValueError("Nao foi possivel ler a imagem enviada.")

        height, width = image.shape[:2]
        hsv_image = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
        gray_image = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        edges = cv2.Canny(gray_image, 80, 160)

        mean_brightness = float(np.mean(gray_image))
        mean_saturation = float(np.mean(hsv_image[:, :, 1]))
        edge_density = float(np.count_nonzero(edges) / edges.size)
        mean_hue = float(np.mean(hsv_image[:, :, 0]))

        suggestion = self._build_suggestion(
            mean_hue=mean_hue,
            mean_saturation=mean_saturation,
            mean_brightness=mean_brightness,
            edge_density=edge_density,
        )

        return ImageAnalysisResponse(
            filename=filename,
            content_type=content_type,
            metrics=ImageAnalysisMetrics(
                width_px=width,
                height_px=height,
                mean_brightness=round(mean_brightness, 2),
                mean_saturation=round(mean_saturation, 2),
                edge_density=round(edge_density, 4),
            ),
            suggestion=suggestion,
            disclaimer=(
                "A analise por imagem e apenas assistiva. O sistema usa heuristicas "
                "visuais simples para sugerir preenchimento do formulario, sem prometer "
                "classificacao ou estimativa de massa automatica."
            ),
        )

    def _build_suggestion(
        self,
        *,
        mean_hue: float,
        mean_saturation: float,
        mean_brightness: float,
        edge_density: float,
    ) -> ImageAnalysisSuggestion:
        suggested_waste_type: WasteType | None = None
        confidence_score = 0.22
        rationale = (
            "A imagem nao apresentou um padrao visual forte o suficiente; mantenha a "
            "confirmacao manual do tipo de residuo."
        )

        if edge_density > 0.18 and mean_saturation < 55:
            suggested_waste_type = WasteType.RUBBLE
            confidence_score = 0.48
            rationale = (
                "Alta densidade de bordas e baixa saturacao sugerem fragmentos irregulares, "
                "mais proximos de entulho."
            )
        elif 20 <= mean_hue <= 95 and mean_saturation > 70:
            suggested_waste_type = WasteType.ORGANIC
            confidence_score = 0.43
            rationale = (
                "Faixa de matiz entre amarelo e verde com saturacao elevada sugere material "
                "organico ou vegetacao misturada."
            )
        elif mean_saturation < 45 and mean_brightness > 150:
            suggested_waste_type = WasteType.PAPER
            confidence_score = 0.37
            rationale = (
                "Baixa saturacao com brilho alto pode indicar papel, papelao claro ou fundo "
                "com baixa variedade cromatica."
            )
        elif mean_saturation > 90 and edge_density < 0.12:
            suggested_waste_type = WasteType.PLASTIC
            confidence_score = 0.35
            rationale = (
                "Saturacao elevada com baixa densidade de bordas pode ser compativel com "
                "superficies plasticas ou sacos compactados."
            )
        elif mean_saturation < 80 and 85 <= mean_brightness <= 170 and edge_density > 0.10:
            suggested_waste_type = WasteType.METAL
            confidence_score = 0.31
            rationale = (
                "Brilho intermediario com contraste de bordas pode corresponder a objetos "
                "metalicos, mas a confianca continua baixa."
            )

        confidence_label = self._confidence_label(confidence_score)
        return ImageAnalysisSuggestion(
            suggested_waste_type=suggested_waste_type,
            suggested_volume_method=VolumeMethod.IMAGE_ASSISTED,
            confidence_score=round(confidence_score, 2),
            confidence_label=confidence_label,
            rationale=rationale,
        )

    @staticmethod
    def _confidence_label(score: float) -> str:
        if score >= 0.5:
            return "media"
        if score >= 0.3:
            return "baixa-media"
        return "baixa"
