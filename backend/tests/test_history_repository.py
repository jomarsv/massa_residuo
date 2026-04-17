from app.repositories.history_repository import HistoryRepository


def test_calibration_summary_prefers_matching_scenario():
    repository = HistoryRepository()
    repository.list_estimations = lambda: [  # type: ignore[method-assign]
        {
            "waste_type": "organico",
            "volume_method": "estimativa_assistida_imagem",
            "estimated_mass_kg": 100.0,
            "actual_mass_kg": 120.0,
            "calibration_context": "Poda ensacada",
        },
        {
            "waste_type": "organico",
            "volume_method": "estimativa_assistida_imagem",
            "estimated_mass_kg": 100.0,
            "actual_mass_kg": 110.0,
            "calibration_context": "Poda ensacada",
        },
        {
            "waste_type": "organico",
            "volume_method": "estimativa_assistida_imagem",
            "estimated_mass_kg": 100.0,
            "actual_mass_kg": 80.0,
            "calibration_context": "Folhagem solta",
        },
    ]

    summary = repository.get_calibration_summary(
        waste_type="organico",
        volume_method="estimativa_assistida_imagem",
        calibration_context="poda ensacada",
    )

    assert summary["applied_scope"] == "cenario"
    assert summary["applied_sample_count"] == 2
    assert summary["applied_context_label"] == "Poda ensacada"
    assert summary["applied_multiplier"] == 1.15


def test_calibration_summary_falls_back_to_general_scope():
    repository = HistoryRepository()
    repository.list_estimations = lambda: [  # type: ignore[method-assign]
        {
            "waste_type": "organico",
            "volume_method": "estimativa_assistida_imagem",
            "estimated_mass_kg": 100.0,
            "actual_mass_kg": 120.0,
            "calibration_context": "Poda ensacada",
        },
        {
            "waste_type": "organico",
            "volume_method": "estimativa_assistida_imagem",
            "estimated_mass_kg": 100.0,
            "actual_mass_kg": 90.0,
            "calibration_context": None,
        },
    ]

    summary = repository.get_calibration_summary(
        waste_type="organico",
        volume_method="estimativa_assistida_imagem",
        calibration_context="entulho solto",
    )

    assert summary["applied_scope"] == "geral"
    assert summary["applied_sample_count"] == 2
    assert summary["applied_context_label"] is None
    assert summary["applied_multiplier"] == 1.05
