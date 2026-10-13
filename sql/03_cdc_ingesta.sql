/*=============================================================================
  VIP CENTER FIT - INGESTA CDC

  Este archivo es independiente de la carga batch inicial:

      03_Ingesta_Programada.sql  -> primera fotografía completa
      03_CDC_Ingesta.sql          -> cambios posteriores

  Se usa @supports_net_changes = 0 porque las tablas de origen fueron creadas
  intencionalmente sin PRIMARY KEY. Para UPDATE se conserva únicamente el
  cambio nuevo (operación 4); la operación 3 se ignora.

  Requisito: SQL Server Agent debe estar activo para que CDC capture cambios.
=============================================================================*/

USE BI_VIP_CENTER_FIT_DW_ORIGEN;
GO

IF (SELECT is_cdc_enabled FROM sys.databases WHERE name = DB_NAME()) = 0
BEGIN
    EXEC sys.sp_cdc_enable_db;
END;
GO

/* Capturas necesarias para las dimensiones y hechos del Data Mart. */
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'DimFecha' AND is_tracked_by_cdc = 0)
    EXEC sys.sp_cdc_enable_table @source_schema = 'dbo', @source_name = 'DimFecha', @role_name = NULL, @supports_net_changes = 0;
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'DimCliente' AND is_tracked_by_cdc = 0)
    EXEC sys.sp_cdc_enable_table @source_schema = 'dbo', @source_name = 'DimCliente', @role_name = NULL, @supports_net_changes = 0;
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'DimEmpleado' AND is_tracked_by_cdc = 0)
    EXEC sys.sp_cdc_enable_table @source_schema = 'dbo', @source_name = 'DimEmpleado', @role_name = NULL, @supports_net_changes = 0;
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'DimPlan' AND is_tracked_by_cdc = 0)
    EXEC sys.sp_cdc_enable_table @source_schema = 'dbo', @source_name = 'DimPlan', @role_name = NULL, @supports_net_changes = 0;
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'DimPromocion' AND is_tracked_by_cdc = 0)
    EXEC sys.sp_cdc_enable_table @source_schema = 'dbo', @source_name = 'DimPromocion', @role_name = NULL, @supports_net_changes = 0;
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'FactMembresias' AND is_tracked_by_cdc = 0)
    EXEC sys.sp_cdc_enable_table @source_schema = 'dbo', @source_name = 'FactMembresias', @role_name = NULL, @supports_net_changes = 0;
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'FactVentas' AND is_tracked_by_cdc = 0)
    EXEC sys.sp_cdc_enable_table @source_schema = 'dbo', @source_name = 'FactVentas', @role_name = NULL, @supports_net_changes = 0;
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'FactRenovaciones' AND is_tracked_by_cdc = 0)
    EXEC sys.sp_cdc_enable_table @source_schema = 'dbo', @source_name = 'FactRenovaciones', @role_name = NULL, @supports_net_changes = 0;
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'FactAvisos' AND is_tracked_by_cdc = 0)
    EXEC sys.sp_cdc_enable_table @source_schema = 'dbo', @source_name = 'FactAvisos', @role_name = NULL, @supports_net_changes = 0;
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'FactAsistencias' AND is_tracked_by_cdc = 0)
    EXEC sys.sp_cdc_enable_table @source_schema = 'dbo', @source_name = 'FactAsistencias', @role_name = NULL, @supports_net_changes = 0;
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'FactObjetivos' AND is_tracked_by_cdc = 0)
    EXEC sys.sp_cdc_enable_table @source_schema = 'dbo', @source_name = 'FactObjetivos', @role_name = NULL, @supports_net_changes = 0;
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'FactEvaluaciones' AND is_tracked_by_cdc = 0)
    EXEC sys.sp_cdc_enable_table @source_schema = 'dbo', @source_name = 'FactEvaluaciones', @role_name = NULL, @supports_net_changes = 0;
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'FactReclamos' AND is_tracked_by_cdc = 0)
    EXEC sys.sp_cdc_enable_table @source_schema = 'dbo', @source_name = 'FactReclamos', @role_name = NULL, @supports_net_changes = 0;
GO

