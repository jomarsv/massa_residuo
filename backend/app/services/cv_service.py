import cv2
import numpy as np
import unicodedata

from app.models.enums import VolumeMethod, WasteType
from app.schemas.estimation import (
    ImageAnalysisMetrics,
    ImageAnalysisResponse,
    ImageAnalysisSuggestion,
    ImageAssistedInput,
)


class ComputerVisionSupportService:
    """Servico inicial para futura integracao de classificacao e segmentacao."""

    KEYWORDS_BY_WASTE_TYPE = {
        WasteType.PLASTIC: (
            "plastico",
            "plastico",
            "plastica",
            "pet",
            "embalagem",
            "embalagens",
            "garrafa",
            "garrafas",
            "sacola",
            "sacolas",
        ),
        WasteType.PAPER: (
            "papel",
            "papeis",
            "papelao",
            "caixa",
            "caixas",
            "jornal",
            "revista",
            "folheto",
        ),
        WasteType.ORGANIC: (
            "organico",
            "organica",
            "poda",
            "podas",
            "folha",
            "folhas",
            "galho",
            "galhos",
            "grama",
            "resto",
            "restos",
            "comida",
            "alimento",
            "cascas",
            "jardim",
        ),
        WasteType.RUBBLE: (
            "entulho",
            "obra",
            "cimento",
            "concreto",
            "tijolo",
            "tijolos",
            "bloco",
            "blocos",
            "ceramica",
            "azulejo",
            "areia",
            "brita",
        ),
        WasteType.METAL: (
            "metal",
            "metais",
            "lata",
            "latas",
            "aluminio",
            "ferro",
            "aco",
            "sucata",
            "cobre",
            "fio",
            "fios",
        ),
    }

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
        content_description: str | None = None,
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
            content_description=content_description,
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
        content_description: str | None,
    ) -> ImageAnalysisSuggestion:
        visual_suggestion, visual_confidence, visual_rationale = self._build_visual_suggestion(
            mean_hue=mean_hue,
            mean_saturation=mean_saturation,
            mean_brightness=mean_brightness,
            edge_density=edge_density,
        )
        text_signal = self._build_text_signal(content_description)

        suggested_waste_type = visual_suggestion
        confidence_score = visual_confidence
        rationale = visual_rationale
        used_user_context = False
        context_summary = None

        if text_signal is not None:
            suggested_waste_type = text_signal["waste_type"]
            confidence_score = text_signal["confidence_score"]
            used_user_context = True
            context_summary = text_signal["context_summary"]

            if visual_suggestion == suggested_waste_type:
                confidence_score = min(0.78, confidence_score + 0.06)
                rationale = (
                    f"{text_signal['rationale']} A leitura visual permaneceu compativel com "
                    "essa informacao, mas a classificacao continua assistiva."
                )
            else:
                rationale = (
                    f"{text_signal['rationale']} A imagem foi mantida apenas como apoio, "
                    "porque o conteudo descrito pelo usuario tem prioridade nesta fase."
                )

        confidence_label = self._confidence_label(confidence_score)
        return ImageAnalysisSuggestion(
            suggested_waste_type=suggested_waste_type,
            suggested_volume_method=VolumeMethod.IMAGE_ASSISTED,
            confidence_score=round(confidence_score, 2),
            confidence_label=confidence_label,
            rationale=rationale,
            used_user_context=used_user_context,
            context_summary=context_summary,
        )

    def _build_visual_suggestion(
        self,
        *,
        mean_hue: float,
        mean_saturation: float,
        mean_brightness: float,
        edge_density: float,
    ) -> tuple[WasteType | None, float, str]:
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

        return suggested_waste_type, confidence_score, rationale

    def _build_text_signal(self, content_description: str | None) -> dict | None:
        if not content_description:
            return None

        normalized = self._normalize_text(content_description)
        if not normalized:
            return None

        scores: dict[WasteType, int] = {}
        matches_by_type: dict[WasteType, list[str]] = {}
        for waste_type, keywords in self.KEYWORDS_BY_WASTE_TYPE.items():
            matches = [keyword for keyword in keywords if keyword in normalized]
            if matches:
                scores[waste_type] = len(matches)
                matches_by_type[waste_type] = matches

        if not scores:
            return None

        ranked = sorted(scores.items(), key=lambda item: item[1], reverse=True)
        top_type, top_score = ranked[0]
        second_score = ranked[1][1] if len(ranked) > 1 else 0
        top_matches = matches_by_type[top_type][:3]
        joined_matches = ", ".join(top_matches)

        if top_score == second_score and second_score > 0:
            return {
                "waste_type": top_type,
                "confidence_score": 0.49,
                "context_summary": f"Descricao ambigua com termos como {joined_matches}.",
                "rationale": (
                    "A descricao textual trouxe sinais de mais de um tipo de residuo. "
                    f"Os termos mais fortes apontam para {top_type.value}, mas a confirmacao "
                    "manual continua necessaria."
                ),
            }

        confidence_score = 0.58 if top_score == 1 else 0.68
        return {
            "waste_type": top_type,
            "confidence_score": confidence_score,
            "context_summary": f"Descricao do usuario menciona: {joined_matches}.",
            "rationale": (
                f"A descricao do usuario menciona {joined_matches}, o que torna mais "
                f"plausivel classificar o conteudo como {top_type.value}."
            ),
        }

    @staticmethod
    def _normalize_text(value: str) -> str:
        normalized = unicodedata.normalize("NFD", value)
        without_accents = "".join(char for char in normalized if unicodedata.category(char) != "Mn")
        return without_accents.lower()

    @staticmethod
    def _confidence_label(score: float) -> str:
        if score >= 0.5:
            return "media"
        if score >= 0.3:
            return "baixa-media"
        return "baixa"
