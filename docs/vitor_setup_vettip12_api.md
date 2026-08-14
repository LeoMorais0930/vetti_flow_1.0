# VettiFlow + API Protheus: alinhamento Leonardo/Vitor

Este documento resume o que foi ajustado para os dois ambientes trabalharem no
mesmo padrão, evitando conflito de banco, senha, host e merge.

## O que mudou

O banco local padrão agora é:

```text
vettip12
```

Esse nome vale para o app Flutter e para a FastAPI. Antes ainda existiam
referências antigas a `vettiflow`; elas foram trocadas para `vettip12`.

A FastAPI agora também carrega automaticamente o arquivo:

```text
api/.env
```

Esse arquivo não entra no Git. Cada máquina pode ter o próprio host, usuário,
senha e token sem gerar conflito.

O arquivo que entra no Git é só o modelo:

```text
api/.env.example
```

## Estrutura esperada do banco

O banco precisa ter os schemas:

```text
public
protheus_raw
vettiflow
```

O schema `vettiflow` guarda os dados próprios do app, como OPs, etapas,
pausas, assinaturas e requisições internas.

O schema `protheus_raw` guarda a cópia/importação das tabelas do Protheus em
formato tratado para leitura pelo app.

O schema `public` guarda as tabelas físicas no padrão que a API de mutações
usa:

```text
public.sb1010
public.sb2010
public.sc2010
public.sg1010
public.sd3010
public.sd4010
```

No ambiente do Leonardo, essas tabelas físicas foram criadas a partir de
`protheus_raw.*` para ficar compatível com o formato esperado pela API.

No ambiente do Vitor, se o banco já veio do dump completo do Protheus e já tem
essas tabelas no `public`, não precisa recriar.

## O que a API faz hoje

A FastAPI é a ponte entre o app e as tabelas do Protheus em PostgreSQL.

Ela lê:

```text
SB1: cadastro de produtos
SB2: saldo físico/empenhado por armazém
SG1: estrutura do produto
SC2: ordens de produção
SD4: empenhos da OP
SD3: movimentos/apontamentos
```

Ela grava/aplica principalmente:

```text
SC2: abertura da OP
SD4: empenhos da OP
SB2: saldo/empenho
SD3: movimentos como RE4/DE4, PR0/RE1
vf_mutations: auditoria/idempotência da API
```

Na criação da OP, a regra alinhada é:

```text
Cria SC2
Cria SD4
Aumenta B2_QEMP na SB2 conforme empenhos
Não faz baixa/requisição física ainda
```

Na transferência entre armazéns:

```text
Grava SD3 com RE4/DE4
Move B2_QATU entre origem e destino na SB2
Não move B2_QEMP junto
```

Na baixa/finalização de produção:

```text
Grava PR0 para produto acabado
Grava RE1 para consumo dos componentes
Atualiza SB2
Atualiza SD4
Atualiza SC2 conforme produção feita/encerrada
```

## Como configurar no ambiente do Vitor

Dentro da pasta `api`, criar um `.env` a partir do exemplo:

```bash
cd api
cp .env.example .env
```

Editar `api/.env` com os dados reais da máquina dele:

```env
VF_DSN=postgresql://usuario:senha@localhost:5432/vettip12
VF_API_TOKEN=um-token-local
VF_CORS_ORIGINS=*
VF_EMPRESA=010
VF_FILIAL=04
VF_APPLY=0
VF_REQUIRE_SF5_MOVEMENTS=0
```

Para teste seguro, começar com:

```env
VF_APPLY=0
```

Assim a API valida o fluxo sem aplicar de verdade nas tabelas do Protheus.
Depois que conferir no banco dev, trocar para:

```env
VF_APPLY=1
```

## Como subir a API

No Mac/Linux:

```bash
cd api
python3 -m venv venv
./venv/bin/pip install -r requirements.txt
./venv/bin/uvicorn app.main:app --reload --port 8000
```

Para deixar acessível na rede:

```bash
./venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Testar health:

```bash
curl -i -H "X-API-Token: SEU_TOKEN" http://localhost:8000/api/v1/health
```

Se estiver em outra máquina, trocar `localhost` pelo IP da máquina que roda a
API.

## Como apontar o Flutter para a API

Rodar o app usando FastAPI:

```bash
flutter run -d windows \
  --dart-define=VETTIFLOW_API_URL=http://IP_DA_API:8000 \
  --dart-define=VETTIFLOW_API_TOKEN=SEU_TOKEN \
  --dart-define=VETTIFLOW_ALLOW_DIRECT_POSTGRES_FALLBACK=false
```

No Mac, trocar o device conforme necessário:

```bash
flutter run -d macos \
  --dart-define=VETTIFLOW_API_URL=http://localhost:8000 \
  --dart-define=VETTIFLOW_API_TOKEN=SEU_TOKEN \
  --dart-define=VETTIFLOW_ALLOW_DIRECT_POSTGRES_FALLBACK=false
```

## Quando usar Postgres direto

O modo Postgres direto ainda existe para desenvolvimento local do Leonardo.
Mas para o fluxo entre vocês dois, o caminho preferido é:

```text
Flutter -> FastAPI -> PostgreSQL/Protheus
```

Isso centraliza a regra de gravação e evita cada app escrevendo direto no banco.

## Se o banco do Vitor não tiver as tabelas físicas

Se o banco dele tiver só `protheus_raw.*` e não tiver `public.sc2010`,
`public.sd4010`, etc., rodar:

```bash
psql -d vettip12 -f db/local/create_public_protheus_tables_from_raw.sql
```

Esse script cria as tabelas físicas a partir do `protheus_raw`.

Ele é seguro para rodar mais de uma vez: se a tabela já existe e tem dados, ele
não duplica os registros.

## Checklist rápido do Vitor

1. Puxar a branch atual.
2. Rodar `flutter pub get`.
3. Criar `api/.env` a partir de `api/.env.example`.
4. Conferir se o banco chama `vettip12`.
5. Conferir se existem `public.sc2010`, `public.sd4010`, `public.sb2010`.
6. Subir a API com `uvicorn`.
7. Testar `/api/v1/health` com `X-API-Token`.
8. Rodar o Flutter apontando para a API.
9. Começar com `VF_APPLY=0`.
10. Só mudar para `VF_APPLY=1` depois de validar no banco dev.

## Validação feita no ambiente do Leonardo

Resultado final dos testes:

```text
FastAPI: 41 testes passaram
Flutter analyze: sem erros
Flutter tests: 96 testes passaram
```

Contagem confirmada no `vettip12` local:

```text
public.sb1010   4.183 linhas
public.sb2010   41.220 linhas
public.sc2010   16.011 linhas
public.sg1010   5.266 linhas
public.sd3010   320.234 linhas
public.sd4010   107.668 linhas
```

