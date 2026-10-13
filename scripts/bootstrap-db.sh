#!/usr/bin/env bash
# ==============================================================================
# bootstrap-db.sh — Levanta SQL Server 2022 en Docker y ejecuta los scripts SQL
# del proyecto en el orden correcto para reconstruir las 3 bases:
#   BI_VIP_CENTER_FIT_DW_ORIGEN  (crudo, con defectos inyectados)
#   BI_VIP_CENTER_FIT_STG        (staging / raw)
#   BI_VIP_CENTER_FIT_DW         (data mart limpio + vistas de KPIs)
#
# Uso:  bash scripts/bootstrap-db.sh
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

SA_PASSWORD="${MSSQL_SA_PASSWORD:-YourStrong!Passw0rd}"
CONTAINER="vipfit-mssql"
SQLCMD="/opt/mssql-tools18/bin/sqlcmd"

echo ">> Levantando SQL Server 2022..."
docker compose up -d

echo ">> Esperando a que SQL Server acepte conexiones..."
ready=0
for i in $(seq 1 60); do
  if docker exec "$CONTAINER" "$SQLCMD" -S localhost -U sa -P "$SA_PASSWORD" -C -Q "SELECT 1" >/dev/null 2>&1; then
    echo "   OK (intento $i)"
    ready=1
    break
  fi
  sleep 3
done

if [[ "$ready" != "1" ]]; then
  echo "ERROR: SQL Server no respondió a tiempo. Revisá 'docker compose logs mssql'." >&2
  exit 1
fi

run_sql() {
  echo ">> Ejecutando $1"
  docker exec "$CONTAINER" "$SQLCMD" -S localhost -U sa -P "$SA_PASSWORD" -C -b -i "/sql/$1"
}

# Orden de dependencias del pipeline BI.
run_sql "00_origen.sql"                  # crea/recarga el origen crudo
run_sql "02_staging_estructura.sql"      # crea las tablas stg.*
run_sql "03_ingesta_programada.sql"      # carga batch inicial -> staging
run_sql "04_transformacion_datamart.sql" # transforma -> data mart + ejecuta ETL
run_sql "05_metricas_datamart.sql"       # crea las vistas DM_* de KPIs

echo ""
echo ">> Bases listas: ORIGEN, STG y DW."
echo ">> El CDC (03_cdc_ingesta.sql y 07_prueba_cdc.sql) requiere SQL Server Agent."
echo "   Para habilitarlo dentro del contenedor:"
echo "     docker exec -u root $CONTAINER /opt/mssql/bin/mssql-conf set sqlagent.enabled true"
echo "     docker restart $CONTAINER"
echo "   Luego:"
echo "     docker exec $CONTAINER $SQLCMD -S localhost -U sa -P \"\$MSSQL_SA_PASSWORD\" -C -i /sql/03_cdc_ingesta.sql"
echo "     docker exec $CONTAINER $SQLCMD -S localhost -U sa -P \"\$MSSQL_SA_PASSWORD\" -C -i /sql/07_prueba_cdc.sql"
echo ""
echo ">> Siguiente paso:  bash scripts/generate-uml.sh"
