from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api.routes.estimates import router as estimates_router
from app.api.routes.health import router as health_router
from app.api.routes.reference_data import router as reference_data_router
from app.config.settings import API_PREFIX, APP_TITLE, APP_VERSION, use_firebase_persistence
from app.utils.database import init_db


@asynccontextmanager
async def lifespan(_: FastAPI):
    if not use_firebase_persistence():
        init_db()
    yield


app = FastAPI(
    title=APP_TITLE,
    version=APP_VERSION,
    lifespan=lifespan,
    description=(
        "API inicial para estimativa de massa de residuos solidos com base em "
        "volume aparente, densidade configuravel e fatores de correcao."
    ),
)

app.include_router(health_router, prefix=API_PREFIX)
app.include_router(reference_data_router, prefix=API_PREFIX)
app.include_router(estimates_router, prefix=API_PREFIX)
