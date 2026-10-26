# Cumplimiento del modelo frente a `AEQUITECTURA BI (2).xlsx`

Trazabilidad de cada métrica/KPI/indicador del requerimiento v2 contra el Data Warehouse de
7 hechos, las vistas `dbo.DM_*` y los endpoints REST/OData.

Leyenda: ✅ cubierto · ⚠️ cubierto con una limitación declarada.

**Modelo de referencia**

| Elemento | Requerimiento v2 | Implementación |
| :--- | :--- | :--- |
| Data marts | 3 | `dm_comercial`, `dm_entrenamiento`, `dm_atencion` |
| Hechos | 7 | `FactVentas`, `FactMembresias`, `FactAsistencias`, `FactSesionesEntrenamiento`, `FactSeguimientoFisico`, `FactReclamos`, `FactRetenciones` |
| Dimensiones | 4 | `DimFecha`, `DimCliente`, `DimEmpleado` (reestructurada), `DimPlan` |
| Consolidaciones | M01/M02/M03 | renovaciones y avisos → `FactMembresias`; objetivos y evaluaciones → `FactSeguimientoFisico` |

---

## 1. Gerencia General

*Pregunta:* ¿cómo evolucionan los ingresos, las membresías activas, las renovaciones y la retención?

| Métrica / KPI | Tipo | Vista / campo | Hecho | Estado |
| :--- | :--- | :--- | :--- | :---: |
| Ingresos del periodo actual | Métrica | `DM_Gerencia_Ingresos.IngresosPeriodoActual` | FactVentas | ✅ |
| Ingresos del periodo anterior | Métrica | `DM_Gerencia_Ingresos.IngresosPeriodoAnterior` | FactVentas | ✅ |
| Tasa de crecimiento de ingresos | KPI | `DM_Gerencia_Ingresos.TasaCrecimientoIngresos` | FactVentas | ✅ |
| Clientes activos al inicio | Métrica | `DM_Gerencia_Membresias.ClientesActivosInicio` | FactMembresias (corte de inicio) | ✅ |
| Clientes del inicio activos al cierre | Métrica | `DM_Gerencia_Membresias.ClientesInicioActivosCierre` | FactMembresias (corte de cierre) | ✅ |
| Tasa de retención de clientes | KPI | `DM_Gerencia_Membresias.TasaRetencionClientes` | FactMembresias | ✅ |
| Membresías activas | Métrica | `DM_Gerencia_Membresias.MembresiasActivas` | FactMembresias | ✅ |
| Membresías que vencen en el periodo | Métrica | `DM_Gerencia_Membresias.MembresiasVencenPeriodo` | FactMembresias | ✅ |
| Membresías de la cohorte renovadas | Métrica | `DM_Gerencia_Membresias.MembresiasCohorteRenovadas` | FactMembresias | ✅ |
| Tasa de renovación de membresías | KPI | `DM_Gerencia_Membresias.TasaRenovacionMembresias` | FactMembresias | ✅ |

API: `GET /api/v1/kpis/gerencia/ingresos`, `GET /api/v1/kpis/gerencia/membresias`.

> Las medidas de estado usan el **último corte del mes** (`SkFechaCorteCierre`), no la suma de los
> cortes diarios.

## 2. Administración y Área Comercial

*Pregunta:* ¿qué planes, promociones y avisos preventivos generan más ventas y renovaciones?

| Métrica / KPI | Tipo | Vista / campo | Hecho | Estado |
| :--- | :--- | :--- | :--- | :---: |
| Ingresos por tipo de plan | Métrica | `DM_Comercial_Plan.IngresosPorTipoPlan` | FactVentas | ✅ |
| Membresías vendidas por plan o promoción | Métrica | `DM_Comercial_Plan.MembresiasVendidas`, `DM_Comercial_Promociones.MembresiasVendidas` | FactMembresias | ✅ |
| Membresías que vencen por tipo de plan | Métrica | `DM_Comercial_Plan.MembresiasVencen` | FactMembresias | ✅ |
| Membresías renovadas por tipo de plan | Métrica | `DM_Comercial_Plan.MembresiasRenovadas` | FactMembresias | ✅ |
| Tasa de renovación por tipo de plan | Indicador | `DM_Comercial_Plan.TasaRenovacionPorPlan` | FactMembresias | ✅ |
| Membresías próximas a vencer (7 días) | Métrica | `DM_Avisos_Cobertura.MembresiasProximasVencer` | FactMembresias | ✅ |
| Avisos de renovación emitidos | Métrica | `DM_Avisos_Cobertura.MembresiasConAviso`, `AvisosEmitidosDia` | FactMembresias | ✅ |
| Tasa de cobertura de avisos | KPI | `DM_Avisos_Cobertura.TasaCoberturaAvisos` | FactMembresias | ✅ |
| Ingresos por promoción | Métrica | `DM_Comercial_Promociones.IngresosPorPromocion` | FactVentas | ✅ |
| Membresías vendidas por promoción | Métrica | `DM_Comercial_Promociones.MembresiasVendidas` | FactMembresias | ✅ |
| Clientes captados por promoción | Métrica | `DM_Comercial_Promociones.ClientesCaptados` | FactMembresias | ✅ |

