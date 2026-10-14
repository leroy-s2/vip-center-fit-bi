/*=============================================================================
  VIP CENTER FIT - ETAPA 2: INGESTA PROGRAMADA

  Esta versión realiza una carga batch inicial desde la fuente hacia Raw.
  Conserva los defectos originales y no aplica reglas de limpieza.

  En el futuro, los INSERT ... SELECT de este archivo podrán sustituirse por
  lecturas de las tablas CDC. La transformación no debe leer directamente el
  origen: debe leer las tablas stg_ creadas en la etapa anterior.
=============================================================================*/

SET NOCOUNT ON;
GO

USE BI_VIP_CENTER_FIT_STG;
GO

DECLARE @CargaID UNIQUEIDENTIFIER = NEWID();

/* Carga batch completa para la primera prueba de integración. */
TRUNCATE TABLE stg.stg_atencion_reclamos;
TRUNCATE TABLE stg.stg_entrenamiento;
TRUNCATE TABLE stg.stg_ventas_membresias;
TRUNCATE TABLE stg.stg_planes;
TRUNCATE TABLE stg.stg_empleados;
TRUNCATE TABLE stg.stg_clientes;
TRUNCATE TABLE stg.stg_fecha;

/* La fecha se conserva tal como llega desde el origen. */
INSERT INTO stg.stg_fecha
(
    CargaID, OperacionCDC, StartLSN, SeqVal,
    sk_fecha_origen, fecha, anio, trimestre, semestre, mes,
    nombre_mes, dia, dia_semana, es_fin_de_semana
)
SELECT
    @CargaID, 2, NULL, NULL,
    sk_fecha, fecha, anio, trimestre, semestre, mes,
    nombre_mes, dia, dia_semana, es_fin_de_semana
FROM BI_VIP_CENTER_FIT_DW_ORIGEN.dbo.DimFecha;

INSERT INTO stg.stg_clientes
(
    CargaID, OperacionCDC, StartLSN, SeqVal,
    sk_cliente_origen, id_cliente_bk, dni, nombre_completo, sexo,
    rango_etario, estado_cliente, fecha_registro_origen,
    fecha_inicio_validez, fecha_fin_validez, es_actual
)
SELECT
    @CargaID, 2, NULL, NULL,
    sk_cliente, id_cliente_bk, dni, nombre_completo, sexo,
    rango_etario, estado_cliente, fecha_registro_origen,
    fecha_inicio_validez, fecha_fin_validez, es_actual
FROM BI_VIP_CENTER_FIT_DW_ORIGEN.dbo.DimCliente;

INSERT INTO stg.stg_empleados
(
    CargaID, OperacionCDC, StartLSN, SeqVal,
    sk_empleado_origen, id_empleado_bk, dni, nombre_completo, cargo, area
)
SELECT
    @CargaID, 2, NULL, NULL,
    sk_empleado, id_empleado_bk, dni, nombre_completo, cargo, area
FROM BI_VIP_CENTER_FIT_DW_ORIGEN.dbo.DimEmpleado;

INSERT INTO stg.stg_planes
(
    CargaID, OperacionCDC, StartLSN, SeqVal,
    sk_plan_origen, id_plan_bk, nombre_plan, duracion_dias,
    precio_referencial, categoria_duracion
)
SELECT
    @CargaID, 2, NULL, NULL,
    sk_plan, id_plan_bk, nombre_plan, duracion_dias,
    precio_referencial, categoria_duracion
FROM BI_VIP_CENTER_FIT_DW_ORIGEN.dbo.DimPlan;

/* Membresías. */
INSERT INTO stg.stg_ventas_membresias
(
    CargaID, OperacionCDC, StartLSN, SeqVal, EntidadOrigen,
    id_membresia_bk, sk_fecha_inicio_origen, sk_fecha_fin_origen,
    sk_cliente_origen, sk_plan_origen, sk_empleado_origen,
    duracion_dias, precio_final, es_renovacion,
    estado_membresia, dias_anticipacion_renovacion
)
SELECT
    @CargaID, 2, NULL, NULL, 'MEMBRESIA',
    id_membresia_bk, sk_fecha_inicio, sk_fecha_fin,
    sk_cliente, sk_plan, sk_empleado, duracion_dias, precio_final, es_renovacion,
    estado_membresia, dias_anticipacion_renovacion
FROM BI_VIP_CENTER_FIT_DW_ORIGEN.dbo.FactMembresias;

/* Ventas. */
INSERT INTO stg.stg_ventas_membresias
(
    CargaID, OperacionCDC, StartLSN, SeqVal, EntidadOrigen,
    id_pago_bk, sk_fecha_pago_origen, sk_cliente_origen, sk_plan_origen,
    sk_empleado_origen, id_membresia_bk,
    monto_neto, descuento_aplicado, precio_lista, metodo_pago
)
SELECT
    @CargaID, 2, NULL, NULL, 'VENTA',
    id_pago_bk, sk_fecha_pago, sk_cliente, sk_plan,
    sk_empleado, id_membresia_bk,
    monto_neto, descuento_aplicado, precio_lista, metodo_pago
