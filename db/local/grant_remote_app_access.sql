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

-- E escrita completa em `protheus_raw`. O app move essas tabelas sozinho,
-- direto pelo Postgres: abertura de OP grava SC2 e SD4, a baixa grava SD3, e o
-- saldo da SB2 anda junto em toda operacao. Nao passa pela API — a fila de
-- mutacoes e um segundo caminho, que hoje nenhuma tela alimenta.
--
-- Inclui `DELETE` e o cadastro `sb1_products` a pedido: as duas maquinas
-- trabalham a copia do Protheus em pe de igualdade, e a copia se refaz de
-- `db/local/load_protheus_raw_from_vettip12.sql` quando precisar.
--
-- Detalhe que so aparece executando: `UPDATE` e necessario mesmo para quem so
-- insere. O `_withNextRecno` calcula o proximo RECNO sob
-- `LOCK TABLE ... IN SHARE ROW EXCLUSIVE MODE`, e esse modo de lock exige
-- privilegio de escrita.
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA protheus_raw
  TO vettiflow_app;

-- A coluna `id` e serial, e serial precisa da sequence: sem isso o INSERT morre
-- em `permission denied for sequence`, com o GRANT da tabela ja no lugar.
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA protheus_raw TO vettiflow_app;

-- Tabelas novas de `protheus_raw` ja nascem gravaveis.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA protheus_raw
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO vettiflow_app;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA protheus_raw
  GRANT USAGE, SELECT ON SEQUENCES TO vettiflow_app;

-- Tabelas que a `postgres` criar depois (migrations novas) ja nascem legiveis.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA protheus_raw, protheus_metadata, public
  GRANT SELECT ON TABLES TO vettiflow_app;

COMMIT;
