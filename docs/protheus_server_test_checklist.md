# Checklist de teste pesado no servidor Protheus

Use este roteiro antes de ligar escrita real em uma base dev.

## 1. Subir a API em modo simulação

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

## 2. Abrir o app apontando para a API

```bash
flutter run \
  --dart-define=VETTIFLOW_API_URL=http://IP-OU-HOST-DO-SERVIDOR:8000 \
  --dart-define=VETTIFLOW_API_TOKEN=trocar-por-um-token-interno \
  --dart-define=VETTIFLOW_ALLOW_DIRECT_POSTGRES_FALLBACK=false
```

## 3. Fluxo mínimo obrigatório

Antes de criar qualquer OP, rode o smoke da API:

```powershell
.\tools\check_protheus_server_api.ps1 `
  -ApiUrl 'http://IP-OU-HOST-DO-SERVIDOR:8000' `
  -ApiToken 'trocar-por-um-token-interno' `
  -SampleProduct '730-0863'
```

Antes de ligar `VF_APPLY=1`, confirme os movimentos reais cadastrados na SF5:

```sql
SELECT f5_filial, f5_codigo, f5_tipo, f5_texto, f5_atuemp, f5_tranmod
FROM sf5010
WHERE d_e_l_e_t_ <> '*'
  AND f5_tipo IN ('P', 'R', 'D')
ORDER BY f5_tipo, f5_codigo;
```

Preencha `VF_TM_PR0`, `VF_TM_RE1`, `VF_TM_RE4` e `VF_TM_DE4` com os
`F5_CODIGO` confirmados. Com `VF_REQUIRE_SF5_MOVEMENTS=1`, a API recusa a
gravação em `SD3` se o código não existir ou se o tipo estiver incoerente.

1. Login Tatiane.
2. Criar OP no armazém 05 com item que tenha componentes SG1.
3. Escolher origem de componentes externos, se aparecer.
4. Conferir fila do Protheus.
5. Finalizar/aplicar com `VF_APPLY=0`.
6. Conferir `vf_mutations`: deve estar `enviado` com `protheus_ref` `DRY:*`.
7. Repetir com `VF_APPLY=1` apenas na base dev.

## 4. Consultas de conferência

Troque `OP_COMPLETA` pelo número Protheus completo, por exemplo
`01595801001`.

```sql
SELECT id, kind, status, protheus_ref, erro, criado_em, aplicado_em
FROM vf_mutations
WHERE protheus_ref ILIKE '%OP_COMPLETA%'
   OR payload->>'op' = 'OP_COMPLETA'
ORDER BY criado_em;

SELECT c2_filial, c2_num, c2_item, c2_sequen, c2_produto, c2_local,
       c2_quant, c2_quje, c2_status, c2_datrf, d_e_l_e_t_
FROM sc2010
WHERE btrim(c2_num) || btrim(c2_item) || btrim(c2_sequen) = 'OP_COMPLETA';

SELECT d4_filial, d4_op, d4_cod, d4_local, d4_quant, d4_qtdeori,
       d4_produto, d4_trt, d_e_l_e_t_
FROM sd4010
WHERE btrim(d4_op) = 'OP_COMPLETA'
ORDER BY d4_cod, d4_local;

SELECT d3_filial, d3_doc, d3_cf, d3_cod, d3_local, d3_quant,
       d3_tm, d3_op, d3_emissao, d_e_l_e_t_
FROM sd3010
WHERE btrim(d3_op) = 'OP_COMPLETA'
ORDER BY r_e_c_n_o_;
```

Para conferir saldo dos componentes vistos na SD4:

```sql
SELECT b2_filial, b2_cod, b2_local, b2_qatu, b2_qemp, b2_reserva
FROM sb2010
WHERE b2_filial = '04'
  AND btrim(b2_cod) IN (
    SELECT btrim(d4_cod)
    FROM sd4010
    WHERE btrim(d4_op) = 'OP_COMPLETA'
  )
ORDER BY b2_cod, b2_local;
```

## 5. Sinais de parada

Pare o teste e volte para `VF_APPLY=0` se acontecer qualquer um destes pontos:

- OP criada sem SD4 correspondente.
- `B2_QEMP` diferente do total empenhado na SD4.
- `D4_LOCAL` diferente do armazém escolhido no app.
- Mutação sem `protheus_ref` e sem erro claro.
- App conseguiu escrever sem `VETTIFLOW_API_TOKEN`.
