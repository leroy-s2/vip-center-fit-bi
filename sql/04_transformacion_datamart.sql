/*=============================================================================
  VIP CENTER FIT - ETAPA 4: TRANSFORMACIÓN Y CARGA DEL DATA MART

  El procedimiento lee únicamente las tablas stg_. La fuente de origen no se
  consulta aquí. La carga es de reconstrucción completa para esta primera
  versión; por eso permite probar las reglas de calidad con todo el lote.
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

/* Instalación limpia del modelo destino de prueba. */
IF OBJECT_ID('dbo.DM_Entrenamiento_Progreso', 'V') IS NOT NULL DROP VIEW dbo.DM_Entrenamiento_Progreso;
IF OBJECT_ID('dbo.DM_Entrenamiento_Asistencia', 'V') IS NOT NULL DROP VIEW dbo.DM_Entrenamiento_Asistencia;
IF OBJECT_ID('dbo.DM_Atencion_Reclamos', 'V') IS NOT NULL DROP VIEW dbo.DM_Atencion_Reclamos;
IF OBJECT_ID('dbo.DM_Avisos_Cobertura', 'V') IS NOT NULL DROP VIEW dbo.DM_Avisos_Cobertura;
IF OBJECT_ID('dbo.DM_Comercial_Plan', 'V') IS NOT NULL DROP VIEW dbo.DM_Comercial_Plan;
IF OBJECT_ID('dbo.DM_Gerencia_Membresias', 'V') IS NOT NULL DROP VIEW dbo.DM_Gerencia_Membresias;
IF OBJECT_ID('dbo.DM_Gerencia_Ingresos', 'V') IS NOT NULL DROP VIEW dbo.DM_Gerencia_Ingresos;
IF OBJECT_ID('dbo.DM_Ventas_Gerencia', 'V') IS NOT NULL DROP VIEW dbo.DM_Ventas_Gerencia;
IF OBJECT_ID('dbo.DM_Rutinas_Entrenador', 'V') IS NOT NULL DROP VIEW dbo.DM_Rutinas_Entrenador;
IF OBJECT_ID('dbo.DM_Atencion_Recepcion', 'V') IS NOT NULL DROP VIEW dbo.DM_Atencion_Recepcion;
GO

DROP SYNONYM IF EXISTS dbo.FactReclamos;
DROP SYNONYM IF EXISTS dbo.FactEvaluaciones;
DROP SYNONYM IF EXISTS dbo.FactObjetivos;
DROP SYNONYM IF EXISTS dbo.FactAsistencias;
DROP SYNONYM IF EXISTS dbo.FactAvisos;
DROP SYNONYM IF EXISTS dbo.FactRenovaciones;
DROP SYNONYM IF EXISTS dbo.FactMembresias;
DROP SYNONYM IF EXISTS dbo.FactVentas;
DROP SYNONYM IF EXISTS dbo.DimPromocion;
DROP SYNONYM IF EXISTS dbo.DimPlan;
DROP SYNONYM IF EXISTS dbo.DimEmpleado;
DROP SYNONYM IF EXISTS dbo.DimCliente;
DROP SYNONYM IF EXISTS dbo.DimFecha;
DROP SYNONYM IF EXISTS dbo.stg_fecha;
DROP SYNONYM IF EXISTS dbo.stg_clientes;
DROP SYNONYM IF EXISTS dbo.stg_empleados;
DROP SYNONYM IF EXISTS dbo.stg_planes;
DROP SYNONYM IF EXISTS dbo.stg_promociones;
DROP SYNONYM IF EXISTS dbo.stg_ventas_membresias;
DROP SYNONYM IF EXISTS dbo.stg_entrenamiento;
DROP SYNONYM IF EXISTS dbo.stg_atencion_reclamos;

DROP TABLE IF EXISTS dbo.FactReclamos;
DROP TABLE IF EXISTS dbo.FactEvaluaciones;
DROP TABLE IF EXISTS dbo.FactObjetivos;
DROP TABLE IF EXISTS dbo.FactAsistencias;
DROP TABLE IF EXISTS dbo.FactAvisos;
DROP TABLE IF EXISTS dbo.FactRenovaciones;
DROP TABLE IF EXISTS dbo.FactMembresias;
DROP TABLE IF EXISTS dbo.FactVentas;
DROP TABLE IF EXISTS dbo.DimPromocion;
DROP TABLE IF EXISTS dbo.DimPlan;
DROP TABLE IF EXISTS dbo.DimEmpleado;
DROP TABLE IF EXISTS dbo.DimCliente;
DROP TABLE IF EXISTS dbo.DimFecha;
GO

/* Limpieza de una instalación anterior ya separada por esquemas. */
DROP SYNONYM IF EXISTS dbo.FactReclamos;
DROP SYNONYM IF EXISTS dbo.FactEvaluaciones;
DROP SYNONYM IF EXISTS dbo.FactObjetivos;
DROP SYNONYM IF EXISTS dbo.FactAsistencias;
DROP SYNONYM IF EXISTS dbo.FactAvisos;
DROP SYNONYM IF EXISTS dbo.FactRenovaciones;
DROP SYNONYM IF EXISTS dbo.FactMembresias;
DROP SYNONYM IF EXISTS dbo.FactVentas;
DROP SYNONYM IF EXISTS dbo.DimPromocion;
DROP SYNONYM IF EXISTS dbo.DimPlan;
DROP SYNONYM IF EXISTS dbo.DimEmpleado;
DROP SYNONYM IF EXISTS dbo.DimCliente;
DROP SYNONYM IF EXISTS dbo.DimFecha;

DROP TABLE IF EXISTS dm_atencion.FactReclamos;
DROP TABLE IF EXISTS dm_entrenamiento.FactEvaluaciones;
DROP TABLE IF EXISTS dm_entrenamiento.FactObjetivos;
DROP TABLE IF EXISTS dm_entrenamiento.FactAsistencias;
DROP TABLE IF EXISTS dm_comercial.FactAvisos;
DROP TABLE IF EXISTS dm_comercial.FactRenovaciones;
DROP TABLE IF EXISTS dm_comercial.FactMembresias;
DROP TABLE IF EXISTS dm_comercial.FactVentas;
DROP TABLE IF EXISTS dim.DimPromocion;
DROP TABLE IF EXISTS dim.DimPlan;
DROP TABLE IF EXISTS dim.DimEmpleado;
DROP TABLE IF EXISTS dim.DimCliente;
DROP TABLE IF EXISTS dim.DimFecha;
GO

CREATE TABLE dbo.DimFecha
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

CREATE TABLE dbo.DimCliente
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

CREATE TABLE dbo.DimEmpleado
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

