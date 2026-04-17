from enum import Enum


class WasteType(str, Enum):
    PLASTIC = "plastico"
    PAPER = "papel_papelao"
    ORGANIC = "organico"
    RUBBLE = "entulho"
    METAL = "metal"


class VolumeMethod(str, Enum):
    KNOWN_CONTAINER = "recipiente_conhecido"
    MANUAL_DIMENSIONS = "dimensoes_manuais"
    IMAGE_ASSISTED = "estimativa_assistida_imagem"


class MoistureCondition(str, Enum):
    DRY = "seco"
    WET = "umido"


class CompactionCondition(str, Enum):
    LOOSE = "solto"
    COMPACTED = "compactado"


class HeterogeneityCondition(str, Enum):
    HOMOGENEOUS = "homogeneo"
    MIXED = "misto"
