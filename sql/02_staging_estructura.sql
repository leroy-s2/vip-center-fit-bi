/*=============================================================================
  VIP CENTER FIT - ETAPA 3: STAGING / RAW

  Esta estructura conserva los datos tal como llegan desde la fuente.
  No corrige duplicados, nulos, fechas ni claves huérfanas.

  Ejecutar este archivo solo para instalar/recrear la estructura de staging.
  La ingesta programada se encuentra en 03_Ingesta_Programada.sql.
=============================================================================*/

USE master;
GO

IF DB_ID(N'BI_VIP_CENTER_FIT_STG') IS NULL
BEGIN
    CREATE DATABASE BI_VIP_CENTER_FIT_STG;
END;
GO

USE BI_VIP_CENTER_FIT_STG;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'stg')
    EXEC('CREATE SCHEMA stg');
GO

/* La estructura puede recrearse porque todavía no es la zona histórica final. */
DROP TABLE IF EXISTS stg.stg_atencion_reclamos;
DROP TABLE IF EXISTS stg.stg_entrenamiento;
DROP TABLE IF EXISTS stg.stg_ventas_membresias;
DROP TABLE IF EXISTS stg.stg_planes;
DROP TABLE IF EXISTS stg.stg_empleados;
DROP TABLE IF EXISTS stg.stg_clientes;
DROP TABLE IF EXISTS stg.stg_fecha;
DROP TABLE IF EXISTS stg.etl_cdc_control;
GO

/* Marca de agua para que la ingesta CDC sea incremental y no repita cambios. */
CREATE TABLE stg.etl_cdc_control
(
    capture_instance SYSNAME NOT NULL PRIMARY KEY,
    last_lsn BINARY(10) NULL,
    ultima_carga DATETIME2(0) NULL,
    filas_ultima_carga BIGINT NULL
);
GO

