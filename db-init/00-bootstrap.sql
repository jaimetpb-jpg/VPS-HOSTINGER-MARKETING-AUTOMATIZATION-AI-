-- ═══════════════════════════════════════════════════════════════
-- NEXUS v1.3 · 00-bootstrap.sql · Idempotente
--
-- FIX v1.3: Usa SELECT format()\gexec en lugar de DO $$ para
-- garantizar sustitución correcta de variables psql en todos los
-- contextos (Docker exec, scripts externos, CI/CD).
--
-- Passwords vienen como variables psql con \set (seguro vs sed)
-- ═══════════════════════════════════════════════════════════════


-- ─────── USERS POR APP ───────
-- ─────── dify_app ───────
SELECT format('CREATE ROLE dify_app LOGIN PASSWORD %L', :'pg_dify_pass')
WHERE NOT EXISTS (
  SELECT FROM pg_catalog.pg_roles WHERE rolname = 'dify_app'
)\gexec

SELECT format('ALTER ROLE dify_app WITH PASSWORD %L', :'pg_dify_pass')
WHERE EXISTS (
  SELECT FROM pg_catalog.pg_roles WHERE rolname = 'dify_app'
)\gexec

-- ─────── n8n_app ───────
SELECT format('CREATE ROLE n8n_app LOGIN PASSWORD %L', :'pg_n8n_pass')
WHERE NOT EXISTS (
  SELECT FROM pg_catalog.pg_roles WHERE rolname = 'n8n_app'
)\gexec

SELECT format('ALTER ROLE n8n_app WITH PASSWORD %L', :'pg_n8n_pass')
WHERE EXISTS (
  SELECT FROM pg_catalog.pg_roles WHERE rolname = 'n8n_app'
)\gexec

-- ─────── litellm_app ───────
SELECT format('CREATE ROLE litellm_app LOGIN PASSWORD %L', :'pg_litellm_pass')
WHERE NOT EXISTS (
  SELECT FROM pg_catalog.pg_roles WHERE rolname = 'litellm_app'
)\gexec

SELECT format('ALTER ROLE litellm_app WITH PASSWORD %L', :'pg_litellm_pass')
WHERE EXISTS (
  SELECT FROM pg_catalog.pg_roles WHERE rolname = 'litellm_app'
)\gexec

-- ─────── nexus_core_app ───────
SELECT format('CREATE ROLE nexus_core_app LOGIN PASSWORD %L', :'pg_nexus_core_pass')
WHERE NOT EXISTS (
  SELECT FROM pg_catalog.pg_roles WHERE rolname = 'nexus_core_app'
)\gexec

SELECT format('ALTER ROLE nexus_core_app WITH PASSWORD %L', :'pg_nexus_core_pass')
WHERE EXISTS (
  SELECT FROM pg_catalog.pg_roles WHERE rolname = 'nexus_core_app'
)\gexec

-- ─────── listmonk_app ───────
SELECT format('CREATE ROLE listmonk_app LOGIN PASSWORD %L', :'pg_listmonk_pass')
WHERE NOT EXISTS (
  SELECT FROM pg_catalog.pg_roles WHERE rolname = 'listmonk_app'
)\gexec

SELECT format('ALTER ROLE listmonk_app WITH PASSWORD %L', :'pg_listmonk_pass')
WHERE EXISTS (
  SELECT FROM pg_catalog.pg_roles WHERE rolname = 'listmonk_app'
)\gexec

-- ─────── postiz_app ───────
SELECT format('CREATE ROLE postiz_app LOGIN PASSWORD %L', :'pg_postiz_pass')
WHERE NOT EXISTS (
  SELECT FROM pg_catalog.pg_roles WHERE rolname = 'postiz_app'
)\gexec

SELECT format('ALTER ROLE postiz_app WITH PASSWORD %L', :'pg_postiz_pass')
WHERE EXISTS (
  SELECT FROM pg_catalog.pg_roles WHERE rolname = 'postiz_app'
)\gexec

-- ─────── evolution_app ───────
SELECT format('CREATE ROLE evolution_app LOGIN PASSWORD %L', :'pg_evolution_pass')
WHERE NOT EXISTS (
  SELECT FROM pg_catalog.pg_roles WHERE rolname = 'evolution_app'
)\gexec

SELECT format('ALTER ROLE evolution_app WITH PASSWORD %L', :'pg_evolution_pass')
WHERE EXISTS (
  SELECT FROM pg_catalog.pg_roles WHERE rolname = 'evolution_app'
)\gexec

-- ─────── plausible_app ───────
SELECT format('CREATE ROLE plausible_app LOGIN PASSWORD %L', :'pg_plausible_pass')
WHERE NOT EXISTS (
  SELECT FROM pg_catalog.pg_roles WHERE rolname = 'plausible_app'
)\gexec

SELECT format('ALTER ROLE plausible_app WITH PASSWORD %L', :'pg_plausible_pass')
WHERE EXISTS (
  SELECT FROM pg_catalog.pg_roles WHERE rolname = 'plausible_app'
)\gexec


-- ─────── DBs (con SELECT pg_database.datname → idempotente) ───────
-- Postgres NO permite CREATE DATABASE dentro de DO $$, hay que verificar antes
SELECT 'CREATE DATABASE dify OWNER dify_app'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'dify')\gexec

SELECT 'CREATE DATABASE n8n OWNER n8n_app'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'n8n')\gexec

SELECT 'CREATE DATABASE litellm OWNER litellm_app'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'litellm')\gexec

SELECT 'CREATE DATABASE nexus_core OWNER nexus_core_app'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'nexus_core')\gexec


SELECT 'CREATE DATABASE listmonk OWNER listmonk_app'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'listmonk')\gexec

SELECT 'CREATE DATABASE postiz OWNER postiz_app'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'postiz')\gexec

SELECT 'CREATE DATABASE evolution OWNER evolution_app'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'evolution')\gexec

SELECT 'CREATE DATABASE plausible_db OWNER plausible_app'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'plausible_db')\gexec

-- ─────── GRANTS ───────
GRANT ALL PRIVILEGES ON DATABASE dify TO dify_app;
GRANT ALL PRIVILEGES ON DATABASE n8n TO n8n_app;
GRANT ALL PRIVILEGES ON DATABASE litellm TO litellm_app;
GRANT ALL PRIVILEGES ON DATABASE nexus_core TO nexus_core_app;
GRANT ALL PRIVILEGES ON DATABASE listmonk TO listmonk_app;
GRANT ALL PRIVILEGES ON DATABASE postiz TO postiz_app;
GRANT ALL PRIVILEGES ON DATABASE evolution TO evolution_app;
GRANT ALL PRIVILEGES ON DATABASE plausible_db TO plausible_app;

REVOKE ALL ON DATABASE dify FROM PUBLIC;
REVOKE ALL ON DATABASE n8n FROM PUBLIC;
REVOKE ALL ON DATABASE litellm FROM PUBLIC;
REVOKE ALL ON DATABASE nexus_core FROM PUBLIC;
