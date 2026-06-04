#!/usr/bin/env bash
# Verifica que .env tenga todas las variables requeridas de .env.example
cd "$(dirname "$0")/.."
MISSING=0
while IFS= read -r line; do
  [[ "$line" =~ ^[A-Z0-9_]+=.* ]] || continue
  KEY="${line%%=*}"
  if ! grep -q "^${KEY}=" .env 2>/dev/null; then
    echo "⚠ Falta en .env: ${KEY}"
    MISSING=$((MISSING+1))
  fi
done < .env.example
[ "$MISSING" -gt 0 ] && { echo "✗ $MISSING variables faltantes en .env"; exit 1; } || echo "✓ .env completo"
