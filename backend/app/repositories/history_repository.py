from datetime import datetime, timezone

from app.schemas.estimation import EstimateRequest, EstimateResult
from app.utils.database import get_connection


class HistoryRepository:
    def save_estimation(self, request: EstimateRequest, result: EstimateResult) -> dict:
        created_at = datetime.now(timezone.utc).isoformat()
        with get_connection() as connection:
            cursor = connection.execute(
                """
                INSERT INTO estimation_history (
                    waste_type,
                    volume_method,
                    estimated_volume_m3,
                    density_kg_m3,
                    moisture_factor,
                    compaction_factor,
                    heterogeneity_factor,
                    estimated_mass_kg,
                    lower_bound_kg,
                    upper_bound_kg,
                    confidence_level,
                    notes,
                    created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    result.waste_type.value,
                    result.volume_method.value,
                    result.estimated_volume_m3,
                    result.density_kg_m3,
                    result.applied_factors.moisture_factor,
                    result.applied_factors.compaction_factor,
                    result.applied_factors.heterogeneity_factor,
                    result.estimated_mass_kg,
                    result.lower_bound_kg,
                    result.upper_bound_kg,
                    result.confidence_level,
                    request.notes,
                    created_at,
                ),
            )
            connection.commit()
            record_id = cursor.lastrowid
        return self.get_by_id(record_id)

    def list_estimations(self) -> list[dict]:
        with get_connection() as connection:
            rows = connection.execute(
                """
                SELECT
                    id,
                    waste_type,
                    volume_method,
                    estimated_volume_m3,
                    density_kg_m3,
                    estimated_mass_kg,
                    lower_bound_kg,
                    upper_bound_kg,
                    confidence_level,
                    notes,
                    created_at
                FROM estimation_history
                ORDER BY datetime(created_at) DESC, id DESC
                """
            ).fetchall()
        return [dict(row) for row in rows]

    def get_by_id(self, record_id: int) -> dict:
        with get_connection() as connection:
            row = connection.execute(
                """
                SELECT
                    id,
                    waste_type,
                    volume_method,
                    estimated_volume_m3,
                    density_kg_m3,
                    estimated_mass_kg,
                    lower_bound_kg,
                    upper_bound_kg,
                    confidence_level,
                    notes,
                    created_at
                FROM estimation_history
                WHERE id = ?
                """,
                (record_id,),
            ).fetchone()
        if row is None:
            raise ValueError(f"Registro {record_id} nao encontrado.")
        return dict(row)
