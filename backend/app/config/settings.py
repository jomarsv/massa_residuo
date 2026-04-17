import os
from pathlib import Path

from app.models.enums import (
    CompactionCondition,
    HeterogeneityCondition,
    MoistureCondition,
    WasteType,
)


BASE_DIR = Path(__file__).resolve().parents[2]
IS_VERCEL = os.getenv("VERCEL") == "1"
DATA_DIR = Path("/tmp") if IS_VERCEL else BASE_DIR / "data"
DATABASE_PATH = DATA_DIR / "residuos_massa_estimada.db"

APP_TITLE = "Residuos Massa Estimada API"
APP_VERSION = "0.1.0"
API_PREFIX = "/api/v1"

WASTE_DENSITIES_KG_M3: dict[WasteType, float] = {
    WasteType.PLASTIC: 45.0,
    WasteType.PAPER: 85.0,
    WasteType.ORGANIC: 420.0,
    WasteType.RUBBLE: 1350.0,
    WasteType.METAL: 280.0,
}

MOISTURE_FACTORS: dict[MoistureCondition, float] = {
    MoistureCondition.DRY: 1.0,
    MoistureCondition.WET: 1.15,
}

COMPACTION_FACTORS: dict[CompactionCondition, float] = {
    CompactionCondition.LOOSE: 1.0,
    CompactionCondition.COMPACTED: 1.2,
}

HETEROGENEITY_FACTORS: dict[HeterogeneityCondition, float] = {
    HeterogeneityCondition.HOMOGENEOUS: 1.0,
    HeterogeneityCondition.MIXED: 1.1,
}

UNCERTAINTY_MARGIN_BY_METHOD: dict[str, float] = {
    "recipiente_conhecido": 0.12,
    "dimensoes_manuais": 0.18,
    "estimativa_assistida_imagem": 0.25,
}

CONFIDENCE_LABEL_BY_METHOD: dict[str, str] = {
    "recipiente_conhecido": "media-alta",
    "dimensoes_manuais": "media",
    "estimativa_assistida_imagem": "baixa-media",
}
