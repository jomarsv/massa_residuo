from app.schemas.estimation import ImageAssistedInput


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
