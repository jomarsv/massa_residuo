import cv2
import numpy as np
import unicodedata

from app.models.enums import VolumeMethod, WasteType
from app.schemas.estimation import (
    ImageAnalysisMetrics,
    ImageAnalysisResponse,
    ImageAnalysisSuggestion,
    ImageAssistedInput,
    ImageVolumeEstimateMetrics,
    ImageVolumeEstimateResponse,
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

    def estimate_volume_from_ruler(
        self,
        *,
        filename: str,
        content_type: str | None,
        file_bytes: bytes,
        ruler_point_a: tuple[float, float],
        ruler_point_b: tuple[float, float],
        reference_length_m: float = 1.0,
    ) -> ImageVolumeEstimateResponse:
        image_array = np.frombuffer(file_bytes, dtype=np.uint8)
        image = cv2.imdecode(image_array, cv2.IMREAD_COLOR)
        if image is None:
            raise ValueError("Nao foi possivel ler a imagem enviada.")
        if reference_length_m <= 0:
            raise ValueError("O comprimento de referencia da regua deve ser positivo.")

        height, width = image.shape[:2]
        point_a = np.array(
            [ruler_point_a[0] * width, ruler_point_a[1] * height],
            dtype=np.float32,
        )
        point_b = np.array(
            [ruler_point_b[0] * width, ruler_point_b[1] * height],
            dtype=np.float32,
        )
        ruler_length_px = float(np.linalg.norm(point_a - point_b))
        if ruler_length_px < 40:
            raise ValueError(
                "Os pontos da regua estao muito proximos. Marque os extremos do trecho de 1 metro."
            )

        pixels_per_meter = ruler_length_px / reference_length_m
        mask = self._segment_pile_mask(image)
        foreground_area_px = int(np.count_nonzero(mask))
        if foreground_area_px < max(1200, int(width * height * 0.01)):
            raise ValueError(
                "Nao foi possivel segmentar a pilha com confianca suficiente. "
                "Tente outra imagem ou ajuste melhor os pontos da regua."
            )

        ys, xs = np.where(mask > 0)
        min_x, max_x = int(xs.min()), int(xs.max())
        min_y, max_y = int(ys.min()), int(ys.max())
        bounding_width_px = max_x - min_x + 1
        bounding_height_px = max_y - min_y + 1
        coverage_ratio = foreground_area_px / float(bounding_width_px * bounding_height_px)
        silhouette_area_m2 = foreground_area_px / (pixels_per_meter**2)

        estimated_length_m = bounding_width_px / pixels_per_meter
        estimated_height_m = (bounding_height_px / pixels_per_meter) * (
            0.64 + 0.22 * min(max(coverage_ratio, 0.0), 1.0)
        )
        estimated_height_m = max(estimated_height_m, 0.25)

        face_fill_factor = min(max(coverage_ratio, 0.35), 0.88)
        estimated_depth_m = silhouette_area_m2 / max(estimated_height_m * face_fill_factor, 0.1)
        estimated_depth_m = min(max(estimated_depth_m, 0.35), max(estimated_length_m * 0.95, 0.6))

        shape_factor = min(max(0.56 + coverage_ratio * 0.18, 0.55), 0.78)
        estimated_volume_m3 = estimated_length_m * estimated_height_m * estimated_depth_m * shape_factor

        confidence_score = min(
            0.78,
            max(
                0.42,
                0.44
                + min(ruler_length_px / 600.0, 0.12)
                + min(coverage_ratio, 0.55) * 0.18,
            ),
        )
        confidence_label = self._confidence_label(confidence_score)

        return ImageVolumeEstimateResponse(
            filename=filename,
            content_type=content_type,
            estimated_volume_m3=round(estimated_volume_m3, 3),
            estimated_length_m=round(estimated_length_m, 2),
            estimated_height_m=round(estimated_height_m, 2),
            estimated_depth_m=round(estimated_depth_m, 2),
            confidence_score=round(confidence_score, 2),
            confidence_label=confidence_label,
            rationale=(
                "O volume foi estimado a partir da escala de 1 metro marcada na regua e "
                "da silhueta aparente da pilha segmentada na imagem. A profundidade foi "
                "inferida por fator geometrico, portanto a incerteza continua relevante."
            ),
            metrics=ImageVolumeEstimateMetrics(
                width_px=width,
                height_px=height,
                pixels_per_meter=round(pixels_per_meter, 2),
                foreground_area_px=foreground_area_px,
                coverage_ratio=round(coverage_ratio, 3),
            ),
            disclaimer=(
                "Esta estimativa de volume e semiautomatica e depende da marcacao correta "
                "da regua, da segmentacao visual da pilha e de hipoteses geometricas "
                "simplificadas. Nao substitui medicao fisica direta."
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

    def _segment_pile_mask(self, image: np.ndarray) -> np.ndarray:
        height, width = image.shape[:2]
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)

        rect = (
            int(width * 0.03),
            int(height * 0.12),
            max(1, int(width * 0.90)),
            max(1, int(height * 0.80)),
        )
        grabcut_mask = np.zeros((height, width), np.uint8)
        background_model = np.zeros((1, 65), np.float64)
        foreground_model = np.zeros((1, 65), np.float64)

        try:
            cv2.grabCut(
                image,
                grabcut_mask,
                rect,
                background_model,
                foreground_model,
                3,
                cv2.GC_INIT_WITH_RECT,
            )
            grabcut_foreground = np.where(
                (grabcut_mask == cv2.GC_FGD) | (grabcut_mask == cv2.GC_PR_FGD),
                255,
                0,
            ).astype("uint8")
        except cv2.error:
            grabcut_foreground = np.zeros((height, width), dtype="uint8")

        dark_mask = cv2.inRange(gray, 0, 165)
        low_saturation_dark = cv2.inRange(hsv, (0, 0, 0), (180, 140, 190))
        edge_mask = cv2.Canny(gray, 70, 160)
        edge_mask = cv2.dilate(edge_mask, np.ones((5, 5), np.uint8), iterations=1)

        combined = cv2.bitwise_or(grabcut_foreground, dark_mask)
        combined = cv2.bitwise_or(combined, low_saturation_dark)
        combined = cv2.bitwise_and(
            combined,
            np.where(
                np.indices((height, width))[0] > int(height * 0.16),
                255,
                0,
            ).astype("uint8"),
        )
        combined = cv2.bitwise_or(combined, edge_mask)

        kernel = np.ones((7, 7), np.uint8)
        combined = cv2.morphologyEx(combined, cv2.MORPH_CLOSE, kernel, iterations=2)
        combined = cv2.morphologyEx(combined, cv2.MORPH_OPEN, kernel, iterations=1)

        contours, _ = cv2.findContours(combined, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        filtered_mask = np.zeros_like(combined)
        min_area = max(1500, int(width * height * 0.002))
        for contour in contours:
            if cv2.contourArea(contour) >= min_area:
                cv2.drawContours(filtered_mask, [contour], -1, 255, thickness=cv2.FILLED)

        filtered_mask = cv2.morphologyEx(filtered_mask, cv2.MORPH_CLOSE, kernel, iterations=1)
        return filtered_mask

    @staticmethod
    def _confidence_label(score: float) -> str:
        if score >= 0.5:
            return "media"
        if score >= 0.3:
            return "baixa-media"
        return "baixa"
