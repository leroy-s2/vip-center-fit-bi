# Cumplimiento del modelo frente a `OFICIAL1.xlsx`

> ⚠️ **Documento histórico (modelo de 11 hechos).** El modelo vigente corresponde a
> `AEQUITECTURA BI (2).xlsx` (7 hechos) y su trazabilidad está en
> [`CUMPLIMIENTO_V2.md`](CUMPLIMIENTO_V2.md). Se conserva este archivo sólo como referencia de la
> versión anterior.

Verificación del Excel oficial (métricas, indicadores y KPIs por actor) contra el Data
Warehouse (3 data marts en constelación) y las APIs. Leyenda: ✅ cubierto · ⚠️ parcial ·
❌ falta (requiere modelar un dato que hoy no existe en la fuente).

## Gerencia General — DM_Comercial/Gerencia · vista `DM_Gerencia_Ingresos` y `DM_Gerencia_Membresias`

| Métrica / KPI del Excel | Calculado en | Estado |
| --- | --- | --- |
| Ingresos del periodo actual | `IngresosPeriodoActual` | ✅ |
| Ingresos del periodo anterior | `IngresosPeriodoAnterior` | ✅ |
| Tasa de crecimiento de ingresos | `TasaCrecimientoIngresos` | ✅ |
| Clientes activos al inicio | `ClientesActivosInicio` | ✅ |
| Clientes del inicio activos al cierre | `ClientesInicioActivosCierre` | ✅ |
| Tasa de retención de clientes | `TasaRetencionClientes` | ✅ |
| Membresías activas | `MembresiasActivas` | ✅ |
| Membresías que vencen en el periodo | `MembresiasVencenPeriodo` | ✅ |
| Membresías de la cohorte renovadas | `MembresiasCohorteRenovadas` | ✅ |
| Tasa de renovación de membresías | `TasaRenovacionMembresias` | ✅ |

API: `GET /api/v1/kpis/gerencia/ingresos`, `GET /api/v1/kpis/gerencia/membresias`, `GET /api/v1/kpis/ventas`.

## Administración y Área Comercial — `DM_Comercial_Plan` y `DM_Avisos_Cobertura`

| Métrica / KPI del Excel | Calculado en | Estado |
| --- | --- | --- |
| Ingresos por tipo de plan | `IngresosPorTipoPlan` | ✅ |
| Membresías vendidas por plan o promoción | `MembresiasVendidas` | ✅ |
| Membresías que vencen por tipo de plan | `MembresiasVencen` | ✅ |
| Membresías renovadas por tipo de plan | `MembresiasRenovadas` | ✅ |
| Tasa de renovación por tipo de plan | `TasaRenovacionPorPlan` | ✅ |
| Membresías próximas a vencer (ventana 7 días) | `MembresiasProximasVencer` | ✅ |
| Avisos de renovación emitidos | `AvisosRenovacionEmitidos` | ✅ |
| Tasa de cobertura de avisos de renovación | `TasaCoberturaAvisos` | ✅ |

**Métricas nuevas de promoción** (no estaban en el Excel): se derivan de `DimPlan.promocion` — los planes promocionales de periodo corto del catálogo.

| Métrica nueva | Vista | Dimensiones (matriz bus) |
| --- | --- | --- |
| Ingresos, ventas y descuento por promoción | `DM_Promociones_Ventas` | Fecha, Plan |
| Membresías vendidas/renovadas por promoción y empleado | `DM_Promociones_Membresias` | Fecha, Empleado, Plan |
| Clientes captados por promoción y segmento | `DM_Promociones_Clientes` | Fecha, Cliente, Plan |

API: `GET /api/v1/kpis/comercial/planes`, `GET /api/v1/kpis/comercial/avisos-cobertura`.

## Recepción — `DM_Atencion_Reclamos` y `DM_Atencion_Recepcion`

| Métrica / KPI del Excel | Calculado en | Estado |
| --- | --- | --- |
| Reclamos registrados | `ReclamosRegistrados` | ✅ |
| Reclamos resueltos (según estado) | `ReclamosResueltosSegunEstado` | ✅ |
| Tasa de resolución (según estado) | `TasaResolucionSegunEstado` | ✅ |
| Tasa de resolución **directa en mostrador** | `TasaResolucionDirectaMostrador` | ✅ |
| Membresías no renovadas (inactivas) | aproximable (`Vencen − Renovadas`) | ⚠️ no se publica como métrica |
| Clientes retenidos tras acción de retención | `ClientesRetenidos` | ✅ |
| Tasa de éxito de retención en mostrador | `TasaExitoRetencion` | ✅ |

