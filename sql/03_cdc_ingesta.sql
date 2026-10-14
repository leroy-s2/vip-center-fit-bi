/*=============================================================================
  VIP CENTER FIT - INGESTA CDC

  Este archivo es independiente de la carga batch inicial:

      03_Ingesta_Programada.sql  -> primera fotografía completa
      03_CDC_Ingesta.sql          -> cambios posteriores

  Se usa @supports_net_changes = 0 porque las tablas de origen fueron creadas
  intencionalmente sin PRIMARY KEY. Para UPDATE se conserva únicamente el
  cambio nuevo (operación 4); la operación 3 se ignora.

  Requisito: SQL Server Agent debe estar activo para que CDC capture cambios.

  Nota importante: cada capture instance se habilitó en un momento distinto, así
  que su LSN mínimo difiere. Consultar una instancia con un @from_lsn menor a su
  propio mínimo provoca el error 313 de CDC. Por eso el procedimiento acota el
  LSN por instancia antes de leer los cambios.
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
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'FactSesionesProgramadas' AND is_tracked_by_cdc = 0)
    EXEC sys.sp_cdc_enable_table @source_schema = 'dbo', @source_name = 'FactSesionesProgramadas', @role_name = NULL, @supports_net_changes = 0;
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'FactEvaluacionesProgramadas' AND is_tracked_by_cdc = 0)
    EXEC sys.sp_cdc_enable_table @source_schema = 'dbo', @source_name = 'FactEvaluacionesProgramadas', @role_name = NULL, @supports_net_changes = 0;
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'FactRetenciones' AND is_tracked_by_cdc = 0)
    EXEC sys.sp_cdc_enable_table @source_schema = 'dbo', @source_name = 'FactRetenciones', @role_name = NULL, @supports_net_changes = 0;
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
    'DimFecha', 'DimCliente', 'DimEmpleado', 'DimPlan',
    'FactMembresias', 'FactVentas', 'FactRenovaciones', 'FactAvisos',
    'FactAsistencias', 'FactObjetivos', 'FactEvaluaciones', 'FactReclamos',
    'FactSesionesProgramadas', 'FactEvaluacionesProgramadas', 'FactRetenciones'
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

    /* LSN efectivo por capture instance (acotado a su mínimo propio). */
    DECLARE @fFecha BINARY(10), @fCli BINARY(10), @fEmp BINARY(10), @fPla BINARY(10);
    DECLARE @fMem BINARY(10), @fVen BINARY(10), @fRen BINARY(10);
    DECLARE @fAvi BINARY(10), @fAsi BINARY(10), @fObj BINARY(10), @fEva BINARY(10), @fRec BINARY(10);
    DECLARE @fSes BINARY(10), @fEvaP BINARY(10), @fRet BINARY(10);

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

    /* Cota inferior por instancia: no se puede consultar por debajo de su min_lsn. */
    SET @fFecha = CASE WHEN @DesdeLSN < BI_VIP_CENTER_FIT_DW_ORIGEN.sys.fn_cdc_get_min_lsn('dbo_DimFecha')     THEN BI_VIP_CENTER_FIT_DW_ORIGEN.sys.fn_cdc_get_min_lsn('dbo_DimFecha')     ELSE @DesdeLSN END;
    SET @fCli   = CASE WHEN @DesdeLSN < BI_VIP_CENTER_FIT_DW_ORIGEN.sys.fn_cdc_get_min_lsn('dbo_DimCliente')   THEN BI_VIP_CENTER_FIT_DW_ORIGEN.sys.fn_cdc_get_min_lsn('dbo_DimCliente')   ELSE @DesdeLSN END;
    SET @fEmp   = CASE WHEN @DesdeLSN < BI_VIP_CENTER_FIT_DW_ORIGEN.sys.fn_cdc_get_min_lsn('dbo_DimEmpleado')  THEN BI_VIP_CENTER_FIT_DW_ORIGEN.sys.fn_cdc_get_min_lsn('dbo_DimEmpleado')  ELSE @DesdeLSN END;
    SET @fPla   = CASE WHEN @DesdeLSN < BI_VIP_CENTER_FIT_DW_ORIGEN.sys.fn_cdc_get_min_lsn('dbo_DimPlan')      THEN BI_VIP_CENTER_FIT_DW_ORIGEN.sys.fn_cdc_get_min_lsn('dbo_DimPlan')      ELSE @DesdeLSN END;
    SET @fMem   = CASE WHEN @DesdeLSN < BI_VIP_CENTER_FIT_DW_ORIGEN.sys.fn_cdc_get_min_lsn('dbo_FactMembresias')    THEN BI_VIP_CENTER_FIT_DW_ORIGEN.sys.fn_cdc_get_min_lsn('dbo_FactMembresias')    ELSE @DesdeLSN END;
    SET @fVen   = CASE WHEN @DesdeLSN < BI_VIP_CENTER_FIT_DW_ORIGEN.sys.fn_cdc_get_min_lsn('dbo_FactVentas')         THEN BI_VIP_CENTER_FIT_DW_ORIGEN.sys.fn_cdc_get_min_lsn('dbo_FactVentas')         ELSE @DesdeLSN END;
    SET @fRen   = CASE WHEN @DesdeLSN < BI_VIP_CENTER_FIT_DW_ORIGEN.sys.fn_cdc_get_min_lsn('dbo_FactRenovaciones')   THEN BI_VIP_CENTER_FIT_DW_ORIGEN.sys.fn_cdc_get_min_lsn('dbo_FactRenovaciones')   ELSE @DesdeLSN END;
    SET @fAvi   = CASE WHEN @DesdeLSN < BI_VIP_CENTER_FIT_DW_ORIGEN.sys.fn_cdc_get_min_lsn('dbo_FactAvisos')         THEN BI_VIP_CENTER_FIT_DW_ORIGEN.sys.fn_cdc_get_min_lsn('dbo_FactAvisos')         ELSE @DesdeLSN END;
    SET @fAsi   = CASE WHEN @DesdeLSN < BI_VIP_CENTER_FIT_DW_ORIGEN.sys.fn_cdc_get_min_lsn('dbo_FactAsistencias')    THEN BI_VIP_CENTER_FIT_DW_ORIGEN.sys.fn_cdc_get_min_lsn('dbo_FactAsistencias')    ELSE @DesdeLSN END;
    SET @fObj   = CASE WHEN @DesdeLSN < BI_VIP_CENTER_FIT_DW_ORIGEN.sys.fn_cdc_get_min_lsn('dbo_FactObjetivos')      THEN BI_VIP_CENTER_FIT_DW_ORIGEN.sys.fn_cdc_get_min_lsn('dbo_FactObjetivos')      ELSE @DesdeLSN END;
    SET @fEva   = CASE WHEN @DesdeLSN < BI_VIP_CENTER_FIT_DW_ORIGEN.sys.fn_cdc_get_min_lsn('dbo_FactEvaluaciones')   THEN BI_VIP_CENTER_FIT_DW_ORIGEN.sys.fn_cdc_get_min_lsn('dbo_FactEvaluaciones')   ELSE @DesdeLSN END;
    SET @fRec   = CASE WHEN @DesdeLSN < BI_VIP_CENTER_FIT_DW_ORIGEN.sys.fn_cdc_get_min_lsn('dbo_FactReclamos')       THEN BI_VIP_CENTER_FIT_DW_ORIGEN.sys.fn_cdc_get_min_lsn('dbo_FactReclamos')       ELSE @DesdeLSN END;
    SET @fSes   = CASE WHEN @DesdeLSN < BI_VIP_CENTER_FIT_DW_ORIGEN.sys.fn_cdc_get_min_lsn('dbo_FactSesionesProgramadas')          THEN BI_VIP_CENTER_FIT_DW_ORIGEN.sys.fn_cdc_get_min_lsn('dbo_FactSesionesProgramadas')          ELSE @DesdeLSN END;
    SET @fEvaP  = CASE WHEN @DesdeLSN < BI_VIP_CENTER_FIT_DW_ORIGEN.sys.fn_cdc_get_min_lsn('dbo_FactEvaluacionesProgramadas')     THEN BI_VIP_CENTER_FIT_DW_ORIGEN.sys.fn_cdc_get_min_lsn('dbo_FactEvaluacionesProgramadas')     ELSE @DesdeLSN END;
    SET @fRet   = CASE WHEN @DesdeLSN < BI_VIP_CENTER_FIT_DW_ORIGEN.sys.fn_cdc_get_min_lsn('dbo_FactRetenciones')                THEN BI_VIP_CENTER_FIT_DW_ORIGEN.sys.fn_cdc_get_min_lsn('dbo_FactRetenciones')                ELSE @DesdeLSN END;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @fFecha IS NOT NULL AND @fFecha <= @HastaLSN
        BEGIN
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
            FROM BI_VIP_CENTER_FIT_DW_ORIGEN.cdc.fn_cdc_get_all_changes_dbo_DimFecha(@fFecha, @HastaLSN, 'all')
            WHERE __$operation IN (1, 2, 4);
            SET @Filas += @@ROWCOUNT;
        END;

        IF @fCli IS NOT NULL AND @fCli <= @HastaLSN
        BEGIN
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
            FROM BI_VIP_CENTER_FIT_DW_ORIGEN.cdc.fn_cdc_get_all_changes_dbo_DimCliente(@fCli, @HastaLSN, 'all')
            WHERE __$operation IN (1, 2, 4);
            SET @Filas += @@ROWCOUNT;
        END;

        IF @fEmp IS NOT NULL AND @fEmp <= @HastaLSN
        BEGIN
            INSERT INTO stg.stg_empleados
            (
                CargaID, OperacionCDC, StartLSN, SeqVal,
                sk_empleado_origen, id_empleado_bk, dni, nombre_completo, cargo, area
            )
            SELECT
                @CargaID, __$operation, __$start_lsn, __$seqval,
                sk_empleado, id_empleado_bk, dni, nombre_completo, cargo, area
            FROM BI_VIP_CENTER_FIT_DW_ORIGEN.cdc.fn_cdc_get_all_changes_dbo_DimEmpleado(@fEmp, @HastaLSN, 'all')
            WHERE __$operation IN (1, 2, 4);
            SET @Filas += @@ROWCOUNT;
        END;

        IF @fPla IS NOT NULL AND @fPla <= @HastaLSN
        BEGIN
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
            FROM BI_VIP_CENTER_FIT_DW_ORIGEN.cdc.fn_cdc_get_all_changes_dbo_DimPlan(@fPla, @HastaLSN, 'all')
            WHERE __$operation IN (1, 2, 4);
            SET @Filas += @@ROWCOUNT;
        END;

        IF @fMem IS NOT NULL AND @fMem <= @HastaLSN
        BEGIN
            INSERT INTO stg.stg_ventas_membresias
            (
                CargaID, OperacionCDC, StartLSN, SeqVal, EntidadOrigen,
                id_membresia_bk, sk_fecha_inicio_origen, sk_fecha_fin_origen,
                sk_cliente_origen, sk_plan_origen, sk_empleado_origen,
                duracion_dias, precio_final, es_renovacion,
                estado_membresia, dias_anticipacion_renovacion
            )
            SELECT
                @CargaID, __$operation, __$start_lsn, __$seqval, 'MEMBRESIA',
                id_membresia_bk, sk_fecha_inicio, sk_fecha_fin,
                sk_cliente, sk_plan, sk_empleado, duracion_dias, precio_final, es_renovacion,
                estado_membresia, dias_anticipacion_renovacion
            FROM BI_VIP_CENTER_FIT_DW_ORIGEN.cdc.fn_cdc_get_all_changes_dbo_FactMembresias(@fMem, @HastaLSN, 'all')
            WHERE __$operation IN (1, 2, 4);
            SET @Filas += @@ROWCOUNT;
        END;

        IF @fVen IS NOT NULL AND @fVen <= @HastaLSN
        BEGIN
            INSERT INTO stg.stg_ventas_membresias
            (
                CargaID, OperacionCDC, StartLSN, SeqVal, EntidadOrigen,
                id_pago_bk, sk_fecha_pago_origen, sk_cliente_origen, sk_plan_origen,
                sk_empleado_origen, id_membresia_bk,
                monto_neto, descuento_aplicado, precio_lista, metodo_pago
            )
            SELECT
                @CargaID, __$operation, __$start_lsn, __$seqval, 'VENTA',
                id_pago_bk, sk_fecha_pago, sk_cliente, sk_plan,
                sk_empleado, id_membresia_bk,
                monto_neto, descuento_aplicado, precio_lista, metodo_pago
            FROM BI_VIP_CENTER_FIT_DW_ORIGEN.cdc.fn_cdc_get_all_changes_dbo_FactVentas(@fVen, @HastaLSN, 'all')
            WHERE __$operation IN (1, 2, 4);
            SET @Filas += @@ROWCOUNT;
        END;

        IF @fRen IS NOT NULL AND @fRen <= @HastaLSN
        BEGIN
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
            FROM BI_VIP_CENTER_FIT_DW_ORIGEN.cdc.fn_cdc_get_all_changes_dbo_FactRenovaciones(@fRen, @HastaLSN, 'all')
            WHERE __$operation IN (1, 2, 4);
            SET @Filas += @@ROWCOUNT;
        END;

        IF @fAvi IS NOT NULL AND @fAvi <= @HastaLSN
        BEGIN
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
            FROM BI_VIP_CENTER_FIT_DW_ORIGEN.cdc.fn_cdc_get_all_changes_dbo_FactAvisos(@fAvi, @HastaLSN, 'all')
            WHERE __$operation IN (1, 2, 4);
            SET @Filas += @@ROWCOUNT;
        END;

        IF @fAsi IS NOT NULL AND @fAsi <= @HastaLSN
        BEGIN
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
            FROM BI_VIP_CENTER_FIT_DW_ORIGEN.cdc.fn_cdc_get_all_changes_dbo_FactAsistencias(@fAsi, @HastaLSN, 'all')
            WHERE __$operation IN (1, 2, 4);
            SET @Filas += @@ROWCOUNT;
        END;

        IF @fObj IS NOT NULL AND @fObj <= @HastaLSN
        BEGIN
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
            FROM BI_VIP_CENTER_FIT_DW_ORIGEN.cdc.fn_cdc_get_all_changes_dbo_FactObjetivos(@fObj, @HastaLSN, 'all')
            WHERE __$operation IN (1, 2, 4);
            SET @Filas += @@ROWCOUNT;
        END;

        IF @fEva IS NOT NULL AND @fEva <= @HastaLSN
        BEGIN
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
            FROM BI_VIP_CENTER_FIT_DW_ORIGEN.cdc.fn_cdc_get_all_changes_dbo_FactEvaluaciones(@fEva, @HastaLSN, 'all')
            WHERE __$operation IN (1, 2, 4);
            SET @Filas += @@ROWCOUNT;
        END;

        IF @fRec IS NOT NULL AND @fRec <= @HastaLSN
        BEGIN
            INSERT INTO stg.stg_atencion_reclamos
            (
                CargaID, OperacionCDC, StartLSN, SeqVal, EntidadOrigen,
                id_reclamo_bk, sk_fecha_reclamo_origen, sk_cliente_origen,
                sk_empleado_origen, categoria, estado, fecha_resolucion,
                dias_resolucion, resuelto_en_mostrador
            )
            SELECT
                @CargaID, __$operation, __$start_lsn, __$seqval, 'RECLAMO',
                id_reclamo_bk, sk_fecha_reclamo, sk_cliente,
                sk_empleado, categoria, estado, fecha_resolucion,
                dias_resolucion, resuelto_en_mostrador
            FROM BI_VIP_CENTER_FIT_DW_ORIGEN.cdc.fn_cdc_get_all_changes_dbo_FactReclamos(@fRec, @HastaLSN, 'all')
            WHERE __$operation IN (1, 2, 4);
            SET @Filas += @@ROWCOUNT;
        END;

        IF @fSes IS NOT NULL AND @fSes <= @HastaLSN
        BEGIN
            INSERT INTO stg.stg_entrenamiento
            (
                CargaID, OperacionCDC, StartLSN, SeqVal, EntidadOrigen,
                id_sesion_bk, sk_fecha_programada_origen, sk_cliente_origen,
                sk_plan_origen, sk_empleado_origen, tipo_sesion, hora_programada,
                estado_sesion, duracion_minutos
            )
            SELECT
                @CargaID, __$operation, __$start_lsn, __$seqval, 'SESION_PROGRAMADA',
                id_sesion_bk, sk_fecha_programada, sk_cliente,
                sk_plan, sk_empleado, tipo_sesion, hora_programada,
                estado_sesion, duracion_minutos
            FROM BI_VIP_CENTER_FIT_DW_ORIGEN.cdc.fn_cdc_get_all_changes_dbo_FactSesionesProgramadas(@fSes, @HastaLSN, 'all')
            WHERE __$operation IN (1, 2, 4);
            SET @Filas += @@ROWCOUNT;
        END;

        IF @fEvaP IS NOT NULL AND @fEvaP <= @HastaLSN
        BEGIN
            INSERT INTO stg.stg_entrenamiento
            (
                CargaID, OperacionCDC, StartLSN, SeqVal, EntidadOrigen,
                id_evaluacion_programada_bk, sk_fecha_programada_origen, sk_cliente_origen,
                sk_empleado_origen, id_objetivo_bk, tipo_evaluacion, estado_evaluacion,
                id_evaluacion_bk
            )
            SELECT
                @CargaID, __$operation, __$start_lsn, __$seqval, 'EVALUACION_PROGRAMADA',
                id_evaluacion_programada_bk, sk_fecha_programada, sk_cliente,
                sk_empleado, id_objetivo_bk, tipo_evaluacion, estado_evaluacion,
                id_evaluacion_bk
            FROM BI_VIP_CENTER_FIT_DW_ORIGEN.cdc.fn_cdc_get_all_changes_dbo_FactEvaluacionesProgramadas(@fEvaP, @HastaLSN, 'all')
            WHERE __$operation IN (1, 2, 4);
            SET @Filas += @@ROWCOUNT;
        END;

        IF @fRet IS NOT NULL AND @fRet <= @HastaLSN
        BEGIN
            INSERT INTO stg.stg_atencion_reclamos
            (
                CargaID, OperacionCDC, StartLSN, SeqVal, EntidadOrigen,
                id_retencion_bk, sk_fecha_retencion_origen, sk_cliente_origen,
                sk_empleado_origen, id_membresia_bk, canal, motivo, resultado,
                monto_oferta
            )
            SELECT
                @CargaID, __$operation, __$start_lsn, __$seqval, 'RETENCION',
                id_retencion_bk, sk_fecha_retencion, sk_cliente,
                sk_empleado, id_membresia_bk, canal, motivo, resultado,
                monto_oferta
            FROM BI_VIP_CENTER_FIT_DW_ORIGEN.cdc.fn_cdc_get_all_changes_dbo_FactRetenciones(@fRet, @HastaLSN, 'all')
            WHERE __$operation IN (1, 2, 4);
            SET @Filas += @@ROWCOUNT;
        END;

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
