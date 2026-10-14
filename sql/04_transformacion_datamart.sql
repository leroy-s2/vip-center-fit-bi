/*=============================================================================
  VIP CENTER FIT - ETAPA 4: TRANSFORMACIÓN Y CARGA DEL DATA MART

  Este archivo tiene dos responsabilidades separadas:

    1) INSTALACIÓN / DDL  (idempotente)
       Crea la base, los esquemas, las dimensiones, los hechos, las FOREIGN KEY
       y la tabla de marca de agua ETL si no existen. NO borra lo que ya existe,
       así que puede ejecutarse repetidamente sin destruir datos.

    2) RECONSTRUCCIÓN COMPLETA INICIAL
       Deja el Data Mart limpio y ejecuta una primera carga. Se usa sólo en el
       bootstrap (instalación). La operación normal (cada 10 minutos) NO corre
       este archivo: el job de SQL Agent ejecuta únicamente los procedimientos
       usp_Ingesta_CDC y usp_Transformar_CargarDataMart.

  El procedimiento usp_Transformar_CargarDataMart es INCREMENTAL:
  lee únicamente las filas nuevas del staging desde la última marca de agua
  (dbo.etl_control.ultimo_staging_id) y aplica MERGE por clave de negocio.
  La fuente de origen no se consulta aquí.
=============================================================================*/

USE master;
GO

IF DB_ID(N'BI_VIP_CENTER_FIT_DW') IS NULL
BEGIN
    CREATE DATABASE BI_VIP_CENTER_FIT_DW;
END;
GO

USE BI_VIP_CENTER_FIT_DW;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dim')
    EXEC('CREATE SCHEMA dim');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dm_comercial')
    EXEC('CREATE SCHEMA dm_comercial');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dm_entrenamiento')
    EXEC('CREATE SCHEMA dm_entrenamiento');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dm_atencion')
    EXEC('CREATE SCHEMA dm_atencion');
GO

/* Las vistas se recrean en 05; se limpian aquí para permitir recargar el modelo. */
IF OBJECT_ID('dbo.DM_Entrenamiento_Progreso', 'V') IS NOT NULL DROP VIEW dbo.DM_Entrenamiento_Progreso;
IF OBJECT_ID('dbo.DM_Entrenamiento_Asistencia', 'V') IS NOT NULL DROP VIEW dbo.DM_Entrenamiento_Asistencia;
IF OBJECT_ID('dbo.DM_Entrenamiento_Cumplimiento', 'V') IS NOT NULL DROP VIEW dbo.DM_Entrenamiento_Cumplimiento;
IF OBJECT_ID('dbo.DM_Atencion_Reclamos', 'V') IS NOT NULL DROP VIEW dbo.DM_Atencion_Reclamos;
IF OBJECT_ID('dbo.DM_Avisos_Cobertura', 'V') IS NOT NULL DROP VIEW dbo.DM_Avisos_Cobertura;
IF OBJECT_ID('dbo.DM_Comercial_Plan', 'V') IS NOT NULL DROP VIEW dbo.DM_Comercial_Plan;
IF OBJECT_ID('dbo.DM_Gerencia_Membresias', 'V') IS NOT NULL DROP VIEW dbo.DM_Gerencia_Membresias;
IF OBJECT_ID('dbo.DM_Gerencia_Ingresos', 'V') IS NOT NULL DROP VIEW dbo.DM_Gerencia_Ingresos;
IF OBJECT_ID('dbo.DM_Ventas_Gerencia', 'V') IS NOT NULL DROP VIEW dbo.DM_Ventas_Gerencia;
IF OBJECT_ID('dbo.DM_Rutinas_Entrenador', 'V') IS NOT NULL DROP VIEW dbo.DM_Rutinas_Entrenador;
IF OBJECT_ID('dbo.DM_Atencion_Recepcion', 'V') IS NOT NULL DROP VIEW dbo.DM_Atencion_Recepcion;
IF OBJECT_ID('dbo.DM_Entrenamiento_Evaluaciones', 'V') IS NOT NULL DROP VIEW dbo.DM_Entrenamiento_Evaluaciones;
IF OBJECT_ID('dbo.DM_Atencion_Retencion', 'V') IS NOT NULL DROP VIEW dbo.DM_Atencion_Retencion;
GO

/* -----------------------------------------------------------------------------
   Tabla de dimensiones conformadas (esquema compartido por los 3 data mart).
   ----------------------------------------------------------------------------- */
IF OBJECT_ID('dim.DimFecha', 'U') IS NULL
CREATE TABLE dim.DimFecha
(
    sk_fecha INT NOT NULL PRIMARY KEY,
    fecha DATE NOT NULL UNIQUE,
    anio INT NOT NULL,
    trimestre INT NOT NULL,
    semestre INT NOT NULL,
    mes INT NOT NULL,
    nombre_mes VARCHAR(30) NOT NULL,
    dia INT NOT NULL,
    dia_semana VARCHAR(30) NOT NULL,
    es_fin_de_semana BIT NOT NULL
);
GO

IF OBJECT_ID('dim.DimCliente', 'U') IS NULL
CREATE TABLE dim.DimCliente
(
    sk_cliente INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    sk_cliente_origen INT NULL,
    id_cliente_bk INT NOT NULL UNIQUE,
    dni VARCHAR(8) NULL,
    nombre_completo VARCHAR(250) NOT NULL,
    sexo CHAR(1) NOT NULL,
    rango_etario VARCHAR(50) NULL,
    estado_cliente VARCHAR(30) NOT NULL,
    fecha_registro_origen DATE NULL,
    fecha_inicio_validez DATE NULL,
    fecha_fin_validez DATE NULL,
    es_actual BIT NOT NULL
);
GO

IF OBJECT_ID('dim.DimEmpleado', 'U') IS NULL
CREATE TABLE dim.DimEmpleado
(
    sk_empleado INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    sk_empleado_origen INT NULL,
    id_empleado_bk INT NOT NULL UNIQUE,
    dni VARCHAR(20) NULL,
    nombre_completo VARCHAR(250) NOT NULL,
    cargo VARCHAR(60) NOT NULL,
    area VARCHAR(60) NOT NULL
);
GO

IF OBJECT_ID('dim.DimPlan', 'U') IS NULL
CREATE TABLE dim.DimPlan
(
    sk_plan INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    tipo_plan VARCHAR(40) NOT NULL,
    tipo_operacion VARCHAR(40) NOT NULL,
    promocion VARCHAR(100) NOT NULL,
    CONSTRAINT UQ_DimPlan_Combinacion UNIQUE (tipo_plan, tipo_operacion, promocion)
);
GO

/* -----------------------------------------------------------------------------
   Hechos de cada data mart.
   ----------------------------------------------------------------------------- */
IF OBJECT_ID('dm_comercial.FactVentas', 'U') IS NULL
CREATE TABLE dm_comercial.FactVentas
(
    sk_venta BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    id_pago_bk INT NOT NULL UNIQUE,
    sk_fecha_pago INT NOT NULL,
    sk_cliente INT NOT NULL,
    sk_plan INT NOT NULL,
    sk_empleado INT NULL,
    id_membresia_bk INT NULL,
    monto_neto DECIMAL(12,2) NOT NULL,
    descuento_aplicado DECIMAL(12,2) NULL,
    precio_lista DECIMAL(12,2) NULL,
    metodo_pago VARCHAR(50) NOT NULL
);
GO

IF OBJECT_ID('dm_comercial.FactMembresias', 'U') IS NULL
CREATE TABLE dm_comercial.FactMembresias
(
    sk_membresia BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    id_membresia_bk INT NOT NULL UNIQUE,
    sk_cliente INT NOT NULL,
    sk_plan INT NOT NULL,
    sk_empleado INT NULL,
    sk_fecha_inicio INT NOT NULL,
    sk_fecha_fin INT NOT NULL,
    duracion_dias INT NULL,
    precio_final DECIMAL(12,2) NULL,
    es_renovacion BIT NOT NULL,
    estado_membresia VARCHAR(30) NOT NULL,
    dias_anticipacion_renovacion INT NULL
);
GO

IF OBJECT_ID('dm_comercial.FactRenovaciones', 'U') IS NULL
CREATE TABLE dm_comercial.FactRenovaciones
(
    sk_renovacion BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    id_renovacion_bk INT NOT NULL UNIQUE,
    sk_fecha_renovacion INT NOT NULL,
    sk_cliente INT NOT NULL,
    sk_empleado INT NULL,
    id_membresia_anterior_bk INT NULL,
    id_membresia_nueva_bk INT NULL,
    dias_anticipacion INT NULL,
    monto DECIMAL(12,2) NULL
);
GO

IF OBJECT_ID('dm_comercial.FactAvisos', 'U') IS NULL
CREATE TABLE dm_comercial.FactAvisos
(
    sk_aviso BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    id_aviso_bk INT NOT NULL UNIQUE,
    sk_fecha_aviso INT NOT NULL,
    sk_cliente INT NOT NULL,
    sk_empleado INT NULL,
    id_membresia_bk INT NULL,
    dias_antes_vencimiento INT NULL,
    medio VARCHAR(30) NOT NULL,
    estado VARCHAR(30) NOT NULL
);
GO

IF OBJECT_ID('dm_entrenamiento.FactAsistencias', 'U') IS NULL
CREATE TABLE dm_entrenamiento.FactAsistencias
(
    sk_asistencia BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    id_asistencia_bk INT NOT NULL UNIQUE,
    sk_fecha_asistencia INT NOT NULL,
    sk_cliente INT NOT NULL,
    sk_plan INT NULL,
    sk_empleado INT NULL,
    hora_ingreso INT NULL,
    cantidad_asistencias INT NOT NULL
);
GO

IF OBJECT_ID('dm_entrenamiento.FactObjetivos', 'U') IS NULL
CREATE TABLE dm_entrenamiento.FactObjetivos
(
    sk_objetivo BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    id_objetivo_bk INT NOT NULL UNIQUE,
    sk_fecha_inicio INT NOT NULL,
    sk_cliente INT NOT NULL,
    tipo_objetivo VARCHAR(60) NOT NULL,
    valor_inicial DECIMAL(10,2) NULL,
    valor_objetivo DECIMAL(10,2) NULL,
    unidad_medida VARCHAR(30) NOT NULL,
    estado VARCHAR(30) NOT NULL
);
GO

IF OBJECT_ID('dm_entrenamiento.FactEvaluaciones', 'U') IS NULL
CREATE TABLE dm_entrenamiento.FactEvaluaciones
(
    sk_evaluacion BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    id_evaluacion_bk INT NOT NULL UNIQUE,
    sk_fecha_evaluacion INT NOT NULL,
    sk_cliente INT NOT NULL,
    sk_empleado INT NULL,
    id_objetivo_bk INT NULL,
    peso DECIMAL(8,2) NULL,
    altura DECIMAL(8,2) NULL,
    grasa_corporal DECIMAL(8,2) NULL,
    masa_muscular DECIMAL(8,2) NULL
);
GO

IF OBJECT_ID('dm_atencion.FactReclamos', 'U') IS NULL
CREATE TABLE dm_atencion.FactReclamos
(
    sk_reclamo BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    id_reclamo_bk INT NOT NULL UNIQUE,
    sk_fecha_reclamo INT NOT NULL,
    sk_cliente INT NOT NULL,
    sk_empleado INT NULL,
    categoria VARCHAR(60) NOT NULL,
    estado VARCHAR(30) NOT NULL,
    fecha_resolucion DATETIME2(7) NULL,
    dias_resolucion INT NULL,
    resuelto_en_mostrador BIT NULL
);
GO

IF COL_LENGTH('dm_atencion.FactReclamos', 'resuelto_en_mostrador') IS NULL
    ALTER TABLE dm_atencion.FactReclamos ADD resuelto_en_mostrador BIT NULL;
GO

IF OBJECT_ID('dm_entrenamiento.FactSesionesProgramadas', 'U') IS NULL
CREATE TABLE dm_entrenamiento.FactSesionesProgramadas
(
    sk_sesion_programada BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    id_sesion_bk INT NOT NULL UNIQUE,
    sk_fecha_programada INT NOT NULL,
    sk_cliente INT NOT NULL,
    sk_plan INT NULL,
    sk_empleado INT NULL,
    tipo_sesion VARCHAR(40) NOT NULL,
    hora_programada INT NULL,
    estado_sesion VARCHAR(30) NOT NULL,
    duracion_minutos INT NULL
);
GO

IF OBJECT_ID('dm_entrenamiento.FactEvaluacionesProgramadas', 'U') IS NULL
CREATE TABLE dm_entrenamiento.FactEvaluacionesProgramadas
(
    sk_evaluacion_programada BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    id_evaluacion_programada_bk INT NOT NULL UNIQUE,
    sk_fecha_programada INT NOT NULL,
    sk_cliente INT NOT NULL,
    sk_empleado INT NULL,
    id_objetivo_bk INT NULL,
    tipo_evaluacion VARCHAR(40) NOT NULL,
    estado_evaluacion VARCHAR(30) NOT NULL,
    id_evaluacion_bk INT NULL
);
GO

IF OBJECT_ID('dm_atencion.FactRetenciones', 'U') IS NULL
CREATE TABLE dm_atencion.FactRetenciones
(
    sk_retencion BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    id_retencion_bk INT NOT NULL UNIQUE,
    sk_fecha_retencion INT NOT NULL,
    sk_cliente INT NOT NULL,
    sk_empleado INT NULL,
    id_membresia_bk INT NULL,
    canal VARCHAR(40) NOT NULL,
    motivo VARCHAR(60) NOT NULL,
    resultado VARCHAR(30) NOT NULL,
    monto_oferta DECIMAL(12,2) NULL
);
GO

/* -----------------------------------------------------------------------------
   Marca de agua del ETL (staging -> Data Mart). Una fila por tabla de staging.
   Permite que el ETL procese SÓLO las filas nuevas sin recargar todo.
   ----------------------------------------------------------------------------- */
IF OBJECT_ID('dbo.etl_control', 'U') IS NULL
CREATE TABLE dbo.etl_control
(
    proceso SYSNAME NOT NULL PRIMARY KEY,
    ultimo_staging_id BIGINT NOT NULL DEFAULT (0),
    ultima_carga DATETIME2(3) NULL,
    filas_ultima_carga BIGINT NULL
);
GO

