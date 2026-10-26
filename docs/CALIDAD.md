# Calidad de Datos — VIP Center Fit BI

Catálogo de las **reglas de calidad** aplicadas en la Etapa 4 (transformación y carga del
Data Mart), su severidad y la acción que ejecuta el ETL. Se complementa con:

- `sql/04_transformacion_datamart.sql` → aplica las reglas (corrige o imputa al centinela `-1`).
- `sql/12_reglas_calidad.sql` → **queries de auditoría** que detectan violaciones sobre el DW.
- `dq.RegistroImputaciones` (esquema `dq`) → bitácora de las imputaciones a miembros centinela.

Severidades: **Alta** (afecta integridad/imputación de hechos) · **Media** (calidad analítica) ·
**Baja** (cosmética/consistencia).

---

## 1. Reglas de corrección (el ETL normaliza, no rechaza)

| ID | Categoría | Campo / Entidad | Condición | Severidad | Acción |
| :--- | :--- | :--- | :--- | :---: | :--- |
| CAL-01 | Limpieza | `DimCliente.dni` | No numérico o longitud ≠ 8 | Media | Normaliza (`-`, espacios, `O`→`0`); si persiste inválido → `NULL` |
| CAL-02 | Limpieza | `DimCliente.nombre_completo` | Vacío / solo espacios | Baja | `UPPER/TRIM` y colapsa dobles espacios; vacío → `'SIN NOMBRE'` |
| CAL-03 | Estandarización | `DimCliente.sexo` | Fuera de `M/F/X` | Media | Mapea a `M`/`F`; desconocido → `X` |
| CAL-04 | Estandarización | `DimCliente.estado_cliente` | Fuera de dominio | Media | ` LIKE 'ACT%'` → `ACTIVO`; resto → `INACTIVO` |
| CAL-05 | Estandarización | `FactVentas.metodo_pago` | Variantes (`yape`, `Transf.`, …) | Baja | Enum `YAPE/PLIN/TRANSFERENCIA/TARJETA/EFECTIVO/NO ESPECIFICADO` |
| CAL-06 | Limpieza | Montos (`monto_neto`, `precio_final`, `precio_lista`, `descuento_aplicado`) | Negativos o NULL | Alta | `monto_neto` NULL/negativo → `0`; otros negativos → `NULL` |
| CAL-07 | Fechas | `DimCliente.fecha_*` | Fuera de `[2000-01-01, @FechaCorte]` | Media | → `NULL` |
| CAL-08 | Fechas | `DimCliente.fecha_fin_validez` | Anterior a `fecha_inicio_validez` | Media | → `NULL` |
| CAL-09 | Estados | `FactMembresias.estado_membresia` | Inconsistente con las fechas | Alta | **Recalcula en cada corte** (`ACTIVA`/`VENCIDA`/`PENDIENTE`) según la fecha del snapshot |
| CAL-10 | Limpieza | `FactAsistencias.hora_ingreso` | Fuera de `[5, 23]` | Baja | → `NULL` y `es_acceso_valido = 0` |
| CAL-11 | Limpieza | `FactSeguimientoFisico.peso/altura` | Fuera de rango o unidad distinta | Media | `lb→kg`, `cm→m`; fuera de rango → `NULL` |
| CAL-12 | Estandarización | `FactReclamos`/`FactRetenciones`/`FactSeguimientoFisico`/sesiones | Texto libre | Baja | Mapea a dominios (COBRO/SERVICIO, RESUELTO/PENDIENTE, canal, motivo, tipo de objetivo, tipo de sesión…) |
| CAL-13 | Estandarización | `DimPlan` | Catálogo de planes | Media | Deriva `tipo_plan`, `tipo_operacion` y `promocion` |
| CAL-14 | Estandarización | `DimEmpleado.codigo_empleado` | Ausente | Media | Deriva `EMP-<id_empleado_bk>` (regla IMP-13) |
| CAL-15 | Fechas | `FactMembresias.sk_fecha_fin` | Anterior a `sk_fecha_inicio` | Alta | Ajusta al día de inicio (regla IMP-15) |
| CAL-16 | Fechas | `FactMembresias.sk_fecha_meta` | Ausente en el objetivo | Media | Usa `inicio + 90 días`; el valor esperado queda plano (regla IMP-14) |

