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
| Origen (crudo) | `BI_VIP_CENTER_FIT_DW_ORIGEN` | 13 tablas sin PK/FK con defectos inyectados + CDC |
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
| `dm_entrenamiento` | Entrenamiento | FactAsistencias, FactObjetivos, FactEvaluaciones | DimFecha, DimCliente, DimEmpleado, DimPlan |
| `dm_atencion` | Atención | FactReclamos | DimFecha, DimCliente, DimEmpleado |
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

# 3. Levantar SQL Server (puerto host 14330) y reconstruir las 3 bases
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

> Las FK obligaron a cambiar el ETL: `usp_Transformar_CargarDataMart` usa `DELETE` (no
> `TRUNCATE`) porque SQL Server no permite truncar tablas referenciadas por una FK.

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

## CDC (captura de cambios)

El CDC de SQL Server requiere **SQL Server Agent** activo, que en el contenedor viene
deshabilitado. Para la parte de estudio/UML **no hace falta**. Si querés reproducir el
flujo CDC completo:

```bash
docker exec -u root vipfit-mssql /opt/mssql/bin/mssql-conf set sqlagent.enabled true
docker restart vipfit-mssql
# luego ejecutar sql/03_cdc_ingesta.sql y sql/07_prueba_cdc.sql (ver salida de db:bootstrap)
```

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
│   └── 07_prueba_cdc.sql
├── scripts/
│   ├── bootstrap-db.sh       # levanta el motor y ejecuta sql/
│   ├── generate-uml.sh       # db pull + generate + erd
│   └── erd.mjs               # genera docs/ERD.md (Mermaid)
└── docs/
    └── ERD.md                # UML generado (se versiona)
```

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

1. Validar el UML del Data Mart (`docs/ERD.md`).
2. Replicar el estudio sobre `ORIGEN` (incluyendo `cdc.*`) y `STG`.
3. Sobre esta misma base, montar el backend de API (ASP.NET Core) que consuma Power BI
   por SQL directo y por REST/OData.
