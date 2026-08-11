-- Role para o app rodando em outra maquina (ex.: o Windows do Leonardo).
--
-- Rode passando a senha por variavel, para ela nao acabar no git:
--
--   psql -h localhost -U postgres -d vettip12 -v ON_ERROR_STOP=1 \
--        -v senha="'senha-forte-aqui'" \
--        -f db/local/grant_remote_app_access.sql
--
-- Nao exponha a role `postgres` na rede: ela e superusuaria e o `pg_hba.conf`
-- local a aceita em `trust`, sem senha nenhuma.

BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'vettiflow_app') THEN
    CREATE ROLE vettiflow_app LOGIN;
  END IF;
END
$$;

ALTER ROLE vettiflow_app PASSWORD :senha;

-- O app roda DDL sozinho ao abrir: `_ensureSchema` faz ALTER TABLE nas tabelas
-- do fluxo e o armazem faz CREATE TABLE IF NOT EXISTS. ALTER TABLE exige ser
-- dono, entao a role precisa mais do que GRANT — precisa da posse do schema
-- `vettiflow` e do que tem dentro dele. Localmente o app conecta como
-- `postgres` (superusuaria), que passa por cima disso de qualquer jeito.
ALTER SCHEMA vettiflow OWNER TO vettiflow_app;

DO $$
DECLARE
  obj record;
BEGIN
  FOR obj IN
    SELECT format('%I.%I', schemaname, tablename) AS nome
    FROM pg_tables WHERE schemaname = 'vettiflow'
  LOOP
    EXECUTE format('ALTER TABLE %s OWNER TO vettiflow_app', obj.nome);
  END LOOP;

  FOR obj IN
    SELECT format('%I.%I', schemaname, sequencename) AS nome
    FROM pg_sequences WHERE schemaname = 'vettiflow'
  LOOP
    EXECUTE format('ALTER SEQUENCE %s OWNER TO vettiflow_app', obj.nome);
  END LOOP;
END
$$;

-- Leitura em todo o lado Protheus.
GRANT USAGE ON SCHEMA protheus_raw, protheus_metadata, public TO vettiflow_app;
GRANT SELECT ON ALL TABLES IN SCHEMA protheus_raw, protheus_metadata, public
  TO vettiflow_app;

-- E escrita nas quatro tabelas que o app move sozinho, direto pelo Postgres:
-- abertura de OP grava SC2 e SD4, a baixa grava SD3, e o saldo da SB2 anda
-- junto em toda operacao. Nao passa pela API — a fila de mutacoes e um segundo
-- caminho, que hoje nenhuma tela alimenta.
--
-- `UPDATE` nao e so pelos UPDATEs: o `_withNextRecno` calcula o proximo RECNO
-- sob `LOCK TABLE ... IN SHARE ROW EXCLUSIVE MODE`, e esse modo de lock exige
-- privilegio de escrita. So com INSERT o app trava na primeira gravacao.
GRANT INSERT, UPDATE ON
  protheus_raw.sc2_orders,
  protheus_raw.sd3_movements,
  protheus_raw.sd4_commitments,
  protheus_raw.sb2_balances
  TO vettiflow_app;

-- A coluna `id` dessas tabelas e serial, e serial precisa da sequence: sem
-- isso o INSERT morre em `permission denied for sequence`, mesmo com o GRANT
-- de INSERT na tabela.
DO $$
DECLARE
  tabela text;
  seq text;
BEGIN
  FOREACH tabela IN ARRAY ARRAY[
    'protheus_raw.sc2_orders',
    'protheus_raw.sd3_movements',
    'protheus_raw.sd4_commitments',
    'protheus_raw.sb2_balances'
  ]
  LOOP
    seq := pg_get_serial_sequence(tabela, 'id');
    IF seq IS NOT NULL THEN
      EXECUTE format('GRANT USAGE, SELECT ON SEQUENCE %s TO vettiflow_app', seq);
    END IF;
  END LOOP;
END
$$;

-- Tabelas que a `postgres` criar depois (migrations novas) ja nascem legiveis.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA protheus_raw, protheus_metadata, public
  GRANT SELECT ON TABLES TO vettiflow_app;

COMMIT;
