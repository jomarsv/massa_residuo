# Residuos Massa Estimada MVP

MVP tecnico para estimativa de massa de residuos solidos a partir de imagem e entradas semiassistidas. O sistema nao promete medicao direta por imagem: ele calcula uma estimativa usando volume aparente, densidade aparente e fatores de correcao, com faixa de incerteza.

## Objetivo do MVP

- Capturar ou carregar imagem de residuos.
- Permitir classificacao manual e, futuramente, assistida por visao computacional.
- Calcular massa estimada com base na formula `M = V x rho x fu x fc x fm`.
- Exibir valor central, limite inferior, limite superior e nivel simplificado de confianca.
- Salvar historico local.
- Preparar o sistema para calibracao futura com peso real.

## Arquitetura

O projeto foi dividido em dois blocos:

- `backend/`: API FastAPI, motor de estimativa, persistencia SQLite e modulo inicial de visao computacional.
- `mobile/`: app Flutter organizado por camadas (`presentation`, `domain`, `data`, `services`, `widgets`).

### Justificativa da arquitetura

- A separacao `mobile` e `backend` permite evoluir o processamento e a integracao de IA sem acoplar a interface.
- No backend, as camadas `api`, `services`, `repositories`, `schemas`, `models`, `utils` e `config` isolam HTTP, regra de negocio e persistencia.
- No mobile, a separacao por camadas facilita migrar de dados mockados para API real sem reescrever telas.
- O modulo de visao computacional entra como apoio opcional, preservando o funcionamento do MVP mesmo sem modelo treinado.

## Estrutura de pastas

```text
residuos-massa-estimada/
|-- README.md
|-- docs/
|   `-- project-structure.md
|-- backend/
|   |-- requirements.txt
|   |-- app/
|   |   |-- main.py
|   |   |-- api/
|   |   |   `-- routes/
|   |   |       |-- estimates.py
|   |   |       |-- health.py
|   |   |       `-- reference_data.py
|   |   |-- config/
|   |   |   `-- settings.py
|   |   |-- models/
|   |   |   `-- enums.py
|   |   |-- repositories/
|   |   |   `-- history_repository.py
|   |   |-- schemas/
|   |   |   `-- estimation.py
|   |   |-- services/
|   |   |   |-- cv_service.py
|   |   |   `-- estimation_service.py
|   |   `-- utils/
|   |       `-- database.py
|   `-- tests/
|       `-- test_estimation_service.py
`-- mobile/
    |-- pubspec.yaml
    |-- lib/
    |   |-- main.dart
    |   |-- app.dart
    |   |-- core/
    |   |   `-- theme/
    |   |       `-- app_theme.dart
    |   |-- data/
    |   |   |-- models/
    |   |   |   `-- waste_option.dart
    |   |   `-- repositories/
    |   |       `-- reference_data_repository.dart
    |   |-- domain/
    |   |   `-- entities/
    |   |       `-- app_status.dart
    |   |-- presentation/
    |   |   `-- screens/
    |   |       `-- home_screen.dart
    |   |-- services/
    |   |   `-- backend_service.dart
    |   `-- widgets/
    |       |-- app_section_card.dart
    |       `-- status_badge.dart
    `-- test/
        `-- widget_test.dart
```

## Dependencias principais

### Backend

- `fastapi`
- `uvicorn[standard]`
- `pydantic`
- `opencv-python-headless`
- `firebase-admin`
- `pytest`
- `httpx`

### Mobile

- `flutter`
- `cupertino_icons`
- `http`

## Plano de desenvolvimento em fases

### Fase 1

- Criar base do backend FastAPI com calculo, persistencia SQLite e endpoints iniciais.
- Criar estrutura base do app Flutter com arquitetura em camadas.
- Documentar arquitetura, dependencias e fluxo do MVP.

### Fase 2

- Implementar formulario completo no mobile para tipo de residuo, condicao e metodo de volume.
- Integrar calculo do backend ao app.
- Salvar historico local no dispositivo e exibir lista de analises.

### Fase 3

- Adicionar upload/captura de imagem.
- Preparar pipeline assistido de visao computacional para classificacao e analise basica.
- Introduzir fallback claro quando a IA nao conseguir inferir dados.

### Fase 4

- Incluir calibracao com peso real.
- Ajustar fatores empiricos configuraveis.
- Expandir testes, observabilidade e validacao experimental.

## Firebase

Para persistencia remota compartilhada, voce precisa criar um projeto no Firebase.

Minimo necessario:

- criar um projeto Firebase
- habilitar o Firestore Database
- gerar uma Service Account no Google Cloud vinculado ao projeto
- copiar o JSON da credencial para a variavel `FIREBASE_SERVICE_ACCOUNT_JSON`

Em desenvolvimento local, se essa variavel nao existir, o backend continua usando SQLite como fallback.

## Como executar

### Backend

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

API disponivel em `http://127.0.0.1:8000`.

Para usar Firebase localmente, configure as variaveis de ambiente com base em `backend/.env.example`.

### Mobile

```bash
cd mobile
flutter pub get
flutter run
```

## Como testar

### Backend

```bash
cd backend
pytest
```

### Mobile

```bash
cd mobile
flutter test
```

## Limitacoes atuais

- A estimativa por imagem ainda e apenas um modulo preparado para evolucao futura.
- Os fatores e densidades sao iniciais e precisam de calibracao com dados reais.
- O app Flutter nesta fase e uma base funcional de interface, ainda sem fluxo completo de formulario e historico.
- Sem `FIREBASE_SERVICE_ACCOUNT_JSON`, o backend usa fallback local em SQLite.
