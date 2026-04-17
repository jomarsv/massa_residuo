import sqlite3

from app.config.settings import DATA_DIR, DATABASE_PATH


def get_connection() -> sqlite3.Connection:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(DATABASE_PATH)
    connection.row_factory = sqlite3.Row
    return connection


def init_db() -> None:
    with get_connection() as connection:
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS estimation_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                waste_type TEXT NOT NULL,
                volume_method TEXT NOT NULL,
                estimated_volume_m3 REAL NOT NULL,
                density_kg_m3 REAL NOT NULL,
                moisture_factor REAL NOT NULL,
                compaction_factor REAL NOT NULL,
                heterogeneity_factor REAL NOT NULL,
                estimated_mass_kg REAL NOT NULL,
                lower_bound_kg REAL NOT NULL,
                upper_bound_kg REAL NOT NULL,
                confidence_level TEXT NOT NULL,
                notes TEXT,
                created_at TEXT NOT NULL
            )
            """
        )
        existing_columns = {
            row["name"]
            for row in connection.execute("PRAGMA table_info(estimation_history)").fetchall()
        }
        if "content_description" not in existing_columns:
            connection.execute(
                "ALTER TABLE estimation_history ADD COLUMN content_description TEXT"
            )
        if "calibration_context" not in existing_columns:
            connection.execute(
                "ALTER TABLE estimation_history ADD COLUMN calibration_context TEXT"
            )
        if "actual_mass_kg" not in existing_columns:
            connection.execute(
                "ALTER TABLE estimation_history ADD COLUMN actual_mass_kg REAL"
            )
        if "calibration_notes" not in existing_columns:
            connection.execute(
                "ALTER TABLE estimation_history ADD COLUMN calibration_notes TEXT"
            )
        if "calibrated_at" not in existing_columns:
            connection.execute(
                "ALTER TABLE estimation_history ADD COLUMN calibrated_at TEXT"
            )
        connection.commit()