/* Verificación visible, equivalente a la demostración de CDC del SQL de referencia. */
SELECT
    DB_NAME() AS BaseDatosOrigen,
    is_cdc_enabled AS CDC_Base_Activo
FROM sys.databases
WHERE name = DB_NAME();

SELECT
    name AS TablaOrigen,
    is_tracked_by_cdc AS CDC_Tabla_Activo
FROM sys.tables
WHERE name IN
(
    'DimFecha', 'DimCliente', 'DimEmpleado', 'DimPlan', 'DimPromocion',
    'FactMembresias', 'FactVentas', 'FactRenovaciones', 'FactAvisos',
    'FactAsistencias', 'FactObjetivos', 'FactEvaluaciones', 'FactReclamos'
)
ORDER BY name;

SELECT
    capture_instance,
    start_lsn,
    supports_net_changes
FROM cdc.change_tables
ORDER BY capture_instance;
GO

USE BI_VIP_CENTER_FIT_STG;
GO

/* Se establece la marca inicial después de la fotografía batch. */
IF NOT EXISTS (SELECT 1 FROM stg.etl_cdc_control WHERE capture_instance = 'GLOBAL')
BEGIN
    INSERT INTO stg.etl_cdc_control
    (
        capture_instance, last_lsn, ultima_carga, filas_ultima_carga
    )
    SELECT
        'GLOBAL',
        BI_VIP_CENTER_FIT_DW_ORIGEN.sys.fn_cdc_get_max_lsn(),
        SYSUTCDATETIME(),
        0;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Ingesta_CDC
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @CargaID UNIQUEIDENTIFIER = NEWID();
    DECLARE @UltimoLSN BINARY(10);
    DECLARE @DesdeLSN BINARY(10);
    DECLARE @HastaLSN BINARY(10);
    DECLARE @Filas BIGINT = 0;

    SELECT @UltimoLSN = last_lsn
    FROM stg.etl_cdc_control
    WHERE capture_instance = 'GLOBAL';

    SET @HastaLSN = BI_VIP_CENTER_FIT_DW_ORIGEN.sys.fn_cdc_get_max_lsn();
    SET @DesdeLSN = CASE
        WHEN @UltimoLSN IS NULL
            THEN BI_VIP_CENTER_FIT_DW_ORIGEN.sys.fn_cdc_get_min_lsn('dbo_DimFecha')
        ELSE BI_VIP_CENTER_FIT_DW_ORIGEN.sys.fn_cdc_increment_lsn(@UltimoLSN)
    END;

    IF @HastaLSN IS NULL OR @DesdeLSN > @HastaLSN
    BEGIN
        SELECT
            'SIN_CAMBIOS' AS Estado,
            @UltimoLSN AS UltimoLSN,
            @HastaLSN AS HastaLSN,
            CAST(0 AS BIGINT) AS FilasStaging,
            'Realice un INSERT, UPDATE o DELETE en la fuente y vuelva a ejecutar el procedimiento.' AS Mensaje;

        SELECT 'stg_ventas_membresias' AS Tabla, COUNT_BIG(*) AS Filas
        FROM stg.stg_ventas_membresias
        UNION ALL
        SELECT 'stg_entrenamiento', COUNT_BIG(*)
        FROM stg.stg_entrenamiento
        UNION ALL
        SELECT 'stg_atencion_reclamos', COUNT_BIG(*)
        FROM stg.stg_atencion_reclamos;

        SELECT *
        FROM stg.etl_cdc_control
        WHERE capture_instance = 'GLOBAL';
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO stg.stg_fecha
        (
            CargaID, OperacionCDC, StartLSN, SeqVal,
            sk_fecha_origen, fecha, anio, trimestre, semestre, mes,
            nombre_mes, dia, dia_semana, es_fin_de_semana
        )
        SELECT
            @CargaID, __$operation, __$start_lsn, __$seqval,
            sk_fecha, fecha, anio, trimestre, semestre, mes,
            nombre_mes, dia, dia_semana, es_fin_de_semana
        FROM BI_VIP_CENTER_FIT_DW_ORIGEN.cdc.fn_cdc_get_all_changes_dbo_DimFecha(@DesdeLSN, @HastaLSN, 'all')
        WHERE __$operation IN (1, 2, 4);
        SET @Filas += @@ROWCOUNT;

        INSERT INTO stg.stg_clientes
        (
            CargaID, OperacionCDC, StartLSN, SeqVal,
            sk_cliente_origen, id_cliente_bk, dni, nombre_completo, sexo,
            rango_etario, estado_cliente, fecha_registro_origen,
            fecha_inicio_validez, fecha_fin_validez, es_actual
        )
        SELECT
            @CargaID, __$operation, __$start_lsn, __$seqval,
            sk_cliente, id_cliente_bk, dni, nombre_completo, sexo,
            rango_etario, estado_cliente, fecha_registro_origen,
            fecha_inicio_validez, fecha_fin_validez, es_actual
        FROM BI_VIP_CENTER_FIT_DW_ORIGEN.cdc.fn_cdc_get_all_changes_dbo_DimCliente(@DesdeLSN, @HastaLSN, 'all')
        WHERE __$operation IN (1, 2, 4);
        SET @Filas += @@ROWCOUNT;

        INSERT INTO stg.stg_empleados
        (
            CargaID, OperacionCDC, StartLSN, SeqVal,
            sk_empleado_origen, id_empleado_bk, dni, nombre_completo, cargo, area
        )
        SELECT
            @CargaID, __$operation, __$start_lsn, __$seqval,
            sk_empleado, id_empleado_bk, dni, nombre_completo, cargo, area
        FROM BI_VIP_CENTER_FIT_DW_ORIGEN.cdc.fn_cdc_get_all_changes_dbo_DimEmpleado(@DesdeLSN, @HastaLSN, 'all')
        WHERE __$operation IN (1, 2, 4);
        SET @Filas += @@ROWCOUNT;

        INSERT INTO stg.stg_planes
        (
            CargaID, OperacionCDC, StartLSN, SeqVal,
            sk_plan_origen, id_plan_bk, nombre_plan, duracion_dias,
            precio_referencial, categoria_duracion
        )
        SELECT
            @CargaID, __$operation, __$start_lsn, __$seqval,
            sk_plan, id_plan_bk, nombre_plan, duracion_dias,
            precio_referencial, categoria_duracion
        FROM BI_VIP_CENTER_FIT_DW_ORIGEN.cdc.fn_cdc_get_all_changes_dbo_DimPlan(@DesdeLSN, @HastaLSN, 'all')
        WHERE __$operation IN (1, 2, 4);
        SET @Filas += @@ROWCOUNT;

        INSERT INTO stg.stg_promociones
        (
            CargaID, OperacionCDC, StartLSN, SeqVal,
            sk_promocion_origen, id_promocion_bk, nombre_promocion,
            tipo_descuento, valor_descuento
        )
        SELECT
            @CargaID, __$operation, __$start_lsn, __$seqval,
            sk_promocion, id_promocion_bk, nombre_promocion,
            tipo_descuento, valor_descuento
        FROM BI_VIP_CENTER_FIT_DW_ORIGEN.cdc.fn_cdc_get_all_changes_dbo_DimPromocion(@DesdeLSN, @HastaLSN, 'all')
        WHERE __$operation IN (1, 2, 4);
        SET @Filas += @@ROWCOUNT;

        INSERT INTO stg.stg_ventas_membresias
        (
            CargaID, OperacionCDC, StartLSN, SeqVal, EntidadOrigen,
            id_membresia_bk, sk_fecha_inicio_origen, sk_fecha_fin_origen,
            sk_cliente_origen, sk_plan_origen, sk_promocion_origen,
            sk_empleado_origen, duracion_dias, precio_final, es_renovacion,
            estado_membresia, dias_anticipacion_renovacion
        )
        SELECT
            @CargaID, __$operation, __$start_lsn, __$seqval, 'MEMBRESIA',
            id_membresia_bk, sk_fecha_inicio, sk_fecha_fin,
            sk_cliente, sk_plan, sk_promocion,
            sk_empleado, duracion_dias, precio_final, es_renovacion,
            estado_membresia, dias_anticipacion_renovacion
        FROM BI_VIP_CENTER_FIT_DW_ORIGEN.cdc.fn_cdc_get_all_changes_dbo_FactMembresias(@DesdeLSN, @HastaLSN, 'all')
        WHERE __$operation IN (1, 2, 4);
        SET @Filas += @@ROWCOUNT;

        INSERT INTO stg.stg_ventas_membresias
        (
            CargaID, OperacionCDC, StartLSN, SeqVal, EntidadOrigen,
            id_pago_bk, sk_fecha_pago_origen, sk_cliente_origen, sk_plan_origen,
            sk_promocion_origen, sk_empleado_origen, id_membresia_bk,
            monto_neto, descuento_aplicado, precio_lista, metodo_pago
        )
        SELECT
            @CargaID, __$operation, __$start_lsn, __$seqval, 'VENTA',
            id_pago_bk, sk_fecha_pago, sk_cliente, sk_plan,
            sk_promocion, sk_empleado, id_membresia_bk,
            monto_neto, descuento_aplicado, precio_lista, metodo_pago
        FROM BI_VIP_CENTER_FIT_DW_ORIGEN.cdc.fn_cdc_get_all_changes_dbo_FactVentas(@DesdeLSN, @HastaLSN, 'all')
        WHERE __$operation IN (1, 2, 4);
        SET @Filas += @@ROWCOUNT;

        INSERT INTO stg.stg_ventas_membresias
        (
            CargaID, OperacionCDC, StartLSN, SeqVal, EntidadOrigen,
            id_renovacion_bk, sk_fecha_renovacion_origen, sk_cliente_origen,
            sk_empleado_origen, id_membresia_anterior_bk,
            id_membresia_nueva_bk, dias_anticipacion, monto_renovacion
        )
        SELECT
            @CargaID, __$operation, __$start_lsn, __$seqval, 'RENOVACION',
            id_renovacion_bk, sk_fecha_renovacion, sk_cliente,
            sk_empleado, id_membresia_anterior_bk,
            id_membresia_nueva_bk, dias_anticipacion, monto
        FROM BI_VIP_CENTER_FIT_DW_ORIGEN.cdc.fn_cdc_get_all_changes_dbo_FactRenovaciones(@DesdeLSN, @HastaLSN, 'all')
        WHERE __$operation IN (1, 2, 4);
        SET @Filas += @@ROWCOUNT;

        INSERT INTO stg.stg_ventas_membresias
        (
            CargaID, OperacionCDC, StartLSN, SeqVal, EntidadOrigen,
            id_aviso_bk, sk_fecha_aviso_origen, sk_cliente_origen,
            sk_empleado_origen, id_membresia_bk, dias_antes_vencimiento,
            medio_aviso, estado_aviso
        )
        SELECT
            @CargaID, __$operation, __$start_lsn, __$seqval, 'AVISO',
            id_aviso_bk, sk_fecha_aviso, sk_cliente,
            sk_empleado, id_membresia_bk, dias_antes_vencimiento,
            medio, estado
        FROM BI_VIP_CENTER_FIT_DW_ORIGEN.cdc.fn_cdc_get_all_changes_dbo_FactAvisos(@DesdeLSN, @HastaLSN, 'all')
        WHERE __$operation IN (1, 2, 4);
        SET @Filas += @@ROWCOUNT;

        INSERT INTO stg.stg_entrenamiento
        (
            CargaID, OperacionCDC, StartLSN, SeqVal, EntidadOrigen,
            id_asistencia_bk, sk_fecha_asistencia_origen, sk_cliente_origen,
            sk_plan_origen, sk_empleado_origen, hora_ingreso, cantidad_asistencias
        )
        SELECT
            @CargaID, __$operation, __$start_lsn, __$seqval, 'ASISTENCIA',
            id_asistencia_bk, sk_fecha_asistencia, sk_cliente,
            sk_plan, sk_empleado, hora_ingreso, cantidad_asistencias
        FROM BI_VIP_CENTER_FIT_DW_ORIGEN.cdc.fn_cdc_get_all_changes_dbo_FactAsistencias(@DesdeLSN, @HastaLSN, 'all')
        WHERE __$operation IN (1, 2, 4);
        SET @Filas += @@ROWCOUNT;

        INSERT INTO stg.stg_entrenamiento
        (
            CargaID, OperacionCDC, StartLSN, SeqVal, EntidadOrigen,
            id_objetivo_bk, sk_fecha_inicio_origen, sk_cliente_origen,
            tipo_objetivo, valor_inicial, valor_objetivo, unidad_medida,
            estado_objetivo
        )
        SELECT
            @CargaID, __$operation, __$start_lsn, __$seqval, 'OBJETIVO',
            id_objetivo_bk, sk_fecha_inicio, sk_cliente,
            tipo_objetivo, valor_inicial, valor_objetivo, unidad_medida,
            estado
        FROM BI_VIP_CENTER_FIT_DW_ORIGEN.cdc.fn_cdc_get_all_changes_dbo_FactObjetivos(@DesdeLSN, @HastaLSN, 'all')
        WHERE __$operation IN (1, 2, 4);
        SET @Filas += @@ROWCOUNT;

        INSERT INTO stg.stg_entrenamiento
        (
            CargaID, OperacionCDC, StartLSN, SeqVal, EntidadOrigen,
            id_evaluacion_bk, sk_fecha_evaluacion_origen, sk_cliente_origen,
            sk_empleado_origen, id_objetivo_bk, peso, altura,
            grasa_corporal, masa_muscular
        )
        SELECT
            @CargaID, __$operation, __$start_lsn, __$seqval, 'EVALUACION',
            id_evaluacion_bk, sk_fecha_evaluacion, sk_cliente,
            sk_empleado, id_objetivo_bk, peso, altura,
            grasa_corporal, masa_muscular
        FROM BI_VIP_CENTER_FIT_DW_ORIGEN.cdc.fn_cdc_get_all_changes_dbo_FactEvaluaciones(@DesdeLSN, @HastaLSN, 'all')
        WHERE __$operation IN (1, 2, 4);
        SET @Filas += @@ROWCOUNT;

        INSERT INTO stg.stg_atencion_reclamos
        (
            CargaID, OperacionCDC, StartLSN, SeqVal, EntidadOrigen,
            id_reclamo_bk, sk_fecha_reclamo_origen, sk_cliente_origen,
            sk_empleado_origen, categoria, estado, fecha_resolucion,
            dias_resolucion
        )
        SELECT
            @CargaID, __$operation, __$start_lsn, __$seqval, 'RECLAMO',
            id_reclamo_bk, sk_fecha_reclamo, sk_cliente,
            sk_empleado, categoria, estado, fecha_resolucion,
            dias_resolucion
        FROM BI_VIP_CENTER_FIT_DW_ORIGEN.cdc.fn_cdc_get_all_changes_dbo_FactReclamos(@DesdeLSN, @HastaLSN, 'all')
        WHERE __$operation IN (1, 2, 4);
        SET @Filas += @@ROWCOUNT;

        UPDATE stg.etl_cdc_control
        SET last_lsn = @HastaLSN,
            ultima_carga = SYSUTCDATETIME(),
            filas_ultima_carga = @Filas
        WHERE capture_instance = 'GLOBAL';

        COMMIT TRANSACTION;

        SELECT
            'CDC_CARGADO' AS Estado,
            @CargaID AS CargaID,
            @DesdeLSN AS DesdeLSN,
            @HastaLSN AS HastaLSN,
            @Filas AS FilasStaging;

        SELECT EntidadOrigen, COUNT_BIG(*) AS FilasCDC
        FROM stg.stg_ventas_membresias
        WHERE CargaID = @CargaID
        GROUP BY EntidadOrigen
        UNION ALL
        SELECT EntidadOrigen, COUNT_BIG(*)
        FROM stg.stg_entrenamiento
        WHERE CargaID = @CargaID
        GROUP BY EntidadOrigen
        UNION ALL
        SELECT EntidadOrigen, COUNT_BIG(*)
        FROM stg.stg_atencion_reclamos
        WHERE CargaID = @CargaID
        GROUP BY EntidadOrigen;

        SELECT *
        FROM stg.etl_cdc_control
        WHERE capture_instance = 'GLOBAL';
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* Ejecución manual posterior a cualquier cambio realizado en la fuente. */
-- EXEC dbo.usp_Ingesta_CDC;
GO
