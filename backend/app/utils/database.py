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
        connection.commit()