API: `GET /api/v1/kpis/atencion/reclamos`, `GET /api/v1/kpis/atencion/recepcion`, `GET /api/v1/kpis/atencion/retencion`.

## Entrenador — `DM_Entrenamiento_Asistencia`, `DM_Entrenamiento_Progreso`, `DM_Entrenamiento_Cumplimiento`, `DM_Entrenamiento_Evaluaciones`, `DM_Rutinas_Entrenador`

| Métrica / KPI del Excel | Calculado en | Estado |
| --- | --- | --- |
| Sesiones asistidas por cliente | `SesionesAsistidasRegistradas` | ✅ |
| Sesiones programadas por cliente | `SesionesProgramadas` | ✅ |
| Tasa de asistencia por cliente | `TasaAsistencia` | ✅ |
| Valor inicial / actual / esperado del objetivo | `ValorInicialObjetivo`, `ValorActualObjetivo`, `ValorObjetivo` | ✅ |
| Avance alcanzado / esperado | `AvanceAlcanzado`, `AvanceEsperado` | ✅ |
| Porcentaje de progreso por cliente y objetivo | `PorcentajeProgreso` | ✅ |
| Clientes con bajo progreso | `TieneBajoProgreso` | ✅ |
| Evaluaciones exigibles al corte | `EvaluacionesProgramadas` | ✅ |
| Evaluaciones exigibles completadas | `EvaluacionesCompletadas` | ✅ |
| Evaluaciones físicas pendientes | `EvaluacionesPendientes` | ✅ |

API: `GET /api/v1/kpis/entrenamiento/asistencia|progreso|cumplimiento|evaluaciones|rutinas`.

## Matriz bus (dimensiones conformadas)

El Excel pide dimensiones fecha (año/trimestre/mes/día), cliente (nombre/sexo/rango etario),
empleado (nombre/puesto/área) y plan (tipo de plan / tipo de operación / promoción). El esquema
`dim` las cubre con **4 dimensiones conformadas**: `DimFecha` (anio/trimestre/mes/dia),
`DimCliente` (nombre_completo/sexo/rango_etario), `DimEmpleado` (nombre_completo/cargo/area)
y `DimPlan` (tipo_plan/tipo_operacion/promocion), que absorbe el antiguo `DimPromocion`. ✅

## Brechas cerradas (datos nuevos en la fuente)

Las 4 brechas que requerían datos inexistentes en la fuente ya están modeladas de extremo a
extremo (ORIGEN → CDC → STG → ETL → vista `DM_*` → endpoints REST/OData + seeder/JMeter/tests):

1. **Tasa de asistencia** — nueva tabla `FactSesionesProgramadas` (denominador) → vista
   `DM_Entrenamiento_Asistencia` (`SesionesProgramadas`, `TasaAsistencia`).
2. **Resolución directa de reclamos** — columna `resuelto_en_mostrador` en `FactReclamos` →
   `DM_Atencion_Reclamos` (`ReclamosResueltosMostrador`, `TasaResolucionDirectaMostrador`).
3. **Evaluaciones físicas pendientes/exigibles** — nueva tabla `FactEvaluacionesProgramadas`
   (fecha prevista) → vista `DM_Entrenamiento_Evaluaciones` (`EvaluacionesProgramadas`,
   `EvaluacionesCompletadas`, `EvaluacionesPendientes`, `TasaCumplimientoEvaluaciones`).
4. **Retención en mostrador** — nueva tabla `FactRetenciones` (acción y resultado) → vista
   `DM_Atencion_Retencion` (`AccionesRetencion`, `ClientesRetenidos`, `TasaExitoRetencion`).

Escritura: `POST /api/v1/sesiones-programadas`, `POST /api/v1/evaluaciones-programadas`,
`POST /api/v1/retenciones`. Las limitaciones declaradas previas en `sql/05_metricas_datamart.sql`
quedaron reemplazadas por su implementación.