FROM BI_VIP_CENTER_FIT_DW_ORIGEN.dbo.FactVentas;

/* Renovaciones. */
INSERT INTO stg.stg_ventas_membresias
(
    CargaID, OperacionCDC, StartLSN, SeqVal, EntidadOrigen,
    id_renovacion_bk, sk_fecha_renovacion_origen, sk_cliente_origen,
    sk_empleado_origen, id_membresia_anterior_bk,
    id_membresia_nueva_bk, dias_anticipacion, monto_renovacion
)
SELECT
    @CargaID, 2, NULL, NULL, 'RENOVACION',
    id_renovacion_bk, sk_fecha_renovacion, sk_cliente,
    sk_empleado, id_membresia_anterior_bk,
    id_membresia_nueva_bk, dias_anticipacion, monto
FROM BI_VIP_CENTER_FIT_DW_ORIGEN.dbo.FactRenovaciones;

/* Avisos. */
INSERT INTO stg.stg_ventas_membresias
(
    CargaID, OperacionCDC, StartLSN, SeqVal, EntidadOrigen,
    id_aviso_bk, sk_fecha_aviso_origen, sk_cliente_origen,
    sk_empleado_origen, id_membresia_bk, dias_antes_vencimiento,
    medio_aviso, estado_aviso
)
SELECT
    @CargaID, 2, NULL, NULL, 'AVISO',
    id_aviso_bk, sk_fecha_aviso, sk_cliente,
    sk_empleado, id_membresia_bk, dias_antes_vencimiento,
    medio, estado
FROM BI_VIP_CENTER_FIT_DW_ORIGEN.dbo.FactAvisos;

/* Asistencias. */
INSERT INTO stg.stg_entrenamiento
(
    CargaID, OperacionCDC, StartLSN, SeqVal, EntidadOrigen,
    id_asistencia_bk, sk_fecha_asistencia_origen, sk_cliente_origen,
    sk_plan_origen, sk_empleado_origen, hora_ingreso, cantidad_asistencias
)
SELECT
    @CargaID, 2, NULL, NULL, 'ASISTENCIA',
    id_asistencia_bk, sk_fecha_asistencia, sk_cliente,
    sk_plan, sk_empleado, hora_ingreso, cantidad_asistencias
FROM BI_VIP_CENTER_FIT_DW_ORIGEN.dbo.FactAsistencias;

/* Objetivos. */
INSERT INTO stg.stg_entrenamiento
(
    CargaID, OperacionCDC, StartLSN, SeqVal, EntidadOrigen,
    id_objetivo_bk, sk_fecha_inicio_origen, sk_cliente_origen,
    tipo_objetivo, valor_inicial, valor_objetivo, unidad_medida,
    estado_objetivo
)
SELECT
    @CargaID, 2, NULL, NULL, 'OBJETIVO',
    id_objetivo_bk, sk_fecha_inicio, sk_cliente,
    tipo_objetivo, valor_inicial, valor_objetivo, unidad_medida,
    estado
FROM BI_VIP_CENTER_FIT_DW_ORIGEN.dbo.FactObjetivos;

/* Evaluaciones. */
INSERT INTO stg.stg_entrenamiento
(
    CargaID, OperacionCDC, StartLSN, SeqVal, EntidadOrigen,
    id_evaluacion_bk, sk_fecha_evaluacion_origen, sk_cliente_origen,
    sk_empleado_origen, id_objetivo_bk, peso, altura,
    grasa_corporal, masa_muscular
)
SELECT
    @CargaID, 2, NULL, NULL, 'EVALUACION',
    id_evaluacion_bk, sk_fecha_evaluacion, sk_cliente,
    sk_empleado, id_objetivo_bk, peso, altura,
    grasa_corporal, masa_muscular
FROM BI_VIP_CENTER_FIT_DW_ORIGEN.dbo.FactEvaluaciones;

/* Reclamos. */
INSERT INTO stg.stg_atencion_reclamos
(
    CargaID, OperacionCDC, StartLSN, SeqVal, EntidadOrigen,
    id_reclamo_bk, sk_fecha_reclamo_origen, sk_cliente_origen,
    sk_empleado_origen, categoria, estado, fecha_resolucion,
    dias_resolucion, resuelto_en_mostrador
)
SELECT
    @CargaID, 2, NULL, NULL, 'RECLAMO',
    id_reclamo_bk, sk_fecha_reclamo, sk_cliente,
    sk_empleado, categoria, estado, fecha_resolucion,
    dias_resolucion, resuelto_en_mostrador
