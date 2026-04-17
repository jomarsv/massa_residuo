import json
from functools import lru_cache
from typing import Any

from app.config.settings import FIREBASE_COLLECTION_NAME, FIREBASE_SERVICE_ACCOUNT_JSON


@lru_cache(maxsize=1)
def get_firestore_collection():
    if not FIREBASE_SERVICE_ACCOUNT_JSON:
        return None

    try:
        import firebase_admin
        from firebase_admin import credentials, firestore
    except ImportError as exc:
        raise RuntimeError(
            "Firebase persistence was requested, but firebase-admin is not installed."
        ) from exc

    service_account_info = json.loads(FIREBASE_SERVICE_ACCOUNT_JSON)

    if not firebase_admin._apps:
        firebase_admin.initialize_app(credentials.Certificate(service_account_info))

    client = firestore.client()
    return client.collection(FIREBASE_COLLECTION_NAME)


def serialize_firestore_value(value: Any):
    if hasattr(value, "isoformat"):
        return value.isoformat()
    return value
