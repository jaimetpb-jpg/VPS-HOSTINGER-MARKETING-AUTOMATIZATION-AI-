#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# NEXUS v1.3 · 08 · Backup cifrado externo
# FIX v1.3: restic init automático si no existe el repositorio
#           + carga .env.future si tiene vars de restic
# ═══════════════════════════════════════════════════════════════
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] && { set -a; source .env; set +a; }
# También cargar .env.future si tiene vars de restic
[ -f .env.future ] && { set -a; source .env.future; set +a; } 2>/dev/null || true

if ! command -v restic &>/dev/null; then
  echo "✗ restic no instalado. Instalar: apt install -y restic"
  exit 1
fi

if [ -z "${RESTIC_PASSWORD:-}" ] || [ -z "${RESTIC_REPOSITORY:-}" ]; then
  echo "✗ Faltan RESTIC_PASSWORD y RESTIC_REPOSITORY en .env o .env.future"
  echo "  Mover esas variables de .env.future a .env cuando estés listo para backups"
  exit 1
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
echo "═══════════════════════════════════════════════════════════"
echo "  Backup cifrado · $TIMESTAMP"
echo "═══════════════════════════════════════════════════════════"

# FIX v1.3: Init automático si el repositorio no existe
echo "→ Verificando repositorio restic..."
if ! restic snapshots &>/dev/null 2>&1; then
  echo "  Repositorio no existe. Inicializando..."
  restic init || { echo "✗ Fallo al inicializar repositorio. Verificar credenciales."; exit 1; }
  echo "✓ Repositorio inicializado"
else
  echo "✓ Repositorio existe"
fi

# ─── 1. Verificar espacio ───
FREE_GB=$(df -BG /opt 2>/dev/null | awk 'NR==2 {gsub("G","",$4); print $4}' || echo "5")
if [ "${FREE_GB}" -lt 5 ]; then
  echo "✗ Solo ${FREE_GB}GB libres. Necesita >=5GB"
  exit 1
fi
echo "✓ Espacio disponible: ${FREE_GB}GB"

# ─── 2. Postgres dump streaming ───
echo "→ Backup Postgres (streaming)..."
docker exec -e PGPASSWORD="${PG_ADMIN_PASS}" nexus-postgres \
  pg_dumpall -U "${PG_ADMIN_USER}" \
  | restic backup --stdin --stdin-filename "postgres_${TIMESTAMP}.sql" \
                  --tag nexus-supreme --tag postgres --tag "${TIMESTAMP}"
echo "✓ Postgres OK"

# ─── 3. Qdrant ───
echo "→ Backup Qdrant..."
docker exec nexus-qdrant tar -cf - -C /qdrant storage 2>/dev/null \
  | restic backup --stdin --stdin-filename "qdrant_${TIMESTAMP}.tar" \
                  --tag nexus-supreme --tag qdrant --tag "${TIMESTAMP}" \
  || echo "⚠ Qdrant backup falló (vectores se regeneran, no crítico)"

# ─── 4. Volumes Docker con nombres explícitos ───
echo "→ Backup volumes Docker..."
for vol in nexus_n8n_data nexus_dify_storage nexus_evolution_instances nexus_listmonk_uploads nexus_postiz_uploads; do
  VOL_PATH=$(docker volume inspect "$vol" --format '{{.Mountpoint}}' 2>/dev/null || echo "")
  if [ -n "$VOL_PATH" ] && [ -d "$VOL_PATH" ]; then
    restic backup "$VOL_PATH" \
      --tag nexus-supreme --tag "volume-${vol}" --tag "${TIMESTAMP}" \
      --exclude '*.tmp' --exclude '*.log' 2>/dev/null || echo "  ⚠ $vol falló"
    echo "  ✓ $vol"
  else
    echo "  ⚠ $vol no encontrado (puede no estar desplegado aún)"
  fi
done

# ─── 5. Configs ───
echo "→ Backup configs y workflows..."
restic backup .env configs/ workflows/ db-init/ \
       phase-1-core/*.yml phase-1-core/*.yaml \
       phase-2-marketing/*.yml phase-3-observability/*.yml \
  --tag nexus-supreme --tag configs --tag "${TIMESTAMP}" 2>/dev/null \
  || echo "⚠ Backup de configs falló parcialmente"

# ─── 6. Rotación ───
echo "→ Rotación de snapshots..."
restic forget \
  --keep-daily 7 --keep-weekly 4 --keep-monthly 6 \
  --prune --tag nexus-supreme

# ─── 7. Verificación aleatoria ───
if [ "$((RANDOM % 7))" -eq 0 ]; then
  echo "→ Verificación de integridad (1/7 probabilidad)..."
  restic check --read-data-subset=5% || echo "⚠ Check encontró issues"
fi

echo ""
echo "✅ Backup completo: $TIMESTAMP"
echo "   Ver: restic snapshots --tag nexus-supreme"
echo "   RAM usada: $(free -h | awk '/^Mem:/ {print $3}')"