API: `GET /api/v1/kpis/comercial/planes`, `/promociones`, `/avisos-cobertura`.

> El requerimiento pide los avisos como **cantidad del día**; por eso `avisos_emitidos_dia` es
> aditivo y la cobertura se evalúa al corte con `aviso_emitido`.

## 3. Recepción

*Pregunta:* ¿cuál es la efectividad en la retención de membresías vencidas y en la resolución de
reclamos en mostrador?

| Métrica / KPI | Tipo | Vista / campo | Hecho | Estado |
| :--- | :--- | :--- | :--- | :---: |
| Membresías no renovadas atendidas | Métrica | `DM_Atencion_Retencion.MembresiasNoRenovadasAtendidas` | FactRetenciones + FactMembresias | ✅ |
| Membresías recuperadas tras acción | Métrica | `DM_Atencion_Retencion.MembresiasRecuperadas` | FactRetenciones | ✅ |
| Tasa de éxito de retención en mostrador | KPI | `DM_Atencion_Retencion.TasaExitoRetencion` | FactRetenciones | ✅ |
| Reclamos registrados | Métrica | `DM_Atencion_Reclamos.ReclamosRegistrados` | FactReclamos | ✅ |
| Reclamos resueltos en mostrador | Métrica | `DM_Atencion_Reclamos.ReclamosResueltosMostrador` | FactReclamos | ✅ |
| Tasa de resolución directa de reclamos | Indicador | `DM_Atencion_Reclamos.TasaResolucionDirectaMostrador` | FactReclamos | ✅ |
| Reclamos escalados | Métrica (nueva) | `DM_Atencion_Reclamos.ReclamosEscalados` | FactReclamos | ✅ |
| Atenciones por segmento y categoría | Métrica | `DM_Atencion_Recepcion.*` | FactReclamos | ✅ |

API: `GET /api/v1/kpis/atencion/reclamos`, `/recepcion`, `/retencion`.

## 4. Entrenador

*Pregunta:* ¿qué clientes presentan baja asistencia, poco progreso o evaluaciones pendientes?

| Métrica / KPI | Tipo | Vista / campo | Hecho | Estado |
| :--- | :--- | :--- | :--- | :---: |
| Sesiones asistidas por cliente | Métrica | `DM_Entrenamiento_Asistencia.SesionesAsistidasRegistradas` | FactSesionesEntrenamiento | ✅ |
| Sesiones programadas por cliente | Métrica | `DM_Entrenamiento_Asistencia.SesionesProgramadas` (excluye canceladas) | FactSesionesEntrenamiento | ✅ |
| Tasa de asistencia por cliente | KPI | `DM_Entrenamiento_Asistencia.TasaAsistencia` | FactSesionesEntrenamiento | ✅ |
| Valor inicial del objetivo físico | Métrica | `DM_Entrenamiento_Progreso.ValorInicialObjetivo` | FactSeguimientoFisico | ✅ |
| Valor actual del objetivo físico | Métrica | `DM_Entrenamiento_Progreso.ValorActualObjetivo` | FactSeguimientoFisico | ✅ |
| Valor esperado al corte | Métrica | `DM_Entrenamiento_Progreso.ValorEsperado` | FactSeguimientoFisico | ✅ |
| Avance alcanzado | Métrica | `DM_Entrenamiento_Progreso.AvanceAlcanzado` | FactSeguimientoFisico | ✅ |
| Avance esperado | Métrica | `DM_Entrenamiento_Progreso.AvanceEsperado` | FactSeguimientoFisico | ✅ |
| Porcentaje de progreso | Indicador | `DM_Entrenamiento_Progreso.PorcentajeProgreso` | FactSeguimientoFisico | ✅ |
| Clientes con bajo progreso | Métrica | `DM_Entrenamiento_BajoProgreso.ObjetivosBajoProgreso` | FactSeguimientoFisico | ✅ |
| Evaluaciones exigibles al corte | Métrica | `DM_Entrenamiento_Evaluaciones.EvaluacionesExigibles` | FactSeguimientoFisico | ✅ |
| Evaluaciones exigibles completadas | Métrica | `DM_Entrenamiento_Evaluaciones.EvaluacionesCompletadas` | FactSeguimientoFisico | ✅ |
| Evaluaciones físicas pendientes | Métrica | `DM_Entrenamiento_Evaluaciones.EvaluacionesPendientes` | FactSeguimientoFisico | ✅ |
| **Accesos registrados al gimnasio** | Métrica (nueva v2) | `DM_Entrenamiento_Accesos.AccesosRegistrados` | FactAsistencias | ✅ |
| **Días con acceso al gimnasio** | Métrica (nueva v2) | `DM_Entrenamiento_Accesos.DiasConAcceso` | FactAsistencias | ✅ |
| Sesiones asistidas por entrenador | Métrica | `DM_Rutinas_Entrenador.TotalAsistencias` | FactSesionesEntrenamiento | ✅ |

