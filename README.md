# VIP Center Fit — BI Sandbox (Prisma)

Proyecto para **estudiar el esquema de datos `BI_VIP_CENTER_FIT` desde el punto de vista de Prisma**:
introspección de la base real de SQL Server y generación automática del **UML / ERD** en Mermaid.

No es (todavía) el backend de la API. Es el laboratorio de exploración del modelo de datos:
un motor SQL Server 2022 local, los scripts que reconstruyen las 3 bases y Prisma como herramienta de lectura.

---

## ¿Qué reconstruye este proyecto?

Los scripts de `sql/` levantan el mismo pipeline BI que ya existe:

| Capa | Base de datos | Contenido |
| --- | --- | --- |
| Origen (crudo) | `BI_VIP_CENTER_FIT_DW_ORIGEN` | 16 tablas sin PK/FK con defectos inyectados + CDC |
| Staging (raw) | `BI_VIP_CENTER_FIT_STG` | Tablas `stg.*` + marca de agua CDC |
| Data Mart (limpio) | `BI_VIP_CENTER_FIT_DW` | Modelo constelación + vistas `DM_*` de KPIs |

La base más interesante para el UML es el **Data Warehouse** (`BI_VIP_CENTER_FIT_DW`).

### Arquitectura del Data Warehouse: constelación (bus)

No son 3 datamarts aislados: es **un DW en constelación** — 3 data marts por área de negocio,
cada uno una **estrella**, que **comparten dimensiones conformadas**. Los data marts están
separados por esquema:

| Data mart (esquema) | Área | Hechos | Dimensiones conformadas |
| --- | --- | --- | --- |
| `dm_comercial` | Comercial | FactVentas, FactMembresias, FactRenovaciones, FactAvisos | DimFecha, DimCliente, DimEmpleado, DimPlan, DimPromocion |
| `dm_entrenamiento` | Entrenamiento | FactAsistencias, FactSesionesProgramadas, FactObjetivos, FactEvaluaciones, FactEvaluacionesProgramadas | DimFecha, DimCliente, DimEmpleado, DimPlan |
| `dm_atencion` | Atención | FactReclamos, FactRetenciones | DimFecha, DimCliente, DimEmpleado |
| `dim` | (compartido) | — | DimFecha, DimCliente, DimEmpleado, DimPlan, DimPromocion |

> Las dimensiones del esquema `dim` son **conformadas**: las usan los 3 data marts. Eso es lo
> que convierte las 3 estrellas en una constelación y permite comparar entre áreas.

`docs/ERD.md` incluye la vista general, **una estrella por data mart** y la matriz bus.

---

## Requisitos

- Docker + Docker Compose
- Node.js 20+ y npm

---

## Quickstart

```bash
# 1. Dependencias (Prisma queda pinneado a 6.19.3)
npm install

# 2. Entorno
cp .env.example .env      # ajustá la contraseña si querés

# 3. Levantar SQL Server (puerto host 14330) y reconstruir las 3 bases.
#    Habilita SQL Server Agent (para CDC) y crea el job VIPFIT_ETL_10min.
npm run db:bootstrap      # levanta el motor, espera y ejecuta sql/ en orden

# 4. Introspección + UML
npm run uml               # prisma db pull && prisma generate && erd.mjs
```

Al terminar:

- **`docs/ERD.md`** — el diagrama ER en Mermaid (se ve en VS Code y GitHub).
- **`prisma/schema.prisma`** — todas las tablas introspectadas.

> El puerto host es **14330** a propósito, para no chocar con otras instancias de
> SQL Server que ya escuchen en 1433.

---

## Cómo funciona la introspección

`prisma/schema.prisma` define:

- `provider = "sqlserver"` con la URL en `DATABASE_URL`.
- `previewFeatures = ["multiSchema"]`, porque el Data Mart reparte el modelo en
  los esquemas `dim`, `dm_comercial`, `dm_entrenamiento` y `dm_atencion`.
- Sin modelos: `prisma db pull` los escribe al introspeccionar la base.

El flujo `npm run uml` es:

1. `prisma db pull` → lee el esquema real y pobla `prisma/schema.prisma`.
2. `prisma generate` → genera el cliente Prisma.
3. `node scripts/erd.mjs` → genera `docs/ERD.md` (Mermaid, **sin Chromium**).

### Relaciones del ERD

El DW **define FOREIGN KEY físicas** hecho → dimensión conformada. Gracias a eso:

- `prisma db pull` introspecciona las relaciones y el `schema.prisma` **conecta** las estrellas.
- Power BI, dbdiagram y cualquier herramienta reconocen el modelo estrella.
- SQL Server **rechaza hechos con claves de dimensión inexistentes** durante la carga.

`scripts/erd.mjs` usa esas FK reales. Si alguna relación no tuviera FK, **cae a inferencia**
por convención `sk_*` (cada columna `sk_x` de un hecho apunta a la dimensión con PK `sk_x`).

