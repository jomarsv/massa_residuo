from datetime import datetime, timezone
from statistics import median, quantiles

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
            "content_description": request.content_description,
            "calibration_context": request.calibration_context,
            "notes": request.notes,
            "actual_mass_kg": None,
            "calibration_notes": None,
            "calibrated_at": None,
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
                    content_description,
                    calibration_context,
                    notes,
                    actual_mass_kg,
                    calibration_notes,
                    calibrated_at,
                    created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
                    content_description,
                    calibration_context,
                    notes,
                    actual_mass_kg,
                    calibration_notes,
                    calibrated_at,
                    created_at
                FROM estimation_history
                ORDER BY datetime(created_at) DESC, id DESC
                """
            ).fetchall()
        return [dict(row) for row in rows]

    def get_by_id(self, record_id: str | int) -> dict:
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
                    content_description,
                    calibration_context,
                    notes,
                    actual_mass_kg,
                    calibration_notes,
                    calibrated_at,
                    created_at
                FROM estimation_history
                WHERE id = ?
                """,
                (record_id,),
            ).fetchone()
        if row is None:
            raise ValueError(f"Registro {record_id} nao encontrado.")
        return dict(row)

    def save_calibration(self, record_id: str | int, actual_mass_kg: float, notes: str | None) -> dict:
        calibrated_at = datetime.now(timezone.utc).isoformat()

        if use_firebase_persistence():
            collection = get_firestore_collection()
            if collection is None:
                raise ValueError(f"Registro {record_id} nao encontrado.")
            document = collection.document(str(record_id))
            snapshot = document.get()
            if not snapshot.exists:
                raise ValueError(f"Registro {record_id} nao encontrado.")
            document.update(
                {
                    "actual_mass_kg": actual_mass_kg,
                    "calibration_notes": notes,
                    "calibrated_at": calibrated_at,
                }
            )
            return self.get_by_id(record_id)

        with get_connection() as connection:
            cursor = connection.execute(
                """
                UPDATE estimation_history
                SET actual_mass_kg = ?, calibration_notes = ?, calibrated_at = ?
                WHERE id = ?
                """,
                (actual_mass_kg, notes, calibrated_at, record_id),
            )
            connection.commit()
            if cursor.rowcount == 0:
                raise ValueError(f"Registro {record_id} nao encontrado.")
        return self.get_by_id(record_id)

    def get_calibration_multiplier(self, waste_type: str, volume_method: str) -> float:
        summary = self.get_calibration_summary(
            waste_type=waste_type,
            volume_method=volume_method,
        )
        return summary["applied_multiplier"]

    def get_calibration_summary(
        self,
        waste_type: str,
        volume_method: str,
        calibration_context: str | None = None,
    ) -> dict:
        base_records = self._get_calibrated_records(waste_type, volume_method)
        normalized_requested_context = self._normalize_context(calibration_context)

        scenario_groups: dict[str, dict] = {}
        total_outlier_count = 0
        for record in base_records:
            normalized_context = self._normalize_context(record.get("calibration_context"))
            group_key = normalized_context or "__sem_cenario__"
            display_label = record.get("calibration_context") or "Sem cenario definido"
            scenario_groups.setdefault(
                group_key,
                {
                    "label": display_label,
                    "calibration_context": record.get("calibration_context"),
                    "records": [],
                },
            )["records"].append(record)

        scenario_summaries = []
        matching_summary = None
        for group_key, group in scenario_groups.items():
            stats = self._build_multiplier_stats(group["records"])
            total_outlier_count += stats["outlier_count"]
            summary = {
                "label": group["label"],
                "calibration_context": group["calibration_context"],
                **stats,
            }
            scenario_summaries.append(summary)
            if normalized_requested_context and group_key == normalized_requested_context:
                matching_summary = summary

        scenario_summaries.sort(
            key=lambda item: (-item["sample_count"], item["label"].lower()),
        )
        overall_stats = self._build_multiplier_stats(base_records)

        applied_summary = overall_stats
        applied_scope = "geral"
        applied_context_label = None
        if matching_summary and matching_summary["sample_count"] > 0:
            applied_summary = matching_summary
            applied_scope = "cenario"
            applied_context_label = matching_summary["label"]
        elif overall_stats["sample_count"] == 0:
            applied_scope = "nenhuma"

        return {
            "waste_type": waste_type,
            "volume_method": volume_method,
            "requested_context": calibration_context,
            "applied_scope": applied_scope,
            "applied_multiplier": applied_summary["median_multiplier"],
            "applied_sample_count": applied_summary["sample_count"],
            "applied_context_label": applied_context_label,
            "total_calibrated_samples": len(base_records),
            "total_outlier_count": total_outlier_count,
            "scenario_summaries": scenario_summaries,
        }

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
            "content_description": data.get("content_description"),
            "calibration_context": data.get("calibration_context"),
            "notes": data.get("notes"),
            "actual_mass_kg": data.get("actual_mass_kg"),
            "calibration_notes": data.get("calibration_notes"),
            "calibrated_at": data.get("calibrated_at"),
            "created_at": data["created_at"],
        }

    def _get_calibrated_records(self, waste_type: str, volume_method: str) -> list[dict]:
        return [
            record
            for record in self.list_estimations()
            if record["waste_type"] == waste_type
            and record["volume_method"] == volume_method
            and record.get("actual_mass_kg") is not None
            and record.get("estimated_mass_kg")
        ]

    def _build_multiplier_stats(self, records: list[dict]) -> dict:
        multipliers = []
        for record in records:
            estimated_mass = float(record["estimated_mass_kg"])
            actual_mass = float(record["actual_mass_kg"])
            if estimated_mass <= 0:
                continue
            ratio = min(max(actual_mass / estimated_mass, 0.35), 2.5)
            multipliers.append(ratio)

        if not multipliers:
            return {
                "sample_count": 0,
                "median_multiplier": 1.0,
                "min_multiplier": 1.0,
                "max_multiplier": 1.0,
                "outlier_count": 0,
            }

        filtered = multipliers
        outlier_count = 0
        if len(multipliers) >= 4:
            q1, _, q3 = quantiles(multipliers, n=4, method="inclusive")
            iqr = q3 - q1
            lower_bound = q1 - (1.5 * iqr)
            upper_bound = q3 + (1.5 * iqr)
            candidate = [
                value for value in multipliers if lower_bound <= value <= upper_bound
            ]
            if candidate:
                filtered = candidate
                outlier_count = len(multipliers) - len(filtered)

        return {
            "sample_count": len(filtered),
            "median_multiplier": round(float(median(filtered)), 3),
            "min_multiplier": round(float(min(filtered)), 3),
            "max_multiplier": round(float(max(filtered)), 3),
            "outlier_count": outlier_count,
        }

    @staticmethod
    def _normalize_context(value: str | None) -> str | None:
        if value is None:
            return None
        normalized = " ".join(value.strip().lower().split())
        return normalized or None
