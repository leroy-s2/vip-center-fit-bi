#!/usr/bin/env bash
# ==============================================================================
# bootstrap-db.sh — Levanta SQL Server 2022 en Docker, habilita SQL Server Agent
# y reconstruye el pipeline BI completo:
#   BI_VIP_CENTER_FIT_DW_ORIGEN  (crudo, con defectos inyectados)
#   BI_VIP_CENTER_FIT_STG        (staging / raw + marca de agua CDC)
#   BI_VIP_CENTER_FIT_DW         (data mart en constelación + vistas de KPIs)
#
# Además habilita el Agent (necesario para el capture job de CDC) y crea el job
# VIPFIT_ETL_10min (ingesta CDC + ETL incremental cada 10 minutos).
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
# Sólo el motor: el bootstrap reconstruye las 3 bases, no necesita construir la API.
docker compose up -d mssql

wait_for_sql() {
  local ready=0
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
}

echo ">> Esperando a que SQL Server acepte conexiones..."
wait_for_sql

# ----------------------------------------------------------------------------
# SQL Server Agent: es requisito para el capture job de CDC. Si no está activo
# se habilita en la configuración y se reinicia el contenedor.
# ----------------------------------------------------------------------------
agent_running() {
  docker exec "$CONTAINER" "$SQLCMD" -S localhost -U sa -P "$SA_PASSWORD" -C -h -1 -W -Q \
    "SET NOCOUNT ON; SELECT CASE WHEN EXISTS (SELECT 1 FROM sys.dm_server_services WHERE servicename LIKE 'SQL Server Agent%' AND status_desc = 'Running') THEN 1 ELSE 0 END;" 2>/dev/null | tr -d '[:space:]'
}

if [[ "$(agent_running)" == "1" ]]; then
  echo ">> SQL Server Agent ya está en ejecución."
else
  echo ">> Habilitando SQL Server Agent (requiere reinicio del contenedor)..."
  docker exec -u root "$CONTAINER" /opt/mssql/bin/mssql-conf set sqlagent.enabled true
  docker restart "$CONTAINER" >/dev/null
  echo ">> Esperando a SQL Server tras el reinicio..."
  wait_for_sql
fi

run_sql() {
  echo ">> Ejecutando $1"
  docker exec "$CONTAINER" "$SQLCMD" -S localhost -U sa -P "$SA_PASSWORD" -C -b -i "/sql/$1"
}

# Orden de dependencias del pipeline BI.
run_sql "00_origen.sql"                  # crea/recarga el origen crudo
run_sql "02_staging_estructura.sql"      # crea las tablas stg.*
run_sql "03_ingesta_programada.sql"      # carga batch inicial -> staging
run_sql "04_transformacion_datamart.sql" # DDL idempotente + ETL inicial -> data mart
run_sql "05_metricas_datamart.sql"       # crea las vistas DM_* de KPIs
run_sql "03_cdc_ingesta.sql"             # habilita CDC + proc usp_Ingesta_CDC + marca de agua
run_sql "08_job_agent.sql"               # job VIPFIT_ETL_10min (cada 10 minutos)
run_sql "10_usuarios_permisos.sql"       # usuarios de permisos mínimos (API, ETL, Power BI)

echo ""
echo ">> Bases listas: ORIGEN, STG y DW."
echo ">> CDC habilitado y job VIPFIT_ETL_10min creado (ingesta + ETL incremental cada 10 min)."
echo ""
echo ">> Para probar el flujo CDC + ETL incremental manualmente:"
echo "     docker exec $CONTAINER $SQLCMD -S localhost -U sa -P \"\$MSSQL_SA_PASSWORD\" -C -i /sql/07_prueba_cdc.sql"
echo "     docker exec $CONTAINER $SQLCMD -S localhost -U sa -P \"\$MSSQL_SA_PASSWORD\" -C -i /sql/09_prueba_etl_incremental.sql"
echo ""
echo ">> Siguiente paso:  bash scripts/generate-uml.sh"