IF NOT EXISTS (SELECT 1 FROM dbo.etl_control WHERE proceso = 'stg_fecha')
    INSERT INTO dbo.etl_control (proceso, ultimo_staging_id) VALUES
        ('stg_fecha', 0),
        ('stg_clientes', 0),
        ('stg_empleados', 0),
        ('stg_planes', 0),
        ('stg_ventas_membresias', 0),
        ('stg_entrenamiento', 0),
        ('stg_atencion_reclamos', 0);
GO

/* -----------------------------------------------------------------------------
   Calidad de datos: registro de filas descartadas por el ETL (ver docs/CALIDAD.md).
   ----------------------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dq')
    EXEC('CREATE SCHEMA dq');
GO

IF OBJECT_ID('dq.RegistroRechazos', 'U') IS NULL
CREATE TABLE dq.RegistroRechazos
(
    id_rechazo     BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    codigo_regla   VARCHAR(20) NOT NULL,
    entidad        VARCHAR(60) NOT NULL,
    campo          VARCHAR(60) NULL,
    staging_id     BIGINT NULL,
    bk             VARCHAR(40) NULL,
    valor          VARCHAR(200) NULL,
    motivo         VARCHAR(300) NOT NULL,
    fecha_registro DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

/* -----------------------------------------------------------------------------
   Sinónimos de compatibilidad (los usan el ETL y las vistas de KPIs).
   ----------------------------------------------------------------------------- */
DROP SYNONYM IF EXISTS dbo.DimFecha;
DROP SYNONYM IF EXISTS dbo.DimCliente;
DROP SYNONYM IF EXISTS dbo.DimEmpleado;
DROP SYNONYM IF EXISTS dbo.DimPlan;
DROP SYNONYM IF EXISTS dbo.FactVentas;
DROP SYNONYM IF EXISTS dbo.FactMembresias;
DROP SYNONYM IF EXISTS dbo.FactRenovaciones;
DROP SYNONYM IF EXISTS dbo.FactAvisos;
DROP SYNONYM IF EXISTS dbo.FactAsistencias;
DROP SYNONYM IF EXISTS dbo.FactObjetivos;
DROP SYNONYM IF EXISTS dbo.FactEvaluaciones;
DROP SYNONYM IF EXISTS dbo.FactReclamos;
DROP SYNONYM IF EXISTS dbo.FactSesionesProgramadas;
DROP SYNONYM IF EXISTS dbo.FactEvaluacionesProgramadas;
DROP SYNONYM IF EXISTS dbo.FactRetenciones;
DROP SYNONYM IF EXISTS dbo.stg_fecha;
DROP SYNONYM IF EXISTS dbo.stg_clientes;
DROP SYNONYM IF EXISTS dbo.stg_empleados;
DROP SYNONYM IF EXISTS dbo.stg_planes;
DROP SYNONYM IF EXISTS dbo.stg_ventas_membresias;
DROP SYNONYM IF EXISTS dbo.stg_entrenamiento;
DROP SYNONYM IF EXISTS dbo.stg_atencion_reclamos;
GO

CREATE SYNONYM dbo.DimFecha FOR dim.DimFecha;
CREATE SYNONYM dbo.DimCliente FOR dim.DimCliente;
CREATE SYNONYM dbo.DimEmpleado FOR dim.DimEmpleado;
CREATE SYNONYM dbo.DimPlan FOR dim.DimPlan;
CREATE SYNONYM dbo.FactVentas FOR dm_comercial.FactVentas;
CREATE SYNONYM dbo.FactMembresias FOR dm_comercial.FactMembresias;
CREATE SYNONYM dbo.FactRenovaciones FOR dm_comercial.FactRenovaciones;
CREATE SYNONYM dbo.FactAvisos FOR dm_comercial.FactAvisos;
CREATE SYNONYM dbo.FactAsistencias FOR dm_entrenamiento.FactAsistencias;
CREATE SYNONYM dbo.FactObjetivos FOR dm_entrenamiento.FactObjetivos;
CREATE SYNONYM dbo.FactEvaluaciones FOR dm_entrenamiento.FactEvaluaciones;
CREATE SYNONYM dbo.FactReclamos FOR dm_atencion.FactReclamos;
CREATE SYNONYM dbo.FactSesionesProgramadas FOR dm_entrenamiento.FactSesionesProgramadas;
CREATE SYNONYM dbo.FactEvaluacionesProgramadas FOR dm_entrenamiento.FactEvaluacionesProgramadas;
CREATE SYNONYM dbo.FactRetenciones FOR dm_atencion.FactRetenciones;

/* Sinónimos de lectura hacia el Staging separado. */
CREATE SYNONYM dbo.stg_fecha FOR BI_VIP_CENTER_FIT_STG.stg.stg_fecha;
CREATE SYNONYM dbo.stg_clientes FOR BI_VIP_CENTER_FIT_STG.stg.stg_clientes;
CREATE SYNONYM dbo.stg_empleados FOR BI_VIP_CENTER_FIT_STG.stg.stg_empleados;
CREATE SYNONYM dbo.stg_planes FOR BI_VIP_CENTER_FIT_STG.stg.stg_planes;
CREATE SYNONYM dbo.stg_ventas_membresias FOR BI_VIP_CENTER_FIT_STG.stg.stg_ventas_membresias;
CREATE SYNONYM dbo.stg_entrenamiento FOR BI_VIP_CENTER_FIT_STG.stg.stg_entrenamiento;
CREATE SYNONYM dbo.stg_atencion_reclamos FOR BI_VIP_CENTER_FIT_STG.stg.stg_atencion_reclamos;
GO

/* -----------------------------------------------------------------------------
   Integridad referencial: relaciones FÍSICAS hecho -> dimensión conformada.
   Se crean sólo si no existen (idempotente).
   ----------------------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactVentas_DimFecha')
    ALTER TABLE dm_comercial.FactVentas ADD CONSTRAINT FK_FactVentas_DimFecha
        FOREIGN KEY (sk_fecha_pago) REFERENCES dim.DimFecha(sk_fecha);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactVentas_DimCliente')
    ALTER TABLE dm_comercial.FactVentas ADD CONSTRAINT FK_FactVentas_DimCliente
        FOREIGN KEY (sk_cliente) REFERENCES dim.DimCliente(sk_cliente);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactVentas_DimPlan')
    ALTER TABLE dm_comercial.FactVentas ADD CONSTRAINT FK_FactVentas_DimPlan
        FOREIGN KEY (sk_plan) REFERENCES dim.DimPlan(sk_plan);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactVentas_DimEmpleado')
    ALTER TABLE dm_comercial.FactVentas ADD CONSTRAINT FK_FactVentas_DimEmpleado
        FOREIGN KEY (sk_empleado) REFERENCES dim.DimEmpleado(sk_empleado);

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactMembresias_DimCliente')
    ALTER TABLE dm_comercial.FactMembresias ADD CONSTRAINT FK_FactMembresias_DimCliente
        FOREIGN KEY (sk_cliente) REFERENCES dim.DimCliente(sk_cliente);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactMembresias_DimPlan')
    ALTER TABLE dm_comercial.FactMembresias ADD CONSTRAINT FK_FactMembresias_DimPlan
        FOREIGN KEY (sk_plan) REFERENCES dim.DimPlan(sk_plan);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactMembresias_DimEmpleado')
    ALTER TABLE dm_comercial.FactMembresias ADD CONSTRAINT FK_FactMembresias_DimEmpleado
        FOREIGN KEY (sk_empleado) REFERENCES dim.DimEmpleado(sk_empleado);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactMembresias_DimFechaInicio')
    ALTER TABLE dm_comercial.FactMembresias ADD CONSTRAINT FK_FactMembresias_DimFechaInicio
        FOREIGN KEY (sk_fecha_inicio) REFERENCES dim.DimFecha(sk_fecha);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactMembresias_DimFechaFin')
    ALTER TABLE dm_comercial.FactMembresias ADD CONSTRAINT FK_FactMembresias_DimFechaFin
        FOREIGN KEY (sk_fecha_fin) REFERENCES dim.DimFecha(sk_fecha);

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactRenovaciones_DimFecha')
    ALTER TABLE dm_comercial.FactRenovaciones ADD CONSTRAINT FK_FactRenovaciones_DimFecha
        FOREIGN KEY (sk_fecha_renovacion) REFERENCES dim.DimFecha(sk_fecha);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactRenovaciones_DimCliente')
    ALTER TABLE dm_comercial.FactRenovaciones ADD CONSTRAINT FK_FactRenovaciones_DimCliente
        FOREIGN KEY (sk_cliente) REFERENCES dim.DimCliente(sk_cliente);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactRenovaciones_DimEmpleado')
    ALTER TABLE dm_comercial.FactRenovaciones ADD CONSTRAINT FK_FactRenovaciones_DimEmpleado
        FOREIGN KEY (sk_empleado) REFERENCES dim.DimEmpleado(sk_empleado);

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactAvisos_DimFecha')
    ALTER TABLE dm_comercial.FactAvisos ADD CONSTRAINT FK_FactAvisos_DimFecha
        FOREIGN KEY (sk_fecha_aviso) REFERENCES dim.DimFecha(sk_fecha);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactAvisos_DimCliente')
    ALTER TABLE dm_comercial.FactAvisos ADD CONSTRAINT FK_FactAvisos_DimCliente
        FOREIGN KEY (sk_cliente) REFERENCES dim.DimCliente(sk_cliente);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactAvisos_DimEmpleado')
    ALTER TABLE dm_comercial.FactAvisos ADD CONSTRAINT FK_FactAvisos_DimEmpleado
        FOREIGN KEY (sk_empleado) REFERENCES dim.DimEmpleado(sk_empleado);

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactAsistencias_DimFecha')
    ALTER TABLE dm_entrenamiento.FactAsistencias ADD CONSTRAINT FK_FactAsistencias_DimFecha
        FOREIGN KEY (sk_fecha_asistencia) REFERENCES dim.DimFecha(sk_fecha);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactAsistencias_DimCliente')
    ALTER TABLE dm_entrenamiento.FactAsistencias ADD CONSTRAINT FK_FactAsistencias_DimCliente
        FOREIGN KEY (sk_cliente) REFERENCES dim.DimCliente(sk_cliente);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactAsistencias_DimPlan')
    ALTER TABLE dm_entrenamiento.FactAsistencias ADD CONSTRAINT FK_FactAsistencias_DimPlan
        FOREIGN KEY (sk_plan) REFERENCES dim.DimPlan(sk_plan);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactAsistencias_DimEmpleado')
    ALTER TABLE dm_entrenamiento.FactAsistencias ADD CONSTRAINT FK_FactAsistencias_DimEmpleado
        FOREIGN KEY (sk_empleado) REFERENCES dim.DimEmpleado(sk_empleado);

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactObjetivos_DimFecha')
    ALTER TABLE dm_entrenamiento.FactObjetivos ADD CONSTRAINT FK_FactObjetivos_DimFecha
        FOREIGN KEY (sk_fecha_inicio) REFERENCES dim.DimFecha(sk_fecha);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactObjetivos_DimCliente')
    ALTER TABLE dm_entrenamiento.FactObjetivos ADD CONSTRAINT FK_FactObjetivos_DimCliente
        FOREIGN KEY (sk_cliente) REFERENCES dim.DimCliente(sk_cliente);

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactEvaluaciones_DimFecha')
    ALTER TABLE dm_entrenamiento.FactEvaluaciones ADD CONSTRAINT FK_FactEvaluaciones_DimFecha
        FOREIGN KEY (sk_fecha_evaluacion) REFERENCES dim.DimFecha(sk_fecha);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactEvaluaciones_DimCliente')
    ALTER TABLE dm_entrenamiento.FactEvaluaciones ADD CONSTRAINT FK_FactEvaluaciones_DimCliente
        FOREIGN KEY (sk_cliente) REFERENCES dim.DimCliente(sk_cliente);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactEvaluaciones_DimEmpleado')
    ALTER TABLE dm_entrenamiento.FactEvaluaciones ADD CONSTRAINT FK_FactEvaluaciones_DimEmpleado
        FOREIGN KEY (sk_empleado) REFERENCES dim.DimEmpleado(sk_empleado);

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactReclamos_DimFecha')
    ALTER TABLE dm_atencion.FactReclamos ADD CONSTRAINT FK_FactReclamos_DimFecha
        FOREIGN KEY (sk_fecha_reclamo) REFERENCES dim.DimFecha(sk_fecha);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactReclamos_DimCliente')
    ALTER TABLE dm_atencion.FactReclamos ADD CONSTRAINT FK_FactReclamos_DimCliente
        FOREIGN KEY (sk_cliente) REFERENCES dim.DimCliente(sk_cliente);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactReclamos_DimEmpleado')
    ALTER TABLE dm_atencion.FactReclamos ADD CONSTRAINT FK_FactReclamos_DimEmpleado
        FOREIGN KEY (sk_empleado) REFERENCES dim.DimEmpleado(sk_empleado);

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactSesionesProgramadas_DimFecha')
    ALTER TABLE dm_entrenamiento.FactSesionesProgramadas ADD CONSTRAINT FK_FactSesionesProgramadas_DimFecha
        FOREIGN KEY (sk_fecha_programada) REFERENCES dim.DimFecha(sk_fecha);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactSesionesProgramadas_DimCliente')
    ALTER TABLE dm_entrenamiento.FactSesionesProgramadas ADD CONSTRAINT FK_FactSesionesProgramadas_DimCliente
        FOREIGN KEY (sk_cliente) REFERENCES dim.DimCliente(sk_cliente);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactSesionesProgramadas_DimPlan')
    ALTER TABLE dm_entrenamiento.FactSesionesProgramadas ADD CONSTRAINT FK_FactSesionesProgramadas_DimPlan
        FOREIGN KEY (sk_plan) REFERENCES dim.DimPlan(sk_plan);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactSesionesProgramadas_DimEmpleado')
    ALTER TABLE dm_entrenamiento.FactSesionesProgramadas ADD CONSTRAINT FK_FactSesionesProgramadas_DimEmpleado
        FOREIGN KEY (sk_empleado) REFERENCES dim.DimEmpleado(sk_empleado);

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactEvaluacionesProgramadas_DimFecha')
    ALTER TABLE dm_entrenamiento.FactEvaluacionesProgramadas ADD CONSTRAINT FK_FactEvaluacionesProgramadas_DimFecha
        FOREIGN KEY (sk_fecha_programada) REFERENCES dim.DimFecha(sk_fecha);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactEvaluacionesProgramadas_DimCliente')
    ALTER TABLE dm_entrenamiento.FactEvaluacionesProgramadas ADD CONSTRAINT FK_FactEvaluacionesProgramadas_DimCliente
        FOREIGN KEY (sk_cliente) REFERENCES dim.DimCliente(sk_cliente);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactEvaluacionesProgramadas_DimEmpleado')
    ALTER TABLE dm_entrenamiento.FactEvaluacionesProgramadas ADD CONSTRAINT FK_FactEvaluacionesProgramadas_DimEmpleado
        FOREIGN KEY (sk_empleado) REFERENCES dim.DimEmpleado(sk_empleado);

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactRetenciones_DimFecha')
    ALTER TABLE dm_atencion.FactRetenciones ADD CONSTRAINT FK_FactRetenciones_DimFecha
        FOREIGN KEY (sk_fecha_retencion) REFERENCES dim.DimFecha(sk_fecha);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactRetenciones_DimCliente')
    ALTER TABLE dm_atencion.FactRetenciones ADD CONSTRAINT FK_FactRetenciones_DimCliente
        FOREIGN KEY (sk_cliente) REFERENCES dim.DimCliente(sk_cliente);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactRetenciones_DimEmpleado')
    ALTER TABLE dm_atencion.FactRetenciones ADD CONSTRAINT FK_FactRetenciones_DimEmpleado
        FOREIGN KEY (sk_empleado) REFERENCES dim.DimEmpleado(sk_empleado);
GO

/* =============================================================================
   ETL INCREMENTAL: staging -> Data Mart

   - Sólo procesa las filas del staging con StagingID > marca de agua y
     StagingID <= máximo leído al inicio de esta corrida.
   - MERGE por clave de negocio (BK): inserta lo nuevo y actualiza lo cambiado.
   - Los borrados (OperacionCDC = 1) se aplican: baja física en hechos y baja
     lógica (es_actual = 0) en DimCliente.
   - Dimensiones primero y hechos después, para respetar las FOREIGN KEY.
   - Todo dentro de una transacción: si falla, no avanza la marca de agua.
   ============================================================================= */