---

## 2. Reglas de imputación (el hecho **siempre entra**)

**En un Data Warehouse no se descarta dinero.** Si un hecho no resuelve su dimensión
conformada, se **imputa a un miembro centinela** y se dispara una **alerta**; la fila queda
cargada. Las imputaciones se registran en `dq.RegistroImputaciones`.

**Miembros centinela (`-1`):** `DimCliente` → `CLIENTE NO IDENTIFICADO`, `DimEmpleado` →
`SIN EMPLEADO`, `DimPlan` → `NO_APLICA/NO_ESPECIFICADO/SIN PROMOCION`, `DimFecha` → `1900-01-01`
(fecha desconocida).

| ID | Entidad | Campo | Condición | Acción |
| :--- | :--- | :--- | :--- | :--- |
| IMP-01 | `DimCliente` | `id_cliente_bk` | `NULL` | Miembro excluido (no forma dimensión) |
| IMP-02 | `DimFecha` | `fecha` | `NULL` o fuera de `[2000-01-01, 2100-12-31]` | Miembro excluido |
| IMP-03 | `FactVentas` | `sk_cliente` | No resuelve | Imputa `sk_cliente = -1` + alerta |
| IMP-04 | `FactVentas` | `sk_fecha_pago` | No resuelve | Imputa `-1` + alerta |
| IMP-05 | `FactMembresias` | `sk_cliente` | No resuelve | Imputa `-1` + alerta |
| IMP-06 | `FactMembresias` | `sk_fecha_inicio` | No resuelve | Imputa `-1` + alerta |
| IMP-07 | `FactAsistencias` | `sk_cliente` | No resuelve | Imputa `-1` + alerta |
| IMP-08 | `FactAsistencias` | `sk_fecha_asistencia` | No resuelve | Imputa `-1` + alerta |
| IMP-09 | `FactReclamos` | `sk_cliente` | No resuelve | Imputa `-1` + alerta |
| IMP-10 | `FactReclamos` | `sk_fecha_reclamo` | No resuelve | Imputa `-1` + alerta |
| IMP-11 | `FactRetenciones` | `sk_cliente` | No resuelve | Imputa `-1` + alerta |
| IMP-12 | `FactRetenciones` | `sk_fecha_retencion` | No resuelve | Imputa `-1` + alerta |
| IMP-13 | `DimEmpleado` | `codigo_empleado` | Ausente | Deriva `EMP-<id_empleado_bk>` |
| IMP-14 | `FactSeguimientoFisico` | `sk_fecha_meta` | Ausente en el objetivo | Usa `inicio + 90 días`; el valor esperado queda plano |
| IMP-15 | `FactMembresias` | `sk_fecha_fin` | Anterior a `sk_fecha_inicio` | Ajusta `fin = inicio` |
| IMP-16 | `FactMembresias` | `sk_fecha_aviso` | Posterior al vencimiento | Descarta el aviso del snapshot (no es aviso de renovación) |

Las FK de hechos a empleado/plan (`sk_empleado`, `sk_plan`) son **`NOT NULL`** y también se
imputan al centinela cuando no resuelven.

### 2.1 Reglas propias de los snapshots diarios (SNP-*)

`FactMembresias` y `FactSeguimientoFisico` tienen grano *clave de negocio + fecha de corte*. Además
de las reglas anteriores, el ETL y la auditoría verifican:

