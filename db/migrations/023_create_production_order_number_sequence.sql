-- Numero da OP passa a sair do banco, nao de cada cliente.
--
-- Ate aqui cada app carregava seu proprio contador (`_nextSequence`), semeado
-- do banco so na abertura. Com duas maquinas no mesmo Postgres isso colide: os
-- dois geram o mesmo `OP-2026-N` e o `ON CONFLICT (number) DO UPDATE` do
-- `saveOrder` sobrescreve a OP de quem gravou primeiro, sem erro nenhum.
--
-- A sequence resolve na origem: `nextval` e atomico, entao dois clientes nunca
-- recebem o mesmo numero, mesmo pedindo no mesmo instante.

BEGIN;

CREATE SEQUENCE IF NOT EXISTS vettiflow.production_order_number_seq
  AS bigint
  START WITH 564351
  MINVALUE 1
  NO MAXVALUE
  CACHE 1;

-- Continua de onde as OPs existentes pararam. O numero e `OP-<ano>-<n>`, entao
-- a parte que interessa e o terceiro campo. `setval` com `is_called = true` faz
-- o proximo `nextval` devolver max+1.
SELECT setval(
  'vettiflow.production_order_number_seq',
  GREATEST(
    564350,
    COALESCE(
      (
        SELECT max(split_part(number, '-', 3)::bigint)
        FROM vettiflow.production_orders
        WHERE split_part(number, '-', 3) ~ '^[0-9]+$'
      ),
      0
    )
  ),
  true
);

COMMIT;
