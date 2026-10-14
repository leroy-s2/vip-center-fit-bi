# API — VIP Center Fit BI

API ASP.NET Core (.NET 8) con dos roles:

- **Escritura transaccional en ORIGEN** (`BI_VIP_CENTER_FIT_DW_ORIGEN`): lo que simula
  JMeter (la "web" del gimnasio). Cada INSERT/UPDATE/DELETE lo captura CDC.
- **Lectura de KPIs del Data Warehouse** (`BI_VIP_CENTER_FIT_DW`) por **REST** y por **OData**.

Swagger UI: `GET /` (redirige a `/swagger`). OpenAPI: `/swagger/v1/swagger.json`.
Health: `/health`, `/health/ready`.

## Ejecutar

```bash
# Local (requiere el SQL Server del bootstrap en localhost:14330)
dotnet run --project src/VipCenterFit.Api

# Con Docker (junto al SQL Server)
docker compose up -d --build api      # expone http://localhost:5080
```

Configuración (`appsettings.json` / variables de entorno):

| Clave | Descripción |
| --- | --- |
| `ConnectionStrings:Origen` | OLTP de escritura |
| `ConnectionStrings:Stg` | Staging (marca de agua CDC) |
| `ConnectionStrings:Dw` | Data Warehouse (vistas DM_*) |
| `ApiKey` | Si tiene valor, exige header `X-Api-Key` (excepto `/health`, `/swagger`, `/odata`) |

## Escritura (ORIGEN) — lo que golpea JMeter

Todos son `POST`, `Content-Type: application/json`. Devuelven `{ entidad, filasInsertadas, <clave> }`.

| Endpoint | Tabla destino |
| --- | --- |
| `POST /api/v1/clientes` | `DimCliente` |
| `POST /api/v1/empleados` | `DimEmpleado` |
| `POST /api/v1/membresias` | `FactMembresias` |
| `POST /api/v1/ventas` | `FactVentas` |
| `POST /api/v1/renovaciones` | `FactRenovaciones` |
| `POST /api/v1/avisos` | `FactAvisos` |
| `POST /api/v1/asistencias` | `FactAsistencias` |
| `POST /api/v1/objetivos` | `FactObjetivos` |
| `POST /api/v1/evaluaciones` | `FactEvaluaciones` |
| `POST /api/v1/reclamos` | `FactReclamos` |
| `POST /api/v1/sesiones-programadas` | `FactSesionesProgramadas` |
| `POST /api/v1/evaluaciones-programadas` | `FactEvaluacionesProgramadas` |
| `POST /api/v1/retenciones` | `FactRetenciones` |

Ejemplo:

```bash
curl -X POST http://localhost:5080/api/v1/clientes -H "Content-Type: application/json" -d '{
  "idClienteBk": 888001, "dni": "00088001", "nombreCompleto": "Cliente API",
  "sexo": "M", "rangoEtario": "Adultos (>40)", "estadoCliente": "ACTIVO",
  "fechaRegistroOrigen": "2026-09-01", "fechaInicioValidez": "2026-09-01", "esActual": true
}'
```

## KPIs (REST)

Filtros comunes por querystring: `desde`/`hasta` (año), `plan`, `categoria`, `skCliente`, `tipoObjetivo`, `entrenador`, `canal`.

| Endpoint | Vista DW | Actor |
| --- | --- | --- |
| `GET /api/v1/kpis/gerencia/ingresos` | `DM_Gerencia_Ingresos` | Gerencia General |
| `GET /api/v1/kpis/gerencia/membresias` | `DM_Gerencia_Membresias` | Gerencia General |
| `GET /api/v1/kpis/ventas` | `DM_Ventas_Gerencia` | Gerencia General |
| `GET /api/v1/kpis/comercial/planes` | `DM_Comercial_Plan` | Administración y Comercial |
| `GET /api/v1/kpis/comercial/avisos-cobertura` | `DM_Avisos_Cobertura` | Administración y Comercial |
| `GET /api/v1/kpis/comercial/promociones/ventas` | `DM_Promociones_Ventas` | Administración y Comercial |
| `GET /api/v1/kpis/comercial/promociones/membresias` | `DM_Promociones_Membresias` | Administración y Comercial |
| `GET /api/v1/kpis/comercial/promociones/clientes` | `DM_Promociones_Clientes` | Administración y Comercial |
| `GET /api/v1/kpis/atencion/reclamos` | `DM_Atencion_Reclamos` | Recepción |
| `GET /api/v1/kpis/atencion/recepcion` | `DM_Atencion_Recepcion` | Recepción |
| `GET /api/v1/kpis/atencion/retencion` | `DM_Atencion_Retencion` | Recepción |
| `GET /api/v1/kpis/entrenamiento/asistencia` | `DM_Entrenamiento_Asistencia` | Entrenador |
| `GET /api/v1/kpis/entrenamiento/progreso` | `DM_Entrenamiento_Progreso` | Entrenador |
| `GET /api/v1/kpis/entrenamiento/cumplimiento` | `DM_Entrenamiento_Cumplimiento` | Entrenador |
| `GET /api/v1/kpis/entrenamiento/evaluaciones` | `DM_Entrenamiento_Evaluaciones` | Entrenador |
| `GET /api/v1/kpis/entrenamiento/rutinas` | `DM_Rutinas_Entrenador` | Entrenador |

**Dashboard por actor** (todo en una llamada, ideal para el frontend):

```
GET /api/v1/actores/{gerencia|comercial|recepcion|entrenador}/dashboard
```

**Estado del pipeline** (marca de agua CDC + marcas de agua del ETL):

```
GET /api/v1/etl/estado
```

## OData (Power BI)

Un entity set por vista de KPI, con `$select`, `$filter`, `$orderby`, `$top`, `$skip`, `$count`, `$expand`.

```
GET /odata/DM_Gerencia_Ingresos?$top=5&$count=true&$select=Anio,MesNumero,IngresosPeriodoActual
GET /odata/DM_Comercial_Plan?$filter=Anio eq 2025 and TipoPlan eq 'MENSUAL VIP'
GET /odata/$metadata
```

Entity sets: `DM_Gerencia_Ingresos`, `DM_Gerencia_Membresias`, `DM_Comercial_Plan`,
`DM_Avisos_Cobertura`, `DM_Promociones_Ventas`, `DM_Promociones_Membresias`,
`DM_Promociones_Clientes`, `DM_Atencion_Reclamos`, `DM_Atencion_Recepcion`, `DM_Atencion_Retencion`,
`DM_Entrenamiento_Asistencia`, `DM_Entrenamiento_Progreso`, `DM_Entrenamiento_Cumplimiento`,
`DM_Entrenamiento_Evaluaciones`, `DM_Ventas_Gerencia`, `DM_Rutinas_Entrenador`.

> Cada entidad expone una clave sintética `RowKey` (no nula) para que OData siempre
> tenga una clave válida, ya que varias vistas no tienen clave natural.

## Flujo de datos

```
POST /api/v1/...  →  ORIGEN  →  [CDC captura]  →  usp_Ingesta_CDC (STG)  →  usp_Transformar_CargarDataMart (DW)
        (JMeter)                        cada 10 min (job VIPFIT_ETL_10min)         │
                                                                                   ▼
                                                        GET /api/v1/kpis/*  y  /odata/*  ← frontend / Power BI
```
