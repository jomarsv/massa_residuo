# Deploy remoto

## Estrategia adotada

- Backend FastAPI publicado separadamente no Vercel a partir de `backend/`.
- Frontend Flutter Web publicado separadamente no Vercel a partir de `mobile/build/web`.
- Persistencia compartilhada preferencialmente em Firebase Firestore.

## Observacao importante

Quando `FIREBASE_SERVICE_ACCOUNT_JSON` estiver configurada, o backend passa a salvar o historico no Firestore. Sem essa credencial, o sistema usa SQLite como fallback e, no Vercel, esse fallback continua temporario em `/tmp`.

## Backend

O arquivo `backend/index.py` exporta a aplicacao FastAPI no formato esperado pela Vercel.

Variaveis recomendadas no projeto da Vercel:

- `FIREBASE_SERVICE_ACCOUNT_JSON`
- `FIREBASE_COLLECTION_NAME` opcional

## Frontend

A build web aceita `BACKEND_BASE_URL` via `--dart-define`, para apontar para a URL publicada da API.