FROM BI_VIP_CENTER_FIT_DW_ORIGEN.dbo.FactReclamos;

/* Sesiones programadas (denominador de la tasa de asistencia). */
INSERT INTO stg.stg_entrenamiento
(
    CargaID, OperacionCDC, StartLSN, SeqVal, EntidadOrigen,
    id_sesion_bk, sk_fecha_programada_origen, sk_cliente_origen,
    sk_plan_origen, sk_empleado_origen, tipo_sesion, hora_programada,
    estado_sesion, duracion_minutos
)
SELECT
    @CargaID, 2, NULL, NULL, 'SESION_PROGRAMADA',
    id_sesion_bk, sk_fecha_programada, sk_cliente,
    sk_plan, sk_empleado, tipo_sesion, hora_programada,
    estado_sesion, duracion_minutos
FROM BI_VIP_CENTER_FIT_DW_ORIGEN.dbo.FactSesionesProgramadas;

/* Evaluaciones programadas (exigibles/pendientes). */
INSERT INTO stg.stg_entrenamiento
(
    CargaID, OperacionCDC, StartLSN, SeqVal, EntidadOrigen,
    id_evaluacion_programada_bk, sk_fecha_programada_origen, sk_cliente_origen,
    sk_empleado_origen, id_objetivo_bk, tipo_evaluacion, estado_evaluacion,
    id_evaluacion_bk
)
SELECT
    @CargaID, 2, NULL, NULL, 'EVALUACION_PROGRAMADA',
    id_evaluacion_programada_bk, sk_fecha_programada, sk_cliente,
    sk_empleado, id_objetivo_bk, tipo_evaluacion, estado_evaluacion,
    id_evaluacion_bk
FROM BI_VIP_CENTER_FIT_DW_ORIGEN.dbo.FactEvaluacionesProgramadas;

/* Retenciones en mostrador (acciones y resultado). */
INSERT INTO stg.stg_atencion_reclamos
(
    CargaID, OperacionCDC, StartLSN, SeqVal, EntidadOrigen,
    id_retencion_bk, sk_fecha_retencion_origen, sk_cliente_origen,
    sk_empleado_origen, id_membresia_bk, canal, motivo, resultado,
    monto_oferta
)
SELECT
    @CargaID, 2, NULL, NULL, 'RETENCION',
    id_retencion_bk, sk_fecha_retencion, sk_cliente,
    sk_empleado, id_membresia_bk, canal, motivo, resultado,
    monto_oferta
FROM BI_VIP_CENTER_FIT_DW_ORIGEN.dbo.FactRetenciones;

/* Control rápido de la ingesta. Los errores siguen presentes por diseño. */
SELECT @CargaID AS CargaID, 'BATCH_INICIAL' AS TipoCarga;

SELECT 'stg_fecha' AS Tabla, COUNT_BIG(*) AS Filas FROM stg.stg_fecha
UNION ALL SELECT 'stg_clientes', COUNT_BIG(*) FROM stg.stg_clientes
UNION ALL SELECT 'stg_empleados', COUNT_BIG(*) FROM stg.stg_empleados
UNION ALL SELECT 'stg_planes', COUNT_BIG(*) FROM stg.stg_planes
UNION ALL SELECT 'stg_ventas_membresias', COUNT_BIG(*) FROM stg.stg_ventas_membresias
UNION ALL SELECT 'stg_entrenamiento', COUNT_BIG(*) FROM stg.stg_entrenamiento
UNION ALL SELECT 'stg_atencion_reclamos', COUNT_BIG(*) FROM stg.stg_atencion_reclamos;

SELECT EntidadOrigen, COUNT_BIG(*) AS Filas
FROM stg.stg_ventas_membresias
GROUP BY EntidadOrigen
UNION ALL
SELECT EntidadOrigen, COUNT_BIG(*)
FROM stg.stg_entrenamiento
GROUP BY EntidadOrigen
UNION ALL
SELECT EntidadOrigen, COUNT_BIG(*)
FROM stg.stg_atencion_reclamos
GROUP BY EntidadOrigen;
GO

/* Al rehacer la fotografía completa, el TRUNCATE reinicia los IDENTITY del
   staging; por eso la marca de agua del ETL debe volver a 0 para que la
   siguiente carga incremental procese de nuevo todo el lote inicial.
   La base del DW puede no existir todavía en la primera instalación. */
IF DB_ID(N'BI_VIP_CENTER_FIT_DW') IS NOT NULL
   AND OBJECT_ID(N'BI_VIP_CENTER_FIT_DW.dbo.etl_control', 'U') IS NOT NULL
BEGIN
    UPDATE BI_VIP_CENTER_FIT_DW.dbo.etl_control
       SET ultimo_staging_id = 0,
           ultima_carga = NULL,
           filas_ultima_carga = NULL;
END;
GO