CREATE TABLE dbo.DimPlan
(
    sk_plan INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    sk_plan_origen INT NULL,
    id_plan_bk INT NOT NULL UNIQUE,
    nombre_plan VARCHAR(60) NOT NULL,
    duracion_dias INT NULL,
    precio_referencial DECIMAL(12,2) NULL,
    categoria_duracion VARCHAR(40) NULL
);
GO

CREATE TABLE dbo.DimPromocion
(
    sk_promocion INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    sk_promocion_origen INT NULL,
    id_promocion_bk INT NOT NULL UNIQUE,
    nombre_promocion VARCHAR(100) NOT NULL,
    tipo_descuento VARCHAR(30) NOT NULL,
    valor_descuento DECIMAL(12,2) NULL
);
GO

CREATE TABLE dbo.FactVentas
(
    sk_venta BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    id_pago_bk INT NOT NULL UNIQUE,
    sk_fecha_pago INT NOT NULL,
    sk_cliente INT NOT NULL,
    sk_plan INT NOT NULL,
    sk_promocion INT NULL,
    sk_empleado INT NULL,
    id_membresia_bk INT NULL,
    monto_neto DECIMAL(12,2) NOT NULL,
    descuento_aplicado DECIMAL(12,2) NULL,
    precio_lista DECIMAL(12,2) NULL,
    metodo_pago VARCHAR(50) NOT NULL
);
GO

