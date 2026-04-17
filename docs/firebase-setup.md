# Firebase Setup

## Voce precisa criar um projeto?

Sim. Para usar persistencia compartilhada com Firebase, voce precisa criar um projeto no Firebase.

## Passos minimos

1. Criar um projeto em Firebase.
2. Ativar o Firestore Database em modo nativo.
3. Abrir `Project settings` -> `Service accounts`.
4. Gerar uma nova chave privada para a conta de servico.
5. Copiar o JSON da chave para a variavel de ambiente `FIREBASE_SERVICE_ACCOUNT_JSON`.

## Variaveis usadas pelo backend

- `FIREBASE_SERVICE_ACCOUNT_JSON`: JSON completo da service account.
- `FIREBASE_COLLECTION_NAME`: nome da collection; padrao `estimation_history`.

## Observacao de seguranca

Nunca commite a chave JSON no repositrio. Configure-a apenas como variavel de ambiente local e na Vercel.
