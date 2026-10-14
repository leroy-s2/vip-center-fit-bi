# Calidad de Datos — VIP Center Fit BI

Catálogo de las **reglas de calidad** aplicadas en la Etapa 4 (transformación y carga del
Data Mart), su severidad y la acción que ejecuta el ETL. Se complementa con:

- `sql/04_transformacion_datamart.sql` → aplica las reglas (corrige o descarta).
- `sql/12_reglas_calidad.sql` → **queries de auditoría** que detectan violaciones sobre el DW.
- `dq.RegistroRechazos` (esquema `dq`) → bitácora de las filas que el ETL **descarta**.

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
| CAL-09 | Estados | `FactMembresias.estado_membresia` | Inconsistente con fechas | Alta | **Recalcula** (`ACTIVA`/`VENCIDA`/`PENDIENTE`) según `@FechaCorte` |
| CAL-10 | Limpieza | `FactAsistencias.hora_ingreso` | Fuera de `[5, 23]` | Baja | → `NULL` |
| CAL-11 | Limpieza | `FactEvaluaciones.peso/altura` | Fuera de rango o unidad distinta | Media | `lb→kg`, `cm→m`; fuera de rango → `NULL` |
| CAL-12 | Estandarización | `FactReclamos`/`FactRetenciones`/`FactObjetivos`/sesiones | Texto libre | Baja | Mapea a dominios (COBRO/SERVICIO, RESUELTO/PENDIENTE, canal, motivo, tipo…) |
| CAL-13 | Estandarización | `DimPlan` | Catálogo de planes | Media | Deriva `tipo_plan`, `tipo_operacion` y `promocion` |

---

## 2. Reglas de rechazo (descartan la fila y **quedan auditadas**)

Se registran en `dq.RegistroRechazos`. La fila **no se carga** en el Data Mart porque no
resuelve su dimensión conformada.

| ID | Entidad | Campo | Condición | Acción |
| :--- | :--- | :--- | :--- | :--- |
| RC-12 | `DimCliente` | `id_cliente_bk` | `NULL` | Descarta el cliente |
| RC-13 | `DimFecha` | `fecha` | `NULL` o fuera de `[2000-01-01, 2100-12-31]` | Descarta la fecha |
| RC-14 | `FactVentas` | `sk_cliente` | No resuelve en `DimCliente` | Descarta la venta |
| RC-15 | `FactVentas` | `sk_fecha_pago` | No resuelve en `DimFecha` | Descarta la venta |
| RC-16 | `FactMembresias` | `sk_cliente` | No resuelve | Descarta la membresía |
| RC-17 | `FactMembresias` | `sk_fecha_inicio` | No resuelve | Descarta la membresía |
| RC-18 | `FactAsistencias` | `sk_cliente` | No resuelve | Descarta la asistencia |
| RC-19 | `FactAsistencias` | `sk_fecha_asistencia` | No resuelve | Descarta la asistencia |
| RC-20 | `FactReclamos` | `sk_cliente` | No resuelve | Descarta el reclamo |
| RC-21 | `FactReclamos` | `sk_fecha_reclamo` | No resuelve | Descarta el reclamo |
| RC-22 | `FactRetenciones` | `sk_cliente` | No resuelve | Descarta la retención |
| RC-23 | `FactRetenciones` | `sk_fecha_retencion` | No resuelve | Descarta la retención |

### Bitácora `dq.RegistroRechazos`

| Columna | Descripción |
| :--- | :--- |
| `id_rechazo` | PK autogenerada |
| `codigo_regla` | ID de la regla (RC-*) |
| `entidad` | Tabla de hechos/dimensión afectada |
| `campo` | Columna que no resolvió |
| `staging_id` | Fila de staging que originó el rechazo (trazabilidad) |
| `bk` | Clave de negocio (p. ej. `id_pago_bk`) |
| `valor` | Valor rechazado |
| `motivo` | Descripción legible |
| `fecha_registro` | Momento del descarte |

Se reindexa/consulta con la vista `dq.V_RechazosPorRegla`.

---

## 3. Mapeo con los "6 query requeridos" (Etapa 4 del blueprint)

| # | Query del blueprint | Estado | Dónde |
| :--- | :--- | :---: | :--- |
| 1 | Limpieza | ✅ | `04` (corrección) + `12` bloque 1 (auditoría) |
| 2 | Estandarización | ✅ | `04` + `12` bloque 2 |
| 3 | Validación de fechas y estados | ✅ | `04` + `12` bloque 3 |
| 4 | Cálculo de cohortes | ✅ | `05` (`DM_Gerencia_Membresias`) + `12` bloque 4 |
| 5 | Carga incremental | ✅ | `04` (`dbo.etl_control`, MERGE) + `12` bloque 5 |
| 6 | Reglas de calidad | ✅ | `04` (CAL-*, RC-*) + `12` bloque 6 (`dq.RegistroRechazos`) |

---

## 4. Brechas conocidas (pendientes)

- **Doble cobro / solapes**: no hay regla que detecte un mismo `id_membresia_bk` con montos
  o vigencias conflictivas; hoy sólo se conserva la última fila por `ROW_NUMBER` **sin registrar**.
- **Coherencia de importes**: no se valida `monto_neto = precio_lista - descuento_aplicado`.
- **Huérfanos tolerados**: `sk_empleado`, `sk_plan` y `id_membresia_bk` son opcionales; no se
  rechazan (a lo sumo quedan `NULL`).
- **Sin política de severidad/escalamiento**: no hay notificación ni cuarentena por umbral de rechazos.
- **Auditoría de entrenamiento**: sesiones, objetivos y evaluaciones normalizan estados pero
  aún no tienen control en el bloque 2/3 de `12`.

> Las reglas de esta sección son las candidatas a implementar en la próxima iteración; hoy
> están declaradas como brechas, no como reglas activas.
