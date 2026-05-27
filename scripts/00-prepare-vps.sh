#!/usr/bin/env bash
# NEXUS v1.3 · 00-prepare-vps.sh · Preparar VPS Hostinger KVM8
# Idempotente — seguro de correr múltiples veces
set -euo pipefail

echo "═══════════════════════════════════════════════════════════"
echo "  NEXUS v1.3 · Preparar VPS Hostinger"
echo "═══════════════════════════════════════════════════════════"

# ─── Sistema ───
echo "→ Actualizando sistema..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq \
  curl wget git unzip jq dnsutils \
  ca-certificates gnupg lsb-release \
  htop iotop fail2ban ufw \
  apache2-utils 2>/dev/null || true
echo "✓ Sistema actualizado"

# ─── Docker ───
echo "→ Instalando Docker..."
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | sh
  systemctl enable docker
  systemctl start docker
  echo "✓ Docker instalado"
else
  echo "✓ Docker ya instalado: $(docker --version)"
fi

# ─── Docker Compose plugin ───
if ! docker compose version &>/dev/null 2>&1; then
  apt-get install -y docker-compose-plugin
  echo "✓ Docker Compose plugin instalado"
else
  echo "✓ Docker Compose: $(docker compose version --short)"
fi

# ─── Detener servicios conflictivos ───
echo "→ Deteniendo servicios web conflictivos..."
systemctl stop apache2 nginx 2>/dev/null || true
systemctl disable apache2 nginx 2>/dev/null || true
echo "✓ Puertos 80/443 libres"

# ─── UFW Firewall ───
echo "→ Configurando UFW..."
ufw --force reset > /dev/null 2>&1
ufw default deny incoming > /dev/null
ufw default allow outgoing > /dev/null
ufw allow 22/tcp comment "SSH"
ufw allow 80/tcp comment "HTTP Traefik"
ufw allow 443/tcp comment "HTTPS Traefik"
# Beszel agent — solo desde localhost
ufw allow from 127.0.0.1 to any port 45876 comment "Beszel agent"
ufw --force enable > /dev/null
echo "✓ UFW: 22, 80, 443 abiertos"

# ─── Swap (4GB si no existe) ───
echo "→ Configurando swap..."
if [ ! -f /swapfile ]; then
  fallocate -l 4G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
  echo "✓ Swap 4GB creado"
else
  echo "✓ Swap ya existe: $(swapon --show | tail -1)"
fi

# ─── Directorios ───
echo "→ Creando estructura de directorios..."
mkdir -p /opt/nexus /opt/nexus-rollback
chmod 700 /opt/nexus-rollback
echo "✓ Directorios creados"

# ─── sysctl (performance) ───
cat > /etc/sysctl.d/99-nexus.conf << 'EOF'
vm.swappiness=10
vm.overcommit_memory=1
net.core.somaxconn=65535
net.ipv4.tcp_max_syn_backlog=65535
fs.file-max=1000000
EOF
sysctl -p /etc/sysctl.d/99-nexus.conf > /dev/null 2>&1
echo "✓ sysctl optimizado"

# ─── ulimits ───
cat > /etc/security/limits.d/99-nexus.conf << 'EOF'
* soft nofile 65535
* hard nofile 65535
root soft nofile 65535
root hard nofile 65535
EOF
echo "✓ ulimits configurados"

# ─── Resumen ───
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  ✅ VPS preparado"
echo "  RAM: $(free -h | awk '/^Mem:/{print $2}') total · $(free -h | awk '/^Mem:/{print $7}') libre"
echo "  Disco: $(df -h /opt | awk 'NR==2{print $4}') libre en /opt"
echo "  Docker: $(docker --version)"
echo "═══════════════════════════════════════════════════════════"
echo "Siguiente: bash scripts/01-generate-secrets.sh"
