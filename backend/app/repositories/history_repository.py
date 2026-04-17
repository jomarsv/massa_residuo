from datetime import datetime, timezone

from app.config.settings import use_firebase_persistence
from app.schemas.estimation import EstimateRequest, EstimateResult
from app.utils.database import get_connection
from app.utils.firebase import get_firestore_collection


class HistoryRepository:
    def save_estimation(self, request: EstimateRequest, result: EstimateResult) -> dict:
        created_at = datetime.now(timezone.utc).isoformat()
        payload = {
            "waste_type": result.waste_type.value,
            "volume_method": result.volume_method.value,
            "estimated_volume_m3": result.estimated_volume_m3,
            "density_kg_m3": result.density_kg_m3,
            "moisture_factor": result.applied_factors.moisture_factor,
            "compaction_factor": result.applied_factors.compaction_factor,
            "heterogeneity_factor": result.applied_factors.heterogeneity_factor,
            "estimated_mass_kg": result.estimated_mass_kg,
            "lower_bound_kg": result.lower_bound_kg,
            "upper_bound_kg": result.upper_bound_kg,
            "confidence_level": result.confidence_level,
            "notes": request.notes,
            "created_at": created_at,
        }

        if use_firebase_persistence():
            collection = get_firestore_collection()
            if collection is None:
                raise RuntimeError("Firebase collection is not available.")
            document = collection.document()
            document.set(payload)
            return self.get_by_id(document.id)

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
                tuple(payload.values()),
            )
            connection.commit()
            record_id = cursor.lastrowid
        return self.get_by_id(record_id)

    def list_estimations(self) -> list[dict]:
        if use_firebase_persistence():
            collection = get_firestore_collection()
            if collection is None:
                return []
            from firebase_admin import firestore

            documents = collection.order_by(
                "created_at",
                direction=firestore.Query.DESCENDING,
            ).stream()
            return [self._normalize_firestore_document(document) for document in documents]

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
        if use_firebase_persistence():
            collection = get_firestore_collection()
            if collection is None:
                raise ValueError(f"Registro {record_id} nao encontrado.")
            document = collection.document(str(record_id)).get()
            if not document.exists:
                raise ValueError(f"Registro {record_id} nao encontrado.")
            return self._normalize_firestore_document(document)

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

    @staticmethod
    def _normalize_firestore_document(document) -> dict:
        data = document.to_dict()
        return {
            "id": document.id,
            "waste_type": data["waste_type"],
            "volume_method": data["volume_method"],
            "estimated_volume_m3": data["estimated_volume_m3"],
            "density_kg_m3": data["density_kg_m3"],
            "estimated_mass_kg": data["estimated_mass_kg"],
            "lower_bound_kg": data["lower_bound_kg"],
            "upper_bound_kg": data["upper_bound_kg"],
            "confidence_level": data["confidence_level"],
            "notes": data.get("notes"),
            "created_at": data["created_at"],
        }
