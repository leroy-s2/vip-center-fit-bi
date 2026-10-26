# Arquitectura — VIP Center Fit BI

Implementación del blueprint de 7 etapas, con el foco en las etapas **1 a 5** (el Data
Warehouse) y las APIs listas para un frontend.

```
1 Fuentes            2 Captura         3 Staging/Raw     4 Transformación   5 DataMart        6 Consumo      7 Decisión
  ORIGEN       →      CDC continuo →    stg.*        →   limpieza/reglas →  constelación    →  API + PBI  →  actores
  (15 tablas)         (cdc.*_CT)        + marca de agua   + MERGE + snapshot 3 datamarts       REST/OData
```

## 1. Fuente (OLTP): `BI_VIP_CENTER_FIT_DW_ORIGEN`

15 tablas (4 dimensiones + 11 tablas de eventos) **sin PK/FK y con defectos inyectados a propósito**.
Es donde **escribe la API** (`POST /api/v1/...`), simulando la web del gimnasio (JMeter).

El ORIGEN conserva el detalle operativo (aviso, renovación, objetivo, evaluación y evaluación
programada son eventos reales del negocio); la **consolidación a 7 hechos ocurre en el ETL**.

## 2. Captura de cambios: CDC de SQL Server

CDC habilitado en las 15 tablas (`cdc.*_CT`). Requiere SQL Server Agent activo.
`sql/03_cdc_ingesta.sql` habilita CDC y crea `dbo.usp_Ingesta_CDC`.

## 3. Staging/Raw: `BI_VIP_CENTER_FIT_STG`

Tablas `stg.*` (misma forma que el origen, sin limpiar) + tabla de marca de agua
`stg.etl_cdc_control` (columna `last_lsn`). La ingesta es **incremental por LSN**.

## 4. Transformación: ETL incremental

`dbo.usp_Transformar_CargarDataMart` (en `DW`) lee **sólo las filas nuevas** del staging
según `dbo.etl_control.ultimo_staging_id`, aplica las reglas de calidad (DNI, sexo, fechas,
rangos, unidades) y hace **`MERGE` por clave de negocio** (upsert + borrados). Dimensiones
antes que hechos (FK). Las filas que no resuelven su dimensión **no se descartan**: se imputan al
**miembro centinela `-1`** y quedan auditadas en `dq.RegistroImputaciones` (ver
[`CALIDAD.md`](CALIDAD.md); auditoría en `sql/12_reglas_calidad.sql`).

## 5. DataMart: un Data Warehouse en **constelación** con **3 data marts**

No son 3 datamarts aislados: es **un DW** cuyos 3 datamarts (estrellas) comparten las
**dimensiones conformadas** del esquema `dim`. Eso es lo que forma la constelación (bus).

| Data mart (esquema) | Área / actor | Hechos |
| --- | --- | --- |
| `dm_comercial` | Administración y Comercial | FactVentas, FactMembresias (absorbe renovaciones y avisos) |
| `dm_entrenamiento` | Entrenador | FactAsistencias, FactSesionesEntrenamiento, FactSeguimientoFisico (absorbe objetivos y evaluaciones) |
| `dm_atencion` | Recepción | FactReclamos, FactRetenciones |
| `dim` (compartido) | — | DimFecha, DimCliente, DimEmpleado, DimPlan |

**Consolidación (M01/M02/M03):** de las 11 tablas de hechos del modelo anterior quedan 7.
`FactRenovaciones` y `FactAvisos` se absorben en `FactMembresias`; `FactObjetivos`,
`FactEvaluaciones` y `FactEvaluacionesProgramadas` se consolidan en `FactSeguimientoFisico`;
`FactSesionesProgramadas` pasa a llamarse `FactSesionesEntrenamiento`.

**Snapshots diarios.** `FactMembresias` y `FactSeguimientoFisico` tienen grano
*clave de negocio + fecha de corte*. El ETL construye la serie día por día desde el inicio de cada
contrato/objetivo, añade los cortes faltantes en cada corrida y actualiza la fila del mismo día si se
re-ejecuta. Nunca copia el estado actual hacia atrás: cada corte se calcula con la información
disponible en esa fecha. Las medidas de estado se consultan en un corte; no se suman entre días.

Las FK físicas hecho → dimensión están declaradas en el motor; `docs/ERD.md` es la vista UML
de la constelación completa (`npm run uml`).

Sobre el modelo, `sql/05_metricas_datamart.sql` publica **14 vistas** `dbo.DM_*` con las
métricas/indicadores/KPIs.

## 6. Actualización: cada 10 minutos

Job de SQL Server Agent `VIPFIT_ETL_10min` (`sql/08_job_agent.sql`): paso 1 ingesta CDC,
paso 2 ETL incremental. El *capture job* de CDC corre continuo (~5 s). Las escrituras de
JMeter llegan "en cualquier momento" y se procesan **por lotes**, sin recargar todo.

## 7. Consumo

- **API ASP.NET Core** (`src/VipCenterFit.Api`): KPIs REST por actor + **OData** (`/odata/DM_*`)
  + `GET /api/v1/etl/estado` (lag del pipeline). Documentada en `docs/API.md`.
- **Power BI**: login SQL read-only `pbi_lector` o el endpoint OData.

## Cadencia de actualización

| Etapa | Frecuencia |
| --- | --- |
| Escritura OLTP (API/JMeter) | en cualquier momento |
| Captura CDC (`cdc.*_CT`) | continua (~5 s, capture job de Agent) |
| Ingesta CDC → Staging | cada 10 min (job) |
| ETL → DataMart (incremental) | cada 10 min (job), sólo filas nuevas |