| ID | Entidad | Condición | Severidad | Acción |
| :--- | :--- | :--- | :---: | :--- |
| SNP-01 | `FactMembresias` | Corte duplicado (`id_membresia_bk` + `sk_fecha_corte`) | Alta | El MERGE actualiza la fila existente, nunca inserta un duplicado |
| SNP-02 | `FactSeguimientoFisico` | Corte duplicado (`sk_cliente` + `id_objetivo_bk` + `sk_fecha_corte`) | Alta | Igual que SNP-01 |
| SNP-03 | `FactMembresias` | Corte anterior al inicio del contrato | Alta | La ventana arranca en `sk_fecha_inicio` |
| SNP-04 | `FactMembresias` | `aviso_emitido` retrocede en la serie | Media | El flag es acumulado: una vez emitido no vuelve a 0 |
| SNP-05 | `FactMembresias` | Aviso con fecha posterior al vencimiento | Media | Se descarta del snapshot (IMP-16) |
| SNP-06 | `FactSeguimientoFisico` | `evaluacion_completada = 1` sin `id_evaluacion_bk` | Alta | Deriva del último registro de evaluación ≤ corte |
| SNP-07 | `FactSeguimientoFisico` | `evaluacion_pendiente` incoherente | Alta | `pendiente = exigible AND NOT completada` |

**Reglas temporales del snapshot de seguimiento físico:** `valor_actual` usa la última evaluación
con fecha ≤ corte (nunca una posterior) y `valor_esperado` interpola linealmente entre
`valor_inicial` y `valor_objetivo` en `[sk_fecha_inicio, sk_fecha_meta]`. No se inventan mediciones
diarias.

### Bitácora `dq.RegistroImputaciones`

| Columna | Descripción |
| :--- | :--- |
| `id_imputacion` | PK autogenerada |
| `codigo_regla` | ID de la regla (IMP-*) |
| `entidad` | Tabla de hechos/dimensión afectada |
| `campo` | Columna que no resolvió |
| `staging_id` | Fila de staging que originó la imputación (trazabilidad) |
| `bk` | Clave de negocio (p. ej. `id_pago_bk`) |
| `valor` | Valor imputado |
| `motivo` | Descripción legible |
| `fecha_registro` | Momento de la imputación |

Se consulta con la vista `dq.V_ImputacionesPorRegla`.

---

## 3. Mapeo con los "6 query requeridos" (Etapa 4 del blueprint)

| # | Query del blueprint | Estado | Dónde |
| :--- | :--- | :---: | :--- |
| 1 | Limpieza | ✅ | `04` (corrección) + `12` bloque 1 (auditoría) |
| 2 | Estandarización | ✅ | `04` + `12` bloque 2 |
| 3 | Validación de fechas y estados | ✅ | `04` + `12` bloque 3 |
| 4 | Cálculo de cohortes | ✅ | `05` (`DM_Gerencia_Membresias`) + `12` bloque 4 |
| 5 | Carga incremental | ✅ | `04` (`dbo.etl_control`, MERGE) + `12` bloque 5 |
| 6 | Reglas de calidad | ✅ | `04` (CAL-*, IMP-*) + `12` bloque 6 (`dq.RegistroImputaciones`) |
| 7 | Snapshots diarios (adicional v2) | ✅ | `04` fase C (motor de cortes) + `12` bloque 3c (SNP-*) |

---

## 4. Brechas conocidas (pendientes)

- **Doble cobro / solapes**: no hay regla que detecte un mismo `id_membresia_bk` con montos
  o vigencias conflictivas; hoy sólo se conserva la última fila por `ROW_NUMBER` **sin registrar**.
- **Coherencia de importes**: no se valida `monto_neto = precio_lista - descuento_aplicado`.
- **Huérfanos**: ya no quedan `NULL`; se imputan al centinela `-1` (cliente/empleado/plan/fecha),
  pero no se distingue un huérfano real de un dato ausente.
- **Sin política de severidad/escalamiento**: no hay notificación ni cuarentena por umbral de imputaciones.
- **Avisos múltiples**: el snapshot guarda el primer aviso válido y la cantidad del día; si una
  membresía recibe avisos por canales distintos el mismo día, sólo se conserva el primero.
- **`@DiasObservacion` fijo en 90**: es el parámetro del procedimiento, pero el job de 10 minutos lo
  invoca con el valor por defecto; cambiarlo exige alterar el paso del job.
- **DimCliente es SCD1** (sin historial): conserva marcas de validez del origen, pero no versiona.

> Las reglas de esta sección son las candidatas a implementar en la próxima iteración; hoy
> están declaradas como brechas, no como reglas activas.
