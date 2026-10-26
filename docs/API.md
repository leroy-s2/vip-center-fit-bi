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
| `GET /api/v1/kpis/comercial/planes` | `DM_Comercial_Plan` | Administración y Comercial |
| `GET /api/v1/kpis/comercial/promociones` | `DM_Comercial_Promociones` | Administración y Comercial |
| `GET /api/v1/kpis/comercial/avisos-cobertura` | `DM_Avisos_Cobertura` | Administración y Comercial |
| `GET /api/v1/kpis/atencion/reclamos` | `DM_Atencion_Reclamos` | Recepción |
| `GET /api/v1/kpis/atencion/recepcion` | `DM_Atencion_Recepcion` | Recepción |
| `GET /api/v1/kpis/atencion/retencion` | `DM_Atencion_Retencion` | Recepción |
| `GET /api/v1/kpis/entrenamiento/asistencia` | `DM_Entrenamiento_Asistencia` | Entrenador |
| `GET /api/v1/kpis/entrenamiento/accesos` | `DM_Entrenamiento_Accesos` | Entrenador |
| `GET /api/v1/kpis/entrenamiento/progreso` | `DM_Entrenamiento_Progreso` | Entrenador |
| `GET /api/v1/kpis/entrenamiento/bajo-progreso` | `DM_Entrenamiento_BajoProgreso` | Entrenador |
| `GET /api/v1/kpis/entrenamiento/evaluaciones` | `DM_Entrenamiento_Evaluaciones` | Entrenador |
| `GET /api/v1/kpis/entrenamiento/rutinas` | `DM_Rutinas_Entrenador` | Entrenador |

> Las vistas de cohorte y de progreso (`DM_Gerencia_Membresias`, `DM_Entrenamiento_Progreso`,
> `DM_Entrenamiento_Evaluaciones`) son **medidas de estado**: se leen en un corte y no deben sumarse
> entre días. El campo `SkFechaCorteCierre` / `FechaCorte` identifica el corte de cada fila.

**Dashboard por actor** (todo en una llamada, ideal para el frontend):

```
GET /api/v1/actores/{gerencia|comercial|recepcion|entrenador}/dashboard
```

**Estado del pipeline** (marca de agua CDC + marcas de agua del ETL):

```
GET /api/v1/etl/estado
```

## OData (Power BI)

Dos familias de *entity sets*, con `$select`, `$filter`, `$orderby`, `$top`, `$skip`, `$count`.

**1) Vistas de KPI agregadas** (14): `DM_Gerencia_Ingresos`, `DM_Gerencia_Membresias`,
`DM_Comercial_Plan`, `DM_Comercial_Promociones`, `DM_Avisos_Cobertura`, `DM_Atencion_Reclamos`,
`DM_Atencion_Recepcion`, `DM_Atencion_Retencion`, `DM_Entrenamiento_Asistencia`,
`DM_Entrenamiento_Accesos`, `DM_Entrenamiento_Progreso`, `DM_Entrenamiento_BajoProgreso`,
`DM_Entrenamiento_Evaluaciones`, `DM_Rutinas_Entrenador`.

**2) Modelo en estrella** (11): `DimFecha`, `DimCliente`, `DimEmpleado`, `DimPlan`, `FactVentas`,
`FactMembresias`, `FactAsistencias`, `FactSesionesEntrenamiento`, `FactSeguimientoFisico`,
`FactReclamos`, `FactRetenciones`.

```
GET /odata/DM_Gerencia_Ingresos?$top=5&$count=true&$select=Anio,MesNumero,IngresosPeriodoActual
GET /odata/DM_Comercial_Plan?$filter=Anio eq 2025 and TipoPlan eq 'MENSUAL'
GET /odata/DimEmpleado?$top=100&$select=CodigoEmpleado,NombreCompleto,Area,Cargo
GET /odata/FactVentas?fechaDesde=2026-01-01&fechaHasta=2026-09-29&$top=1000&$count=true
GET /odata/$metadata
```

> Los **hechos exigen la ventana** `fechaDesde`/`fechaHasta` (se aplica en SQL, no en memoria). Si se
> omite, el repositorio devuelve el último año. Para volúmenes grandes, la alternativa es importar
> directo desde SQL con el login `pbi_lector` (4 dimensiones + 7 hechos).

> Cada entidad expone una clave sintética `RowKey` (no nula), ya que varias vistas y todos los hechos
> tienen clave compuesta. Las claves reales (`SkCliente`, `SkEmpleado`, etc.) viajan como columnas
> para que Power BI construya las relaciones.

## Flujo de datos

```
POST /api/v1/...  →  ORIGEN  →  [CDC captura]  →  usp_Ingesta_CDC (STG)  →  usp_Transformar_CargarDataMart (DW)
        (JMeter)                        cada 10 min (job VIPFIT_ETL_10min)         │
                                                                                   ▼
                                                        GET /api/v1/kpis/*  y  /odata/*  ← frontend / Power BI
```