API: `GET /api/v1/kpis/entrenamiento/asistencia`, `/accesos`, `/progreso`, `/bajo-progreso`,
`/evaluaciones`, `/rutinas`.

> **Accesos ≠ sesiones.** `FactAsistencias` mide el ingreso real al club; `FactSesionesEntrenamiento`
> mide la sesión programada y su resultado. El requerimiento v2 los separa explícitamente.

---

## 5. Matriz bus (dimensiones del requerimiento v2)

| Proceso | Hechos | Fecha (año/trim/mes/día) | Cliente (nombre/sexo/rango) | Empleado (área/cargo/código) | Plan (tipo/operación/promoción) |
| :--- | :--- | :---: | :---: | :---: | :---: |
| Gestión de Inscripciones y Membresías | FactVentas, FactMembresias | ✅ | ✅ | ✅ | ✅ |
| Servicio de Entrenamiento y Clases | FactAsistencias, FactSesionesEntrenamiento | ✅ | ✅ | ✅ | ✅ |
| Servicio de Entrenamiento y Clases | FactSeguimientoFisico | ✅ | ✅ | ✅ | — |
| Atención y Fidelización del Cliente | FactReclamos | ✅ | ✅ | ✅ | — |
| Atención y Fidelización del Cliente | FactRetenciones | ✅ | ✅ | ✅ | ✅ |

Las tres excepciones (`—`) coinciden con los FALSE de la hoja MATRIZ BUS: seguimiento físico y
reclamos no usan la dimensión Plan.

## 6. Modelo semántico (Power BI)

| KPI | Fuente | Medida DAX esperada | Dimensiones de filtro |
| :--- | :--- | :--- | :--- |
| Tasa de crecimiento de ingresos | FactVentas | `DIVIDE([Ingresos actual] - [Ingresos anterior], [Ingresos anterior])` | Fecha, Membresía (tipo de plan) |
| Tasa de retención de clientes | FactMembresias | `DIVIDE([Clientes inicio activos al cierre], [Clientes activos al inicio])` | Fecha, Cliente, Membresía |
| Tasa de cobertura de avisos | FactMembresias | `DIVIDE([Próximas a vencer con aviso], [Próximas a vencer])` | Fecha, Membresía |
| Tasa de éxito de retención en mostrador | FactRetenciones | `DIVIDE([Recuperadas], [No renovadas atendidas])` | Fecha, Cliente, Empleado, Plan, Tipo de operación |
| Tasa de asistencia por cliente | FactSesionesEntrenamiento | `DIVIDE([Sesiones asistidas], [Sesiones programadas])` | Fecha, Cliente, Tipo de operación |

`DimEmpleado` expone `CodigoEmpleado`, `Area`, `Cargo` y `NombreCompleto`; `DimPlan` sigue actuando
como la dimensión "Membresía" (`TipoPlan`) del modelo semántico.

---

## 7. Limitaciones declaradas

1. **Medidas de estado no aditivas**: `MembresiasActivas`, `PorcentajeProgreso` y
   `EvaluacionesPendientes` se leen en un corte. Sumarlas entre días sobreestima el resultado.
2. **Ventana de observación de 90 días** después del vencimiento: es suficiente para observar
   renovación y recuperación, pero una membresía inactiva más antigua no aparece en los cortes
   posteriores.
3. **`@FechaCorte` por defecto = hoy** (acotado al último día del calendario). El bootstrap usa
   `2026-09-29`, la fecha de referencia de los datos de práctica.
4. **Avisos múltiples el mismo día**: el snapshot conserva el primero y la cantidad del día.
