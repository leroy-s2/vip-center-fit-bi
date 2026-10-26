# VIP Center Fit — Inteligencia de Negocio (BI) & Data Warehouse

[![SQL Server](https://img.shields.io/badge/SQL%20Server-2022-CC292B?logo=microsoftsqlserver&logoColor=white)](https://www.microsoft.com/sql-server)
[![.NET 8](https://img.shields.io/badge/.NET-8.0-512BD4?logo=dotnet&logoColor=white)](https://dotnet.microsoft.com/)
[![Prisma](https://img.shields.io/badge/Prisma-6.19.3-2D3748?logo=prisma&logoColor=white)](https://www.prisma.io/)
[![Power BI Ready](https://img.shields.io/badge/Power%20BI-Certified%20Model-F2C811?logo=powerbi&logoColor=black)](https://powerbi.microsoft.com/)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Metodología](https://img.shields.io/badge/Metodología-Kimball%20Bottom--Up-blue)](#)

> **Plataforma analítica y ecosistema de Business Intelligence para la gestión estratégica, la
> retención de socios y la optimización operativa de cadenas de gimnasios.**
> Modela el **ciclo de vida completo del socio** y lo traduce en indicadores de negocio para
> cada área de la organización.

---

## Índice

- [1. Matriz Bus del Data Warehouse](#1-matriz-bus-del-data-warehouse)
- [2. El negocio: actores y decisiones](#2-el-negocio-actores-y-decisiones)
- [3. Data Marts y los 7 hechos](#3-data-marts-y-los-7-hechos)
- [4. Dimensiones conformadas](#4-dimensiones-conformadas)
- [5. Indicadores: qué se mide](#5-indicadores-qué-se-mide)
- [6. Reglas de calidad de datos](#6-reglas-de-calidad-de-datos)
- [7. API para el frontend — por actor](#7-api-para-el-frontend--por-actor)
- [8. Flujo de la información](#8-flujo-de-la-información)
- [9. Puesta en marcha (Quickstart)](#9-puesta-en-marcha-quickstart)
- [10. Documentación del repositorio](#10-documentación-del-repositorio)

---

## 1. Matriz Bus del Data Warehouse

Siguiendo la **metodología Kimball (Bottom-Up)**, el Data Warehouse **no es una base monolítica**:
es la suma de **Data Marts temáticos por proceso de negocio** que comparten un conjunto único de
**Dimensiones Conformadas**. La *Matriz Bus* es el plano que garantiza que todos los data marts
hablen el mismo idioma y sean comparables entre sí.

**Dimensiones conformadas (esquema `dim`):** `DimFecha`, `DimCliente`, `DimEmpleado`, `DimPlan`.
**Data marts (3):** `dm_comercial`, `dm_entrenamiento`, `dm_atencion`.
**Hechos (7):** dos comerciales, tres de entrenamiento y dos de atención.

| Data Mart | Hecho | Grano declarado | Fecha | Cliente | Empleado | Plan |
| :--- | :--- | :--- | :---: | :---: | :---: | :---: |
| **Comercial** | `FactVentas` | Un pago confirmado (`id_pago_bk`) | ✅ | ✅ | ✅ | ✅ |
| **Comercial** | `FactMembresias` | Una membresía en una fecha de corte (`id_membresia_bk` + `sk_fecha_corte`) | ✅ | ✅ | ✅ | ✅ |
| **Entrenamiento** | `FactAsistencias` | Una marcación real de acceso (`id_asistencia_bk`) | ✅ | ✅ | ✅ | ✅ |
| **Entrenamiento** | `FactSesionesEntrenamiento` | Una sesión programada (`id_sesion_bk`) | ✅ | ✅ | ✅ | ✅ |
| **Entrenamiento** | `FactSeguimientoFisico` | Un cliente, un objetivo y una fecha de corte (`sk_cliente` + `id_objetivo_bk` + `sk_fecha_corte`) | ✅ | ✅ | ✅ | — |
| **Atención** | `FactReclamos` | Un reclamo registrado (`id_reclamo_bk`) | ✅ | ✅ | ✅ | — |
| **Atención** | `FactRetenciones` | Una acción de retención (`id_retencion_bk`) | ✅ | ✅ | ✅ | ✅ |

*Leyenda: ✅ el proceso usa la dimensión · — no aplica.*

> **Consolidación (bloques M01/M02/M03 del requerimiento):**
> - **M01 Comercial:** `FactRenovaciones` y `FactAvisos` se **absorben** en `FactMembresias`.
>   Conservar `FactVentas` aparte mantiene la fecha, el importe y la atribución real del cobro.
> - **M02 Entrenamiento:** `FactObjetivos`, `FactEvaluaciones` y `FactEvaluacionesProgramadas`
>   se consolidan en `FactSeguimientoFisico`, sin perder el detalle de cada objetivo.
> - **M03 Atención:** reclamo y acción de retención siguen separados; unirlos por cliente
>   multiplicaría casos y resultados.

```mermaid
flowchart LR
  subgraph DIM["Dimensiones Conformadas (esquema dim)"]
    direction TB
    DF["DimFecha<br>(tiempo)"]
    DC["DimCliente<br>(socios)"]
    DE["DimEmpleado<br>(codigo · area · cargo)"]
    DP["DimPlan<br>(plan · operación · promoción)"]
  end

  subgraph DMC["dm_comercial"]
    FV["FactVentas"]
    FM["FactMembresias<br>(+ renovaciones + avisos)"]
  end

  subgraph DME["dm_entrenamiento"]
    FAS["FactAsistencias"]
    FSE["FactSesionesEntrenamiento"]
    FSF["FactSeguimientoFisico<br>(+ objetivos + evaluaciones)"]
  end

  subgraph DMA["dm_atencion"]
    FRE["FactReclamos"]
    FRT["FactRetenciones"]
  end

  DIM ==> DMC
  DIM ==> DME
  DIM ==> DMA
```

> **¿Por qué importa?** Al compartir dimensiones, el negocio puede cruzar datos de distintas áreas:
> por ejemplo, relacionar a los socios que **renuevan** (`dm_comercial`) con su **frecuencia de
> asistencia** (`dm_entrenamiento`) y su **historial de reclamos** (`dm_atencion`).

---

## 2. El negocio: actores y decisiones

VIP Center Fit transforma los datos operativos del gimnasio en decisiones. El modelo responde a las
problemáticas reales del sector: **abandono temprano (churn)**, **pérdida de renovaciones**,
**deserción por falta de metas** y **fricción en el mostrador**.

| Actor / Rol | Preguntas de negocio | Decisión que habilita |
| :--- | :--- | :--- |
| **Gerencia General** | ¿Cómo evolucionan los ingresos, las membresías activas y la retención? | Sostenibilidad financiera, proyección de ingresos recurrentes, control del *churn*. |
| **Jefatura Comercial** | ¿Qué planes y promociones rinden más? ¿Se avisa a tiempo antes del vencimiento? | Optimización del catálogo y de las campañas de renovación preventiva. |
| **Coordinación de Entrenamiento** | ¿Quiénes asisten poco, progresan poco o tienen evaluaciones pendientes? | Intervención temprana para evitar el abandono por estancamiento. |
| **Recepción y Atención** | ¿Se resuelven los reclamos en el mostrador? ¿Qué rescates de baja funcionan? | Retención en el punto de contacto y mejora de la satisfacción. |

---

## 3. Data Marts y los 7 hechos

Cada Data Mart es un **esquema estrella** con claves foráneas físicas hacia las dimensiones
conformadas. El diagrama completo está en [`docs/ERD.md`](docs/ERD.md) (generado con Prisma).

### 3.1 `dm_comercial` — ingresos, membresías y avisos

* **Actor principal:** Administración y Jefatura Comercial.
* `FactVentas` (grano `id_pago_bk`): importes aditivos `monto_neto`, `descuento_aplicado`,
  `precio_lista` y `metodo_pago`.
* `FactMembresias` (grano `id_membresia_bk` + `sk_fecha_corte`):
  - snapshot **diario** del contrato: `estado_membresia` (ACTIVA / VENCIDA / PENDIENTE) calculado
    **en cada corte**, no copiado desde el estado actual;
  - enlace de cohorte `id_membresia_anterior_bk` / `id_membresia_nueva_bk` y `monto_renovacion`
    (absorbe las renovaciones);
  - aviso del corte: `aviso_emitido`, `sk_fecha_aviso`, `medio_aviso`, `avisos_emitidos_dia`
    (absorbe los avisos);
  - `dias_desde_vencimiento` para la ventana de observación (90 días después del vencimiento).

### 3.2 `dm_entrenamiento` — accesos, sesiones y progreso

* **Actor principal:** Coordinación de Entrenamiento.
* `FactAsistencias` (grano `id_asistencia_bk`): marcación real de torniquete, con
  `es_acceso_valido`. **No equivale** a una sesión programada.
* `FactSesionesEntrenamiento` (grano `id_sesion_bk`): programación, cancelación
  (`sk_fecha_cancelacion`, `motivo_cancelacion`) y resultado (`asistio`, `estado_sesion`).
* `FactSeguimientoFisico` (grano `sk_cliente` + `id_objetivo_bk` + `sk_fecha_corte`):
  - `valor_actual` = **última evaluación disponible hasta ese corte** (nunca una posterior);
  - `valor_esperado` = interpolación lineal `valor_inicial → valor_objetivo` en
    `[sk_fecha_inicio, sk_fecha_meta]`;
  - `avance_alcanzado`, `avance_esperado`, `porcentaje_progreso`;
  - `evaluacion_exigible`, `evaluacion_completada`, `evaluacion_pendiente`.

### 3.3 `dm_atencion` — reclamos y retención

* **Actor principal:** Recepción.
* `FactReclamos` (grano `id_reclamo_bk`): hitos de apertura, resolución y cierre
  (`sk_fecha_reclamo`, `sk_fecha_resolucion`, `sk_fecha_cierre`), `escalado`, `area_responsable`,
  `dias_resolucion`, `resuelto_en_mostrador`.
* `FactRetenciones` (grano `id_retencion_bk`): acción de mostrador con `canal`, `motivo`,
  `resultado`, `sk_fecha_vencimiento` y `recuperada` (resultado RETENIDO o renovación posterior).

### 3.4 Los dos snapshots diarios

`FactMembresias` y `FactSeguimientoFisico` comparten la misma mecánica:

1. La serie arranca en el **inicio** del contrato/objetivo, no en el día de la carga.
2. El ETL **añade los días faltantes** y actualiza la fila del mismo día si se re-ejecuta.
3. Una **corrección histórica** recalcula los cortes afectados.
4. Las medidas de estado (membresías activas, progreso, evaluaciones pendientes) **se leen en un
   corte**; nunca se suman entre días. Las cantidades de evento (avisos, ventas, reclamos) sí son
   aditivas.

---

## 4. Dimensiones conformadas

Son los maestros del negocio, enriquecidos y estandarizados, que **comparten los tres data marts**.
Viven en el esquema `dim`.

| Dimensión | Qué representa | Atributos de análisis |
| :--- | :--- | :--- |
| **`DimFecha`** | Calendario y estacionalidad. | año, trimestre, semestre, mes, día, día de semana, fin de semana. |
| **`DimCliente`** | Maestro único de socios (persona). **SCD Tipo 1** (sin historial; conserva marcas de validez del origen). | nombre, sexo, rango etario, estado (activo/inactivo). |
| **`DimEmpleado`** | Personal, **reestructurada** en el requerimiento v2. | **código de empleado** (clave de negocio visible), **área**, **cargo (puesto)** y nombre. |
| **`DimPlan`** | Plan, operación y promoción. | **tipo de plan** (mensual, trimestral, semestral, anual, quinquenal, por un día), **tipo de operación** (venta, membresía, asistencia, sesión) y **promoción**. |

* **`DimCliente`** es **SCD Tipo 1**: una sola fila por socio; un cambio de estado o rango etario
  sobrescribe la fila (no versiona historial).
* **`DimEmpleado`** cambia de forma respecto al modelo anterior: `codigo_empleado` pasa a ser una
  clave de negocio única y los atributos de bus son `area`, `cargo` y el propio código. El nombre se
  conserva porque el modelo semántico de Power BI sigue filtrando por *Empleado: nombre/puesto/área*.
* **`DimPlan`** unifica en una sola dimensión las tres propuestas originales (tipo de plan, tipo de
  operación y promoción); absorbe el antiguo catálogo de promociones, que no calificaba como
  dimensión propia.
* **Miembros centinela (`-1`)** e **imputación**: un hecho que no resuelve su dimensión **no se
  descarta**; se imputa al miembro centinela (`CLIENTE NO IDENTIFICADO`, `SIN EMPLEADO`, etc.) y se
  registra la alerta en `dq.RegistroImputaciones` (ver [`docs/CALIDAD.md`](docs/CALIDAD.md)). Las FK
  de hechos nunca quedan `NULL`.

---

## 5. Indicadores: qué se mide

El DW publica **14 vistas** `dbo.DM_*` que desacoplan las fórmulas del consumidor final (Power BI
o API). Cada vista corresponde a las preguntas de negocio de un área.

| Área | Vista | Qué responde |
| :--- | :--- | :--- |
| **Gerencia** | `DM_Gerencia_Ingresos` | Ingresos del período actual vs. anterior y tasa de crecimiento. |
| **Gerencia** | `DM_Gerencia_Membresias` | Clientes activos al inicio/cierre, retención y renovación de cohortes. |
| **Comercial** | `DM_Comercial_Plan` | Ingresos, ventas, vencimientos y renovación por tipo de plan. |
| **Comercial** | `DM_Comercial_Promociones` | Ingresos, membresías vendidas y clientes captados por promoción. |
| **Comercial** | `DM_Avisos_Cobertura` | Cobertura de avisos preventivos (ventana 7 días) y avisos del día. |
| **Atención** | `DM_Atencion_Reclamos` | Resolución general, **resolución directa en mostrador** y escalados. |
| **Atención** | `DM_Atencion_Recepcion` | Atenciones por sexo, rango etario y categoría. |
| **Atención** | `DM_Atencion_Retencion` | No renovadas atendidas, recuperadas y éxito de retención. |
| **Entrenamiento** | `DM_Entrenamiento_Asistencia` | Sesiones programadas vs. asistidas y tasa de asistencia. |
| **Entrenamiento** | `DM_Entrenamiento_Accesos` | **Accesos registrados** y **días con acceso** por cliente. |
| **Entrenamiento** | `DM_Entrenamiento_Progreso` | Valor inicial/actual/esperado, avance y % de progreso al corte. |
| **Entrenamiento** | `DM_Entrenamiento_BajoProgreso` | Clientes con al menos un objetivo por debajo del 100%. |
| **Entrenamiento** | `DM_Entrenamiento_Evaluaciones` | Evaluaciones exigibles, completadas y pendientes. |
| **Entrenamiento** | `DM_Rutinas_Entrenador` | Sesiones asistidas por entrenador, segmento y plan. |

> La trazabilidad de cada indicador contra el requerimiento corporativo está en
> [`docs/CUMPLIMIENTO_V2.md`](docs/CUMPLIMIENTO_V2.md).

---

## 6. Reglas de calidad de datos

Los datos operativos llegan "crudos" (con defectos a propósito). Antes de cargarse al DW, cada fila
pasa por **reglas de calidad**. El catálogo completo está en [`docs/CALIDAD.md`](docs/CALIDAD.md);
la auditoría ejecutable, en `sql/12_reglas_calidad.sql`.

**Corrección y estandarización** (el proceso limpia y normaliza; no descarta):

| Regla | Qué corrige |
| :--- | :--- |
| LIM-01/02 | DNI (formato a 8 dígitos) y nombre (mayúsculas, sin espacios dobles). |
| LIM-06 | Código de empleado obligatorio (se deriva de `id_empleado_bk` si falta). |
| EST-01/02 | Sexo → `M/F/X`; estado del cliente → `ACTIVO/INACTIVO`. |
| EST-04/06/07 | Catálogos de tipo de operación, estado de membresía y estado de sesión. |
| FEC-01/02 | Membresías con fin anterior al inicio y estado incoherente con el corte. |
| FEC-05 | Objetivos con fecha meta anterior al inicio. |
| SNP-01..07 | Duplicados de corte, huecos en la serie, avisos posteriores al vencimiento y evaluaciones inconsistentes. |

**Imputación auditada** (el hecho **siempre entra**; se imputa al centinela `-1` y queda registrado
en `dq.RegistroImputaciones`): filas que **no resuelven su cliente o su fecha** (reglas IMP-01..16).
Así no se pierde dinero y cada imputación es auditable con la vista `dq.V_ImputacionesPorRegla`.

---

## 7. API para el frontend — por actor

La API (.NET 8) expone los indicadores del DW por **REST**, un **dashboard agregado por actor**
(una sola llamada con todo lo que ese rol necesita) y **OData** para Power BI. Swagger: `/swagger`.

### Dashboards por actor (una llamada, ideal para el frontend)

| Actor | Endpoint | Contenido |
| :--- | :--- | :--- |
| **Gerencia General** | `GET /api/v1/actores/gerencia/dashboard` | Crecimiento y retención: ingresos y membresías. |
| **Jefatura Comercial** | `GET /api/v1/actores/comercial/dashboard` | Planes, promociones y cobertura de avisos. |
| **Coordinación de Entrenamiento** | `GET /api/v1/actores/entrenador/dashboard` | Asistencia, accesos, progreso, bajo progreso, evaluaciones y rutinas. |
| **Recepción** | `GET /api/v1/actores/recepcion/dashboard` | Reclamos, atención y retención. |

### Indicadores por área (REST)

| Actor | Endpoints |
| :--- | :--- |
| **Gerencia** | `/kpis/gerencia/ingresos`, `/kpis/gerencia/membresias` |
| **Comercial** | `/kpis/comercial/planes`, `/kpis/comercial/promociones`, `/kpis/comercial/avisos-cobertura` |
| **Entrenamiento** | `/kpis/entrenamiento/asistencia`, `/accesos`, `/progreso`, `/bajo-progreso`, `/evaluaciones`, `/rutinas` |
| **Recepción** | `/kpis/atencion/reclamos`, `/kpis/atencion/recepcion`, `/kpis/atencion/retencion` |

> Prefijo `/api/v1`. Filtros por querystring: `desde`/`hasta` (año), `plan`, `promocion`, `categoria`,
> `skCliente`, `tipoObjetivo`, `entrenador`, `canal`.

### Escritura (operación del gimnasio)

`POST /api/v1/{clientes, empleados, membresias, ventas, renovaciones, avisos, asistencias,
objetivos, evaluaciones, reclamos, sesiones-programadas, evaluaciones-programadas, retenciones}` —
simulan la web del gimnasio; cada cambio lo captura CDC. Las columnas nuevas de la reestructuración
(`codigoEmpleado`, `skFechaMeta`, `fechaCierre`/`escalado`/`areaResponsable`, `fechaCancelacion`)
viajan en el mismo endpoint que ya existía.

### OData (Power BI) y monitoreo

* `/odata/DM_*` — 14 *entity sets* de KPIs con `$select`, `$filter`, `$orderby`, `$top`, `$count`.
* `/odata/{DimFecha, DimCliente, DimEmpleado, DimPlan}` y
  `/odata/{FactVentas, FactMembresias, FactAsistencias, FactSesionesEntrenamiento,
  FactSeguimientoFisico, FactReclamos, FactRetenciones}` — **modelo en estrella** para importar en
  Power BI y relacionar por las claves `sk_*`. Los hechos aceptan `fechaDesde`/`fechaHasta`
  (ventana aplicada en SQL).
* `GET /api/v1/etl/estado` — estado del pipeline (marca de agua CDC + ETL + snapshots).
* `GET /health` — salud del servicio.

> Catálogo detallado de endpoints y ejemplos en [`docs/API.md`](docs/API.md).

---

## 8. Flujo de la información

```mermaid
sequenceDiagram
  autonumber
  actor Operacion as Operación del gimnasio
  participant CDC as Captura CDC (SQL Server)
  participant STG as Staging (stg.*)
  participant DW as Data Warehouse (dim + dm_*)
  actor Consumo as Power BI / API

  Operacion->>CDC: venta, asistencia, reclamo…
  Note over CDC: captura continua (~5 seg)
  CDC->>STG: cada 10 min (marca de agua LSN)
  Note over STG: sin limpiar (raw)
  STG->>DW: dims -> hechos de evento -> snapshots diarios
  Note over DW: MERGE por clave de negocio (solo filas nuevas)
  DW-->>Consumo: vistas DM_* y dashboards por actor
```

---

## 9. Puesta en marcha (Quickstart)

**Requisitos:** Docker + Docker Compose, Node.js 20+ y npm (.NET SDK 8 opcional para la API).

```bash
git clone https://github.com/tu-organizacion/vip-center-fit-bi.git
cd vip-center-fit-bi
npm install
cp .env.example .env

npm run db:bootstrap   # SQL Server + CDC + ETL inicial + snapshots + vistas + reglas de calidad
npm run uml            # genera el ERD (Prisma + Mermaid)

docker compose up -d --build api   # API en http://localhost:5080 (Swagger en /swagger)
```

Generar datos y ejecutar las pruebas de carga:

```bash
dotnet run --project src/VipCenterFit.Seeder -- --seed 1234 --clientes 200 --out jmeter/data
jmeter -n -t jmeter/lectura-kpis.jmx -l resultados/lectura.jtl -e -o resultados/lectura-html
jmeter -n -t jmeter/escritura-oltp.jmx -l resultados/escritura.jtl -e -o resultados/escritura-html
```

---

## 10. Documentación del repositorio

| Documento | Contenido |
| :--- | :--- |
| 📘 [`docs/ARQUITECTURA.md`](docs/ARQUITECTURA.md) | Blueprint de 7 etapas del pipeline y diseño en constelación. |
| 📊 [`docs/CUMPLIMIENTO_V2.md`](docs/CUMPLIMIENTO_V2.md) | Trazabilidad de cada indicador contra el requerimiento v2. |
| 🔌 [`docs/API.md`](docs/API.md) | Catálogo completo de endpoints REST/OData. |
| 🧪 [`docs/CALIDAD.md`](docs/CALIDAD.md) | Catálogo de reglas de calidad (corrección e imputación). |
| 🛠️ [`docs/OPERACION.md`](docs/OPERACION.md) | Runbook: jobs, backups y seguridad. |
| 📐 [`docs/ERD.md`](docs/ERD.md) | Diagrama entidad-relación de toda la constelación. |

---

*Diseñado y desarrollado para **VIP Center Fit** — Inteligencia de Datos aplicada al Alto Rendimiento.*
