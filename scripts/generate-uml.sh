#!/usr/bin/env bash
# ==============================================================================
# generate-uml.sh — Introspecciona la base con Prisma y genera el UML/ERD.
#
# Pasos:
#   1. prisma db pull    -> lee el esquema real y pobla prisma/schema.prisma
#   2. prisma generate   -> genera el cliente Prisma
#   3. node scripts/erd.mjs -> genera docs/ERD.md (Mermaid, sin Chromium)
#
# Uso:  bash scripts/generate-uml.sh
# Requiere: la base levantada (bash scripts/bootstrap-db.sh) y npm install.
# ==============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

# Usamos el binario LOCAL de prisma (evita que npx baje un RC del registro).
PRISMA="$ROOT/node_modules/.bin/prisma"
if [[ ! -x "$PRISMA" ]]; then
  echo "ERROR: no se encontró prisma local. Corré primero: npm install" >&2
  exit 1
fi

echo ">> Introspección de la base (prisma db pull)..."
"$PRISMA" db pull --schema prisma/schema.prisma

echo ">> Generando cliente Prisma (prisma generate)..."
"$PRISMA" generate --schema prisma/schema.prisma

echo ">> Generando UML/ERD (Mermaid)..."
node scripts/erd.mjs

echo ""
echo ">> Listo. UML/ERD en docs/ERD.md"
echo ">> Para explorar los datos:  npx prisma studio --schema prisma/schema.prisma"
