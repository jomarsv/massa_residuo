# Estrutura Tecnica Inicial

Este documento descreve a organizacao inicial do MVP.

## Backend

- `api/routes`: endpoints HTTP.
- `services`: regra de negocio e modulos de apoio.
- `repositories`: acesso ao SQLite.
- `schemas`: contratos de entrada e saida da API.
- `models`: enumeracoes e tipos de dominio reutilizaveis.
- `config`: tabelas configuraveis de densidade e fatores.
- `utils`: inicializacao do banco e utilitarios compartilhados.

## Mobile

- `presentation`: telas e fluxo visual.
- `domain`: entidades puras do app.
- `data`: modelos e repositorios de dados.
- `services`: integracao com backend.
- `widgets`: componentes reutilizaveis.

## Formula adotada

`M = V x rho x fu x fc x fm`

Onde:

- `V`: volume aparente estimado em `m3`
- `rho`: densidade aparente base em `kg/m3`
- `fu`: fator de umidade
- `fc`: fator de compactacao
- `fm`: fator de mistura

## Premissas do MVP

- O resultado e sempre uma estimativa.
- A imagem entra como apoio e nao como unica fonte da decisao.
- O sistema precisa continuar util mesmo quando a inferencia automatica falha.
