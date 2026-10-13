#!/usr/bin/env bash
# ==============================================================================
# generate-uml-mart.sh — UML/ERD de UN data mart puntual.
#
# Introspecciona sólo el esquema `dim` + el data mart indicado y genera su ERD
# (Mermaid) aparte, para estudiar esa estrella sin el ruido de las otras.
#
# Uso:  bash scripts/generate-uml-mart.sh <dm_comercial|dm_entrenamiento|dm_atencion>
# Requiere: la base levantada (bash scripts/bootstrap-db.sh) y npm install.
# ==============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MART="${1:-}"
case "$MART" in
  dm_comercial|dm_entrenamiento|dm_atencion) ;;
  *)
    echo "Uso: bash scripts/generate-uml-mart.sh <dm_comercial|dm_entrenamiento|dm_atencion>" >&2
    exit 1
    ;;
esac

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

PRISMA="$ROOT/node_modules/.bin/prisma"
if [[ ! -x "$PRISMA" ]]; then
  echo "ERROR: no se encontró prisma local. Corré primero: npm install" >&2
  exit 1
fi

SCHEMA="prisma/schema.${MART}.prisma"
OUT="docs/ERD_${MART}.md"

if [[ ! -f "$SCHEMA" ]]; then
  echo "ERROR: falta $SCHEMA (definí el datasource con schemas = [\"dim\", \"$MART\"])." >&2
  exit 1
fi

echo ">> Introspección de dim + $MART (prisma db pull)..."
"$PRISMA" db pull --schema "$SCHEMA"

echo ">> Generando ERD ($MART)..."
node scripts/erd.mjs "$SCHEMA" "$OUT"

echo ""
echo ">> Listo. UML/ERD en $OUT"