> Las FK definen el modelo estrella en el motor y obligan a cargar dimensiones antes que
> hechos. El ETL incremental hace `MERGE` por clave de negocio (no `TRUNCATE`, que SQL
> Server no permite sobre tablas referenciadas por una FK).

### Vistas `DM_*`

Por defecto Prisma introspecciona **tablas**. Para incluir también las vistas de KPIs,
activá la introspección de vistas en `prisma/schema.prisma`:

```prisma
previewFeatures = ["multiSchema", "views"]
```

y volvé a correr `npm run uml`. Si tu versión de Prisma no soporta vistas en SQL Server,
dejalo como está: el modelo estrella (tablas) queda mapeado igual.

---

## Estudiar otra capa

`DATABASE_URL` apunta por defecto al Data Mart. Para mirar otra base, cambiá solo el
valor de `database=` en `.env` y volvé a correr `npm run uml`:

- `BI_VIP_CENTER_FIT_DW_ORIGEN` → tablas crudas + tablas del sistema CDC (`cdc.*`)
- `BI_VIP_CENTER_FIT_STG` → staging

> Al apuntar a `ORIGEN`, las tablas `cdc.*` agregan ruido al diagrama. Se pueden marcar
> con `@@ignore` en el `schema.prisma` para excluirlas del cliente y del ERD.

---

## Ingesta incremental y scheduler (CDC + ETL cada 10 minutos)

El pipeline ya no reconstruye todo: corre **incremental** y está **agendado**.

1. **CDC** (SQL Server) captura cada INSERT/UPDATE/DELETE de las 16 tablas de `ORIGEN`
   en las tablas de cambios `cdc.*_CT`. Requiere SQL Server Agent activo: `bootstrap-db.sh`
   lo habilita y reinicia el contenedor automáticamente.
2. **`dbo.usp_Ingesta_CDC`** (en `STG`) lee sólo los cambios desde la marca de agua
   `stg.etl_cdc_control.last_lsn` y los deja en las tablas `stg.*`.
3. **`dbo.usp_Transformar_CargarDataMart`** (en `DW`) procesa **sólo las filas nuevas**
   del staging (marca de agua `dbo.etl_control.ultimo_staging_id`) y hace `MERGE` por
   clave de negocio (upsert + borrados). No recarga todo.
4. **`VIPFIT_ETL_10min`** (job de SQL Server Agent, `sql/08_job_agent.sql`) ejecuta los
   pasos 2 y 3 **cada 10 minutos**.

```bash
# Probar el flujo a mano (espera unos segundos al capture job entre pasos):
docker exec vipfit-mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -i /sql/07_prueba_cdc.sql
docker exec vipfit-mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -i /sql/09_prueba_etl_incremental.sql
```

> Nota técnica: cada `capture_instance` se habilitó en un momento distinto, así que su
> `min_lsn` difiere. `usp_Ingesta_CDC` acota el LSN por instancia (si no, CDC devuelve
> el error 313 al consultar por debajo del mínimo de esa instancia).

---

## Estructura

```
vip-center-fit-bi/
├── docker-compose.yml        # SQL Server 2022 (host 14330)
├── .env.example              # contraseña + DATABASE_URL de Prisma
├── package.json              # scripts de npm + Prisma 6.19.3 pinneado
├── prisma/
│   └── schema.prisma         # datasource + multiSchema (se puebla con db pull)
├── sql/                      # scripts de reconstrucción de las 3 bases
│   ├── 00_origen.sql
│   ├── 02_staging_estructura.sql
│   ├── 03_ingesta_programada.sql
│   ├── 03_cdc_ingesta.sql
│   ├── 04_transformacion_datamart.sql
│   ├── 05_metricas_datamart.sql
│   ├── 06_pruebas_datamart_metricas.sql
│   ├── 07_prueba_cdc.sql
│   ├── 08_job_agent.sql      # job VIPFIT_ETL_10min (CDC + ETL incremental)
│   ├── 09_prueba_etl_incremental.sql
│   ├── 10_usuarios_permisos.sql   # api_writer, etl_runner, pbi_lector
│   └── 11_backup.sql         # backup de las 3 bases
├── src/
│   ├── VipCenterFit.Api/     # API ASP.NET Core 8 (REST + OData) + Dockerfile
│   └── VipCenterFit.Seeder/  # seeder determinista -> CSV para JMeter
├── tests/
│   └── VipCenterFit.Api.Tests/    # pruebas de integración (xUnit)
├── jmeter/                   # planes de carga + datasets (seeder)
├── infra/
│   └── main.bicep            # IaC Azure (SQL, Key Vault, Container Apps, App Insights)
├── .github/workflows/ci.yml  # CI: SQL Server en contenedor + bootstrap + tests
├── scripts/
│   ├── bootstrap-db.sh       # levanta el motor, habilita Agent y ejecuta sql/
│   ├── generate-uml.sh       # db pull + generate + erd
│   └── erd.mjs               # genera docs/ERD.md (Mermaid)
└── docs/
    ├── ARQUITECTURA.md       # blueprint 1-7 + constelación + cadencia
    ├── API.md                # endpoints REST + OData
    ├── OFICIAL1_CUMPLIMIENTO.md  # matriz actor -> KPI -> vista/endpoint
    ├── OPERACION.md          # runbook (Agent, backups, seguridad, Power BI)
    └── ERD.md                # UML generado (se versiona)
```

