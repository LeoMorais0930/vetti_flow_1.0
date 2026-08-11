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

-- O lado Protheus e so leitura: o app le SB1/SB2/SC2/SD3/SD4 e as views, mas
-- quem escreve la e a API, com a propria conexao.
GRANT USAGE ON SCHEMA protheus_raw, protheus_metadata, public TO vettiflow_app;
GRANT SELECT ON ALL TABLES IN SCHEMA protheus_raw, protheus_metadata, public
  TO vettiflow_app;

-- Tabelas que a `postgres` criar depois (migrations novas) ja nascem legiveis.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA protheus_raw, protheus_metadata, public
  GRANT SELECT ON TABLES TO vettiflow_app;

COMMIT;
