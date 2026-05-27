#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# NEXUS v1.3 · preflight-hostinger.sh
# Verifica el VPS de Hostinger ANTES de cualquier deploy
# Ejecutar como root en el VPS
# ═══════════════════════════════════════════════════════════════
set -uo pipefail
PASS=0; FAIL=0; WARN=0
ok()   { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }
warn() { echo "  ⚠  $1"; WARN=$((WARN+1)); }

echo "═══════════════════════════════════════════════════════════"
echo "  NEXUS v1.3 · Preflight Hostinger VPS"
echo "═══════════════════════════════════════════════════════════"

# ─── Sistema operativo ───
echo ""; echo "── Sistema ──"
OS=$(cat /etc/os-release | grep "^NAME=" | cut -d= -f2 | tr -d '"')
ARCH=$(uname -m)
ok "OS: $OS / $ARCH"

# ─── RAM ───
echo ""; echo "── RAM ──"
RAM_GB=$(free -g | awk '/^Mem:/ {print $2}')
RAM_FREE=$(free -g | awk '/^Mem:/ {print $7}')
[ "$RAM_GB" -ge 16 ] && ok "RAM total: ${RAM_GB}GB (necesita >= 16GB)" \
  || fail "RAM total: ${RAM_GB}GB — insuficiente. Necesita >= 16GB"
[ "$RAM_FREE" -ge 10 ] && ok "RAM libre: ${RAM_FREE}GB" \
  || warn "RAM libre: ${RAM_FREE}GB — puede ser ajustado para primer deploy"

# ─── Disco ───
echo ""; echo "── Disco ──"
DISK_FREE=$(df -BG /opt 2>/dev/null | awk 'NR==2 {gsub("G","",$4); print $4}' \
  || df -BG / | awk 'NR==2 {gsub("G","",$4); print $4}')
[ "${DISK_FREE:-0}" -ge 50 ] && ok "Disco libre: ${DISK_FREE}GB" \
  || fail "Disco libre: ${DISK_FREE}GB — necesita >= 50GB"

# ─── Docker ───
echo ""; echo "── Docker ──"
if command -v docker &>/dev/null; then
  DOCKER_VER=$(docker --version | grep -oP '[\d.]+' | head -1)
  ok "Docker $DOCKER_VER instalado"
  if docker compose version &>/dev/null 2>&1; then
    ok "Docker Compose plugin OK"
  else
    fail "Docker Compose plugin no instalado"
  fi
else
  fail "Docker no instalado — script 00-prepare-vps.sh lo instalará"
fi

# ─── Puertos 80/443 ───
echo ""; echo "── Puertos ──"
BUSY_PORTS=$(ss -tlnp 2>/dev/null | grep -E ':80[^0-9]|:443[^0-9]' || true)
if [ -z "$BUSY_PORTS" ]; then
  ok "Puertos 80 y 443 libres"
else
  # Check who is using them
  if echo "$BUSY_PORTS" | grep -qiE "apache|nginx|httpd"; then
    fail "Apache/Nginx ocupa 80/443 — ejecutar: systemctl stop apache2 nginx"
  else
    warn "Puertos 80/443 ocupados por: $(echo $BUSY_PORTS | head -c 100)"
  fi
fi

# ─── Servicios web pre-instalados ───
echo ""; echo "── Servicios web pre-instalados ──"
for svc in apache2 nginx httpd; do
  if systemctl is-active "$svc" &>/dev/null 2>&1; then
    fail "$svc activo — detener con: systemctl stop $svc && systemctl disable $svc"
  fi
done
systemctl is-active apache2 &>/dev/null 2>&1 || \
systemctl is-active nginx &>/dev/null 2>&1 || ok "Sin apache2/nginx activos"

# ─── DNS wildcard ───
echo ""; echo "── DNS Wildcard ──"
VPS_IP=$(curl -4 -sk --max-time 5 https://ifconfig.me 2>/dev/null || \
         curl -4 -sk --max-time 5 https://api.ipify.org 2>/dev/null || \
         hostname -I | awk '{print $1}')
echo "  IP del VPS: $VPS_IP"

for domain in "ainexus.mx" "ainexus.com.mx"; do
  WILD_IP=$(dig +short "test-preflight.${domain}" @1.1.1.1 2>/dev/null | tail -1 || echo "")
  BASE_IP=$(dig +short "${domain}" @1.1.1.1 2>/dev/null | tail -1 || echo "")
  RESOLVED="${WILD_IP:-$BASE_IP}"
  if [ "$WILD_IP" = "$VPS_IP" ]; then
    ok "DNS *.${domain} wildcard → $WILD_IP ✓ (Traefik subdominios OK)"
  elif [ -n "$BASE_IP" ] && [ "$BASE_IP" = "$VPS_IP" ]; then
    fail "Dominio raíz ${domain} apunta al VPS, pero wildcard *.${domain} NO → Traefik subdominios FALLARÁN. Configura un A record: *.${domain} → $VPS_IP"
  elif [ -n "$WILD_IP" ]; then
    fail "DNS *.${domain} → $WILD_IP (no es $VPS_IP)"
  else
    fail "DNS *.${domain} no resuelve — configura wildcard A record"
  fi
done

# ─── Firewall externo (Hostinger panel) ───
echo ""; echo "── Firewall ──"
PORT80=$(curl -sk --max-time 5 -o /dev/null -w "%{http_code}" "http://${VPS_IP}:80" 2>/dev/null || echo "000")
PORT443=$(curl -sk --max-time 5 -o /dev/null -w "%{http_code}" "https://${VPS_IP}:443" 2>/dev/null || echo "000")
[ "$PORT80" != "000" ] && ok "Puerto 80 accesible desde exterior" || warn "Puerto 80 puede estar bloqueado en panel Hostinger"
[ "$PORT443" != "000" ] && ok "Puerto 443 accesible desde exterior" || warn "Puerto 443 puede estar bloqueado — verificar en panel.hostinger.com → VPS → Firewall"

# ─── Git ───
echo ""; echo "── Git ──"
command -v git &>/dev/null && ok "Git $(git --version | grep -oP '[\d.]+' | head -1)" \
  || fail "Git no instalado"

# ─── Resumen ───
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  PREFLIGHT: ✅ $PASS · ⚠ $WARN · ❌ $FAIL"
echo "═══════════════════════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
  echo "  ❌ Resolver los fallos antes de continuar"
  exit 1
else
  echo "  ✅ VPS listo para deploy"
  [ "$WARN" -gt 0 ] && echo "  ⚠  Revisar warnings antes de levantar Traefik"
fi