---

## API (ASP.NET Core)

API en `src/VipCenterFit.Api` (.NET 8, Dapper). Dos roles: **escribir en ORIGEN**
(lo que simula JMeter) y **leer los KPIs** del Data Warehouse por REST y por OData.

```bash
# Local (SQL Server del bootstrap en localhost:14330)
dotnet run --project src/VipCenterFit.Api

# Con Docker (junto al SQL Server), expone http://localhost:5080
docker compose up -d --build api
```

- Swagger: `http://localhost:5080/swagger` · Health: `/health`
- Escritura: `POST /api/v1/clientes|empleados|membresias|ventas|renovaciones|avisos|asistencias|objetivos|evaluaciones|reclamos|sesiones-programadas|evaluaciones-programadas|retenciones`
- KPIs por actor: `GET /api/v1/kpis/...` y `GET /api/v1/actores/{actor}/dashboard`
- OData (Power BI): `/odata/DM_*` · Estado del pipeline: `GET /api/v1/etl/estado`

Detalle completo de endpoints en **`docs/API.md`**.

---

## Ingesta de prueba (seeder + JMeter)

```bash
# Datasets deterministas (mismo --seed => mismos datos)
dotnet run --project src/VipCenterFit.Seeder -c Release -- --seed 1234 --clientes 200 --out jmeter/data

# Carga (requiere la API levantada)
jmeter -n -t jmeter/escritura-oltp.jmx -l resultados/escritura.jtl -e -o resultados/escritura-html
jmeter -n -t jmeter/lectura-kpis.jmx   -l resultados/lectura.jtl   -e -o resultados/lectura-html
```

Detalle en `jmeter/README.md`. Las escrituras van a ORIGEN y el job de 10 min las lleva al DW.

---

## Tests y CI

```bash
dotnet test tests/VipCenterFit.Api.Tests/VipCenterFit.Api.Tests.csproj   # requiere SQL Server arriba
```

`.github/workflows/ci.yml` levanta SQL Server en un contenedor, corre `bootstrap-db.sh`,
ejecuta la prueba de ETL incremental (`sql/09_...`) y `dotnet test`.

---

## Ops / IaC

- Backup: `sql/11_backup.sql` (3 bases a `/var/opt/mssql/backup`).
- IaC Azure: `infra/main.bicep` (SQL, Key Vault, Container Apps, App Insights).
- Runbook completo: **`docs/OPERACION.md`**.

---

## Power BI

Dos vías, ambas ya disponibles:

1. **Conexión SQL read-only** con el login `pbi_lector` (creado por `sql/10_usuarios_permisos.sql`):
   servidor `localhost,14330` (o el host del DW), base `BI_VIP_CENTER_FIT_DW`, usuario `pbi_lector`.
   Sólo puede `SELECT` sobre `dim`, `dm_comercial`, `dm_entrenamiento`, `dm_atencion` y las vistas
   `dbo.DM_*`. Si es Power BI **Service on-prem**, requiere gateway.
2. **OData** de la API (`/odata/DM_*`): para Power BI Service sin gateway.

Otros logins de permisos mínimos: `api_writer` (escribe en `ORIGEN`) y `etl_runner`
(ejecuta ingesta + ETL). En producción las contraseñas van en Key Vault y no se versionan.

---

## Scripts npm

| Script | Qué hace |
| --- | --- |
| `npm run db:bootstrap` | Levanta SQL Server y reconstruye las 3 bases |
| `npm run db:up` / `db:down` | Levanta / baja el contenedor |
| `npm run db:reset` | Baja con volúmenes y vuelve a levantar (base limpia) |
| `npm run db:pull` | Solo la introspección de Prisma |
| `npm run db:studio` | Prisma Studio (navegador de datos) |
| `npm run uml` | db pull + generate + ERD |
| `npm run uml:only` | Regenera solo el ERD desde el schema actual |

---

## Próximos pasos

1. ✅ ETL incremental + scheduler (job `VIPFIT_ETL_10min` cada 10 min).
2. ✅ API ASP.NET Core: escritura a `ORIGEN` + KPIs por REST/OData (`docs/API.md`).
3. ✅ Power BI (login SQL read-only + OData), seguridad (usuarios de permisos mínimos),
   seeder determinista + JMeter, CI/CD y ops (IaC, backups, runbook).
4. ✅ Brechas de KPIs del Excel `OFICIAL1` cerradas (ver `docs/OFICIAL1_CUMPLIMIENTO.md`):
   tasa de asistencia, resolución directa de reclamos, evaluaciones programadas y retención en
   mostrador, con tablas nuevas en ORIGEN (`FactSesionesProgramadas`, `FactEvaluacionesProgramadas`,
   `FactRetenciones`) y `FactReclamos.resuelto_en_mostrador`.
