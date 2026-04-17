# Deploy remoto

## Estrategia adotada

- Backend FastAPI publicado separadamente no Vercel a partir de `backend/`.
- Frontend Flutter Web publicado separadamente no Vercel a partir de `mobile/build/web`.

## Observacao importante

Em Vercel, o uso de SQLite neste MVP fica limitado a armazenamento temporario em `/tmp`. Isso permite demonstracao remota, mas nao historico compartilhado duravel entre execucoes. Para producao ou uso colaborativo real, sera necessario migrar a persistencia para um banco gerenciado.

## Backend

O arquivo `backend/index.py` exporta a aplicacao FastAPI no formato esperado pela Vercel.

## Frontend

A build web aceita `BACKEND_BASE_URL` via `--dart-define`, para apontar para a URL publicada da API.
