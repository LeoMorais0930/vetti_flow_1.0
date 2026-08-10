# VettiFlow · API do Protheus

Transporte entre a fila de mutações do VettiFlow e as tabelas do Protheus.

O VettiFlow opera com o ERP fora do alcance: o chão de fábrica pede abertura de
OP, mexe nos empenhos e transfere material entre armazéns, e tudo isso fica em
cache local no app. Esta API é o que leva esse cache para o outro lado.

## Onde ela grava — leia antes de subir

Hoje aplica no banco **`vettiflow`**, a cópia do Protheus migrada para o
PostgreSQL. **Não é o Protheus de produção.** É de propósito: o objetivo é ver
o efeito real das mutações nas tabelas — quais linhas nascem, quais saldos se
mexem — antes de encostar no ERP de verdade.

A leitura de produtos/saldos aceita dois formatos:

- export/importado do app: `protheus_raw.vw_sb1_products`,
  `protheus_raw.vw_sg1_product_structures`, `protheus_raw.vw_sb2_stock_balances`
  e `protheus_raw.vw_sc2_orders`;
- tabelas físicas espelhadas do Protheus: `sb1010`, `sg1010`, `sb2010`,
  `sc2010`, etc. O sufixo vem de `VF_EMPRESA`.

Os testes gravam dentro de transações que são desfeitas no fim. O serviço, não:
`POST /api/v1/mutations` **altera SC2, SD4 e SB2 de verdade**. Para exercitar o
caminho inteiro sem escrever:

```bash
VF_APPLY=0 ./venv/bin/uvicorn app.main:app --reload
```

Tudo que for aplicado fica registrado em `vf_mutations`, com o estado anterior
de cada linha tocada na coluna `antes` — é o que permite desfazer.

## Subir

```bash
python3 -m venv venv && ./venv/bin/pip install -r requirements.txt
```

```bash
./venv/bin/uvicorn app.main:app --reload --port 8000
```

Documentação interativa em <http://localhost:8000/docs>.

Apontar o app para cá:

```bash
flutter run \
  --dart-define=VETTIFLOW_API_URL=http://localhost:8000 \
  --dart-define=VETTIFLOW_ALLOW_DIRECT_POSTGRES_FALLBACK=false
```

Com `VETTIFLOW_ALLOW_DIRECT_POSTGRES_FALLBACK=false`, a busca de produto/saldo
fica centralizada na FastAPI. Em desenvolvimento local, deixar o fallback ligado
permite abrir o app mesmo sem a API rodando.

## Testes

```bash
./venv/bin/python -m pytest tests/ -q
```

Rodam contra o banco configurado em `VF_DSN` e desfazem o que fizeram.

## Configuração

| Variável     | Padrão                                   | O que faz                                    |
|--------------|------------------------------------------|----------------------------------------------|
| `VF_DSN`     | `postgresql://localhost:5432/vettiflow`  | Banco onde aplica                            |
| `VF_EMPRESA` | `010`                                    | Sufixo das tabelas (`SC2` → `sc2010`)        |
| `VF_APPLY`   | `1`                                      | `0` valida e audita, mas não grava           |
| `VF_FILIAL`  | `04`                                     | Filial padrão das consultas                  |

## Endpoints

| Método | Rota                             | Para quê                                     |
|--------|----------------------------------|----------------------------------------------|
| `GET`  | `/api/v1/health`                 | A API está no ar e onde ela grava            |
| `POST` | `/api/v1/mutations`              | **Armazena** um lote (não aplica ainda)      |
| `POST` | `/api/v1/finalizar`              | Aplica mutações armazenadas no Protheus      |
| `GET`  | `/api/v1/mutations/{id}`         | O que aconteceu com uma mutação              |
| `GET`  | `/api/v1/produtos?query=...`     | Busca produtos para autocomplete             |
| `GET`  | `/api/v1/produtos/{cod}`         | Produto + estrutura SG1 + saldos por armazém |
| `GET`  | `/api/v1/ops/{op}/empenhos`      | Empenhos de uma OP, direto da SD4            |
| `GET`  | `/api/v1/ops/{op}/armazenadas`   | Mutações armazenadas para uma OP             |
| `GET`  | `/api/v1/produtos/{cod}/saldos`  | Saldo por almoxarifado, direto da SB2        |

## Fluxo em duas fases

1. O app sincroniza a fila com `POST /api/v1/mutations`. As mutações são
   **armazenadas** com status `armazenado` — nada é escrito em SC2/SD4/SB2.
2. Quando a Responsável finaliza a OP, o app chama `POST /api/v1/finalizar`
   com os IDs das mutações a aplicar. Só aí as tabelas do Protheus são
   escritas.

O `id` de cada mutação continua sendo a chave de idempotência: reenviar para
`/mutations` devolve o status atual em vez de duplicar; reenviar para
`/finalizar` uma mutação já aplicada devolve o mesmo `protheusRef`.

## O que cada mutação faz nas tabelas (ao ser finalizada)

| Tipo             | Tabelas tocadas                                        |
|------------------|--------------------------------------------------------|
| `aberturaOp`     | `SC2` (a ordem) + `SD4` (empenhos) + `SB2` (`b2_qemp`) |
| `empenho`        | `SD4` + `SB2` (`b2_qemp`)                              |
| `transferencia`  | `SB2` (`b2_qatu` nas duas pontas)                      |

Sem empenhos no pedido, a abertura de OP explode a estrutura vigente do produto
(`SG1`), que é o que o Protheus faz sozinho. Com empenhos, eles substituem a
explosão — é assim que o operador ajusta o que vai compor a OP antes de ela
existir.

## Detalhes que custaram para descobrir

- **`R_E_C_N_O_` é a chave primária de toda tabela do Protheus** e não é uma
  sequence do banco: o ERP a gerencia por fora. Inserir sem calcular o próximo
  deixa tudo em zero e a segunda linha colide.
- **Todas as colunas são `NOT NULL` e sem default** — a `SC2` tem 151. O
  `INSERT` é montado a partir do `information_schema`, preenchendo o vazio de
  cada tipo (`''` para texto, `0` para número). O Protheus não usa `NULL`;
  gravar `NULL` quebraria as consultas do próprio ERP.
- **Datas são `varchar(8)` no formato `YYYYMMDD`.**
- **Filtrar `d_e_l_e_t_ <> '*'`**: o Protheus exclui logicamente.
- **A vigência faz parte da chave da `SG1`** (`G1_INI`/`G1_FIM`). Sem esse
  filtro vêm componentes de revisões antigas junto com os atuais.
- **Saldo negativo é permitido** e acontece de verdade quando o material está a
  caminho. A API não pode ser mais rígida que o ERP.

## Idempotência

Cada mutação é sua própria transação na finalização. Uma recusa não derruba as
outras: as recusadas voltam com motivo e continuam na fila do app para o
operador corrigir.

## Quando o Protheus de verdade entrar

O que troca de dono é `app/protheus.py`: as funções passam a chamar as rotinas
do ERP (`MATA650` e afins) em vez de escrever nas tabelas. O contrato com o app
— o envelope da mutação e o formato do resultado — não muda.
