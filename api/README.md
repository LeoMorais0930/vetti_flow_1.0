# VettiFlow · API do Protheus

Transporte entre a fila de mutações do VettiFlow e as tabelas do Protheus.

O VettiFlow opera com o ERP fora do alcance: o chão de fábrica pede abertura de
OP, mexe nos empenhos e transfere material entre armazéns, e tudo isso fica em
cache local no app. Esta API é o que leva esse cache para o outro lado.

## Onde ela grava — leia antes de subir

Hoje aplica no banco **`vettip12`**, a cópia do Protheus migrada para o
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
cp .env.example .env
# edite .env com o host, usuário, senha e token desta máquina
./venv/bin/uvicorn app.main:app --reload --port 8000
```

O arquivo `api/.env` é local e ignorado pelo Git. Cada máquina pode ter seu
próprio `VF_DSN`/`VF_API_TOKEN` sem gerar conflito de merge.

Documentação interativa em <http://localhost:8000/docs>.

## Modo servidor / teste pesado

Na VM/servidor, suba a API com token e sem depender dos defaults locais:

```bash
export VF_DSN="postgresql://usuario:senha@localhost:5432/vettip12"
export VF_API_TOKEN="trocar-por-um-token-interno"
export VF_CORS_ORIGINS="http://localhost:8080,http://IP-OU-HOST-DO-SERVIDOR:8080"
export VF_APPLY=0
export VF_REQUIRE_SF5_MOVEMENTS=1
export VF_TM_PR0="CODIGO-PR0-DA-SF5"
export VF_TM_RE1="CODIGO-RE1-DA-SF5"
export VF_TM_RE4="CODIGO-RE4-DA-SF5"
export VF_TM_DE4="CODIGO-DE4-DA-SF5"
./venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Use `VF_APPLY=0` na primeira rodada para simular e auditar sem mexer em
SC2/SD4/SB2. Depois da conferência no banco dev, troque para `VF_APPLY=1`.
Com `VF_REQUIRE_SF5_MOVEMENTS=1`, qualquer gravação em SD3 é recusada se o
tipo de movimento (`D3_TM`) não existir na SF5 ou se o `F5_TIPO` não combinar
com o movimento (`P` produção, `R` requisição, `D` devolução).

Da maquina que roda o app, valide a API antes de criar OP:

```powershell
.\tools\check_protheus_server_api.ps1 `
  -ApiUrl 'http://IP-OU-HOST-DO-SERVIDOR:8000' `
  -ApiToken 'trocar-por-um-token-interno' `
  -SampleProduct '730-0863'
```

Apontar o app para cá:

```bash
flutter run \
  --dart-define=VETTIFLOW_API_URL=http://localhost:8000 \
  --dart-define=VETTIFLOW_API_TOKEN=trocar-por-um-token-interno \
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
| `VF_DSN`     | `postgresql://localhost:5432/vettip12`   | Banco onde aplica                            |
| `VF_API_TOKEN` | vazio                                  | Token exigido nos endpoints de dados/mutação |
| `VF_CORS_ORIGINS` | `*`                                 | Origens web liberadas, separadas por vírgula |
| `VF_EMPRESA` | `010`                                    | Sufixo das tabelas (`SC2` → `sc2010`)        |
| `VF_APPLY`   | `1`                                      | `0` valida e audita, mas não grava           |
| `VF_FILIAL`  | `04`                                     | Filial padrão das consultas                  |
| `VF_REQUIRE_SF5_MOVEMENTS` | `0`                         | `1` exige validar `D3_TM` na `SF5` antes de gravar `SD3` |
| `VF_TM_PR0`  | vazio                                    | `F5_CODIGO` usado no `D3_TM` para produção manual (`D3_CF=PR0`) |
| `VF_TM_RE1`  | vazio                                    | `F5_CODIGO` usado no `D3_TM` para requisição automática (`D3_CF=RE1`) |
| `VF_TM_RE4`  | vazio                                    | `F5_CODIGO` usado no `D3_TM` para saída por transferência (`D3_CF=RE4`) |
| `VF_TM_DE4`  | vazio                                    | `F5_CODIGO` usado no `D3_TM` para entrada/devolução da transferência (`D3_CF=DE4`) |
| Variável          | Padrão                                   | O que faz                                    |
|-------------------|------------------------------------------|----------------------------------------------|
| `VF_DSN`          | `postgresql://localhost:5432/vettip12`   | Banco onde aplica                            |
| `VF_EMPRESA`      | `010`                                    | Sufixo das tabelas (`SC2` → `sc2010`)        |
| `VF_APPLY`        | `1`                                      | `0` valida e audita, mas não grava           |
| `VF_FILIAL`       | `04`                                     | Filial padrão das consultas                  |
| `VF_API_TOKEN`    | vazio                                    | Exigido em `X-API-Token`; vazio = só loopback |
| `VF_CORS_ORIGINS` | `*`                                      | Origens aceitas, separadas por vírgula       |

O `VF_DSN` aqui usa a role **`postgres`**, não a `vettiflow_app`. A API roda na
mesma máquina do banco e precisa criar/gravar a tabela de auditoria
`vf_mutations` — a `vettiflow_app` só tem `SELECT` no schema `public` e a API
morre no startup com ela. A role restrita existe para o acesso pela rede.

## Acesso de outra máquina

Esta API abre OP e dá baixa no Protheus. **Nunca a exponha sem token.**

```bash
export VF_API_TOKEN="$(python3 -c 'import secrets; print(secrets.token_urlsafe(24))')"
./venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Sem `VF_API_TOKEN` definido ela recusa qualquer requisição que não venha do
loopback, com `503` — esquecer a variável fecha a API em vez de abrir o
Protheus. Com o token, toda rota responde `401` sem o cabeçalho, `/health`
inclusive: um `401` já prova que a porta está acessível.

```bash
curl -H "X-API-Token: $VF_API_TOKEN" http://<ip-do-servidor>:8000/api/v1/health
```

E o app da outra máquina leva o mesmo token para o build:

```bash
flutter run \
  --dart-define=VETTIFLOW_API_URL=http://<ip-do-servidor>:8000 \
  --dart-define=VETTIFLOW_API_TOKEN=<o-token>
```

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
| `transferencia`  | `SB2` (`b2_qatu` nas duas pontas) + `SD3` (`RE4`/`DE4`) |

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