CREATE TABLE dbo.FactMembresias
(
    sk_membresia BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    id_membresia_bk INT NOT NULL UNIQUE,
    sk_cliente INT NOT NULL,
    sk_plan INT NOT NULL,
    sk_promocion INT NULL,
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

CREATE TABLE dbo.FactRenovaciones
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

CREATE TABLE dbo.FactAvisos
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

CREATE TABLE dbo.FactAsistencias
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

CREATE TABLE dbo.FactObjetivos
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

CREATE TABLE dbo.FactEvaluaciones
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

CREATE TABLE dbo.FactReclamos
(
    sk_reclamo BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    id_reclamo_bk INT NOT NULL UNIQUE,
    sk_fecha_reclamo INT NOT NULL,
    sk_cliente INT NOT NULL,
    sk_empleado INT NULL,
    categoria VARCHAR(60) NOT NULL,
    estado VARCHAR(30) NOT NULL,
    fecha_resolucion DATETIME2(7) NULL,
    dias_resolucion INT NULL
);
GO

/* Distribución física de las tablas en los tres Data Mart del DW. */
ALTER SCHEMA dim TRANSFER dbo.DimFecha;
ALTER SCHEMA dim TRANSFER dbo.DimCliente;
ALTER SCHEMA dim TRANSFER dbo.DimEmpleado;
ALTER SCHEMA dim TRANSFER dbo.DimPlan;
ALTER SCHEMA dim TRANSFER dbo.DimPromocion;

ALTER SCHEMA dm_comercial TRANSFER dbo.FactVentas;
ALTER SCHEMA dm_comercial TRANSFER dbo.FactMembresias;
ALTER SCHEMA dm_comercial TRANSFER dbo.FactRenovaciones;
ALTER SCHEMA dm_comercial TRANSFER dbo.FactAvisos;

ALTER SCHEMA dm_entrenamiento TRANSFER dbo.FactAsistencias;
ALTER SCHEMA dm_entrenamiento TRANSFER dbo.FactObjetivos;
ALTER SCHEMA dm_entrenamiento TRANSFER dbo.FactEvaluaciones;

ALTER SCHEMA dm_atencion TRANSFER dbo.FactReclamos;
GO

/* Sinónimos de compatibilidad para el procedimiento y las vistas existentes. */
CREATE SYNONYM dbo.DimFecha FOR dim.DimFecha;
CREATE SYNONYM dbo.DimCliente FOR dim.DimCliente;
CREATE SYNONYM dbo.DimEmpleado FOR dim.DimEmpleado;
CREATE SYNONYM dbo.DimPlan FOR dim.DimPlan;
CREATE SYNONYM dbo.DimPromocion FOR dim.DimPromocion;
CREATE SYNONYM dbo.FactVentas FOR dm_comercial.FactVentas;
CREATE SYNONYM dbo.FactMembresias FOR dm_comercial.FactMembresias;
CREATE SYNONYM dbo.FactRenovaciones FOR dm_comercial.FactRenovaciones;
CREATE SYNONYM dbo.FactAvisos FOR dm_comercial.FactAvisos;
CREATE SYNONYM dbo.FactAsistencias FOR dm_entrenamiento.FactAsistencias;
CREATE SYNONYM dbo.FactObjetivos FOR dm_entrenamiento.FactObjetivos;
CREATE SYNONYM dbo.FactEvaluaciones FOR dm_entrenamiento.FactEvaluaciones;
CREATE SYNONYM dbo.FactReclamos FOR dm_atencion.FactReclamos;

/* Sinónimos de lectura hacia el Staging separado. */
CREATE SYNONYM dbo.stg_fecha FOR BI_VIP_CENTER_FIT_STG.stg.stg_fecha;
CREATE SYNONYM dbo.stg_clientes FOR BI_VIP_CENTER_FIT_STG.stg.stg_clientes;
CREATE SYNONYM dbo.stg_empleados FOR BI_VIP_CENTER_FIT_STG.stg.stg_empleados;
CREATE SYNONYM dbo.stg_planes FOR BI_VIP_CENTER_FIT_STG.stg.stg_planes;
CREATE SYNONYM dbo.stg_promociones FOR BI_VIP_CENTER_FIT_STG.stg.stg_promociones;
CREATE SYNONYM dbo.stg_ventas_membresias FOR BI_VIP_CENTER_FIT_STG.stg.stg_ventas_membresias;
CREATE SYNONYM dbo.stg_entrenamiento FOR BI_VIP_CENTER_FIT_STG.stg.stg_entrenamiento;
CREATE SYNONYM dbo.stg_atencion_reclamos FOR BI_VIP_CENTER_FIT_STG.stg.stg_atencion_reclamos;
GO

/* -----------------------------------------------------------------------------
   Integridad referencial: relaciones FÍSICAS hecho -> dimensión conformada.

   Con estas FOREIGN KEY el modelo estrella queda declarado en el motor:
   - Prisma introspecciona las relaciones (el schema deja de estar "desconectado").
   - Power BI, dbdiagram y cualquier herramienta reconocen las estrellas.
   - SQL Server RECHAZA hechos con claves de dimensión inexistentes: los errores
     de integridad se detectan durante la carga, no al consultar.

   Los hechos se cargan después de las dimensiones (INNER/LEFT JOIN en el ETL),
   por lo que las FK se satisfacen; las columnas opcionales (sk_empleado,
   sk_promocion y sk_plan en asistencias) admiten NULL.
   ----------------------------------------------------------------------------- */

/* Data mart comercial */
ALTER TABLE dm_comercial.FactVentas ADD CONSTRAINT FK_FactVentas_DimFecha
    FOREIGN KEY (sk_fecha_pago) REFERENCES dim.DimFecha(sk_fecha);
ALTER TABLE dm_comercial.FactVentas ADD CONSTRAINT FK_FactVentas_DimCliente
    FOREIGN KEY (sk_cliente) REFERENCES dim.DimCliente(sk_cliente);
ALTER TABLE dm_comercial.FactVentas ADD CONSTRAINT FK_FactVentas_DimPlan
    FOREIGN KEY (sk_plan) REFERENCES dim.DimPlan(sk_plan);
ALTER TABLE dm_comercial.FactVentas ADD CONSTRAINT FK_FactVentas_DimPromocion
    FOREIGN KEY (sk_promocion) REFERENCES dim.DimPromocion(sk_promocion);
ALTER TABLE dm_comercial.FactVentas ADD CONSTRAINT FK_FactVentas_DimEmpleado
    FOREIGN KEY (sk_empleado) REFERENCES dim.DimEmpleado(sk_empleado);

ALTER TABLE dm_comercial.FactMembresias ADD CONSTRAINT FK_FactMembresias_DimCliente
    FOREIGN KEY (sk_cliente) REFERENCES dim.DimCliente(sk_cliente);
ALTER TABLE dm_comercial.FactMembresias ADD CONSTRAINT FK_FactMembresias_DimPlan
    FOREIGN KEY (sk_plan) REFERENCES dim.DimPlan(sk_plan);
ALTER TABLE dm_comercial.FactMembresias ADD CONSTRAINT FK_FactMembresias_DimPromocion
    FOREIGN KEY (sk_promocion) REFERENCES dim.DimPromocion(sk_promocion);
ALTER TABLE dm_comercial.FactMembresias ADD CONSTRAINT FK_FactMembresias_DimEmpleado
    FOREIGN KEY (sk_empleado) REFERENCES dim.DimEmpleado(sk_empleado);
ALTER TABLE dm_comercial.FactMembresias ADD CONSTRAINT FK_FactMembresias_DimFechaInicio
    FOREIGN KEY (sk_fecha_inicio) REFERENCES dim.DimFecha(sk_fecha);
ALTER TABLE dm_comercial.FactMembresias ADD CONSTRAINT FK_FactMembresias_DimFechaFin
    FOREIGN KEY (sk_fecha_fin) REFERENCES dim.DimFecha(sk_fecha);

ALTER TABLE dm_comercial.FactRenovaciones ADD CONSTRAINT FK_FactRenovaciones_DimFecha
    FOREIGN KEY (sk_fecha_renovacion) REFERENCES dim.DimFecha(sk_fecha);
ALTER TABLE dm_comercial.FactRenovaciones ADD CONSTRAINT FK_FactRenovaciones_DimCliente
    FOREIGN KEY (sk_cliente) REFERENCES dim.DimCliente(sk_cliente);
ALTER TABLE dm_comercial.FactRenovaciones ADD CONSTRAINT FK_FactRenovaciones_DimEmpleado
    FOREIGN KEY (sk_empleado) REFERENCES dim.DimEmpleado(sk_empleado);

ALTER TABLE dm_comercial.FactAvisos ADD CONSTRAINT FK_FactAvisos_DimFecha
    FOREIGN KEY (sk_fecha_aviso) REFERENCES dim.DimFecha(sk_fecha);
ALTER TABLE dm_comercial.FactAvisos ADD CONSTRAINT FK_FactAvisos_DimCliente
    FOREIGN KEY (sk_cliente) REFERENCES dim.DimCliente(sk_cliente);
ALTER TABLE dm_comercial.FactAvisos ADD CONSTRAINT FK_FactAvisos_DimEmpleado
    FOREIGN KEY (sk_empleado) REFERENCES dim.DimEmpleado(sk_empleado);

/* Data mart entrenamiento */
ALTER TABLE dm_entrenamiento.FactAsistencias ADD CONSTRAINT FK_FactAsistencias_DimFecha
    FOREIGN KEY (sk_fecha_asistencia) REFERENCES dim.DimFecha(sk_fecha);
ALTER TABLE dm_entrenamiento.FactAsistencias ADD CONSTRAINT FK_FactAsistencias_DimCliente
    FOREIGN KEY (sk_cliente) REFERENCES dim.DimCliente(sk_cliente);
ALTER TABLE dm_entrenamiento.FactAsistencias ADD CONSTRAINT FK_FactAsistencias_DimPlan
    FOREIGN KEY (sk_plan) REFERENCES dim.DimPlan(sk_plan);
ALTER TABLE dm_entrenamiento.FactAsistencias ADD CONSTRAINT FK_FactAsistencias_DimEmpleado
    FOREIGN KEY (sk_empleado) REFERENCES dim.DimEmpleado(sk_empleado);

ALTER TABLE dm_entrenamiento.FactObjetivos ADD CONSTRAINT FK_FactObjetivos_DimFecha
    FOREIGN KEY (sk_fecha_inicio) REFERENCES dim.DimFecha(sk_fecha);
ALTER TABLE dm_entrenamiento.FactObjetivos ADD CONSTRAINT FK_FactObjetivos_DimCliente
    FOREIGN KEY (sk_cliente) REFERENCES dim.DimCliente(sk_cliente);

ALTER TABLE dm_entrenamiento.FactEvaluaciones ADD CONSTRAINT FK_FactEvaluaciones_DimFecha
    FOREIGN KEY (sk_fecha_evaluacion) REFERENCES dim.DimFecha(sk_fecha);
ALTER TABLE dm_entrenamiento.FactEvaluaciones ADD CONSTRAINT FK_FactEvaluaciones_DimCliente
    FOREIGN KEY (sk_cliente) REFERENCES dim.DimCliente(sk_cliente);
ALTER TABLE dm_entrenamiento.FactEvaluaciones ADD CONSTRAINT FK_FactEvaluaciones_DimEmpleado
    FOREIGN KEY (sk_empleado) REFERENCES dim.DimEmpleado(sk_empleado);

/* Data mart atención */
ALTER TABLE dm_atencion.FactReclamos ADD CONSTRAINT FK_FactReclamos_DimFecha
    FOREIGN KEY (sk_fecha_reclamo) REFERENCES dim.DimFecha(sk_fecha);
ALTER TABLE dm_atencion.FactReclamos ADD CONSTRAINT FK_FactReclamos_DimCliente
    FOREIGN KEY (sk_cliente) REFERENCES dim.DimCliente(sk_cliente);
ALTER TABLE dm_atencion.FactReclamos ADD CONSTRAINT FK_FactReclamos_DimEmpleado
    FOREIGN KEY (sk_empleado) REFERENCES dim.DimEmpleado(sk_empleado);
GO

CREATE OR ALTER PROCEDURE dbo.usp_Transformar_CargarDataMart
    @FechaCorte DATE = '2026-09-29'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET DATEFIRST 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        /* La carga actual es completa para poder probar todo el lote.
           Se usa DELETE (no TRUNCATE) porque las tablas participan en FOREIGN KEY:
           SQL Server no permite TRUNCATE sobre tablas referenciadas por una FK.
           El orden es hechos primero y dimensiones después, para respetar las FK. */
        DELETE FROM dm_atencion.FactReclamos;
        DELETE FROM dm_entrenamiento.FactEvaluaciones;
        DELETE FROM dm_entrenamiento.FactObjetivos;
        DELETE FROM dm_entrenamiento.FactAsistencias;
        DELETE FROM dm_comercial.FactAvisos;
        DELETE FROM dm_comercial.FactRenovaciones;
        DELETE FROM dm_comercial.FactMembresias;
        DELETE FROM dm_comercial.FactVentas;
        DELETE FROM dim.DimPromocion;
        DELETE FROM dim.DimPlan;
        DELETE FROM dim.DimEmpleado;
        DELETE FROM dim.DimCliente;
        DELETE FROM dim.DimFecha;

        /* DimFecha: se recalculan atributos para corregir inconsistencias de origen. */
        ;WITH FechaCanonica AS
        (
            SELECT
                sk_fecha_origen,
                MIN(fecha) AS fecha
            FROM dbo.stg_fecha
            WHERE fecha IS NOT NULL
              AND fecha >= '2000-01-01'
              AND fecha <= '2100-12-31'
            GROUP BY sk_fecha_origen
        )
        INSERT INTO dbo.DimFecha
        (
            sk_fecha, fecha, anio, trimestre, semestre, mes,
            nombre_mes, dia, dia_semana, es_fin_de_semana
        )
        SELECT
            CONVERT(INT, CONVERT(CHAR(8), fecha, 112)),
            fecha,
            YEAR(fecha),
            DATEPART(QUARTER, fecha),
            CASE WHEN MONTH(fecha) <= 6 THEN 1 ELSE 2 END,
            MONTH(fecha),
            CHOOSE(MONTH(fecha), 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
                   'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'),
            DAY(fecha),
            CHOOSE(DATEPART(WEEKDAY, fecha), 'Lunes', 'Martes', 'Miércoles', 'Jueves',
                   'Viernes', 'Sábado', 'Domingo'),
            CASE WHEN DATEPART(WEEKDAY, fecha) IN (6, 7) THEN 1 ELSE 0 END
        FROM FechaCanonica
        WHERE NOT EXISTS
          (
              SELECT 1
              FROM dbo.DimFecha d
              WHERE d.fecha = FechaCanonica.fecha
          );

        /* DimCliente: se conserva un registro canónico por id_cliente_bk. */
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
        )
        INSERT INTO dbo.DimCliente
        (
            sk_cliente_origen, id_cliente_bk, dni, nombre_completo, sexo,
            rango_etario, estado_cliente, fecha_registro_origen,
            fecha_inicio_validez, fecha_fin_validez, es_actual
        )
        SELECT
            sk_cliente_origen,
            id_cliente_bk,
            CASE
                WHEN NULLIF(REPLACE(REPLACE(REPLACE(UPPER(LTRIM(RTRIM(dni))), '-', ''), ' ', ''), 'O', ''), '') IS NULL THEN NULL
                WHEN REPLACE(REPLACE(REPLACE(UPPER(LTRIM(RTRIM(dni))), '-', ''), ' ', ''), 'O', '0') LIKE '%[^0-9]%' THEN NULL
                ELSE RIGHT('00000000' + REPLACE(REPLACE(REPLACE(UPPER(LTRIM(RTRIM(dni))), '-', ''), ' ', ''), 'O', '0'), 8)
            END,
            COALESCE(UPPER(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(nombre_completo, '  ', ' '), '  ', ' '), '  ', ' ')))), 'SIN NOMBRE'),
            CASE
                WHEN UPPER(LEFT(LTRIM(RTRIM(sexo)), 1)) = 'M' THEN 'M'
                WHEN UPPER(LEFT(LTRIM(RTRIM(sexo)), 1)) = 'F' THEN 'F'
                ELSE 'X'
            END,
            NULLIF(UPPER(LTRIM(RTRIM(rango_etario))), ''),
            CASE
                WHEN UPPER(LTRIM(RTRIM(estado_cliente))) LIKE 'ACT%' THEN 'ACTIVO'
                ELSE 'INACTIVO'
            END,
            CASE WHEN fecha_registro_origen BETWEEN '2000-01-01' AND @FechaCorte THEN fecha_registro_origen END,
            CASE WHEN fecha_inicio_validez BETWEEN '2000-01-01' AND @FechaCorte THEN fecha_inicio_validez END,
            CASE
                WHEN fecha_fin_validez >= fecha_inicio_validez THEN fecha_fin_validez
                ELSE NULL
            END,
            CASE WHEN es_actual = 1 THEN 1 ELSE 0 END
        FROM ClienteCanonico
        WHERE rn = 1
          AND OperacionCDC IN (2, 4);

        /* DimEmpleado. */
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
        )
        INSERT INTO dbo.DimEmpleado
        (
            sk_empleado_origen, id_empleado_bk, dni, nombre_completo, cargo, area
        )
        SELECT
            sk_empleado_origen,
            id_empleado_bk,
            NULLIF(LTRIM(RTRIM(dni)), ''),
            COALESCE(NULLIF(UPPER(LTRIM(RTRIM(nombre_completo))), ''), 'NO ESPECIFICADO'),
            COALESCE(NULLIF(UPPER(LTRIM(RTRIM(cargo))), ''), 'NO ESPECIFICADO'),
            COALESCE(NULLIF(UPPER(LTRIM(RTRIM(area))), ''), 'NO ESPECIFICADO')
        FROM EmpleadoCanonico
        WHERE rn = 1
          AND OperacionCDC IN (2, 4);

        /* DimPlan. */
        ;WITH PlanCanonico AS
        (
            SELECT *,
                   ROW_NUMBER() OVER
                   (
                       PARTITION BY id_plan_bk
                       ORDER BY CASE WHEN duracion_dias > 0 AND precio_referencial > 0 THEN 0 ELSE 1 END,
                                sk_plan_origen DESC,
                                StagingID DESC
                   ) AS rn
            FROM dbo.stg_planes
            WHERE id_plan_bk IS NOT NULL
        )
        INSERT INTO dbo.DimPlan
        (
            sk_plan_origen, id_plan_bk, nombre_plan, duracion_dias,
            precio_referencial, categoria_duracion
        )
        SELECT
            sk_plan_origen,
            id_plan_bk,
            COALESCE(NULLIF(UPPER(LTRIM(RTRIM(nombre_plan))), ''), 'PLAN NO ESPECIFICADO'),
            CASE WHEN duracion_dias > 0 AND duracion_dias <= 3650 THEN duracion_dias END,
            CASE WHEN precio_referencial >= 0 AND precio_referencial <= 5000 THEN precio_referencial END,
            COALESCE(NULLIF(UPPER(LTRIM(RTRIM(categoria_duracion))), ''), 'NO ESPECIFICADA')
        FROM PlanCanonico
        WHERE rn = 1
          AND OperacionCDC IN (2, 4);

        /* DimPromocion. */
        ;WITH PromocionCanonica AS
        (
            SELECT *,
                   ROW_NUMBER() OVER
                   (
                       PARTITION BY id_promocion_bk
                       ORDER BY CASE WHEN valor_descuento BETWEEN 0 AND 1000 THEN 0 ELSE 1 END,
                                sk_promocion_origen DESC,
                                StagingID DESC
                   ) AS rn
            FROM dbo.stg_promociones
            WHERE id_promocion_bk IS NOT NULL
        )
        INSERT INTO dbo.DimPromocion
        (
            sk_promocion_origen, id_promocion_bk, nombre_promocion,
            tipo_descuento, valor_descuento
        )
        SELECT
            sk_promocion_origen,
            id_promocion_bk,
            COALESCE(NULLIF(UPPER(LTRIM(RTRIM(nombre_promocion))), ''), 'SIN PROMOCION'),
            COALESCE(NULLIF(UPPER(LTRIM(RTRIM(tipo_descuento))), ''), 'NINGUNO'),
            CASE WHEN valor_descuento BETWEEN 0 AND 1000 THEN valor_descuento END
        FROM PromocionCanonica
        WHERE rn = 1
          AND OperacionCDC IN (2, 4);

        /* Mapas de claves del origen hacia las dimensiones limpias. */
        SELECT sk_cliente_origen, MAX(id_cliente_bk) AS id_cliente_bk
        INTO #MapCliente
        FROM dbo.stg_clientes
        WHERE sk_cliente_origen IS NOT NULL
          AND id_cliente_bk IS NOT NULL
        GROUP BY sk_cliente_origen;

        SELECT sk_empleado_origen, MAX(id_empleado_bk) AS id_empleado_bk
        INTO #MapEmpleado
        FROM dbo.stg_empleados
        WHERE sk_empleado_origen IS NOT NULL
          AND id_empleado_bk IS NOT NULL
        GROUP BY sk_empleado_origen;

        SELECT sk_plan_origen, MAX(id_plan_bk) AS id_plan_bk
        INTO #MapPlan
        FROM dbo.stg_planes
        WHERE sk_plan_origen IS NOT NULL
          AND id_plan_bk IS NOT NULL
        GROUP BY sk_plan_origen;

        SELECT sk_promocion_origen, MAX(id_promocion_bk) AS id_promocion_bk
        INTO #MapPromocion
        FROM dbo.stg_promociones
        WHERE sk_promocion_origen IS NOT NULL
          AND id_promocion_bk IS NOT NULL
        GROUP BY sk_promocion_origen;

        SELECT sk_fecha_origen, CONVERT(INT, CONVERT(CHAR(8), MIN(fecha), 112)) AS sk_fecha
        INTO #MapFecha
        FROM dbo.stg_fecha
        WHERE sk_fecha_origen IS NOT NULL
          AND fecha IS NOT NULL
          AND fecha >= '2000-01-01'
          AND fecha <= '2100-12-31'
        GROUP BY sk_fecha_origen;

        /* FactVentas: se deduplica por id_pago_bk y se descartan claves obligatorias inválidas. */
        ;WITH VentaCanonica AS
        (
            SELECT *,
                   ROW_NUMBER() OVER
                   (
                       PARTITION BY id_pago_bk
                       ORDER BY StagingID DESC
                   ) AS rn
            FROM dbo.stg_ventas_membresias
            WHERE EntidadOrigen = 'VENTA'
              AND id_pago_bk IS NOT NULL
        )
        INSERT INTO dbo.FactVentas
        (
            id_pago_bk, sk_fecha_pago, sk_cliente, sk_plan, sk_promocion,
            sk_empleado, id_membresia_bk, monto_neto, descuento_aplicado,
            precio_lista, metodo_pago
        )
        SELECT
            v.id_pago_bk,
            df.sk_fecha,
            c.sk_cliente,
            p.sk_plan,
            pr.sk_promocion,
            e.sk_empleado,
            v.id_membresia_bk,
            CASE WHEN v.monto_neto IS NULL OR v.monto_neto < 0 THEN 0 ELSE v.monto_neto END,
            CASE WHEN v.descuento_aplicado >= 0 THEN v.descuento_aplicado END,
            CASE WHEN v.precio_lista >= 0 THEN v.precio_lista END,
            CASE
                WHEN UPPER(LTRIM(RTRIM(v.metodo_pago))) LIKE '%YAPE%' THEN 'YAPE'
                WHEN UPPER(LTRIM(RTRIM(v.metodo_pago))) LIKE '%PLIN%' THEN 'PLIN'
                WHEN UPPER(LTRIM(RTRIM(v.metodo_pago))) LIKE '%TRANS%' THEN 'TRANSFERENCIA'
                WHEN UPPER(LTRIM(RTRIM(v.metodo_pago))) LIKE '%TARJ%' THEN 'TARJETA'
                WHEN UPPER(LTRIM(RTRIM(v.metodo_pago))) LIKE '%EFECT%' THEN 'EFECTIVO'
                ELSE 'NO ESPECIFICADO'
            END
        FROM VentaCanonica v
        INNER JOIN #MapFecha mf0 ON mf0.sk_fecha_origen = v.sk_fecha_pago_origen
        INNER JOIN dbo.DimFecha df ON df.sk_fecha = mf0.sk_fecha
        INNER JOIN #MapCliente mc ON mc.sk_cliente_origen = v.sk_cliente_origen
        INNER JOIN dbo.DimCliente c ON c.id_cliente_bk = mc.id_cliente_bk
        INNER JOIN #MapPlan mp ON mp.sk_plan_origen = v.sk_plan_origen
        INNER JOIN dbo.DimPlan p ON p.id_plan_bk = mp.id_plan_bk
        LEFT JOIN #MapPromocion mpr ON mpr.sk_promocion_origen = v.sk_promocion_origen
        LEFT JOIN dbo.DimPromocion pr ON pr.id_promocion_bk = mpr.id_promocion_bk
        LEFT JOIN #MapEmpleado me ON me.sk_empleado_origen = v.sk_empleado_origen
        LEFT JOIN dbo.DimEmpleado e ON e.id_empleado_bk = me.id_empleado_bk
        WHERE v.rn = 1
          AND v.OperacionCDC IN (2, 4);

        /* FactMembresias. La vigencia se deriva de fechas, no del estado sucio. */
        ;WITH MembresiaCanonica AS
        (
            SELECT *,
                   ROW_NUMBER() OVER
                   (
                       PARTITION BY id_membresia_bk
                       ORDER BY StagingID DESC
                   ) AS rn
            FROM dbo.stg_ventas_membresias
            WHERE EntidadOrigen = 'MEMBRESIA'
              AND id_membresia_bk IS NOT NULL
        )
        INSERT INTO dbo.FactMembresias
        (
            id_membresia_bk, sk_cliente, sk_plan, sk_promocion, sk_empleado,
            sk_fecha_inicio, sk_fecha_fin, duracion_dias, precio_final,
            es_renovacion, estado_membresia, dias_anticipacion_renovacion
        )
        SELECT
            m.id_membresia_bk,
            c.sk_cliente,
            p.sk_plan,
            pr.sk_promocion,
            e.sk_empleado,
            di.sk_fecha,
            df.sk_fecha,
            CASE WHEN m.duracion_dias > 0 THEN m.duracion_dias END,
            CASE WHEN m.precio_final >= 0 THEN m.precio_final END,
            CASE WHEN m.es_renovacion = 1 THEN 1 ELSE 0 END,
            CASE
                WHEN di.fecha <= @FechaCorte AND df.fecha >= @FechaCorte THEN 'ACTIVA'
                WHEN df.fecha < @FechaCorte THEN 'VENCIDA'
                WHEN di.fecha > @FechaCorte THEN 'PENDIENTE'
                ELSE 'DESCONOCIDA'
            END,
            CASE WHEN m.dias_anticipacion_renovacion BETWEEN 0 AND 30 THEN m.dias_anticipacion_renovacion END
        FROM MembresiaCanonica m
        INNER JOIN #MapFecha mfi ON mfi.sk_fecha_origen = m.sk_fecha_inicio_origen
        INNER JOIN dbo.DimFecha di ON di.sk_fecha = mfi.sk_fecha
        INNER JOIN #MapFecha mff ON mff.sk_fecha_origen = m.sk_fecha_fin_origen
        INNER JOIN dbo.DimFecha df ON df.sk_fecha = mff.sk_fecha
        INNER JOIN #MapCliente mc ON mc.sk_cliente_origen = m.sk_cliente_origen
        INNER JOIN dbo.DimCliente c ON c.id_cliente_bk = mc.id_cliente_bk
        INNER JOIN #MapPlan mp ON mp.sk_plan_origen = m.sk_plan_origen
        INNER JOIN dbo.DimPlan p ON p.id_plan_bk = mp.id_plan_bk
        LEFT JOIN #MapPromocion mpr ON mpr.sk_promocion_origen = m.sk_promocion_origen
        LEFT JOIN dbo.DimPromocion pr ON pr.id_promocion_bk = mpr.id_promocion_bk
        LEFT JOIN #MapEmpleado me ON me.sk_empleado_origen = m.sk_empleado_origen
        LEFT JOIN dbo.DimEmpleado e ON e.id_empleado_bk = me.id_empleado_bk
        WHERE m.rn = 1
          AND m.OperacionCDC IN (2, 4);

        /* FactRenovaciones. */
        ;WITH RenovacionCanonica AS
        (
            SELECT *,
                   ROW_NUMBER() OVER
                   (
                       PARTITION BY id_renovacion_bk
                       ORDER BY StagingID DESC
                   ) AS rn
            FROM dbo.stg_ventas_membresias
            WHERE EntidadOrigen = 'RENOVACION'
              AND id_renovacion_bk IS NOT NULL
        )
        INSERT INTO dbo.FactRenovaciones
        (
            id_renovacion_bk, sk_fecha_renovacion, sk_cliente, sk_empleado,
            id_membresia_anterior_bk, id_membresia_nueva_bk,
            dias_anticipacion, monto
        )
        SELECT
            r.id_renovacion_bk,
            mf.sk_fecha,
            c.sk_cliente,
            e.sk_empleado,
            r.id_membresia_anterior_bk,
            r.id_membresia_nueva_bk,
            CASE WHEN r.dias_anticipacion BETWEEN 0 AND 30 THEN r.dias_anticipacion END,
            CASE WHEN r.monto_renovacion > 0 THEN r.monto_renovacion END
        FROM RenovacionCanonica r
        INNER JOIN #MapFecha mf0 ON mf0.sk_fecha_origen = r.sk_fecha_renovacion_origen
        INNER JOIN dbo.DimFecha mf ON mf.sk_fecha = mf0.sk_fecha
        INNER JOIN #MapCliente mc ON mc.sk_cliente_origen = r.sk_cliente_origen
        INNER JOIN dbo.DimCliente c ON c.id_cliente_bk = mc.id_cliente_bk
        LEFT JOIN #MapEmpleado me ON me.sk_empleado_origen = r.sk_empleado_origen
        LEFT JOIN dbo.DimEmpleado e ON e.id_empleado_bk = me.id_empleado_bk
        WHERE r.rn = 1
          AND r.OperacionCDC IN (2, 4);

        /* FactAvisos. */
        ;WITH AvisoCanonico AS
        (
            SELECT *,
                   ROW_NUMBER() OVER
                   (
                       PARTITION BY id_aviso_bk
                       ORDER BY StagingID DESC
                   ) AS rn
            FROM dbo.stg_ventas_membresias
            WHERE EntidadOrigen = 'AVISO'
              AND id_aviso_bk IS NOT NULL
        )
        INSERT INTO dbo.FactAvisos
        (
            id_aviso_bk, sk_fecha_aviso, sk_cliente, sk_empleado,
            id_membresia_bk, dias_antes_vencimiento, medio, estado
        )
        SELECT
            a.id_aviso_bk,
            mf.sk_fecha,
            c.sk_cliente,
            e.sk_empleado,
            a.id_membresia_bk,
            CASE WHEN a.dias_antes_vencimiento BETWEEN 1 AND 30 THEN a.dias_antes_vencimiento END,
            CASE
                WHEN UPPER(LTRIM(RTRIM(a.medio_aviso))) LIKE '%WHATS%' THEN 'WHATSAPP'
                WHEN UPPER(LTRIM(RTRIM(a.medio_aviso))) LIKE '%CORRE%' OR UPPER(LTRIM(RTRIM(a.medio_aviso))) LIKE '%EMAIL%' THEN 'CORREO'
                WHEN UPPER(LTRIM(RTRIM(a.medio_aviso))) LIKE '%SMS%' THEN 'SMS'
                ELSE 'NO ESPECIFICADO'
            END,
            CASE
                WHEN UPPER(LTRIM(RTRIM(a.estado_aviso))) LIKE '%ENV%' OR UPPER(LTRIM(RTRIM(a.estado_aviso))) = 'OK' THEN 'ENVIADO'
                ELSE 'NO CONFIRMADO'
            END
        FROM AvisoCanonico a
        INNER JOIN #MapFecha mf0 ON mf0.sk_fecha_origen = a.sk_fecha_aviso_origen
        INNER JOIN dbo.DimFecha mf ON mf.sk_fecha = mf0.sk_fecha
        INNER JOIN #MapCliente mc ON mc.sk_cliente_origen = a.sk_cliente_origen
        INNER JOIN dbo.DimCliente c ON c.id_cliente_bk = mc.id_cliente_bk
        LEFT JOIN #MapEmpleado me ON me.sk_empleado_origen = a.sk_empleado_origen
        LEFT JOIN dbo.DimEmpleado e ON e.id_empleado_bk = me.id_empleado_bk
        WHERE a.rn = 1
          AND a.OperacionCDC IN (2, 4);

        /* FactAsistencias. */
        ;WITH AsistenciaCanonica AS
        (
            SELECT *,
                   ROW_NUMBER() OVER
                   (
                       PARTITION BY id_asistencia_bk
                       ORDER BY StagingID DESC
                   ) AS rn
            FROM dbo.stg_entrenamiento
            WHERE EntidadOrigen = 'ASISTENCIA'
              AND id_asistencia_bk IS NOT NULL
        )
        INSERT INTO dbo.FactAsistencias
        (
            id_asistencia_bk, sk_fecha_asistencia, sk_cliente, sk_plan,
            sk_empleado, hora_ingreso, cantidad_asistencias
        )
        SELECT
            a.id_asistencia_bk,
            mf.sk_fecha,
            c.sk_cliente,
            p.sk_plan,
            e.sk_empleado,
            CASE WHEN a.hora_ingreso BETWEEN 5 AND 23 THEN a.hora_ingreso END,
            CASE WHEN ISNULL(a.cantidad_asistencias, 0) > 0 THEN 1 ELSE 0 END
        FROM AsistenciaCanonica a
        INNER JOIN #MapFecha mf0 ON mf0.sk_fecha_origen = a.sk_fecha_asistencia_origen
        INNER JOIN dbo.DimFecha mf ON mf.sk_fecha = mf0.sk_fecha
        INNER JOIN #MapCliente mc ON mc.sk_cliente_origen = a.sk_cliente_origen
        INNER JOIN dbo.DimCliente c ON c.id_cliente_bk = mc.id_cliente_bk
        LEFT JOIN #MapPlan mp ON mp.sk_plan_origen = a.sk_plan_origen
        LEFT JOIN dbo.DimPlan p ON p.id_plan_bk = mp.id_plan_bk
        LEFT JOIN #MapEmpleado me ON me.sk_empleado_origen = a.sk_empleado_origen
        LEFT JOIN dbo.DimEmpleado e ON e.id_empleado_bk = me.id_empleado_bk
        WHERE a.rn = 1
          AND a.OperacionCDC IN (2, 4);

        /* FactObjetivos. */
        ;WITH ObjetivoCanonico AS
        (
            SELECT *,
                   ROW_NUMBER() OVER
                   (
                       PARTITION BY id_objetivo_bk
                       ORDER BY StagingID DESC
                   ) AS rn
            FROM dbo.stg_entrenamiento
            WHERE EntidadOrigen = 'OBJETIVO'
              AND id_objetivo_bk IS NOT NULL
        )
        INSERT INTO dbo.FactObjetivos
        (
            id_objetivo_bk, sk_fecha_inicio, sk_cliente, tipo_objetivo,
            valor_inicial, valor_objetivo, unidad_medida, estado
        )
        SELECT
            o.id_objetivo_bk,
            mf.sk_fecha,
            c.sk_cliente,
            CASE
                WHEN UPPER(REPLACE(REPLACE(LTRIM(RTRIM(o.tipo_objetivo)), ' ', '_'), 'DE_', '')) LIKE 'AUMENTO%MASA%' THEN 'AUMENTO_MASA'
                WHEN UPPER(REPLACE(REPLACE(LTRIM(RTRIM(o.tipo_objetivo)), ' ', '_'), 'DE_', '')) LIKE 'REDUCCION%GRASA%' THEN 'REDUCCION_GRASA'
                ELSE COALESCE(NULLIF(UPPER(LTRIM(RTRIM(o.tipo_objetivo))), ''), 'NO ESPECIFICADO')
            END,
            CASE WHEN o.valor_inicial > 0 AND o.valor_inicial < 500 THEN o.valor_inicial END,
            CASE
                WHEN o.valor_inicial > 0 AND o.valor_inicial < 500
                 AND o.valor_objetivo > 0 AND o.valor_objetivo < 500
                 AND (
                     (UPPER(o.tipo_objetivo) LIKE '%AUMENTO%' AND o.valor_objetivo >= o.valor_inicial)
                     OR (UPPER(o.tipo_objetivo) LIKE '%REDUCCION%' AND o.valor_objetivo <= o.valor_inicial)
                     OR (UPPER(o.tipo_objetivo) NOT LIKE '%AUMENTO%' AND UPPER(o.tipo_objetivo) NOT LIKE '%REDUCCION%')
                 )
                THEN o.valor_objetivo
            END,
            CASE
                WHEN UPPER(LTRIM(RTRIM(o.unidad_medida))) LIKE 'KG%' THEN 'KG'
                WHEN UPPER(LTRIM(RTRIM(o.unidad_medida))) LIKE 'CM%' THEN 'CM'
                ELSE 'NO ESPECIFICADA'
            END,
            CASE
                WHEN UPPER(LTRIM(RTRIM(o.estado_objetivo))) LIKE 'CUMPL%' THEN 'CUMPLIDO'
                WHEN UPPER(LTRIM(RTRIM(o.estado_objetivo))) LIKE 'ACT%' THEN 'ACTIVO'
                WHEN UPPER(LTRIM(RTRIM(o.estado_objetivo))) LIKE 'CANCEL%' THEN 'CANCELADO'
                ELSE 'NO ESPECIFICADO'
            END
        FROM ObjetivoCanonico o
        INNER JOIN #MapFecha mf0 ON mf0.sk_fecha_origen = o.sk_fecha_inicio_origen
        INNER JOIN dbo.DimFecha mf ON mf.sk_fecha = mf0.sk_fecha
        INNER JOIN #MapCliente mc ON mc.sk_cliente_origen = o.sk_cliente_origen
        INNER JOIN dbo.DimCliente c ON c.id_cliente_bk = mc.id_cliente_bk
        WHERE o.rn = 1
          AND o.OperacionCDC IN (2, 4);

        /* FactEvaluaciones. */
        ;WITH EvaluacionCanonica AS
        (
            SELECT *,
                   ROW_NUMBER() OVER
                   (
                       PARTITION BY id_evaluacion_bk
                       ORDER BY StagingID DESC
                   ) AS rn
            FROM dbo.stg_entrenamiento
            WHERE EntidadOrigen = 'EVALUACION'
              AND id_evaluacion_bk IS NOT NULL
        )
        INSERT INTO dbo.FactEvaluaciones
        (
            id_evaluacion_bk, sk_fecha_evaluacion, sk_cliente, sk_empleado,
            id_objetivo_bk, peso, altura, grasa_corporal, masa_muscular
        )
        SELECT
            ev.id_evaluacion_bk,
            mf.sk_fecha,
            c.sk_cliente,
            e.sk_empleado,
            ev.id_objetivo_bk,
            CASE
                WHEN ev.peso BETWEEN 20 AND 200 THEN ev.peso
                WHEN ev.peso BETWEEN 200 AND 300 THEN ev.peso / 2.2
            END,
            CASE
                WHEN ev.altura BETWEEN 0.5 AND 2.5 THEN ev.altura
                WHEN ev.altura BETWEEN 100 AND 250 THEN ev.altura / 100.0
            END,
            CASE WHEN ev.grasa_corporal BETWEEN 0 AND 100 THEN ev.grasa_corporal END,
            CASE
                WHEN ev.masa_muscular > 0
                 AND ev.masa_muscular <= ISNULL(ev.peso, ev.masa_muscular)
                THEN ev.masa_muscular
            END
        FROM EvaluacionCanonica ev
        INNER JOIN #MapFecha mf0 ON mf0.sk_fecha_origen = ev.sk_fecha_evaluacion_origen
        INNER JOIN dbo.DimFecha mf ON mf.sk_fecha = mf0.sk_fecha
        INNER JOIN #MapCliente mc ON mc.sk_cliente_origen = ev.sk_cliente_origen
        INNER JOIN dbo.DimCliente c ON c.id_cliente_bk = mc.id_cliente_bk
        LEFT JOIN #MapEmpleado me ON me.sk_empleado_origen = ev.sk_empleado_origen
        LEFT JOIN dbo.DimEmpleado e ON e.id_empleado_bk = me.id_empleado_bk
        WHERE ev.rn = 1
          AND ev.OperacionCDC IN (2, 4);

        /* FactReclamos. */
        ;WITH ReclamoCanonico AS
        (
            SELECT *,
                   ROW_NUMBER() OVER
                   (
                       PARTITION BY id_reclamo_bk
                       ORDER BY StagingID DESC
                   ) AS rn
            FROM dbo.stg_atencion_reclamos
            WHERE EntidadOrigen = 'RECLAMO'
              AND id_reclamo_bk IS NOT NULL
        )
        INSERT INTO dbo.FactReclamos
        (
            id_reclamo_bk, sk_fecha_reclamo, sk_cliente, sk_empleado,
            categoria, estado, fecha_resolucion, dias_resolucion
        )
        SELECT
            r.id_reclamo_bk,
            mf.sk_fecha,
            c.sk_cliente,
            e.sk_empleado,
            CASE
                WHEN UPPER(LTRIM(RTRIM(r.categoria))) LIKE '%COBR%' THEN 'COBRO'
                WHEN UPPER(LTRIM(RTRIM(r.categoria))) LIKE '%SERV%' THEN 'SERVICIO'
                ELSE COALESCE(NULLIF(UPPER(LTRIM(RTRIM(r.categoria))), ''), 'NO ESPECIFICADA')
            END,
            CASE
                WHEN UPPER(LTRIM(RTRIM(r.estado))) LIKE '%RESUEL%' OR UPPER(LTRIM(RTRIM(r.estado))) LIKE '%CERR%' THEN 'RESUELTO'
                WHEN UPPER(LTRIM(RTRIM(r.estado))) LIKE '%PEND%' THEN 'PENDIENTE'
                ELSE 'NO ESPECIFICADO'
            END,
            CASE WHEN r.fecha_resolucion >= df.fecha THEN r.fecha_resolucion END,
            CASE
                WHEN r.fecha_resolucion >= df.fecha THEN DATEDIFF(DAY, df.fecha, r.fecha_resolucion)
            END
        FROM ReclamoCanonico r
        INNER JOIN #MapFecha mf0 ON mf0.sk_fecha_origen = r.sk_fecha_reclamo_origen
        INNER JOIN dbo.DimFecha df ON df.sk_fecha = mf0.sk_fecha
        INNER JOIN dbo.DimFecha mf ON mf.sk_fecha = mf0.sk_fecha
        INNER JOIN #MapCliente mc ON mc.sk_cliente_origen = r.sk_cliente_origen
        INNER JOIN dbo.DimCliente c ON c.id_cliente_bk = mc.id_cliente_bk
        LEFT JOIN #MapEmpleado me ON me.sk_empleado_origen = r.sk_empleado_origen
        LEFT JOIN dbo.DimEmpleado e ON e.id_empleado_bk = me.id_empleado_bk
        WHERE r.rn = 1
          AND r.OperacionCDC IN (2, 4);

        COMMIT TRANSACTION;

        SELECT 'DimFecha' AS Tabla, COUNT_BIG(*) AS Filas FROM dbo.DimFecha
        UNION ALL SELECT 'DimCliente', COUNT_BIG(*) FROM dbo.DimCliente
        UNION ALL SELECT 'DimEmpleado', COUNT_BIG(*) FROM dbo.DimEmpleado
        UNION ALL SELECT 'DimPlan', COUNT_BIG(*) FROM dbo.DimPlan
        UNION ALL SELECT 'DimPromocion', COUNT_BIG(*) FROM dbo.DimPromocion
        UNION ALL SELECT 'FactVentas', COUNT_BIG(*) FROM dbo.FactVentas
        UNION ALL SELECT 'FactMembresias', COUNT_BIG(*) FROM dbo.FactMembresias
        UNION ALL SELECT 'FactRenovaciones', COUNT_BIG(*) FROM dbo.FactRenovaciones
        UNION ALL SELECT 'FactAvisos', COUNT_BIG(*) FROM dbo.FactAvisos
        UNION ALL SELECT 'FactAsistencias', COUNT_BIG(*) FROM dbo.FactAsistencias
        UNION ALL SELECT 'FactObjetivos', COUNT_BIG(*) FROM dbo.FactObjetivos
        UNION ALL SELECT 'FactEvaluaciones', COUNT_BIG(*) FROM dbo.FactEvaluaciones
        UNION ALL SELECT 'FactReclamos', COUNT_BIG(*) FROM dbo.FactReclamos;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* Ejecución de la primera carga transformada. */
EXEC dbo.usp_Transformar_CargarDataMart @FechaCorte = '2026-09-29';
GO