/* Dimensiones que también deben pasar por Raw antes de limpiarse. */
CREATE TABLE stg.stg_fecha
(
    StagingID BIGINT IDENTITY(1,1) PRIMARY KEY,
    CargaID UNIQUEIDENTIFIER NOT NULL,
    OperacionCDC TINYINT NULL,
    StartLSN VARBINARY(10) NULL,
    SeqVal VARBINARY(10) NULL,
    sk_fecha_origen INT NULL,
    fecha DATE NULL,
    anio INT NULL,
    trimestre INT NULL,
    semestre INT NULL,
    mes INT NULL,
    nombre_mes VARCHAR(30) NULL,
    dia INT NULL,
    dia_semana VARCHAR(30) NULL,
    es_fin_de_semana BIT NULL,
    FechaIngesta DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE stg.stg_clientes
(
    StagingID BIGINT IDENTITY(1,1) PRIMARY KEY,
    CargaID UNIQUEIDENTIFIER NOT NULL,
    OperacionCDC TINYINT NULL,
    StartLSN VARBINARY(10) NULL,
    SeqVal VARBINARY(10) NULL,
    sk_cliente_origen INT NULL,
    id_cliente_bk INT NULL,
    dni VARCHAR(20) NULL,
    nombre_completo VARCHAR(250) NULL,
    sexo VARCHAR(20) NULL,
    rango_etario VARCHAR(50) NULL,
    estado_cliente VARCHAR(30) NULL,
    fecha_registro_origen DATE NULL,
    fecha_inicio_validez DATE NULL,
    fecha_fin_validez DATE NULL,
    es_actual BIT NULL,
    FechaIngesta DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE stg.stg_empleados
(
    StagingID BIGINT IDENTITY(1,1) PRIMARY KEY,
    CargaID UNIQUEIDENTIFIER NOT NULL,
    OperacionCDC TINYINT NULL,
    StartLSN VARBINARY(10) NULL,
    SeqVal VARBINARY(10) NULL,
    sk_empleado_origen INT NULL,
    id_empleado_bk INT NULL,
    codigo_empleado VARCHAR(20) NULL,
    dni VARCHAR(20) NULL,
    nombre_completo VARCHAR(250) NULL,
    cargo VARCHAR(60) NULL,
    area VARCHAR(60) NULL,
    FechaIngesta DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE stg.stg_planes
(
    StagingID BIGINT IDENTITY(1,1) PRIMARY KEY,
    CargaID UNIQUEIDENTIFIER NOT NULL,
    OperacionCDC TINYINT NULL,
    StartLSN VARBINARY(10) NULL,
    SeqVal VARBINARY(10) NULL,
    sk_plan_origen INT NULL,
    id_plan_bk INT NULL,
    nombre_plan VARCHAR(60) NULL,
    duracion_dias INT NULL,
    precio_referencial DECIMAL(12,2) NULL,
    categoria_duracion VARCHAR(40) NULL,
    FechaIngesta DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

/* Ventas, membresías, renovaciones y avisos del dominio comercial. */
CREATE TABLE stg.stg_ventas_membresias
(
    StagingID BIGINT IDENTITY(1,1) PRIMARY KEY,
    CargaID UNIQUEIDENTIFIER NOT NULL,
    OperacionCDC TINYINT NULL,
    StartLSN VARBINARY(10) NULL,
    SeqVal VARBINARY(10) NULL,
    EntidadOrigen VARCHAR(30) NOT NULL,

    id_pago_bk INT NULL,
    id_membresia_bk INT NULL,
    id_renovacion_bk INT NULL,
    id_aviso_bk INT NULL,
    id_membresia_anterior_bk INT NULL,
    id_membresia_nueva_bk INT NULL,

    sk_fecha_pago_origen INT NULL,
    sk_fecha_inicio_origen INT NULL,
    sk_fecha_fin_origen INT NULL,
    sk_fecha_renovacion_origen INT NULL,
    sk_fecha_aviso_origen INT NULL,
    sk_cliente_origen INT NULL,
    sk_plan_origen INT NULL,
    sk_empleado_origen INT NULL,

    duracion_dias INT NULL,
    precio_final DECIMAL(12,2) NULL,
    es_renovacion BIT NULL,
    estado_membresia VARCHAR(30) NULL,
    dias_anticipacion_renovacion INT NULL,

    monto_neto DECIMAL(12,2) NULL,
    descuento_aplicado DECIMAL(12,2) NULL,
    precio_lista DECIMAL(12,2) NULL,
    metodo_pago VARCHAR(50) NULL,

    dias_anticipacion INT NULL,
    monto_renovacion DECIMAL(12,2) NULL,
    dias_antes_vencimiento INT NULL,
    medio_aviso VARCHAR(30) NULL,
    estado_aviso VARCHAR(30) NULL,

    FechaIngesta DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

/* Asistencias, objetivos y evaluaciones físicas. */
CREATE TABLE stg.stg_entrenamiento
(
    StagingID BIGINT IDENTITY(1,1) PRIMARY KEY,
    CargaID UNIQUEIDENTIFIER NOT NULL,
    OperacionCDC TINYINT NULL,
    StartLSN VARBINARY(10) NULL,
    SeqVal VARBINARY(10) NULL,
    EntidadOrigen VARCHAR(30) NOT NULL,

    id_asistencia_bk INT NULL,
    id_objetivo_bk INT NULL,
    id_evaluacion_bk INT NULL,
    sk_fecha_asistencia_origen INT NULL,
    sk_fecha_inicio_origen INT NULL,
    sk_fecha_meta_origen INT NULL,
    sk_fecha_evaluacion_origen INT NULL,
    sk_cliente_origen INT NULL,
    sk_plan_origen INT NULL,
    sk_empleado_origen INT NULL,

    hora_ingreso INT NULL,
    cantidad_asistencias INT NULL,
    tipo_objetivo VARCHAR(60) NULL,
    valor_inicial DECIMAL(10,2) NULL,
    valor_objetivo DECIMAL(10,2) NULL,
    unidad_medida VARCHAR(30) NULL,
    estado_objetivo VARCHAR(30) NULL,
    peso DECIMAL(8,2) NULL,
    altura DECIMAL(8,2) NULL,
    grasa_corporal DECIMAL(8,2) NULL,
    masa_muscular DECIMAL(8,2) NULL,

    id_sesion_bk INT NULL,
    id_evaluacion_programada_bk INT NULL,
    sk_fecha_programada_origen INT NULL,
    tipo_sesion VARCHAR(40) NULL,
    hora_programada INT NULL,
    estado_sesion VARCHAR(30) NULL,
    duracion_minutos INT NULL,
    tipo_evaluacion VARCHAR(40) NULL,
    estado_evaluacion VARCHAR(30) NULL,
    fecha_cancelacion DATETIME2(7) NULL,
    motivo_cancelacion VARCHAR(60) NULL,

    FechaIngesta DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

/* Reclamos y atenciones registradas. */
CREATE TABLE stg.stg_atencion_reclamos
(
    StagingID BIGINT IDENTITY(1,1) PRIMARY KEY,
    CargaID UNIQUEIDENTIFIER NOT NULL,
    OperacionCDC TINYINT NULL,
    StartLSN VARBINARY(10) NULL,
    SeqVal VARBINARY(10) NULL,
    EntidadOrigen VARCHAR(30) NOT NULL,
    id_reclamo_bk INT NULL,
    sk_fecha_reclamo_origen INT NULL,
    sk_cliente_origen INT NULL,
    sk_empleado_origen INT NULL,
    categoria VARCHAR(60) NULL,
    estado VARCHAR(30) NULL,
    fecha_resolucion DATETIME2(7) NULL,
    fecha_cierre DATETIME2(7) NULL,
    dias_resolucion INT NULL,
    resuelto_en_mostrador BIT NULL,
    escalado BIT NULL,
    area_responsable VARCHAR(60) NULL,
    id_retencion_bk INT NULL,
    sk_fecha_retencion_origen INT NULL,
    id_membresia_bk INT NULL,
    canal VARCHAR(40) NULL,
    motivo VARCHAR(60) NULL,
    resultado VARCHAR(30) NULL,
    monto_oferta DECIMAL(12,2) NULL,
    FechaIngesta DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

/* Índices para que el ETL pueda resolver las claves de origen rápidamente. */
CREATE INDEX IX_stg_fecha_sk ON stg.stg_fecha(sk_fecha_origen);
CREATE INDEX IX_stg_clientes_sk ON stg.stg_clientes(sk_cliente_origen);
CREATE INDEX IX_stg_clientes_bk ON stg.stg_clientes(id_cliente_bk);
CREATE INDEX IX_stg_empleados_sk ON stg.stg_empleados(sk_empleado_origen);
CREATE INDEX IX_stg_planes_sk ON stg.stg_planes(sk_plan_origen);
CREATE INDEX IX_stg_ventas_entidad ON stg.stg_ventas_membresias(EntidadOrigen);
CREATE INDEX IX_stg_entrenamiento_entidad ON stg.stg_entrenamiento(EntidadOrigen);
CREATE INDEX IX_stg_entrenamiento_objetivo ON stg.stg_entrenamiento(id_objetivo_bk);
CREATE INDEX IX_stg_reclamos_entidad ON stg.stg_atencion_reclamos(EntidadOrigen);
CREATE INDEX IX_stg_reclamos_bk ON stg.stg_atencion_reclamos(id_reclamo_bk);
GO