CREATE OR ALTER PROCEDURE dbo.usp_Transformar_CargarDataMart
    @FechaCorte DATE = '2026-09-29'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET DATEFIRST 1;

    /* Límites de la marca de agua por tabla de staging. */
    DECLARE @DesdeFecha BIGINT, @HastaFecha BIGINT;
    DECLARE @DesdeCli   BIGINT, @HastaCli   BIGINT;
    DECLARE @DesdeEmp   BIGINT, @HastaEmp   BIGINT;
    DECLARE @DesdePla   BIGINT, @HastaPla   BIGINT;
    DECLARE @DesdeVM    BIGINT, @HastaVM    BIGINT;
    DECLARE @DesdeEnt   BIGINT, @HastaEnt   BIGINT;
    DECLARE @DesdeRec   BIGINT, @HastaRec   BIGINT;
    DECLARE @Filas BIGINT = 0;

    SELECT @DesdeFecha = ultimo_staging_id FROM dbo.etl_control WHERE proceso = 'stg_fecha';
    SELECT @DesdeCli   = ultimo_staging_id FROM dbo.etl_control WHERE proceso = 'stg_clientes';
    SELECT @DesdeEmp   = ultimo_staging_id FROM dbo.etl_control WHERE proceso = 'stg_empleados';
    SELECT @DesdePla   = ultimo_staging_id FROM dbo.etl_control WHERE proceso = 'stg_planes';
    SELECT @DesdeVM    = ultimo_staging_id FROM dbo.etl_control WHERE proceso = 'stg_ventas_membresias';
    SELECT @DesdeEnt   = ultimo_staging_id FROM dbo.etl_control WHERE proceso = 'stg_entrenamiento';
    SELECT @DesdeRec   = ultimo_staging_id FROM dbo.etl_control WHERE proceso = 'stg_atencion_reclamos';

    SELECT @HastaFecha = ISNULL(MAX(StagingID), @DesdeFecha) FROM dbo.stg_fecha;
    SELECT @HastaCli   = ISNULL(MAX(StagingID), @DesdeCli)   FROM dbo.stg_clientes;
    SELECT @HastaEmp   = ISNULL(MAX(StagingID), @DesdeEmp)   FROM dbo.stg_empleados;
    SELECT @HastaPla   = ISNULL(MAX(StagingID), @DesdePla)   FROM dbo.stg_planes;
    SELECT @HastaVM    = ISNULL(MAX(StagingID), @DesdeVM)    FROM dbo.stg_ventas_membresias;
    SELECT @HastaEnt   = ISNULL(MAX(StagingID), @DesdeEnt)   FROM dbo.stg_entrenamiento;
    SELECT @HastaRec   = ISNULL(MAX(StagingID), @DesdeRec)   FROM dbo.stg_atencion_reclamos;

    BEGIN TRY
        BEGIN TRANSACTION;

        /* -------- DIMENSIÓN FECHA -------- */
        ;WITH FechaCanonica AS
        (
            SELECT sk_fecha_origen, MIN(fecha) AS fecha
            FROM dbo.stg_fecha
            WHERE fecha IS NOT NULL
              AND fecha >= '2000-01-01'
              AND fecha <= '2100-12-31'
              AND StagingID > @DesdeFecha AND StagingID <= @HastaFecha
            GROUP BY sk_fecha_origen
        )
        MERGE dim.DimFecha AS t
        USING
        (
            SELECT
                CONVERT(INT, CONVERT(CHAR(8), fecha, 112)) AS sk_fecha,
                fecha,
                YEAR(fecha) AS anio,
                DATEPART(QUARTER, fecha) AS trimestre,
                CASE WHEN MONTH(fecha) <= 6 THEN 1 ELSE 2 END AS semestre,
                MONTH(fecha) AS mes,
                CHOOSE(MONTH(fecha), 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
                       'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre') AS nombre_mes,
                DAY(fecha) AS dia,
                CHOOSE(DATEPART(WEEKDAY, fecha), 'Lunes', 'Martes', 'Miércoles', 'Jueves',
                       'Viernes', 'Sábado', 'Domingo') AS dia_semana,
                CASE WHEN DATEPART(WEEKDAY, fecha) IN (6, 7) THEN 1 ELSE 0 END AS es_fin_de_semana
            FROM FechaCanonica
        ) AS s
        ON t.sk_fecha = s.sk_fecha
        WHEN MATCHED AND t.fecha <> s.fecha THEN UPDATE SET
            t.fecha = s.fecha, t.anio = s.anio, t.trimestre = s.trimestre,
            t.semestre = s.semestre, t.mes = s.mes, t.nombre_mes = s.nombre_mes,
            t.dia = s.dia, t.dia_semana = s.dia_semana, t.es_fin_de_semana = s.es_fin_de_semana
        WHEN NOT MATCHED BY TARGET AND NOT EXISTS (SELECT 1 FROM dim.DimFecha d WHERE d.fecha = s.fecha) THEN
            INSERT (sk_fecha, fecha, anio, trimestre, semestre, mes, nombre_mes, dia, dia_semana, es_fin_de_semana)
            VALUES (s.sk_fecha, s.fecha, s.anio, s.trimestre, s.semestre, s.mes, s.nombre_mes, s.dia, s.dia_semana, s.es_fin_de_semana);

        /* -------- DIMENSIÓN CLIENTE (SCD1) -------- */
        ;WITH ClienteCanonico AS
        (
            SELECT *,
                   ROW_NUMBER() OVER
                   (
                       PARTITION BY id_cliente_bk
                       ORDER BY CASE WHEN es_actual = 1 THEN 0 ELSE 1 END,
                                sk_cliente_origen DESC,
                                StagingID DESC
                   ) AS rn
            FROM dbo.stg_clientes
            WHERE id_cliente_bk IS NOT NULL
              AND StagingID > @DesdeCli AND StagingID <= @HastaCli
              AND OperacionCDC IN (2, 4)
        )
        MERGE dim.DimCliente AS t
        USING
        (
            SELECT
                sk_cliente_origen,
                id_cliente_bk,
                CASE
                    WHEN NULLIF(REPLACE(REPLACE(REPLACE(UPPER(LTRIM(RTRIM(dni))), '-', ''), ' ', ''), 'O', ''), '') IS NULL THEN NULL
                    WHEN REPLACE(REPLACE(REPLACE(UPPER(LTRIM(RTRIM(dni))), '-', ''), ' ', ''), 'O', '0') LIKE '%[^0-9]%' THEN NULL
                    ELSE RIGHT('00000000' + REPLACE(REPLACE(REPLACE(UPPER(LTRIM(RTRIM(dni))), '-', ''), ' ', ''), 'O', '0'), 8)
                END AS dni,
                COALESCE(UPPER(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(nombre_completo, '  ', ' '), '  ', ' '), '  ', ' ')))), 'SIN NOMBRE') AS nombre_completo,
                CASE
                    WHEN UPPER(LEFT(LTRIM(RTRIM(sexo)), 1)) = 'M' THEN 'M'
                    WHEN UPPER(LEFT(LTRIM(RTRIM(sexo)), 1)) = 'F' THEN 'F'
                    ELSE 'X'
                END AS sexo,
                NULLIF(UPPER(LTRIM(RTRIM(rango_etario))), '') AS rango_etario,
                CASE WHEN UPPER(LTRIM(RTRIM(estado_cliente))) LIKE 'ACT%' THEN 'ACTIVO' ELSE 'INACTIVO' END AS estado_cliente,
                CASE WHEN fecha_registro_origen BETWEEN '2000-01-01' AND @FechaCorte THEN fecha_registro_origen END AS fecha_registro_origen,
                CASE WHEN fecha_inicio_validez BETWEEN '2000-01-01' AND @FechaCorte THEN fecha_inicio_validez END AS fecha_inicio_validez,
                CASE WHEN fecha_fin_validez >= fecha_inicio_validez THEN fecha_fin_validez ELSE NULL END AS fecha_fin_validez,
                CASE WHEN es_actual = 1 THEN 1 ELSE 0 END AS es_actual
            FROM ClienteCanonico
            WHERE rn = 1
        ) AS s
        ON t.id_cliente_bk = s.id_cliente_bk
        WHEN MATCHED THEN UPDATE SET
            t.sk_cliente_origen = s.sk_cliente_origen,
            t.dni = s.dni,
            t.nombre_completo = s.nombre_completo,
            t.sexo = s.sexo,
            t.rango_etario = s.rango_etario,
            t.estado_cliente = s.estado_cliente,
            t.fecha_registro_origen = s.fecha_registro_origen,
            t.fecha_inicio_validez = s.fecha_inicio_validez,
            t.fecha_fin_validez = s.fecha_fin_validez,
            t.es_actual = s.es_actual
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (sk_cliente_origen, id_cliente_bk, dni, nombre_completo, sexo, rango_etario,
                    estado_cliente, fecha_registro_origen, fecha_inicio_validez, fecha_fin_validez, es_actual)
            VALUES (s.sk_cliente_origen, s.id_cliente_bk, s.dni, s.nombre_completo, s.sexo, s.rango_etario,
                    s.estado_cliente, s.fecha_registro_origen, s.fecha_inicio_validez, s.fecha_fin_validez, s.es_actual);

        /* Borrado lógico de clientes (última operación = DELETE). */
        UPDATE dc
            SET dc.es_actual = 0,
                dc.fecha_fin_validez = COALESCE(dc.fecha_fin_validez, @FechaCorte)
        FROM dim.DimCliente dc
        INNER JOIN
        (
            SELECT id_cliente_bk
            FROM
            (
                SELECT id_cliente_bk, OperacionCDC,
                       ROW_NUMBER() OVER (PARTITION BY id_cliente_bk ORDER BY StagingID DESC) AS rn
                FROM dbo.stg_clientes
                WHERE id_cliente_bk IS NOT NULL
                  AND StagingID > @DesdeCli AND StagingID <= @HastaCli
            ) x
            WHERE x.rn = 1 AND x.OperacionCDC = 1
        ) d ON d.id_cliente_bk = dc.id_cliente_bk;

        /* -------- DIMENSIÓN EMPLEADO (SCD1) -------- */
        ;WITH EmpleadoCanonico AS
        (
            SELECT *,
                   ROW_NUMBER() OVER
                   (
                       PARTITION BY id_empleado_bk
                       ORDER BY CASE WHEN nombre_completo IS NULL THEN 1 ELSE 0 END,
                                sk_empleado_origen DESC,
                                StagingID DESC
                   ) AS rn
            FROM dbo.stg_empleados
            WHERE id_empleado_bk IS NOT NULL
              AND StagingID > @DesdeEmp AND StagingID <= @HastaEmp
              AND OperacionCDC IN (2, 4)
        )
        MERGE dim.DimEmpleado AS t
        USING
        (
            SELECT
                sk_empleado_origen,
                id_empleado_bk,
                NULLIF(LTRIM(RTRIM(dni)), '') AS dni,
                COALESCE(NULLIF(UPPER(LTRIM(RTRIM(nombre_completo))), ''), 'NO ESPECIFICADO') AS nombre_completo,
                COALESCE(NULLIF(UPPER(LTRIM(RTRIM(cargo))), ''), 'NO ESPECIFICADO') AS cargo,
                COALESCE(NULLIF(UPPER(LTRIM(RTRIM(area))), ''), 'NO ESPECIFICADO') AS area
            FROM EmpleadoCanonico
            WHERE rn = 1
        ) AS s
        ON t.id_empleado_bk = s.id_empleado_bk
        WHEN MATCHED THEN UPDATE SET
            t.sk_empleado_origen = s.sk_empleado_origen,
            t.dni = s.dni,
            t.nombre_completo = s.nombre_completo,
            t.cargo = s.cargo,
            t.area = s.area
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (sk_empleado_origen, id_empleado_bk, dni, nombre_completo, cargo, area)
            VALUES (s.sk_empleado_origen, s.id_empleado_bk, s.dni, s.nombre_completo, s.cargo, s.area);

        /* -------- DIMENSIÓN PLAN (Plan + Operación + Promoción) --------
           Dimensión conformada que absorbe el antiguo DimPromocion. Se puebla
           por combinación distinta de (tipo_plan, tipo_operacion, promocion)
           presente en el lote, antes de cargar los hechos (FK). */
        IF OBJECT_ID('tempdb..#PlanOrigen') IS NOT NULL DROP TABLE #PlanOrigen;
        ;WITH PlanCanonicoOrigen AS
        (
            SELECT
                sk_plan_origen,
                CASE
                    WHEN duracion_dias BETWEEN 1 AND 7     THEN 'POR_UN_DIA'
                    WHEN duracion_dias BETWEEN 8 AND 45    THEN 'MENSUAL'
                    WHEN duracion_dias BETWEEN 46 AND 135  THEN 'TRIMESTRAL'
                    WHEN duracion_dias BETWEEN 136 AND 270 THEN 'SEMESTRAL'
                    WHEN duracion_dias BETWEEN 271 AND 500 THEN 'ANUAL'
                    WHEN duracion_dias > 500               THEN 'QUINQUENAL'
                    ELSE 'NO_APLICA'
                END AS tipo_plan,
                CASE
                    WHEN UPPER(ISNULL(categoria_duracion, '')) LIKE '%PROMOC%'
                        THEN COALESCE(NULLIF(UPPER(LTRIM(RTRIM(nombre_plan))), ''), 'PROMOCION')
                    ELSE 'SIN PROMOCION'
                END AS promocion,
                ROW_NUMBER() OVER (PARTITION BY sk_plan_origen ORDER BY StagingID DESC) AS rn
            FROM dbo.stg_planes
            WHERE sk_plan_origen IS NOT NULL
        )
        SELECT sk_plan_origen, tipo_plan, promocion
        INTO #PlanOrigen
        FROM PlanCanonicoOrigen
        WHERE rn = 1;

        ;WITH CombosPlan AS
        (
            SELECT DISTINCT ISNULL(tp.tipo_plan, 'NO_APLICA') AS tipo_plan, 'VENTA' AS tipo_operacion, ISNULL(tp.promocion, 'SIN PROMOCION') AS promocion
            FROM dbo.stg_ventas_membresias v
            LEFT JOIN #PlanOrigen tp ON tp.sk_plan_origen = v.sk_plan_origen
            WHERE v.EntidadOrigen = 'VENTA' AND v.StagingID > @DesdeVM AND v.StagingID <= @HastaVM
            UNION
            SELECT DISTINCT ISNULL(tp.tipo_plan, 'NO_APLICA'), 'MEMBRESIA', ISNULL(tp.promocion, 'SIN PROMOCION')
            FROM dbo.stg_ventas_membresias m
            LEFT JOIN #PlanOrigen tp ON tp.sk_plan_origen = m.sk_plan_origen
            WHERE m.EntidadOrigen = 'MEMBRESIA' AND m.StagingID > @DesdeVM AND m.StagingID <= @HastaVM
            UNION
            SELECT DISTINCT ISNULL(tp.tipo_plan, 'NO_APLICA'), 'ASISTENCIA', ISNULL(tp.promocion, 'SIN PROMOCION')
            FROM dbo.stg_entrenamiento a
            LEFT JOIN #PlanOrigen tp ON tp.sk_plan_origen = a.sk_plan_origen
            WHERE a.EntidadOrigen = 'ASISTENCIA' AND a.StagingID > @DesdeEnt AND a.StagingID <= @HastaEnt
            UNION
            SELECT DISTINCT ISNULL(tp.tipo_plan, 'NO_APLICA'), 'SESION', ISNULL(tp.promocion, 'SIN PROMOCION')
            FROM dbo.stg_entrenamiento s
            LEFT JOIN #PlanOrigen tp ON tp.sk_plan_origen = s.sk_plan_origen
            WHERE s.EntidadOrigen = 'SESION_PROGRAMADA' AND s.StagingID > @DesdeEnt AND s.StagingID <= @HastaEnt
        )
        MERGE dim.DimPlan AS t
        USING CombosPlan AS s
        ON  t.tipo_plan = s.tipo_plan
        AND t.tipo_operacion = s.tipo_operacion
        AND t.promocion = s.promocion
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (tipo_plan, tipo_operacion, promocion)
            VALUES (s.tipo_plan, s.tipo_operacion, s.promocion);

        /* -------- Mapas de claves origen -> dimensión (sobre todo el staging) -------- */
        SELECT sk_cliente_origen, MAX(id_cliente_bk) AS id_cliente_bk
        INTO #MapCliente
        FROM dbo.stg_clientes
        WHERE sk_cliente_origen IS NOT NULL AND id_cliente_bk IS NOT NULL
        GROUP BY sk_cliente_origen;

        SELECT sk_empleado_origen, MAX(id_empleado_bk) AS id_empleado_bk
        INTO #MapEmpleado
        FROM dbo.stg_empleados
        WHERE sk_empleado_origen IS NOT NULL AND id_empleado_bk IS NOT NULL
        GROUP BY sk_empleado_origen;

        SELECT sk_fecha_origen, CONVERT(INT, CONVERT(CHAR(8), MIN(fecha), 112)) AS sk_fecha
        INTO #MapFecha
        FROM dbo.stg_fecha
        WHERE sk_fecha_origen IS NOT NULL AND fecha IS NOT NULL
          AND fecha >= '2000-01-01' AND fecha <= '2100-12-31'
        GROUP BY sk_fecha_origen;

        /* -------- CALIDAD: registrar las filas que se descartan --------
           El ETL descarta las filas que no resuelven su dimensión conformada
           (cliente o fecha). Aquí quedan auditables en dq.RegistroRechazos. */
        ;WITH Rechazos AS
        (
            SELECT 'RC-12' AS codigo_regla, 'DimCliente' AS entidad, 'id_cliente_bk' AS campo,
                   c.StagingID AS staging_id, NULL AS bk, NULL AS valor,
                   'Cliente sin clave de negocio (id_cliente_bk NULL)' AS motivo
            FROM dbo.stg_clientes c
            WHERE c.StagingID > @DesdeCli AND c.StagingID <= @HastaCli AND c.id_cliente_bk IS NULL
            UNION ALL
            SELECT 'RC-13', 'DimFecha', 'fecha', f.StagingID, NULL, CAST(f.fecha AS VARCHAR(200)),
                   'Fecha fuera de rango [2000-01-01, 2100-12-31]'
            FROM dbo.stg_fecha f
            WHERE f.StagingID > @DesdeFecha AND f.StagingID <= @HastaFecha
              AND (f.fecha IS NULL OR f.fecha < '2000-01-01' OR f.fecha > '2100-12-31')
            UNION ALL
            SELECT 'RC-14', 'FactVentas', 'sk_cliente', v.StagingID, CAST(v.id_pago_bk AS VARCHAR(40)),
                   CAST(v.sk_cliente_origen AS VARCHAR(200)), 'Venta con sk_cliente inexistente en el origen'
            FROM dbo.stg_ventas_membresias v
            LEFT JOIN #MapCliente mc ON mc.sk_cliente_origen = v.sk_cliente_origen
            WHERE v.EntidadOrigen = 'VENTA' AND v.id_pago_bk IS NOT NULL
              AND v.StagingID > @DesdeVM AND v.StagingID <= @HastaVM AND v.OperacionCDC IN (2, 4)
              AND (v.sk_cliente_origen IS NULL OR mc.id_cliente_bk IS NULL)
            UNION ALL
            SELECT 'RC-15', 'FactVentas', 'sk_fecha_pago', v.StagingID, CAST(v.id_pago_bk AS VARCHAR(40)),
                   CAST(v.sk_fecha_pago_origen AS VARCHAR(200)), 'Venta con sk_fecha_pago fuera de DimFecha'
            FROM dbo.stg_ventas_membresias v
            LEFT JOIN #MapFecha mf ON mf.sk_fecha_origen = v.sk_fecha_pago_origen
            WHERE v.EntidadOrigen = 'VENTA' AND v.id_pago_bk IS NOT NULL
              AND v.StagingID > @DesdeVM AND v.StagingID <= @HastaVM AND v.OperacionCDC IN (2, 4)
              AND mf.sk_fecha IS NULL
            UNION ALL
            SELECT 'RC-16', 'FactMembresias', 'sk_cliente', m.StagingID, CAST(m.id_membresia_bk AS VARCHAR(40)),
                   CAST(m.sk_cliente_origen AS VARCHAR(200)), 'Membresía con sk_cliente inexistente en el origen'
            FROM dbo.stg_ventas_membresias m
            LEFT JOIN #MapCliente mc ON mc.sk_cliente_origen = m.sk_cliente_origen
            WHERE m.EntidadOrigen = 'MEMBRESIA' AND m.id_membresia_bk IS NOT NULL
              AND m.StagingID > @DesdeVM AND m.StagingID <= @HastaVM AND m.OperacionCDC IN (2, 4)
              AND (m.sk_cliente_origen IS NULL OR mc.id_cliente_bk IS NULL)
            UNION ALL
            SELECT 'RC-17', 'FactMembresias', 'sk_fecha_inicio', m.StagingID, CAST(m.id_membresia_bk AS VARCHAR(40)),
                   CAST(m.sk_fecha_inicio_origen AS VARCHAR(200)), 'Membresía con sk_fecha_inicio fuera de DimFecha'
            FROM dbo.stg_ventas_membresias m
            LEFT JOIN #MapFecha mfi ON mfi.sk_fecha_origen = m.sk_fecha_inicio_origen
            WHERE m.EntidadOrigen = 'MEMBRESIA' AND m.id_membresia_bk IS NOT NULL
              AND m.StagingID > @DesdeVM AND m.StagingID <= @HastaVM AND m.OperacionCDC IN (2, 4)
              AND mfi.sk_fecha IS NULL
            UNION ALL
            SELECT 'RC-18', 'FactAsistencias', 'sk_cliente', a.StagingID, CAST(a.id_asistencia_bk AS VARCHAR(40)),
                   CAST(a.sk_cliente_origen AS VARCHAR(200)), 'Asistencia con sk_cliente inexistente en el origen'
            FROM dbo.stg_entrenamiento a
            LEFT JOIN #MapCliente mc ON mc.sk_cliente_origen = a.sk_cliente_origen
            WHERE a.EntidadOrigen = 'ASISTENCIA' AND a.id_asistencia_bk IS NOT NULL
              AND a.StagingID > @DesdeEnt AND a.StagingID <= @HastaEnt AND a.OperacionCDC IN (2, 4)
              AND (a.sk_cliente_origen IS NULL OR mc.id_cliente_bk IS NULL)
            UNION ALL
            SELECT 'RC-19', 'FactAsistencias', 'sk_fecha_asistencia', a.StagingID, CAST(a.id_asistencia_bk AS VARCHAR(40)),
                   CAST(a.sk_fecha_asistencia_origen AS VARCHAR(200)), 'Asistencia con sk_fecha fuera de DimFecha'
            FROM dbo.stg_entrenamiento a
            LEFT JOIN #MapFecha mf ON mf.sk_fecha_origen = a.sk_fecha_asistencia_origen
            WHERE a.EntidadOrigen = 'ASISTENCIA' AND a.id_asistencia_bk IS NOT NULL
              AND a.StagingID > @DesdeEnt AND a.StagingID <= @HastaEnt AND a.OperacionCDC IN (2, 4)
              AND mf.sk_fecha IS NULL
            UNION ALL
            SELECT 'RC-20', 'FactReclamos', 'sk_cliente', r.StagingID, CAST(r.id_reclamo_bk AS VARCHAR(40)),
                   CAST(r.sk_cliente_origen AS VARCHAR(200)), 'Reclamo con sk_cliente inexistente en el origen'
            FROM dbo.stg_atencion_reclamos r
            LEFT JOIN #MapCliente mc ON mc.sk_cliente_origen = r.sk_cliente_origen
            WHERE r.EntidadOrigen = 'RECLAMO' AND r.id_reclamo_bk IS NOT NULL
              AND r.StagingID > @DesdeRec AND r.StagingID <= @HastaRec AND r.OperacionCDC IN (2, 4)
              AND (r.sk_cliente_origen IS NULL OR mc.id_cliente_bk IS NULL)
            UNION ALL
            SELECT 'RC-21', 'FactReclamos', 'sk_fecha_reclamo', r.StagingID, CAST(r.id_reclamo_bk AS VARCHAR(40)),
                   CAST(r.sk_fecha_reclamo_origen AS VARCHAR(200)), 'Reclamo con sk_fecha fuera de DimFecha'
            FROM dbo.stg_atencion_reclamos r
            LEFT JOIN #MapFecha mf ON mf.sk_fecha_origen = r.sk_fecha_reclamo_origen
            WHERE r.EntidadOrigen = 'RECLAMO' AND r.id_reclamo_bk IS NOT NULL
              AND r.StagingID > @DesdeRec AND r.StagingID <= @HastaRec AND r.OperacionCDC IN (2, 4)
              AND mf.sk_fecha IS NULL
            UNION ALL
            SELECT 'RC-22', 'FactRetenciones', 'sk_cliente', rt.StagingID, CAST(rt.id_retencion_bk AS VARCHAR(40)),
                   CAST(rt.sk_cliente_origen AS VARCHAR(200)), 'Retención con sk_cliente inexistente en el origen'
            FROM dbo.stg_atencion_reclamos rt
            LEFT JOIN #MapCliente mc ON mc.sk_cliente_origen = rt.sk_cliente_origen
            WHERE rt.EntidadOrigen = 'RETENCION' AND rt.id_retencion_bk IS NOT NULL
              AND rt.StagingID > @DesdeRec AND rt.StagingID <= @HastaRec AND rt.OperacionCDC IN (2, 4)
              AND (rt.sk_cliente_origen IS NULL OR mc.id_cliente_bk IS NULL)
            UNION ALL
            SELECT 'RC-23', 'FactRetenciones', 'sk_fecha_retencion', rt.StagingID, CAST(rt.id_retencion_bk AS VARCHAR(40)),
                   CAST(rt.sk_fecha_retencion_origen AS VARCHAR(200)), 'Retención con sk_fecha fuera de DimFecha'
            FROM dbo.stg_atencion_reclamos rt
            LEFT JOIN #MapFecha mf ON mf.sk_fecha_origen = rt.sk_fecha_retencion_origen
            WHERE rt.EntidadOrigen = 'RETENCION' AND rt.id_retencion_bk IS NOT NULL
              AND rt.StagingID > @DesdeRec AND rt.StagingID <= @HastaRec AND rt.OperacionCDC IN (2, 4)
              AND mf.sk_fecha IS NULL
        )
        INSERT INTO dq.RegistroRechazos (codigo_regla, entidad, campo, staging_id, bk, valor, motivo)
        SELECT codigo_regla, entidad, campo, staging_id, bk, valor, motivo FROM Rechazos;

        /* -------- HECHO VENTAS -------- */
        ;WITH VentaCanonica AS
        (
            SELECT *,
                   ROW_NUMBER() OVER (PARTITION BY id_pago_bk ORDER BY StagingID DESC) AS rn
            FROM dbo.stg_ventas_membresias
            WHERE EntidadOrigen = 'VENTA' AND id_pago_bk IS NOT NULL
              AND StagingID > @DesdeVM AND StagingID <= @HastaVM
              AND OperacionCDC IN (2, 4)
        )
        MERGE dm_comercial.FactVentas AS t
        USING
        (
            SELECT
                v.id_pago_bk,
                df.sk_fecha AS sk_fecha_pago,
                c.sk_cliente, p.sk_plan, e.sk_empleado,
                v.id_membresia_bk,
                CASE WHEN v.monto_neto IS NULL OR v.monto_neto < 0 THEN 0 ELSE v.monto_neto END AS monto_neto,
                CASE WHEN v.descuento_aplicado >= 0 THEN v.descuento_aplicado END AS descuento_aplicado,
                CASE WHEN v.precio_lista >= 0 THEN v.precio_lista END AS precio_lista,
                CASE
                    WHEN UPPER(LTRIM(RTRIM(v.metodo_pago))) LIKE '%YAPE%' THEN 'YAPE'
                    WHEN UPPER(LTRIM(RTRIM(v.metodo_pago))) LIKE '%PLIN%' THEN 'PLIN'
                    WHEN UPPER(LTRIM(RTRIM(v.metodo_pago))) LIKE '%TRANS%' THEN 'TRANSFERENCIA'
                    WHEN UPPER(LTRIM(RTRIM(v.metodo_pago))) LIKE '%TARJ%' THEN 'TARJETA'
                    WHEN UPPER(LTRIM(RTRIM(v.metodo_pago))) LIKE '%EFECT%' THEN 'EFECTIVO'
                    ELSE 'NO ESPECIFICADO'
                END AS metodo_pago
            FROM VentaCanonica v
            INNER JOIN #MapFecha mf0 ON mf0.sk_fecha_origen = v.sk_fecha_pago_origen
            INNER JOIN dim.DimFecha df ON df.sk_fecha = mf0.sk_fecha
            INNER JOIN #MapCliente mc ON mc.sk_cliente_origen = v.sk_cliente_origen
            INNER JOIN dim.DimCliente c ON c.id_cliente_bk = mc.id_cliente_bk
            LEFT JOIN #PlanOrigen tp ON tp.sk_plan_origen = v.sk_plan_origen
            INNER JOIN dim.DimPlan p ON p.tipo_plan = ISNULL(tp.tipo_plan, 'NO_APLICA')
                                    AND p.tipo_operacion = 'VENTA'
                                    AND p.promocion = ISNULL(tp.promocion, 'SIN PROMOCION')
            LEFT JOIN #MapEmpleado me ON me.sk_empleado_origen = v.sk_empleado_origen
            LEFT JOIN dim.DimEmpleado e ON e.id_empleado_bk = me.id_empleado_bk
            WHERE v.rn = 1
        ) AS s
        ON t.id_pago_bk = s.id_pago_bk
        WHEN MATCHED THEN UPDATE SET
            t.sk_fecha_pago = s.sk_fecha_pago, t.sk_cliente = s.sk_cliente, t.sk_plan = s.sk_plan,
            t.sk_empleado = s.sk_empleado, t.id_membresia_bk = s.id_membresia_bk,
            t.monto_neto = s.monto_neto, t.descuento_aplicado = s.descuento_aplicado,
            t.precio_lista = s.precio_lista, t.metodo_pago = s.metodo_pago
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (id_pago_bk, sk_fecha_pago, sk_cliente, sk_plan, sk_empleado,
                    id_membresia_bk, monto_neto, descuento_aplicado, precio_lista, metodo_pago)
            VALUES (s.id_pago_bk, s.sk_fecha_pago, s.sk_cliente, s.sk_plan, s.sk_empleado,
                    s.id_membresia_bk, s.monto_neto, s.descuento_aplicado, s.precio_lista, s.metodo_pago);

        /* -------- HECHO MEMBRESÍAS -------- */
        ;WITH MembresiaCanonica AS
        (
            SELECT *,
                   ROW_NUMBER() OVER (PARTITION BY id_membresia_bk ORDER BY StagingID DESC) AS rn
            FROM dbo.stg_ventas_membresias
            WHERE EntidadOrigen = 'MEMBRESIA' AND id_membresia_bk IS NOT NULL
              AND StagingID > @DesdeVM AND StagingID <= @HastaVM
              AND OperacionCDC IN (2, 4)
        )
        MERGE dm_comercial.FactMembresias AS t
        USING
        (
            SELECT
                m.id_membresia_bk,
                c.sk_cliente, p.sk_plan, e.sk_empleado,
                di.sk_fecha AS sk_fecha_inicio,
                df.sk_fecha AS sk_fecha_fin,
                CASE WHEN m.duracion_dias > 0 THEN m.duracion_dias END AS duracion_dias,
                CASE WHEN m.precio_final >= 0 THEN m.precio_final END AS precio_final,
                CASE WHEN m.es_renovacion = 1 THEN 1 ELSE 0 END AS es_renovacion,
                CASE
                    WHEN di.fecha <= @FechaCorte AND df.fecha >= @FechaCorte THEN 'ACTIVA'
                    WHEN df.fecha < @FechaCorte THEN 'VENCIDA'
                    WHEN di.fecha > @FechaCorte THEN 'PENDIENTE'
                    ELSE 'DESCONOCIDA'
                END AS estado_membresia,
                CASE WHEN m.dias_anticipacion_renovacion BETWEEN 0 AND 30 THEN m.dias_anticipacion_renovacion END AS dias_anticipacion_renovacion
            FROM MembresiaCanonica m
            INNER JOIN #MapFecha mfi ON mfi.sk_fecha_origen = m.sk_fecha_inicio_origen
            INNER JOIN dim.DimFecha di ON di.sk_fecha = mfi.sk_fecha
            INNER JOIN #MapFecha mff ON mff.sk_fecha_origen = m.sk_fecha_fin_origen
            INNER JOIN dim.DimFecha df ON df.sk_fecha = mff.sk_fecha
            INNER JOIN #MapCliente mc ON mc.sk_cliente_origen = m.sk_cliente_origen
            INNER JOIN dim.DimCliente c ON c.id_cliente_bk = mc.id_cliente_bk
            LEFT JOIN #PlanOrigen tp ON tp.sk_plan_origen = m.sk_plan_origen
            INNER JOIN dim.DimPlan p ON p.tipo_plan = ISNULL(tp.tipo_plan, 'NO_APLICA')
                                    AND p.tipo_operacion = 'MEMBRESIA'
                                    AND p.promocion = ISNULL(tp.promocion, 'SIN PROMOCION')
            LEFT JOIN #MapEmpleado me ON me.sk_empleado_origen = m.sk_empleado_origen
            LEFT JOIN dim.DimEmpleado e ON e.id_empleado_bk = me.id_empleado_bk
            WHERE m.rn = 1
        ) AS s
        ON t.id_membresia_bk = s.id_membresia_bk
        WHEN MATCHED THEN UPDATE SET
            t.sk_cliente = s.sk_cliente, t.sk_plan = s.sk_plan,
            t.sk_empleado = s.sk_empleado, t.sk_fecha_inicio = s.sk_fecha_inicio, t.sk_fecha_fin = s.sk_fecha_fin,
            t.duracion_dias = s.duracion_dias, t.precio_final = s.precio_final, t.es_renovacion = s.es_renovacion,
            t.estado_membresia = s.estado_membresia, t.dias_anticipacion_renovacion = s.dias_anticipacion_renovacion
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (id_membresia_bk, sk_cliente, sk_plan, sk_empleado, sk_fecha_inicio, sk_fecha_fin,
                    duracion_dias, precio_final, es_renovacion, estado_membresia, dias_anticipacion_renovacion)
            VALUES (s.id_membresia_bk, s.sk_cliente, s.sk_plan, s.sk_empleado, s.sk_fecha_inicio, s.sk_fecha_fin,
                    s.duracion_dias, s.precio_final, s.es_renovacion, s.estado_membresia, s.dias_anticipacion_renovacion);

        /* -------- HECHO RENOVACIONES -------- */
        ;WITH RenovacionCanonica AS
        (
            SELECT *,
                   ROW_NUMBER() OVER (PARTITION BY id_renovacion_bk ORDER BY StagingID DESC) AS rn
            FROM dbo.stg_ventas_membresias
            WHERE EntidadOrigen = 'RENOVACION' AND id_renovacion_bk IS NOT NULL
              AND StagingID > @DesdeVM AND StagingID <= @HastaVM
              AND OperacionCDC IN (2, 4)
        )
        MERGE dm_comercial.FactRenovaciones AS t
        USING
        (
            SELECT
                r.id_renovacion_bk,
                mf.sk_fecha AS sk_fecha_renovacion,
                c.sk_cliente, e.sk_empleado,
                r.id_membresia_anterior_bk, r.id_membresia_nueva_bk,
                CASE WHEN r.dias_anticipacion BETWEEN 0 AND 30 THEN r.dias_anticipacion END AS dias_anticipacion,
                CASE WHEN r.monto_renovacion > 0 THEN r.monto_renovacion END AS monto
            FROM RenovacionCanonica r
            INNER JOIN #MapFecha mf0 ON mf0.sk_fecha_origen = r.sk_fecha_renovacion_origen
            INNER JOIN dim.DimFecha mf ON mf.sk_fecha = mf0.sk_fecha
            INNER JOIN #MapCliente mc ON mc.sk_cliente_origen = r.sk_cliente_origen
            INNER JOIN dim.DimCliente c ON c.id_cliente_bk = mc.id_cliente_bk
            LEFT JOIN #MapEmpleado me ON me.sk_empleado_origen = r.sk_empleado_origen
            LEFT JOIN dim.DimEmpleado e ON e.id_empleado_bk = me.id_empleado_bk
            WHERE r.rn = 1
        ) AS s
        ON t.id_renovacion_bk = s.id_renovacion_bk
        WHEN MATCHED THEN UPDATE SET
            t.sk_fecha_renovacion = s.sk_fecha_renovacion, t.sk_cliente = s.sk_cliente, t.sk_empleado = s.sk_empleado,
            t.id_membresia_anterior_bk = s.id_membresia_anterior_bk, t.id_membresia_nueva_bk = s.id_membresia_nueva_bk,
            t.dias_anticipacion = s.dias_anticipacion, t.monto = s.monto
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (id_renovacion_bk, sk_fecha_renovacion, sk_cliente, sk_empleado,
                    id_membresia_anterior_bk, id_membresia_nueva_bk, dias_anticipacion, monto)
            VALUES (s.id_renovacion_bk, s.sk_fecha_renovacion, s.sk_cliente, s.sk_empleado,
                    s.id_membresia_anterior_bk, s.id_membresia_nueva_bk, s.dias_anticipacion, s.monto);

        /* -------- HECHO AVISOS -------- */
        ;WITH AvisoCanonico AS
        (
            SELECT *,
                   ROW_NUMBER() OVER (PARTITION BY id_aviso_bk ORDER BY StagingID DESC) AS rn
            FROM dbo.stg_ventas_membresias
            WHERE EntidadOrigen = 'AVISO' AND id_aviso_bk IS NOT NULL
              AND StagingID > @DesdeVM AND StagingID <= @HastaVM
              AND OperacionCDC IN (2, 4)
        )
        MERGE dm_comercial.FactAvisos AS t
        USING
        (
            SELECT
                a.id_aviso_bk,
                mf.sk_fecha AS sk_fecha_aviso,
                c.sk_cliente, e.sk_empleado,
                a.id_membresia_bk,
                CASE WHEN a.dias_antes_vencimiento BETWEEN 1 AND 30 THEN a.dias_antes_vencimiento END AS dias_antes_vencimiento,
                CASE
                    WHEN UPPER(LTRIM(RTRIM(a.medio_aviso))) LIKE '%WHATS%' THEN 'WHATSAPP'
                    WHEN UPPER(LTRIM(RTRIM(a.medio_aviso))) LIKE '%CORRE%' OR UPPER(LTRIM(RTRIM(a.medio_aviso))) LIKE '%EMAIL%' THEN 'CORREO'
                    WHEN UPPER(LTRIM(RTRIM(a.medio_aviso))) LIKE '%SMS%' THEN 'SMS'
                    ELSE 'NO ESPECIFICADO'
                END AS medio,
                CASE
                    WHEN UPPER(LTRIM(RTRIM(a.estado_aviso))) LIKE '%ENV%' OR UPPER(LTRIM(RTRIM(a.estado_aviso))) = 'OK' THEN 'ENVIADO'
                    ELSE 'NO CONFIRMADO'
                END AS estado
            FROM AvisoCanonico a
            INNER JOIN #MapFecha mf0 ON mf0.sk_fecha_origen = a.sk_fecha_aviso_origen
            INNER JOIN dim.DimFecha mf ON mf.sk_fecha = mf0.sk_fecha
            INNER JOIN #MapCliente mc ON mc.sk_cliente_origen = a.sk_cliente_origen
            INNER JOIN dim.DimCliente c ON c.id_cliente_bk = mc.id_cliente_bk
            LEFT JOIN #MapEmpleado me ON me.sk_empleado_origen = a.sk_empleado_origen
            LEFT JOIN dim.DimEmpleado e ON e.id_empleado_bk = me.id_empleado_bk
            WHERE a.rn = 1
        ) AS s
        ON t.id_aviso_bk = s.id_aviso_bk
        WHEN MATCHED THEN UPDATE SET
            t.sk_fecha_aviso = s.sk_fecha_aviso, t.sk_cliente = s.sk_cliente, t.sk_empleado = s.sk_empleado,
            t.id_membresia_bk = s.id_membresia_bk, t.dias_antes_vencimiento = s.dias_antes_vencimiento,
            t.medio = s.medio, t.estado = s.estado
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (id_aviso_bk, sk_fecha_aviso, sk_cliente, sk_empleado, id_membresia_bk,
                    dias_antes_vencimiento, medio, estado)
            VALUES (s.id_aviso_bk, s.sk_fecha_aviso, s.sk_cliente, s.sk_empleado, s.id_membresia_bk,
                    s.dias_antes_vencimiento, s.medio, s.estado);

        /* -------- HECHO ASISTENCIAS -------- */
        ;WITH AsistenciaCanonica AS
        (
            SELECT *,
                   ROW_NUMBER() OVER (PARTITION BY id_asistencia_bk ORDER BY StagingID DESC) AS rn
            FROM dbo.stg_entrenamiento
            WHERE EntidadOrigen = 'ASISTENCIA' AND id_asistencia_bk IS NOT NULL
              AND StagingID > @DesdeEnt AND StagingID <= @HastaEnt
              AND OperacionCDC IN (2, 4)
        )
        MERGE dm_entrenamiento.FactAsistencias AS t
        USING
        (
            SELECT
                a.id_asistencia_bk,
                mf.sk_fecha AS sk_fecha_asistencia,
                c.sk_cliente, p.sk_plan, e.sk_empleado,
                CASE WHEN a.hora_ingreso BETWEEN 5 AND 23 THEN a.hora_ingreso END AS hora_ingreso,
                CASE WHEN ISNULL(a.cantidad_asistencias, 0) > 0 THEN 1 ELSE 0 END AS cantidad_asistencias
            FROM AsistenciaCanonica a
            INNER JOIN #MapFecha mf0 ON mf0.sk_fecha_origen = a.sk_fecha_asistencia_origen
            INNER JOIN dim.DimFecha mf ON mf.sk_fecha = mf0.sk_fecha
            INNER JOIN #MapCliente mc ON mc.sk_cliente_origen = a.sk_cliente_origen
            INNER JOIN dim.DimCliente c ON c.id_cliente_bk = mc.id_cliente_bk
            LEFT JOIN #PlanOrigen tp ON tp.sk_plan_origen = a.sk_plan_origen
            LEFT JOIN dim.DimPlan p ON a.sk_plan_origen IS NOT NULL
                                   AND p.tipo_plan = ISNULL(tp.tipo_plan, 'NO_APLICA')
                                   AND p.tipo_operacion = 'ASISTENCIA'
                                   AND p.promocion = ISNULL(tp.promocion, 'SIN PROMOCION')
            LEFT JOIN #MapEmpleado me ON me.sk_empleado_origen = a.sk_empleado_origen
            LEFT JOIN dim.DimEmpleado e ON e.id_empleado_bk = me.id_empleado_bk
            WHERE a.rn = 1
        ) AS s
        ON t.id_asistencia_bk = s.id_asistencia_bk
        WHEN MATCHED THEN UPDATE SET
            t.sk_fecha_asistencia = s.sk_fecha_asistencia, t.sk_cliente = s.sk_cliente, t.sk_plan = s.sk_plan,
            t.sk_empleado = s.sk_empleado, t.hora_ingreso = s.hora_ingreso, t.cantidad_asistencias = s.cantidad_asistencias
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (id_asistencia_bk, sk_fecha_asistencia, sk_cliente, sk_plan, sk_empleado, hora_ingreso, cantidad_asistencias)
            VALUES (s.id_asistencia_bk, s.sk_fecha_asistencia, s.sk_cliente, s.sk_plan, s.sk_empleado, s.hora_ingreso, s.cantidad_asistencias);

        /* -------- HECHO OBJETIVOS -------- */
        ;WITH ObjetivoCanonico AS
        (
            SELECT *,
                   ROW_NUMBER() OVER (PARTITION BY id_objetivo_bk ORDER BY StagingID DESC) AS rn
            FROM dbo.stg_entrenamiento
            WHERE EntidadOrigen = 'OBJETIVO' AND id_objetivo_bk IS NOT NULL
              AND StagingID > @DesdeEnt AND StagingID <= @HastaEnt
              AND OperacionCDC IN (2, 4)
        )
        MERGE dm_entrenamiento.FactObjetivos AS t
        USING
        (
            SELECT
                o.id_objetivo_bk,
                mf.sk_fecha AS sk_fecha_inicio,
                c.sk_cliente,
                CASE
                    WHEN UPPER(REPLACE(REPLACE(LTRIM(RTRIM(o.tipo_objetivo)), ' ', '_'), 'DE_', '')) LIKE 'AUMENTO%MASA%' THEN 'AUMENTO_MASA'
                    WHEN UPPER(REPLACE(REPLACE(LTRIM(RTRIM(o.tipo_objetivo)), ' ', '_'), 'DE_', '')) LIKE 'REDUCCION%GRASA%' THEN 'REDUCCION_GRASA'
                    ELSE COALESCE(NULLIF(UPPER(LTRIM(RTRIM(o.tipo_objetivo))), ''), 'NO ESPECIFICADO')
                END AS tipo_objetivo,
                CASE WHEN o.valor_inicial > 0 AND o.valor_inicial < 500 THEN o.valor_inicial END AS valor_inicial,
                CASE
                    WHEN o.valor_inicial > 0 AND o.valor_inicial < 500
                     AND o.valor_objetivo > 0 AND o.valor_objetivo < 500
                     AND (
                         (UPPER(o.tipo_objetivo) LIKE '%AUMENTO%' AND o.valor_objetivo >= o.valor_inicial)
                         OR (UPPER(o.tipo_objetivo) LIKE '%REDUCCION%' AND o.valor_objetivo <= o.valor_inicial)
                         OR (UPPER(o.tipo_objetivo) NOT LIKE '%AUMENTO%' AND UPPER(o.tipo_objetivo) NOT LIKE '%REDUCCION%')
                     )
                    THEN o.valor_objetivo
                END AS valor_objetivo,
                CASE
                    WHEN UPPER(LTRIM(RTRIM(o.unidad_medida))) LIKE 'KG%' THEN 'KG'
                    WHEN UPPER(LTRIM(RTRIM(o.unidad_medida))) LIKE 'CM%' THEN 'CM'
                    ELSE 'NO ESPECIFICADA'
                END AS unidad_medida,
                CASE
                    WHEN UPPER(LTRIM(RTRIM(o.estado_objetivo))) LIKE 'CUMPL%' THEN 'CUMPLIDO'
                    WHEN UPPER(LTRIM(RTRIM(o.estado_objetivo))) LIKE 'ACT%' THEN 'ACTIVO'
                    WHEN UPPER(LTRIM(RTRIM(o.estado_objetivo))) LIKE 'CANCEL%' THEN 'CANCELADO'
                    ELSE 'NO ESPECIFICADO'
                END AS estado
            FROM ObjetivoCanonico o
            INNER JOIN #MapFecha mf0 ON mf0.sk_fecha_origen = o.sk_fecha_inicio_origen
            INNER JOIN dim.DimFecha mf ON mf.sk_fecha = mf0.sk_fecha
            INNER JOIN #MapCliente mc ON mc.sk_cliente_origen = o.sk_cliente_origen
            INNER JOIN dim.DimCliente c ON c.id_cliente_bk = mc.id_cliente_bk
            WHERE o.rn = 1
        ) AS s
        ON t.id_objetivo_bk = s.id_objetivo_bk
        WHEN MATCHED THEN UPDATE SET
            t.sk_fecha_inicio = s.sk_fecha_inicio, t.sk_cliente = s.sk_cliente, t.tipo_objetivo = s.tipo_objetivo,
            t.valor_inicial = s.valor_inicial, t.valor_objetivo = s.valor_objetivo, t.unidad_medida = s.unidad_medida, t.estado = s.estado
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (id_objetivo_bk, sk_fecha_inicio, sk_cliente, tipo_objetivo, valor_inicial, valor_objetivo, unidad_medida, estado)
            VALUES (s.id_objetivo_bk, s.sk_fecha_inicio, s.sk_cliente, s.tipo_objetivo, s.valor_inicial, s.valor_objetivo, s.unidad_medida, s.estado);

        /* -------- HECHO EVALUACIONES -------- */
        ;WITH EvaluacionCanonica AS
        (
            SELECT *,
                   ROW_NUMBER() OVER (PARTITION BY id_evaluacion_bk ORDER BY StagingID DESC) AS rn
            FROM dbo.stg_entrenamiento
            WHERE EntidadOrigen = 'EVALUACION' AND id_evaluacion_bk IS NOT NULL
              AND StagingID > @DesdeEnt AND StagingID <= @HastaEnt
              AND OperacionCDC IN (2, 4)
        )
        MERGE dm_entrenamiento.FactEvaluaciones AS t
        USING
        (
            SELECT
                ev.id_evaluacion_bk,
                mf.sk_fecha AS sk_fecha_evaluacion,
                c.sk_cliente, e.sk_empleado, ev.id_objetivo_bk,
                CASE
                    WHEN ev.peso BETWEEN 20 AND 200 THEN ev.peso
                    WHEN ev.peso BETWEEN 200 AND 300 THEN ev.peso / 2.2
                END AS peso,
                CASE
                    WHEN ev.altura BETWEEN 0.5 AND 2.5 THEN ev.altura
                    WHEN ev.altura BETWEEN 100 AND 250 THEN ev.altura / 100.0
                END AS altura,
                CASE WHEN ev.grasa_corporal BETWEEN 0 AND 100 THEN ev.grasa_corporal END AS grasa_corporal,
                CASE WHEN ev.masa_muscular > 0 AND ev.masa_muscular <= ISNULL(ev.peso, ev.masa_muscular) THEN ev.masa_muscular END AS masa_muscular
            FROM EvaluacionCanonica ev
            INNER JOIN #MapFecha mf0 ON mf0.sk_fecha_origen = ev.sk_fecha_evaluacion_origen
            INNER JOIN dim.DimFecha mf ON mf.sk_fecha = mf0.sk_fecha
            INNER JOIN #MapCliente mc ON mc.sk_cliente_origen = ev.sk_cliente_origen
            INNER JOIN dim.DimCliente c ON c.id_cliente_bk = mc.id_cliente_bk
            LEFT JOIN #MapEmpleado me ON me.sk_empleado_origen = ev.sk_empleado_origen
            LEFT JOIN dim.DimEmpleado e ON e.id_empleado_bk = me.id_empleado_bk
            WHERE ev.rn = 1
        ) AS s
        ON t.id_evaluacion_bk = s.id_evaluacion_bk
        WHEN MATCHED THEN UPDATE SET
            t.sk_fecha_evaluacion = s.sk_fecha_evaluacion, t.sk_cliente = s.sk_cliente, t.sk_empleado = s.sk_empleado,
            t.id_objetivo_bk = s.id_objetivo_bk, t.peso = s.peso, t.altura = s.altura,
            t.grasa_corporal = s.grasa_corporal, t.masa_muscular = s.masa_muscular
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (id_evaluacion_bk, sk_fecha_evaluacion, sk_cliente, sk_empleado, id_objetivo_bk,
                    peso, altura, grasa_corporal, masa_muscular)
            VALUES (s.id_evaluacion_bk, s.sk_fecha_evaluacion, s.sk_cliente, s.sk_empleado, s.id_objetivo_bk,
                    s.peso, s.altura, s.grasa_corporal, s.masa_muscular);

        /* -------- HECHO RECLAMOS -------- */
        ;WITH ReclamoCanonico AS
        (
            SELECT *,
                   ROW_NUMBER() OVER (PARTITION BY id_reclamo_bk ORDER BY StagingID DESC) AS rn
            FROM dbo.stg_atencion_reclamos
            WHERE EntidadOrigen = 'RECLAMO' AND id_reclamo_bk IS NOT NULL
              AND StagingID > @DesdeRec AND StagingID <= @HastaRec
              AND OperacionCDC IN (2, 4)
        )
        MERGE dm_atencion.FactReclamos AS t
        USING
        (
            SELECT
                r.id_reclamo_bk,
                df.sk_fecha AS sk_fecha_reclamo,
                c.sk_cliente, e.sk_empleado,
                CASE
                    WHEN UPPER(LTRIM(RTRIM(r.categoria))) LIKE '%COBR%' THEN 'COBRO'
                    WHEN UPPER(LTRIM(RTRIM(r.categoria))) LIKE '%SERV%' THEN 'SERVICIO'
                    ELSE COALESCE(NULLIF(UPPER(LTRIM(RTRIM(r.categoria))), ''), 'NO ESPECIFICADA')
                END AS categoria,
                CASE
                    WHEN UPPER(LTRIM(RTRIM(r.estado))) LIKE '%RESUEL%' OR UPPER(LTRIM(RTRIM(r.estado))) LIKE '%CERR%' THEN 'RESUELTO'
                    WHEN UPPER(LTRIM(RTRIM(r.estado))) LIKE '%PEND%' THEN 'PENDIENTE'
                    ELSE 'NO ESPECIFICADO'
                END AS estado,
                CASE WHEN r.fecha_resolucion >= df.fecha THEN r.fecha_resolucion END AS fecha_resolucion,
                CASE WHEN r.fecha_resolucion >= df.fecha THEN DATEDIFF(DAY, df.fecha, r.fecha_resolucion) END AS dias_resolucion,
                CASE
                    WHEN (UPPER(LTRIM(RTRIM(r.estado))) LIKE '%RESUEL%' OR UPPER(LTRIM(RTRIM(r.estado))) LIKE '%CERR%')
                         AND r.resuelto_en_mostrador = 1 THEN 1
                    WHEN UPPER(LTRIM(RTRIM(r.estado))) LIKE '%RESUEL%' OR UPPER(LTRIM(RTRIM(r.estado))) LIKE '%CERR%' THEN 0
                    ELSE NULL
                END AS resuelto_en_mostrador
            FROM ReclamoCanonico r
            INNER JOIN #MapFecha mf0 ON mf0.sk_fecha_origen = r.sk_fecha_reclamo_origen
            INNER JOIN dim.DimFecha df ON df.sk_fecha = mf0.sk_fecha
            INNER JOIN #MapCliente mc ON mc.sk_cliente_origen = r.sk_cliente_origen
            INNER JOIN dim.DimCliente c ON c.id_cliente_bk = mc.id_cliente_bk
            LEFT JOIN #MapEmpleado me ON me.sk_empleado_origen = r.sk_empleado_origen
            LEFT JOIN dim.DimEmpleado e ON e.id_empleado_bk = me.id_empleado_bk
            WHERE r.rn = 1
        ) AS s
        ON t.id_reclamo_bk = s.id_reclamo_bk
        WHEN MATCHED THEN UPDATE SET
            t.sk_fecha_reclamo = s.sk_fecha_reclamo, t.sk_cliente = s.sk_cliente, t.sk_empleado = s.sk_empleado,
            t.categoria = s.categoria, t.estado = s.estado, t.fecha_resolucion = s.fecha_resolucion,
            t.dias_resolucion = s.dias_resolucion, t.resuelto_en_mostrador = s.resuelto_en_mostrador
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (id_reclamo_bk, sk_fecha_reclamo, sk_cliente, sk_empleado, categoria, estado, fecha_resolucion, dias_resolucion, resuelto_en_mostrador)
            VALUES (s.id_reclamo_bk, s.sk_fecha_reclamo, s.sk_cliente, s.sk_empleado, s.categoria, s.estado, s.fecha_resolucion, s.dias_resolucion, s.resuelto_en_mostrador);

        /* -------- HECHO SESIONES PROGRAMADAS -------- */
        ;WITH SesionProgramadaCanonica AS
        (
            SELECT *,
                   ROW_NUMBER() OVER (PARTITION BY id_sesion_bk ORDER BY StagingID DESC) AS rn
            FROM dbo.stg_entrenamiento
            WHERE EntidadOrigen = 'SESION_PROGRAMADA' AND id_sesion_bk IS NOT NULL
              AND StagingID > @DesdeEnt AND StagingID <= @HastaEnt
              AND OperacionCDC IN (2, 4)
        )
        MERGE dm_entrenamiento.FactSesionesProgramadas AS t
        USING
        (
            SELECT
                s.id_sesion_bk,
                mf.sk_fecha AS sk_fecha_programada,
                c.sk_cliente, p.sk_plan, e.sk_empleado,
                CASE
                    WHEN UPPER(LTRIM(RTRIM(s.tipo_sesion))) LIKE 'ENTREN%' THEN 'ENTRENAMIENTO'
                    WHEN UPPER(LTRIM(RTRIM(s.tipo_sesion))) LIKE 'CLASE%' THEN 'CLASE_GRUPAL'
                    WHEN UPPER(LTRIM(RTRIM(s.tipo_sesion))) LIKE 'EVAL%' THEN 'EVALUACION'
                    ELSE 'NO ESPECIFICADO'
                END AS tipo_sesion,
                CASE WHEN s.hora_programada BETWEEN 5 AND 23 THEN s.hora_programada END AS hora_programada,
                CASE
                    WHEN UPPER(LTRIM(RTRIM(s.estado_sesion))) LIKE 'ASIST%' THEN 'ASISTIDA'
                    WHEN UPPER(LTRIM(RTRIM(s.estado_sesion))) LIKE 'AUSENT%' THEN 'AUSENTE'
                    WHEN UPPER(LTRIM(RTRIM(s.estado_sesion))) LIKE 'CANCEL%' THEN 'CANCELADA'
                    ELSE 'PROGRAMADA'
                END AS estado_sesion,
                CASE WHEN s.duracion_minutos BETWEEN 1 AND 480 THEN s.duracion_minutos END AS duracion_minutos
            FROM SesionProgramadaCanonica s
            INNER JOIN #MapFecha mf0 ON mf0.sk_fecha_origen = s.sk_fecha_programada_origen
            INNER JOIN dim.DimFecha mf ON mf.sk_fecha = mf0.sk_fecha
            INNER JOIN #MapCliente mc ON mc.sk_cliente_origen = s.sk_cliente_origen
            INNER JOIN dim.DimCliente c ON c.id_cliente_bk = mc.id_cliente_bk
            LEFT JOIN #PlanOrigen tp ON tp.sk_plan_origen = s.sk_plan_origen
            LEFT JOIN dim.DimPlan p ON s.sk_plan_origen IS NOT NULL
                                   AND p.tipo_plan = ISNULL(tp.tipo_plan, 'NO_APLICA')
                                   AND p.tipo_operacion = 'SESION'
                                   AND p.promocion = ISNULL(tp.promocion, 'SIN PROMOCION')
            LEFT JOIN #MapEmpleado me ON me.sk_empleado_origen = s.sk_empleado_origen
            LEFT JOIN dim.DimEmpleado e ON e.id_empleado_bk = me.id_empleado_bk
            WHERE s.rn = 1
        ) AS s
        ON t.id_sesion_bk = s.id_sesion_bk
        WHEN MATCHED THEN UPDATE SET
            t.sk_fecha_programada = s.sk_fecha_programada, t.sk_cliente = s.sk_cliente, t.sk_plan = s.sk_plan,
            t.sk_empleado = s.sk_empleado, t.tipo_sesion = s.tipo_sesion, t.hora_programada = s.hora_programada,
            t.estado_sesion = s.estado_sesion, t.duracion_minutos = s.duracion_minutos
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (id_sesion_bk, sk_fecha_programada, sk_cliente, sk_plan, sk_empleado,
                    tipo_sesion, hora_programada, estado_sesion, duracion_minutos)
            VALUES (s.id_sesion_bk, s.sk_fecha_programada, s.sk_cliente, s.sk_plan, s.sk_empleado,
                    s.tipo_sesion, s.hora_programada, s.estado_sesion, s.duracion_minutos);

        /* -------- HECHO EVALUACIONES PROGRAMADAS -------- */
        ;WITH EvaluacionProgramadaCanonica AS
        (
            SELECT *,
                   ROW_NUMBER() OVER (PARTITION BY id_evaluacion_programada_bk ORDER BY StagingID DESC) AS rn
            FROM dbo.stg_entrenamiento
            WHERE EntidadOrigen = 'EVALUACION_PROGRAMADA' AND id_evaluacion_programada_bk IS NOT NULL
              AND StagingID > @DesdeEnt AND StagingID <= @HastaEnt
              AND OperacionCDC IN (2, 4)
        )
        MERGE dm_entrenamiento.FactEvaluacionesProgramadas AS t
        USING
        (
            SELECT
                ep.id_evaluacion_programada_bk,
                mf.sk_fecha AS sk_fecha_programada,
                c.sk_cliente, e.sk_empleado,
                CASE WHEN o.id_objetivo_bk IS NOT NULL THEN ep.id_objetivo_bk END AS id_objetivo_bk,
                CASE
                    WHEN UPPER(LTRIM(RTRIM(ep.tipo_evaluacion))) LIKE 'FIS%' THEN 'FISICA'
                    WHEN UPPER(LTRIM(RTRIM(ep.tipo_evaluacion))) LIKE 'MEDIC%' THEN 'MEDICION'
                    WHEN UPPER(LTRIM(RTRIM(ep.tipo_evaluacion))) LIKE 'SEGUIM%' THEN 'SEGUIMIENTO'
                    ELSE 'NO ESPECIFICADA'
                END AS tipo_evaluacion,
                CASE
                    WHEN UPPER(LTRIM(RTRIM(ep.estado_evaluacion))) LIKE 'COMPLET%' THEN 'COMPLETADA'
                    WHEN UPPER(LTRIM(RTRIM(ep.estado_evaluacion))) LIKE 'PENDIENT%' THEN 'PENDIENTE'
                    WHEN UPPER(LTRIM(RTRIM(ep.estado_evaluacion))) LIKE 'CANCEL%' THEN 'CANCELADA'
                    ELSE 'PROGRAMADA'
                END AS estado_evaluacion,
                CASE WHEN ev.id_evaluacion_bk IS NOT NULL THEN ep.id_evaluacion_bk END AS id_evaluacion_bk
            FROM EvaluacionProgramadaCanonica ep
            INNER JOIN #MapFecha mf0 ON mf0.sk_fecha_origen = ep.sk_fecha_programada_origen
            INNER JOIN dim.DimFecha mf ON mf.sk_fecha = mf0.sk_fecha
            INNER JOIN #MapCliente mc ON mc.sk_cliente_origen = ep.sk_cliente_origen
            INNER JOIN dim.DimCliente c ON c.id_cliente_bk = mc.id_cliente_bk
            LEFT JOIN #MapEmpleado me ON me.sk_empleado_origen = ep.sk_empleado_origen
            LEFT JOIN dim.DimEmpleado e ON e.id_empleado_bk = me.id_empleado_bk
            LEFT JOIN dm_entrenamiento.FactObjetivos o ON o.id_objetivo_bk = ep.id_objetivo_bk
            LEFT JOIN dm_entrenamiento.FactEvaluaciones ev ON ev.id_evaluacion_bk = ep.id_evaluacion_bk
            WHERE ep.rn = 1
        ) AS s
        ON t.id_evaluacion_programada_bk = s.id_evaluacion_programada_bk
        WHEN MATCHED THEN UPDATE SET
            t.sk_fecha_programada = s.sk_fecha_programada, t.sk_cliente = s.sk_cliente, t.sk_empleado = s.sk_empleado,
            t.id_objetivo_bk = s.id_objetivo_bk, t.tipo_evaluacion = s.tipo_evaluacion,
            t.estado_evaluacion = s.estado_evaluacion, t.id_evaluacion_bk = s.id_evaluacion_bk
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (id_evaluacion_programada_bk, sk_fecha_programada, sk_cliente, sk_empleado,
                    id_objetivo_bk, tipo_evaluacion, estado_evaluacion, id_evaluacion_bk)
            VALUES (s.id_evaluacion_programada_bk, s.sk_fecha_programada, s.sk_cliente, s.sk_empleado,
                    s.id_objetivo_bk, s.tipo_evaluacion, s.estado_evaluacion, s.id_evaluacion_bk);

        /* -------- HECHO RETENCIONES -------- */
        ;WITH RetencionCanonica AS
        (
            SELECT *,
                   ROW_NUMBER() OVER (PARTITION BY id_retencion_bk ORDER BY StagingID DESC) AS rn
            FROM dbo.stg_atencion_reclamos
            WHERE EntidadOrigen = 'RETENCION' AND id_retencion_bk IS NOT NULL
              AND StagingID > @DesdeRec AND StagingID <= @HastaRec
              AND OperacionCDC IN (2, 4)
        )
        MERGE dm_atencion.FactRetenciones AS t
        USING
        (
            SELECT
                r.id_retencion_bk,
                mf.sk_fecha AS sk_fecha_retencion,
                c.sk_cliente, e.sk_empleado,
                r.id_membresia_bk,
                CASE
                    WHEN UPPER(LTRIM(RTRIM(r.canal))) LIKE '%MOSTRADOR%' THEN 'MOSTRADOR'
                    WHEN UPPER(LTRIM(RTRIM(r.canal))) LIKE '%LLAMADA%' OR UPPER(LTRIM(RTRIM(r.canal))) LIKE '%CALL%' THEN 'LLAMADA'
                    WHEN UPPER(LTRIM(RTRIM(r.canal))) LIKE '%WHATS%' OR UPPER(LTRIM(RTRIM(r.canal))) LIKE '%WSP%' THEN 'WHATSAPP'
                    WHEN UPPER(LTRIM(RTRIM(r.canal))) LIKE '%CORRE%' OR UPPER(LTRIM(RTRIM(r.canal))) LIKE '%EMAIL%' THEN 'CORREO'
                    ELSE 'NO ESPECIFICADO'
                END AS canal,
                CASE
                    WHEN UPPER(LTRIM(RTRIM(r.motivo))) LIKE '%VENC%' THEN 'VENCIMIENTO'
                    WHEN UPPER(LTRIM(RTRIM(r.motivo))) LIKE '%PRECIO%' THEN 'PRECIO'
                    WHEN UPPER(LTRIM(RTRIM(r.motivo))) LIKE '%INSATISF%' THEN 'INSATISFACCION'
                    WHEN UPPER(LTRIM(RTRIM(r.motivo))) LIKE '%MUDANZ%' THEN 'MUDANZA'
                    ELSE 'NO ESPECIFICADO'
                END AS motivo,
                CASE
                    WHEN UPPER(LTRIM(RTRIM(r.resultado))) LIKE 'NO%RETEN%' THEN 'NO_RETENIDO'
                    WHEN UPPER(LTRIM(RTRIM(r.resultado))) LIKE '%RETEN%' THEN 'RETENIDO'
                    ELSE 'NO ESPECIFICADO'
                END AS resultado,
                CASE WHEN r.monto_oferta > 0 THEN r.monto_oferta END AS monto_oferta
            FROM RetencionCanonica r
            INNER JOIN #MapFecha mf0 ON mf0.sk_fecha_origen = r.sk_fecha_retencion_origen
            INNER JOIN dim.DimFecha mf ON mf.sk_fecha = mf0.sk_fecha
            INNER JOIN #MapCliente mc ON mc.sk_cliente_origen = r.sk_cliente_origen
            INNER JOIN dim.DimCliente c ON c.id_cliente_bk = mc.id_cliente_bk
            LEFT JOIN #MapEmpleado me ON me.sk_empleado_origen = r.sk_empleado_origen
            LEFT JOIN dim.DimEmpleado e ON e.id_empleado_bk = me.id_empleado_bk
            WHERE r.rn = 1
        ) AS s
        ON t.id_retencion_bk = s.id_retencion_bk
        WHEN MATCHED THEN UPDATE SET
            t.sk_fecha_retencion = s.sk_fecha_retencion, t.sk_cliente = s.sk_cliente, t.sk_empleado = s.sk_empleado,
            t.id_membresia_bk = s.id_membresia_bk, t.canal = s.canal, t.motivo = s.motivo,
            t.resultado = s.resultado, t.monto_oferta = s.monto_oferta
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (id_retencion_bk, sk_fecha_retencion, sk_cliente, sk_empleado, id_membresia_bk,
                    canal, motivo, resultado, monto_oferta)
            VALUES (s.id_retencion_bk, s.sk_fecha_retencion, s.sk_cliente, s.sk_empleado, s.id_membresia_bk,
                    s.canal, s.motivo, s.resultado, s.monto_oferta);

        /* -------- Borrados físicos en hechos (última operación = DELETE) -------- */
        DELETE t FROM dm_comercial.FactVentas t INNER JOIN
        (
            SELECT id_pago_bk AS bk FROM
            (SELECT id_pago_bk, OperacionCDC, ROW_NUMBER() OVER (PARTITION BY id_pago_bk ORDER BY StagingID DESC) rn
             FROM dbo.stg_ventas_membresias
             WHERE EntidadOrigen = 'VENTA' AND id_pago_bk IS NOT NULL AND StagingID > @DesdeVM AND StagingID <= @HastaVM) x
            WHERE x.rn = 1 AND x.OperacionCDC = 1
        ) d ON d.bk = t.id_pago_bk;

        DELETE t FROM dm_comercial.FactMembresias t INNER JOIN
        (
            SELECT id_membresia_bk AS bk FROM
            (SELECT id_membresia_bk, OperacionCDC, ROW_NUMBER() OVER (PARTITION BY id_membresia_bk ORDER BY StagingID DESC) rn
             FROM dbo.stg_ventas_membresias
             WHERE EntidadOrigen = 'MEMBRESIA' AND id_membresia_bk IS NOT NULL AND StagingID > @DesdeVM AND StagingID <= @HastaVM) x
            WHERE x.rn = 1 AND x.OperacionCDC = 1
        ) d ON d.bk = t.id_membresia_bk;

        DELETE t FROM dm_comercial.FactRenovaciones t INNER JOIN
        (
            SELECT id_renovacion_bk AS bk FROM
            (SELECT id_renovacion_bk, OperacionCDC, ROW_NUMBER() OVER (PARTITION BY id_renovacion_bk ORDER BY StagingID DESC) rn
             FROM dbo.stg_ventas_membresias
             WHERE EntidadOrigen = 'RENOVACION' AND id_renovacion_bk IS NOT NULL AND StagingID > @DesdeVM AND StagingID <= @HastaVM) x
            WHERE x.rn = 1 AND x.OperacionCDC = 1
        ) d ON d.bk = t.id_renovacion_bk;

        DELETE t FROM dm_comercial.FactAvisos t INNER JOIN
        (
            SELECT id_aviso_bk AS bk FROM
            (SELECT id_aviso_bk, OperacionCDC, ROW_NUMBER() OVER (PARTITION BY id_aviso_bk ORDER BY StagingID DESC) rn
             FROM dbo.stg_ventas_membresias
             WHERE EntidadOrigen = 'AVISO' AND id_aviso_bk IS NOT NULL AND StagingID > @DesdeVM AND StagingID <= @HastaVM) x
            WHERE x.rn = 1 AND x.OperacionCDC = 1
        ) d ON d.bk = t.id_aviso_bk;

        DELETE t FROM dm_entrenamiento.FactAsistencias t INNER JOIN
        (
            SELECT id_asistencia_bk AS bk FROM
            (SELECT id_asistencia_bk, OperacionCDC, ROW_NUMBER() OVER (PARTITION BY id_asistencia_bk ORDER BY StagingID DESC) rn
             FROM dbo.stg_entrenamiento
             WHERE EntidadOrigen = 'ASISTENCIA' AND id_asistencia_bk IS NOT NULL AND StagingID > @DesdeEnt AND StagingID <= @HastaEnt) x
            WHERE x.rn = 1 AND x.OperacionCDC = 1
        ) d ON d.bk = t.id_asistencia_bk;

        DELETE t FROM dm_entrenamiento.FactObjetivos t INNER JOIN
        (
            SELECT id_objetivo_bk AS bk FROM
            (SELECT id_objetivo_bk, OperacionCDC, ROW_NUMBER() OVER (PARTITION BY id_objetivo_bk ORDER BY StagingID DESC) rn
             FROM dbo.stg_entrenamiento
             WHERE EntidadOrigen = 'OBJETIVO' AND id_objetivo_bk IS NOT NULL AND StagingID > @DesdeEnt AND StagingID <= @HastaEnt) x
            WHERE x.rn = 1 AND x.OperacionCDC = 1
        ) d ON d.bk = t.id_objetivo_bk;

        DELETE t FROM dm_entrenamiento.FactEvaluaciones t INNER JOIN
        (
            SELECT id_evaluacion_bk AS bk FROM
            (SELECT id_evaluacion_bk, OperacionCDC, ROW_NUMBER() OVER (PARTITION BY id_evaluacion_bk ORDER BY StagingID DESC) rn
             FROM dbo.stg_entrenamiento
             WHERE EntidadOrigen = 'EVALUACION' AND id_evaluacion_bk IS NOT NULL AND StagingID > @DesdeEnt AND StagingID <= @HastaEnt) x
            WHERE x.rn = 1 AND x.OperacionCDC = 1
        ) d ON d.bk = t.id_evaluacion_bk;

        DELETE t FROM dm_atencion.FactReclamos t INNER JOIN
        (
            SELECT id_reclamo_bk AS bk FROM
            (SELECT id_reclamo_bk, OperacionCDC, ROW_NUMBER() OVER (PARTITION BY id_reclamo_bk ORDER BY StagingID DESC) rn
             FROM dbo.stg_atencion_reclamos
             WHERE EntidadOrigen = 'RECLAMO' AND id_reclamo_bk IS NOT NULL AND StagingID > @DesdeRec AND StagingID <= @HastaRec) x
            WHERE x.rn = 1 AND x.OperacionCDC = 1
        ) d ON d.bk = t.id_reclamo_bk;

        DELETE t FROM dm_entrenamiento.FactSesionesProgramadas t INNER JOIN
        (
            SELECT id_sesion_bk AS bk FROM
            (SELECT id_sesion_bk, OperacionCDC, ROW_NUMBER() OVER (PARTITION BY id_sesion_bk ORDER BY StagingID DESC) rn
             FROM dbo.stg_entrenamiento
             WHERE EntidadOrigen = 'SESION_PROGRAMADA' AND id_sesion_bk IS NOT NULL AND StagingID > @DesdeEnt AND StagingID <= @HastaEnt) x
            WHERE x.rn = 1 AND x.OperacionCDC = 1
        ) d ON d.bk = t.id_sesion_bk;

        DELETE t FROM dm_entrenamiento.FactEvaluacionesProgramadas t INNER JOIN
        (
            SELECT id_evaluacion_programada_bk AS bk FROM
            (SELECT id_evaluacion_programada_bk, OperacionCDC, ROW_NUMBER() OVER (PARTITION BY id_evaluacion_programada_bk ORDER BY StagingID DESC) rn
             FROM dbo.stg_entrenamiento
             WHERE EntidadOrigen = 'EVALUACION_PROGRAMADA' AND id_evaluacion_programada_bk IS NOT NULL AND StagingID > @DesdeEnt AND StagingID <= @HastaEnt) x
            WHERE x.rn = 1 AND x.OperacionCDC = 1
        ) d ON d.bk = t.id_evaluacion_programada_bk;

        DELETE t FROM dm_atencion.FactRetenciones t INNER JOIN
        (
            SELECT id_retencion_bk AS bk FROM
            (SELECT id_retencion_bk, OperacionCDC, ROW_NUMBER() OVER (PARTITION BY id_retencion_bk ORDER BY StagingID DESC) rn
             FROM dbo.stg_atencion_reclamos
             WHERE EntidadOrigen = 'RETENCION' AND id_retencion_bk IS NOT NULL AND StagingID > @DesdeRec AND StagingID <= @HastaRec) x
            WHERE x.rn = 1 AND x.OperacionCDC = 1
        ) d ON d.bk = t.id_retencion_bk;

        /* -------- Avance de la marca de agua (sólo si todo salió bien) -------- */
        SET @Filas =
              (@HastaFecha - @DesdeFecha)
            + (@HastaCli - @DesdeCli)
            + (@HastaEmp - @DesdeEmp)
            + (@HastaPla - @DesdePla)
            + (@HastaVM - @DesdeVM);

        UPDATE dbo.etl_control SET ultimo_staging_id = @HastaFecha, ultima_carga = SYSUTCDATETIME(), filas_ultima_carga = @HastaFecha - @DesdeFecha WHERE proceso = 'stg_fecha';
        UPDATE dbo.etl_control SET ultimo_staging_id = @HastaCli,   ultima_carga = SYSUTCDATETIME(), filas_ultima_carga = @HastaCli   - @DesdeCli   WHERE proceso = 'stg_clientes';
        UPDATE dbo.etl_control SET ultimo_staging_id = @HastaEmp,   ultima_carga = SYSUTCDATETIME(), filas_ultima_carga = @HastaEmp   - @DesdeEmp   WHERE proceso = 'stg_empleados';
        UPDATE dbo.etl_control SET ultimo_staging_id = @HastaPla,   ultima_carga = SYSUTCDATETIME(), filas_ultima_carga = @HastaPla   - @DesdePla   WHERE proceso = 'stg_planes';
        UPDATE dbo.etl_control SET ultimo_staging_id = @HastaVM,    ultima_carga = SYSUTCDATETIME(), filas_ultima_carga = @HastaVM    - @DesdeVM    WHERE proceso = 'stg_ventas_membresias';
        UPDATE dbo.etl_control SET ultimo_staging_id = @HastaEnt,   ultima_carga = SYSUTCDATETIME(), filas_ultima_carga = @HastaEnt   - @DesdeEnt   WHERE proceso = 'stg_entrenamiento';
        UPDATE dbo.etl_control SET ultimo_staging_id = @HastaRec,   ultima_carga = SYSUTCDATETIME(), filas_ultima_carga = @HastaRec   - @DesdeRec   WHERE proceso = 'stg_atencion_reclamos';

        COMMIT TRANSACTION;

        SELECT 'ETL_INCREMENTAL' AS Estado, @DesdeFecha AS FechaDesdeStagingID, @HastaFecha AS FechaHastaStagingID;

        SELECT proceso, ultimo_staging_id, ultima_carga, filas_ultima_carga
        FROM dbo.etl_control
        ORDER BY proceso;

        SELECT 'DimFecha' AS Tabla, COUNT_BIG(*) AS Filas FROM dim.DimFecha
        UNION ALL SELECT 'DimCliente', COUNT_BIG(*) FROM dim.DimCliente
        UNION ALL SELECT 'DimEmpleado', COUNT_BIG(*) FROM dim.DimEmpleado
        UNION ALL SELECT 'DimPlan', COUNT_BIG(*) FROM dim.DimPlan
        UNION ALL SELECT 'FactVentas', COUNT_BIG(*) FROM dm_comercial.FactVentas
        UNION ALL SELECT 'FactMembresias', COUNT_BIG(*) FROM dm_comercial.FactMembresias
        UNION ALL SELECT 'FactRenovaciones', COUNT_BIG(*) FROM dm_comercial.FactRenovaciones
        UNION ALL SELECT 'FactAvisos', COUNT_BIG(*) FROM dm_comercial.FactAvisos
        UNION ALL SELECT 'FactAsistencias', COUNT_BIG(*) FROM dm_entrenamiento.FactAsistencias
        UNION ALL SELECT 'FactObjetivos', COUNT_BIG(*) FROM dm_entrenamiento.FactObjetivos
        UNION ALL SELECT 'FactEvaluaciones', COUNT_BIG(*) FROM dm_entrenamiento.FactEvaluaciones
        UNION ALL SELECT 'FactReclamos', COUNT_BIG(*) FROM dm_atencion.FactReclamos
        UNION ALL SELECT 'FactSesionesProgramadas', COUNT_BIG(*) FROM dm_entrenamiento.FactSesionesProgramadas
        UNION ALL SELECT 'FactEvaluacionesProgramadas', COUNT_BIG(*) FROM dm_entrenamiento.FactEvaluacionesProgramadas
        UNION ALL SELECT 'FactRetenciones', COUNT_BIG(*) FROM dm_atencion.FactRetenciones;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* =============================================================================
   RECONSTRUCCIÓN COMPLETA INICIAL (sólo bootstrap).
   Deja el Data Mart limpio, reinicia la marca de agua y ejecuta la primera
   carga. En producción esto NO se corre: el job ejecuta sólo el procedimiento.
   ============================================================================= */
DELETE FROM dm_atencion.FactRetenciones;
DELETE FROM dm_atencion.FactReclamos;
DELETE FROM dm_entrenamiento.FactEvaluacionesProgramadas;
DELETE FROM dm_entrenamiento.FactSesionesProgramadas;
DELETE FROM dm_entrenamiento.FactEvaluaciones;
DELETE FROM dm_entrenamiento.FactObjetivos;
DELETE FROM dm_entrenamiento.FactAsistencias;
DELETE FROM dm_comercial.FactAvisos;
DELETE FROM dm_comercial.FactRenovaciones;
DELETE FROM dm_comercial.FactMembresias;
DELETE FROM dm_comercial.FactVentas;
DELETE FROM dim.DimPlan;
DELETE FROM dim.DimEmpleado;
DELETE FROM dim.DimCliente;
DELETE FROM dim.DimFecha;
DELETE FROM dq.RegistroRechazos;
UPDATE dbo.etl_control SET ultimo_staging_id = 0, ultima_carga = NULL, filas_ultima_carga = NULL;
GO

EXEC dbo.usp_Transformar_CargarDataMart @FechaCorte = '2026-09-29';
GO
