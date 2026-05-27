-- ═══════════════════════════════════════════════════════════════
-- NEXUS v1.3 · 01-nexus-core-schema.sql
-- Schema mínimo para el MVP Lead + WhatsApp
-- ═══════════════════════════════════════════════════════════════

\c nexus_core

-- Tenants (clientes de la agencia)
CREATE TABLE IF NOT EXISTS tenants (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug         TEXT UNIQUE NOT NULL,
    name         TEXT NOT NULL DEFAULT '',
    metadata     JSONB DEFAULT '{}',
    competitor_urls TEXT[] DEFAULT '{}',
    is_active    BOOLEAN DEFAULT true,
    created_at   TIMESTAMPTZ DEFAULT now()
);

-- Tenant inicial: ainexus
INSERT INTO tenants (slug, name) VALUES ('ainexus', 'AI Nexus')
ON CONFLICT (slug) DO NOTHING;

-- Leads calificados por Dify
CREATE TABLE IF NOT EXISTS leads (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id    UUID REFERENCES tenants(id),
    name         TEXT,
    email        TEXT,
    phone        TEXT,
    company      TEXT,
    source       TEXT,
    score        INT,
    tier         TEXT CHECK (tier IN ('HOT','WARM','COLD')),
    intent       TEXT,
    input_data   JSONB DEFAULT '{}',
    qualified_at TIMESTAMPTZ,
    created_at   TIMESTAMPTZ DEFAULT now()
);

-- Tareas de AI procesadas por n8n + Dify
CREATE TABLE IF NOT EXISTS ai_task (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID REFERENCES tenants(id),
    workflow_name   TEXT NOT NULL,
    status          TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending','processing','awaiting_approval','approved','rejected','published','done','error')),
    input_payload   JSONB DEFAULT '{}',
    output_payload  JSONB DEFAULT '{}',
    n8n_form_url    TEXT,
    approval_notes  TEXT,
    approver_user   TEXT,
    tokens_in       INT DEFAULT 0,
    tokens_out      INT DEFAULT 0,
    cost_usd        NUMERIC(12,6) DEFAULT 0,
    model_used      TEXT,
    published_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT now()
);

-- Correcciones del operador para mejorar el modelo
CREATE TABLE IF NOT EXISTS tutor_corrections (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id        UUID REFERENCES tenants(id),
    workflow_name    TEXT,
    original_output  TEXT,
    corrected_output TEXT,
    correction_reason TEXT,
    created_at       TIMESTAMPTZ DEFAULT now()
);

-- Índices para queries frecuentes de workflows
CREATE INDEX IF NOT EXISTS idx_leads_tenant_created ON leads(tenant_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_leads_tier ON leads(tier);
CREATE INDEX IF NOT EXISTS idx_ai_task_tenant_status ON ai_task(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_ai_task_workflow ON ai_task(workflow_name, created_at DESC);

-- Grant al usuario de la app
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO nexus_core_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO nexus_core_app;
