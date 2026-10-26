/*=============================================================================
  VIP CENTER FIT - ETAPA 4: TRANSFORMACIÓN Y CARGA DEL DATA MART

  Modelo vigente: arquitectura de 7 hechos (AEQUITECTURA BI v2, bloques
  M01/M02/M03 de la hoja MATRIZ BUS).

    M01 Comercial       dm_comercial.FactVentas
                        dm_comercial.FactMembresias        (absorbe renovaciones y avisos)
    M02 Entrenamiento   dm_entrenamiento.FactAsistencias
                        dm_entrenamiento.FactSesionesEntrenamiento
                        dm_entrenamiento.FactSeguimientoFisico
                                                           (absorbe objetivos, evaluaciones
                                                            y evaluaciones programadas)
    M03 Atención        dm_atencion.FactReclamos
                        dm_atencion.FactRetenciones

  Dimensiones conformadas (4): DimFecha, DimCliente, DimEmpleado, DimPlan.
  DimEmpleado se reestructura: la clave de negocio pasa a ser codigo_empleado y
  los atributos de bus son area, cargo (puesto) y el propio codigo.

  Este archivo tiene dos responsabilidades:

    1) INSTALACIÓN / DDL (idempotente)
       Crea la base, los esquemas, las dimensiones, los hechos, las FOREIGN KEY,
       los índices y la tabla de marca de agua ETL si no existen.

    2) RECONSTRUCCIÓN COMPLETA INICIAL
       Deja el Data Mart limpio y ejecuta una primera carga. Sólo se usa en el
       bootstrap. La operación normal (cada 10 minutos) ejecuta únicamente los
       procedimientos usp_Ingesta_CDC y usp_Transformar_CargarDataMart.

  usp_Transformar_CargarDataMart es INCREMENTAL y tiene tres fases:

    FASE A  Dimensiones (MERGE por clave de negocio).
    FASE B  Hechos de evento (MERGE por clave de negocio).
    FASE C  Snapshots diarios (FactMembresias y FactSeguimientoFisico), con
            grano (clave de negocio + fecha de corte). Los cortes se construyen
            día por día desde el inicio de cada contrato/objetivo; nunca se copia
            el estado actual hacia los días anteriores. Si el ETL se ejecuta dos
            veces el mismo día actualiza la misma fila. Una corrección histórica
            recalcula los cortes afectados.
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
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dq')
    EXEC('CREATE SCHEMA dq');
GO

/* -----------------------------------------------------------------------------
   Limpieza de las vistas y de los objetos del modelo anterior (11 hechos).
   Las vistas se recrean en 05; los hechos absorbidos desaparecen del DW.
   ----------------------------------------------------------------------------- */
IF OBJECT_ID('dbo.DM_Entrenamiento_BajoProgreso', 'V') IS NOT NULL DROP VIEW dbo.DM_Entrenamiento_BajoProgreso;
IF OBJECT_ID('dbo.DM_Entrenamiento_Accesos', 'V') IS NOT NULL DROP VIEW dbo.DM_Entrenamiento_Accesos;
IF OBJECT_ID('dbo.DM_Comercial_Promociones', 'V') IS NOT NULL DROP VIEW dbo.DM_Comercial_Promociones;
IF OBJECT_ID('dbo.DM_Entrenamiento_Progreso', 'V') IS NOT NULL DROP VIEW dbo.DM_Entrenamiento_Progreso;
IF OBJECT_ID('dbo.DM_Entrenamiento_Asistencia', 'V') IS NOT NULL DROP VIEW dbo.DM_Entrenamiento_Asistencia;
IF OBJECT_ID('dbo.DM_Entrenamiento_Cumplimiento', 'V') IS NOT NULL DROP VIEW dbo.DM_Entrenamiento_Cumplimiento;
IF OBJECT_ID('dbo.DM_Entrenamiento_Evaluaciones', 'V') IS NOT NULL DROP VIEW dbo.DM_Entrenamiento_Evaluaciones;
IF OBJECT_ID('dbo.DM_Atencion_Reclamos', 'V') IS NOT NULL DROP VIEW dbo.DM_Atencion_Reclamos;
IF OBJECT_ID('dbo.DM_Atencion_Recepcion', 'V') IS NOT NULL DROP VIEW dbo.DM_Atencion_Recepcion;
IF OBJECT_ID('dbo.DM_Atencion_Retencion', 'V') IS NOT NULL DROP VIEW dbo.DM_Atencion_Retencion;
IF OBJECT_ID('dbo.DM_Avisos_Cobertura', 'V') IS NOT NULL DROP VIEW dbo.DM_Avisos_Cobertura;
IF OBJECT_ID('dbo.DM_Comercial_Plan', 'V') IS NOT NULL DROP VIEW dbo.DM_Comercial_Plan;
IF OBJECT_ID('dbo.DM_Gerencia_Membresias', 'V') IS NOT NULL DROP VIEW dbo.DM_Gerencia_Membresias;
IF OBJECT_ID('dbo.DM_Gerencia_Ingresos', 'V') IS NOT NULL DROP VIEW dbo.DM_Gerencia_Ingresos;
IF OBJECT_ID('dbo.DM_Ventas_Gerencia', 'V') IS NOT NULL DROP VIEW dbo.DM_Ventas_Gerencia;
IF OBJECT_ID('dbo.DM_Rutinas_Entrenador', 'V') IS NOT NULL DROP VIEW dbo.DM_Rutinas_Entrenador;
IF OBJECT_ID('dbo.DM_Promociones_Ventas', 'V') IS NOT NULL DROP VIEW dbo.DM_Promociones_Ventas;
IF OBJECT_ID('dbo.DM_Promociones_Membresias', 'V') IS NOT NULL DROP VIEW dbo.DM_Promociones_Membresias;
IF OBJECT_ID('dbo.DM_Promociones_Clientes', 'V') IS NOT NULL DROP VIEW dbo.DM_Promociones_Clientes;
GO

/* Sinónimos del modelo anterior. Se recrean al final del bloque DDL. */
DROP SYNONYM IF EXISTS dbo.FactRenovaciones;
DROP SYNONYM IF EXISTS dbo.FactAvisos;
DROP SYNONYM IF EXISTS dbo.FactObjetivos;
DROP SYNONYM IF EXISTS dbo.FactEvaluaciones;
DROP SYNONYM IF EXISTS dbo.FactEvaluacionesProgramadas;
DROP SYNONYM IF EXISTS dbo.FactSesionesProgramadas;
GO

/* Hechos absorbidos: se eliminan del DW. Primero sus FK. */
IF OBJECT_ID('dm_comercial.FactAvisos', 'U') IS NOT NULL
BEGIN
    ALTER TABLE dm_comercial.FactAvisos DROP CONSTRAINT IF EXISTS FK_FactAvisos_DimFecha;
    ALTER TABLE dm_comercial.FactAvisos DROP CONSTRAINT IF EXISTS FK_FactAvisos_DimCliente;
    ALTER TABLE dm_comercial.FactAvisos DROP CONSTRAINT IF EXISTS FK_FactAvisos_DimEmpleado;
    DROP TABLE dm_comercial.FactAvisos;
END;
GO

IF OBJECT_ID('dm_comercial.FactRenovaciones', 'U') IS NOT NULL
BEGIN
    ALTER TABLE dm_comercial.FactRenovaciones DROP CONSTRAINT IF EXISTS FK_FactRenovaciones_DimFecha;
    ALTER TABLE dm_comercial.FactRenovaciones DROP CONSTRAINT IF EXISTS FK_FactRenovaciones_DimCliente;
    ALTER TABLE dm_comercial.FactRenovaciones DROP CONSTRAINT IF EXISTS FK_FactRenovaciones_DimEmpleado;
    DROP TABLE dm_comercial.FactRenovaciones;
END;
GO

IF OBJECT_ID('dm_entrenamiento.FactObjetivos', 'U') IS NOT NULL
BEGIN
    ALTER TABLE dm_entrenamiento.FactObjetivos DROP CONSTRAINT IF EXISTS FK_FactObjetivos_DimFecha;
    ALTER TABLE dm_entrenamiento.FactObjetivos DROP CONSTRAINT IF EXISTS FK_FactObjetivos_DimCliente;
    DROP TABLE dm_entrenamiento.FactObjetivos;
END;
GO

IF OBJECT_ID('dm_entrenamiento.FactEvaluaciones', 'U') IS NOT NULL
BEGIN
    ALTER TABLE dm_entrenamiento.FactEvaluaciones DROP CONSTRAINT IF EXISTS FK_FactEvaluaciones_DimFecha;
    ALTER TABLE dm_entrenamiento.FactEvaluaciones DROP CONSTRAINT IF EXISTS FK_FactEvaluaciones_DimCliente;
    ALTER TABLE dm_entrenamiento.FactEvaluaciones DROP CONSTRAINT IF EXISTS FK_FactEvaluaciones_DimEmpleado;
    DROP TABLE dm_entrenamiento.FactEvaluaciones;
END;
GO

IF OBJECT_ID('dm_entrenamiento.FactEvaluacionesProgramadas', 'U') IS NOT NULL
BEGIN
    ALTER TABLE dm_entrenamiento.FactEvaluacionesProgramadas DROP CONSTRAINT IF EXISTS FK_FactEvaluacionesProgramadas_DimFecha;
    ALTER TABLE dm_entrenamiento.FactEvaluacionesProgramadas DROP CONSTRAINT IF EXISTS FK_FactEvaluacionesProgramadas_DimCliente;
    ALTER TABLE dm_entrenamiento.FactEvaluacionesProgramadas DROP CONSTRAINT IF EXISTS FK_FactEvaluacionesProgramadas_DimEmpleado;
    DROP TABLE dm_entrenamiento.FactEvaluacionesProgramadas;
END;
GO

/* FactSesionesProgramadas se renombra a FactSesionesEntrenamiento. */
IF OBJECT_ID('dm_entrenamiento.FactSesionesProgramadas', 'U') IS NOT NULL
   AND OBJECT_ID('dm_entrenamiento.FactSesionesEntrenamiento', 'U') IS NULL
BEGIN
    EXEC sp_rename 'dm_entrenamiento.FactSesionesProgramadas', 'FactSesionesEntrenamiento';
END;
GO

/* -----------------------------------------------------------------------------
   Dimensiones conformadas (esquema compartido por los 3 data mart).
   ----------------------------------------------------------------------------- */
IF OBJECT_ID('dim.DimFecha', 'U') IS NULL
CREATE TABLE dim.DimFecha
(
    sk_fecha INT NOT NULL CONSTRAINT PK_DimFecha PRIMARY KEY,
    fecha DATE NOT NULL CONSTRAINT UQ_DimFecha_Fecha UNIQUE,
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
    sk_cliente INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimCliente PRIMARY KEY,
    sk_cliente_origen INT NULL,
    id_cliente_bk INT NOT NULL CONSTRAINT UQ_DimCliente_IdClienteBk UNIQUE,
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

/* DimEmpleado reestructurada: codigo_empleado es la clave de negocio visible
   en el bus; area y cargo son los atributos de análisis. El nombre se conserva
   porque el modelo semántico de Power BI sigue filtrando por "Empleado: nombre". */
IF OBJECT_ID('dim.DimEmpleado', 'U') IS NULL
CREATE TABLE dim.DimEmpleado
(
    sk_empleado INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimEmpleado PRIMARY KEY,
    sk_empleado_origen INT NULL,
    id_empleado_bk INT NOT NULL CONSTRAINT UQ_DimEmpleado_IdEmpleadoBk UNIQUE,
    codigo_empleado VARCHAR(20) NOT NULL,
    dni VARCHAR(20) NULL,
    nombre_completo VARCHAR(250) NOT NULL,
    cargo VARCHAR(60) NOT NULL,
    area VARCHAR(60) NOT NULL
);
GO

IF COL_LENGTH('dim.DimEmpleado', 'codigo_empleado') IS NULL
    ALTER TABLE dim.DimEmpleado ADD codigo_empleado VARCHAR(20) NULL;
GO

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dim.DimEmpleado') AND name = 'codigo_empleado' AND is_nullable = 1)
    ALTER TABLE dim.DimEmpleado ALTER COLUMN codigo_empleado VARCHAR(20) NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_DimEmpleado_Codigo' AND object_id = OBJECT_ID('dim.DimEmpleado'))
    CREATE UNIQUE INDEX UQ_DimEmpleado_Codigo ON dim.DimEmpleado(codigo_empleado);
GO

IF OBJECT_ID('dim.DimPlan', 'U') IS NULL
CREATE TABLE dim.DimPlan
(
    sk_plan INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimPlan PRIMARY KEY,
    tipo_plan VARCHAR(40) NOT NULL,
    tipo_operacion VARCHAR(40) NOT NULL,
    promocion VARCHAR(100) NOT NULL,
    CONSTRAINT UQ_DimPlan_Combinacion UNIQUE (tipo_plan, tipo_operacion, promocion)
);
GO

/* -----------------------------------------------------------------------------
   Miembros centinela (-1): imputación de hechos que no resuelven su dimensión.
   ----------------------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM dim.DimFecha WHERE sk_fecha = -1)
    INSERT dim.DimFecha (sk_fecha, fecha, anio, trimestre, semestre, mes, nombre_mes, dia, dia_semana, es_fin_de_semana)
    VALUES (-1, '1900-01-01', 1900, 1, 1, 1, 'Enero', 1, 'Lunes', 0);
GO

IF NOT EXISTS (SELECT 1 FROM dim.DimCliente WHERE sk_cliente = -1)
BEGIN
    SET IDENTITY_INSERT dim.DimCliente ON;
    INSERT dim.DimCliente (sk_cliente, sk_cliente_origen, id_cliente_bk, dni, nombre_completo, sexo, rango_etario,
                           estado_cliente, fecha_registro_origen, fecha_inicio_validez, fecha_fin_validez, es_actual)
    VALUES (-1, NULL, -1, NULL, 'CLIENTE NO IDENTIFICADO', 'X', NULL, 'INACTIVO', NULL, NULL, NULL, 1);
    SET IDENTITY_INSERT dim.DimCliente OFF;
END
GO

IF NOT EXISTS (SELECT 1 FROM dim.DimEmpleado WHERE sk_empleado = -1)
BEGIN
    SET IDENTITY_INSERT dim.DimEmpleado ON;
    INSERT dim.DimEmpleado (sk_empleado, sk_empleado_origen, id_empleado_bk, codigo_empleado,
                            dni, nombre_completo, cargo, area)
    VALUES (-1, NULL, -1, 'SIN-CODIGO', NULL, 'SIN EMPLEADO', 'NO ESPECIFICADO', 'NO ESPECIFICADO');
    SET IDENTITY_INSERT dim.DimEmpleado OFF;
END
GO

IF NOT EXISTS (SELECT 1 FROM dim.DimPlan WHERE sk_plan = -1)
BEGIN
    SET IDENTITY_INSERT dim.DimPlan ON;
    INSERT dim.DimPlan (sk_plan, tipo_plan, tipo_operacion, promocion)
    VALUES (-1, 'NO_APLICA', 'NO_ESPECIFICADO', 'SIN PROMOCION');
    SET IDENTITY_INSERT dim.DimPlan OFF;
END
GO

/* -----------------------------------------------------------------------------
   Hechos de cada data mart.
   ----------------------------------------------------------------------------- */
IF OBJECT_ID('dm_comercial.FactVentas', 'U') IS NULL
CREATE TABLE dm_comercial.FactVentas
(
    sk_venta BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_FactVentas PRIMARY KEY,
    id_pago_bk INT NOT NULL CONSTRAINT UQ_FactVentas_IdPagoBk UNIQUE,
    sk_fecha_pago INT NOT NULL,
    sk_cliente INT NOT NULL,
    sk_plan INT NOT NULL,
    sk_empleado INT NOT NULL,
    id_membresia_bk INT NULL,
    monto_neto DECIMAL(12,2) NOT NULL,
    descuento_aplicado DECIMAL(12,2) NULL,
    precio_lista DECIMAL(12,2) NULL,
    metodo_pago VARCHAR(50) NOT NULL
);
GO

/* Grano: una membresía de un cliente en una fecha de corte diaria.
   Conserva inicio, fin y el enlace con el contrato anterior/nuevo (cohortes).
   Absorbe FactRenovaciones (enlace y monto) y FactAvisos (aviso del corte). */
IF OBJECT_ID('dm_comercial.FactMembresias', 'U') IS NULL
CREATE TABLE dm_comercial.FactMembresias
(
    sk_membresia BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_FactMembresias PRIMARY KEY,
    id_membresia_bk INT NOT NULL,
    sk_fecha_corte INT NOT NULL,
    sk_cliente INT NOT NULL,
    sk_plan INT NOT NULL,
    sk_empleado INT NOT NULL,
    sk_fecha_inicio INT NOT NULL,
    sk_fecha_fin INT NOT NULL,
    duracion_dias INT NULL,
    precio_final DECIMAL(12,2) NULL,
    estado_membresia VARCHAR(30) NOT NULL,
    dias_desde_vencimiento INT NULL,
    es_renovacion BIT NOT NULL,
    id_membresia_anterior_bk INT NULL,
    id_membresia_nueva_bk INT NULL,
    sk_fecha_renovacion INT NULL,
    dias_anticipacion_renovacion INT NULL,
    monto_renovacion DECIMAL(12,2) NULL,
    aviso_emitido BIT NOT NULL,
    sk_fecha_aviso INT NULL,
    dias_antes_vencimiento INT NULL,
    medio_aviso VARCHAR(30) NULL,
    estado_aviso VARCHAR(30) NULL,
    avisos_emitidos_dia INT NOT NULL,
    CONSTRAINT UQ_FactMembresias_Grano UNIQUE (id_membresia_bk, sk_fecha_corte)
);
GO

IF OBJECT_ID('dm_entrenamiento.FactAsistencias', 'U') IS NULL
CREATE TABLE dm_entrenamiento.FactAsistencias
(
    sk_asistencia BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_FactAsistencias PRIMARY KEY,
    id_asistencia_bk INT NOT NULL CONSTRAINT UQ_FactAsistencias_IdAsistenciaBk UNIQUE,
    sk_fecha_asistencia INT NOT NULL,
    sk_cliente INT NOT NULL,
    sk_plan INT NOT NULL,
    sk_empleado INT NOT NULL,
    hora_ingreso INT NULL,
    cantidad_asistencias INT NOT NULL,
    es_acceso_valido BIT NOT NULL
);
GO

IF COL_LENGTH('dm_entrenamiento.FactAsistencias', 'es_acceso_valido') IS NULL
    ALTER TABLE dm_entrenamiento.FactAsistencias ADD es_acceso_valido BIT NULL;
GO

/* Grano: una sesión programada (incluye programación, cancelación y resultado). */
IF OBJECT_ID('dm_entrenamiento.FactSesionesEntrenamiento', 'U') IS NULL
CREATE TABLE dm_entrenamiento.FactSesionesEntrenamiento
(
    sk_sesion BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_FactSesionesEntrenamiento PRIMARY KEY,
    id_sesion_bk INT NOT NULL CONSTRAINT UQ_FactSesionesEntrenamiento_IdSesionBk UNIQUE,
    sk_fecha_programada INT NOT NULL,
    sk_cliente INT NOT NULL,
    sk_plan INT NOT NULL,
    sk_empleado INT NOT NULL,
    tipo_sesion VARCHAR(40) NOT NULL,
    hora_programada INT NULL,
    estado_sesion VARCHAR(30) NOT NULL,
    asistio BIT NOT NULL,
    duracion_minutos INT NULL,
    sk_fecha_cancelacion INT NULL,
    motivo_cancelacion VARCHAR(60) NULL
);
GO

IF COL_LENGTH('dm_entrenamiento.FactSesionesEntrenamiento', 'asistio') IS NULL
    ALTER TABLE dm_entrenamiento.FactSesionesEntrenamiento ADD asistio BIT NULL;
IF COL_LENGTH('dm_entrenamiento.FactSesionesEntrenamiento', 'sk_fecha_cancelacion') IS NULL
    ALTER TABLE dm_entrenamiento.FactSesionesEntrenamiento ADD sk_fecha_cancelacion INT NULL;
IF COL_LENGTH('dm_entrenamiento.FactSesionesEntrenamiento', 'motivo_cancelacion') IS NULL
    ALTER TABLE dm_entrenamiento.FactSesionesEntrenamiento ADD motivo_cancelacion VARCHAR(60) NULL;
GO

/* Grano: un cliente, un objetivo y una fecha de corte diaria.
   Consolida objetivos, evaluaciones y evaluaciones programadas. */
IF OBJECT_ID('dm_entrenamiento.FactSeguimientoFisico', 'U') IS NULL
CREATE TABLE dm_entrenamiento.FactSeguimientoFisico
(
    sk_seguimiento BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_FactSeguimientoFisico PRIMARY KEY,
    id_objetivo_bk INT NOT NULL,
    sk_cliente INT NOT NULL,
    sk_empleado INT NOT NULL,
    sk_fecha_corte INT NOT NULL,
    sk_fecha_inicio INT NOT NULL,
    sk_fecha_meta INT NOT NULL,
    id_evaluacion_bk INT NULL,
    id_evaluacion_programada_bk INT NULL,
    tipo_objetivo VARCHAR(60) NOT NULL,
    unidad_medida VARCHAR(30) NOT NULL,
    estado_objetivo VARCHAR(30) NOT NULL,
    valor_inicial DECIMAL(10,2) NULL,
    valor_actual DECIMAL(10,2) NULL,
    valor_esperado DECIMAL(10,2) NULL,
    avance_alcanzado DECIMAL(10,2) NULL,
    avance_esperado DECIMAL(10,2) NULL,
    porcentaje_progreso DECIMAL(9,2) NULL,
    peso DECIMAL(8,2) NULL,
    altura DECIMAL(8,2) NULL,
    grasa_corporal DECIMAL(8,2) NULL,
    masa_muscular DECIMAL(8,2) NULL,
    evaluacion_exigible BIT NOT NULL,
    evaluacion_completada BIT NOT NULL,
    evaluacion_pendiente BIT NOT NULL,
    estado_evaluacion VARCHAR(30) NOT NULL,
    CONSTRAINT UQ_FactSeguimientoFisico_Grano UNIQUE (sk_cliente, id_objetivo_bk, sk_fecha_corte)
);
GO

IF OBJECT_ID('dm_atencion.FactReclamos', 'U') IS NULL
CREATE TABLE dm_atencion.FactReclamos
(
    sk_reclamo BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_FactReclamos PRIMARY KEY,
    id_reclamo_bk INT NOT NULL CONSTRAINT UQ_FactReclamos_IdReclamoBk UNIQUE,
    sk_fecha_reclamo INT NOT NULL,
    sk_cliente INT NOT NULL,
    sk_empleado INT NOT NULL,
    categoria VARCHAR(60) NOT NULL,
    estado VARCHAR(30) NOT NULL,
    sk_fecha_resolucion INT NULL,
    sk_fecha_cierre INT NULL,
    dias_resolucion INT NULL,
    resuelto_en_mostrador BIT NULL,
    escalado BIT NOT NULL,
    area_responsable VARCHAR(60) NULL
);
GO

IF COL_LENGTH('dm_atencion.FactReclamos', 'sk_fecha_resolucion') IS NULL
    ALTER TABLE dm_atencion.FactReclamos ADD sk_fecha_resolucion INT NULL;
IF COL_LENGTH('dm_atencion.FactReclamos', 'sk_fecha_cierre') IS NULL
    ALTER TABLE dm_atencion.FactReclamos ADD sk_fecha_cierre INT NULL;
IF COL_LENGTH('dm_atencion.FactReclamos', 'escalado') IS NULL
    ALTER TABLE dm_atencion.FactReclamos ADD escalado BIT NULL;
IF COL_LENGTH('dm_atencion.FactReclamos', 'area_responsable') IS NULL
    ALTER TABLE dm_atencion.FactReclamos ADD area_responsable VARCHAR(60) NULL;
GO

IF OBJECT_ID('dm_atencion.FactRetenciones', 'U') IS NULL
CREATE TABLE dm_atencion.FactRetenciones
(
    sk_retencion BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_FactRetenciones PRIMARY KEY,
    id_retencion_bk INT NOT NULL CONSTRAINT UQ_FactRetenciones_IdRetencionBk UNIQUE,
    sk_fecha_retencion INT NOT NULL,
    sk_cliente INT NOT NULL,
    sk_empleado INT NOT NULL,
    sk_plan INT NOT NULL,
    id_membresia_bk INT NULL,
    sk_fecha_vencimiento INT NULL,
    canal VARCHAR(40) NOT NULL,
    motivo VARCHAR(60) NOT NULL,
    resultado VARCHAR(30) NOT NULL,
    recuperada BIT NOT NULL,
    monto_oferta DECIMAL(12,2) NULL
);
GO

IF COL_LENGTH('dm_atencion.FactRetenciones', 'sk_fecha_vencimiento') IS NULL
    ALTER TABLE dm_atencion.FactRetenciones ADD sk_fecha_vencimiento INT NULL;
IF COL_LENGTH('dm_atencion.FactRetenciones', 'recuperada') IS NULL
    ALTER TABLE dm_atencion.FactRetenciones ADD recuperada BIT NULL;
IF COL_LENGTH('dm_atencion.FactRetenciones', 'sk_plan') IS NULL
    ALTER TABLE dm_atencion.FactRetenciones ADD sk_plan INT NULL;
GO

/* -----------------------------------------------------------------------------
   FKs de hechos a centinelas: no se admiten NULL (imputación a -1).
   ----------------------------------------------------------------------------- */
UPDATE dm_comercial.FactVentas                    SET sk_empleado = -1 WHERE sk_empleado IS NULL;
UPDATE dm_comercial.FactMembresias                SET sk_empleado = -1 WHERE sk_empleado IS NULL;
UPDATE dm_entrenamiento.FactAsistencias           SET sk_plan = -1 WHERE sk_plan IS NULL;
UPDATE dm_entrenamiento.FactAsistencias           SET sk_empleado = -1 WHERE sk_empleado IS NULL;
UPDATE dm_entrenamiento.FactAsistencias           SET es_acceso_valido = 1 WHERE es_acceso_valido IS NULL;
UPDATE dm_entrenamiento.FactSesionesEntrenamiento SET sk_plan = -1 WHERE sk_plan IS NULL;
UPDATE dm_entrenamiento.FactSesionesEntrenamiento SET sk_empleado = -1 WHERE sk_empleado IS NULL;
UPDATE dm_entrenamiento.FactSesionesEntrenamiento SET asistio = 0 WHERE asistio IS NULL;
UPDATE dm_atencion.FactReclamos                   SET sk_empleado = -1 WHERE sk_empleado IS NULL;
UPDATE dm_atencion.FactReclamos                   SET escalado = 0 WHERE escalado IS NULL;
UPDATE dm_atencion.FactRetenciones              SET sk_empleado = -1 WHERE sk_empleado IS NULL;
UPDATE dm_atencion.FactRetenciones              SET sk_plan = -1 WHERE sk_plan IS NULL;
UPDATE dm_atencion.FactRetenciones              SET recuperada = 0 WHERE recuperada IS NULL;
GO

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dm_comercial.FactVentas') AND name = 'sk_empleado' AND is_nullable = 1)
    ALTER TABLE dm_comercial.FactVentas ALTER COLUMN sk_empleado INT NOT NULL;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dm_comercial.FactMembresias') AND name = 'sk_empleado' AND is_nullable = 1)
    ALTER TABLE dm_comercial.FactMembresias ALTER COLUMN sk_empleado INT NOT NULL;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dm_entrenamiento.FactAsistencias') AND name = 'sk_plan' AND is_nullable = 1)
    ALTER TABLE dm_entrenamiento.FactAsistencias ALTER COLUMN sk_plan INT NOT NULL;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dm_entrenamiento.FactAsistencias') AND name = 'sk_empleado' AND is_nullable = 1)
    ALTER TABLE dm_entrenamiento.FactAsistencias ALTER COLUMN sk_empleado INT NOT NULL;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dm_entrenamiento.FactAsistencias') AND name = 'es_acceso_valido' AND is_nullable = 1)
    ALTER TABLE dm_entrenamiento.FactAsistencias ALTER COLUMN es_acceso_valido BIT NOT NULL;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dm_entrenamiento.FactSesionesEntrenamiento') AND name = 'sk_plan' AND is_nullable = 1)
    ALTER TABLE dm_entrenamiento.FactSesionesEntrenamiento ALTER COLUMN sk_plan INT NOT NULL;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dm_entrenamiento.FactSesionesEntrenamiento') AND name = 'sk_empleado' AND is_nullable = 1)
    ALTER TABLE dm_entrenamiento.FactSesionesEntrenamiento ALTER COLUMN sk_empleado INT NOT NULL;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dm_entrenamiento.FactSesionesEntrenamiento') AND name = 'asistio' AND is_nullable = 1)
    ALTER TABLE dm_entrenamiento.FactSesionesEntrenamiento ALTER COLUMN asistio BIT NOT NULL;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dm_atencion.FactReclamos') AND name = 'sk_empleado' AND is_nullable = 1)
    ALTER TABLE dm_atencion.FactReclamos ALTER COLUMN sk_empleado INT NOT NULL;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dm_atencion.FactReclamos') AND name = 'escalado' AND is_nullable = 1)
    ALTER TABLE dm_atencion.FactReclamos ALTER COLUMN escalado BIT NOT NULL;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dm_atencion.FactRetenciones') AND name = 'sk_empleado' AND is_nullable = 1)
    ALTER TABLE dm_atencion.FactRetenciones ALTER COLUMN sk_empleado INT NOT NULL;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dm_atencion.FactRetenciones') AND name = 'sk_plan' AND is_nullable = 1)
    ALTER TABLE dm_atencion.FactRetenciones ALTER COLUMN sk_plan INT NOT NULL;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dm_atencion.FactRetenciones') AND name = 'recuperada' AND is_nullable = 1)
    ALTER TABLE dm_atencion.FactRetenciones ALTER COLUMN recuperada BIT NOT NULL;
GO

/* -----------------------------------------------------------------------------
   Marca de agua del ETL (staging -> Data Mart).
   ----------------------------------------------------------------------------- */
IF OBJECT_ID('dbo.etl_control', 'U') IS NULL
CREATE TABLE dbo.etl_control
(
    proceso SYSNAME NOT NULL CONSTRAINT PK_etl_control PRIMARY KEY,
    ultimo_staging_id BIGINT NOT NULL CONSTRAINT DF_etl_control_ultimo_staging_id DEFAULT (0),
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
        ('stg_atencion_reclamos', 0),
        ('snapshot_membresias', 0),
        ('snapshot_seguimiento', 0);
GO

IF NOT EXISTS (SELECT 1 FROM dbo.etl_control WHERE proceso = 'snapshot_membresias')
    INSERT INTO dbo.etl_control (proceso, ultimo_staging_id) VALUES ('snapshot_membresias', 0);
IF NOT EXISTS (SELECT 1 FROM dbo.etl_control WHERE proceso = 'snapshot_seguimiento')
    INSERT INTO dbo.etl_control (proceso, ultimo_staging_id) VALUES ('snapshot_seguimiento', 0);
GO

/* -----------------------------------------------------------------------------
   Calidad de datos: registro de filas imputadas por el ETL (ver docs/CALIDAD.md).
   ----------------------------------------------------------------------------- */
IF OBJECT_ID('dq.RegistroImputaciones', 'U') IS NULL
CREATE TABLE dq.RegistroImputaciones
(
    id_imputacion  BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
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
DROP SYNONYM IF EXISTS dbo.FactAsistencias;
DROP SYNONYM IF EXISTS dbo.FactSesionesEntrenamiento;
DROP SYNONYM IF EXISTS dbo.FactSeguimientoFisico;
DROP SYNONYM IF EXISTS dbo.FactReclamos;
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
CREATE SYNONYM dbo.FactAsistencias FOR dm_entrenamiento.FactAsistencias;
CREATE SYNONYM dbo.FactSesionesEntrenamiento FOR dm_entrenamiento.FactSesionesEntrenamiento;
CREATE SYNONYM dbo.FactSeguimientoFisico FOR dm_entrenamiento.FactSeguimientoFisico;
CREATE SYNONYM dbo.FactReclamos FOR dm_atencion.FactReclamos;
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
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactMembresias_DimFechaCorte')
    ALTER TABLE dm_comercial.FactMembresias ADD CONSTRAINT FK_FactMembresias_DimFechaCorte
        FOREIGN KEY (sk_fecha_corte) REFERENCES dim.DimFecha(sk_fecha);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactMembresias_DimFechaInicio')
    ALTER TABLE dm_comercial.FactMembresias ADD CONSTRAINT FK_FactMembresias_DimFechaInicio
        FOREIGN KEY (sk_fecha_inicio) REFERENCES dim.DimFecha(sk_fecha);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactMembresias_DimFechaFin')
    ALTER TABLE dm_comercial.FactMembresias ADD CONSTRAINT FK_FactMembresias_DimFechaFin
        FOREIGN KEY (sk_fecha_fin) REFERENCES dim.DimFecha(sk_fecha);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactMembresias_DimFechaRenovacion')
    ALTER TABLE dm_comercial.FactMembresias ADD CONSTRAINT FK_FactMembresias_DimFechaRenovacion
        FOREIGN KEY (sk_fecha_renovacion) REFERENCES dim.DimFecha(sk_fecha);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactMembresias_DimFechaAviso')
    ALTER TABLE dm_comercial.FactMembresias ADD CONSTRAINT FK_FactMembresias_DimFechaAviso
        FOREIGN KEY (sk_fecha_aviso) REFERENCES dim.DimFecha(sk_fecha);

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

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactSesionesEntrenamiento_DimFecha')
    ALTER TABLE dm_entrenamiento.FactSesionesEntrenamiento ADD CONSTRAINT FK_FactSesionesEntrenamiento_DimFecha
        FOREIGN KEY (sk_fecha_programada) REFERENCES dim.DimFecha(sk_fecha);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactSesionesEntrenamiento_DimCliente')
    ALTER TABLE dm_entrenamiento.FactSesionesEntrenamiento ADD CONSTRAINT FK_FactSesionesEntrenamiento_DimCliente
        FOREIGN KEY (sk_cliente) REFERENCES dim.DimCliente(sk_cliente);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactSesionesEntrenamiento_DimPlan')
    ALTER TABLE dm_entrenamiento.FactSesionesEntrenamiento ADD CONSTRAINT FK_FactSesionesEntrenamiento_DimPlan
        FOREIGN KEY (sk_plan) REFERENCES dim.DimPlan(sk_plan);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactSesionesEntrenamiento_DimEmpleado')
    ALTER TABLE dm_entrenamiento.FactSesionesEntrenamiento ADD CONSTRAINT FK_FactSesionesEntrenamiento_DimEmpleado
        FOREIGN KEY (sk_empleado) REFERENCES dim.DimEmpleado(sk_empleado);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactSesionesEntrenamiento_DimFechaCancelacion')
    ALTER TABLE dm_entrenamiento.FactSesionesEntrenamiento ADD CONSTRAINT FK_FactSesionesEntrenamiento_DimFechaCancelacion
        FOREIGN KEY (sk_fecha_cancelacion) REFERENCES dim.DimFecha(sk_fecha);

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactSeguimientoFisico_DimCliente')
    ALTER TABLE dm_entrenamiento.FactSeguimientoFisico ADD CONSTRAINT FK_FactSeguimientoFisico_DimCliente
        FOREIGN KEY (sk_cliente) REFERENCES dim.DimCliente(sk_cliente);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactSeguimientoFisico_DimEmpleado')
    ALTER TABLE dm_entrenamiento.FactSeguimientoFisico ADD CONSTRAINT FK_FactSeguimientoFisico_DimEmpleado
        FOREIGN KEY (sk_empleado) REFERENCES dim.DimEmpleado(sk_empleado);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactSeguimientoFisico_DimFechaCorte')
    ALTER TABLE dm_entrenamiento.FactSeguimientoFisico ADD CONSTRAINT FK_FactSeguimientoFisico_DimFechaCorte
        FOREIGN KEY (sk_fecha_corte) REFERENCES dim.DimFecha(sk_fecha);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactSeguimientoFisico_DimFechaInicio')
    ALTER TABLE dm_entrenamiento.FactSeguimientoFisico ADD CONSTRAINT FK_FactSeguimientoFisico_DimFechaInicio
        FOREIGN KEY (sk_fecha_inicio) REFERENCES dim.DimFecha(sk_fecha);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactSeguimientoFisico_DimFechaMeta')
    ALTER TABLE dm_entrenamiento.FactSeguimientoFisico ADD CONSTRAINT FK_FactSeguimientoFisico_DimFechaMeta
        FOREIGN KEY (sk_fecha_meta) REFERENCES dim.DimFecha(sk_fecha);

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactReclamos_DimFecha')
    ALTER TABLE dm_atencion.FactReclamos ADD CONSTRAINT FK_FactReclamos_DimFecha
        FOREIGN KEY (sk_fecha_reclamo) REFERENCES dim.DimFecha(sk_fecha);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactReclamos_DimCliente')
    ALTER TABLE dm_atencion.FactReclamos ADD CONSTRAINT FK_FactReclamos_DimCliente
        FOREIGN KEY (sk_cliente) REFERENCES dim.DimCliente(sk_cliente);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactReclamos_DimEmpleado')
    ALTER TABLE dm_atencion.FactReclamos ADD CONSTRAINT FK_FactReclamos_DimEmpleado
        FOREIGN KEY (sk_empleado) REFERENCES dim.DimEmpleado(sk_empleado);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactReclamos_DimFechaResolucion')
    ALTER TABLE dm_atencion.FactReclamos ADD CONSTRAINT FK_FactReclamos_DimFechaResolucion
        FOREIGN KEY (sk_fecha_resolucion) REFERENCES dim.DimFecha(sk_fecha);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactReclamos_DimFechaCierre')
    ALTER TABLE dm_atencion.FactReclamos ADD CONSTRAINT FK_FactReclamos_DimFechaCierre
        FOREIGN KEY (sk_fecha_cierre) REFERENCES dim.DimFecha(sk_fecha);

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactRetenciones_DimFecha')
    ALTER TABLE dm_atencion.FactRetenciones ADD CONSTRAINT FK_FactRetenciones_DimFecha
        FOREIGN KEY (sk_fecha_retencion) REFERENCES dim.DimFecha(sk_fecha);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactRetenciones_DimCliente')
    ALTER TABLE dm_atencion.FactRetenciones ADD CONSTRAINT FK_FactRetenciones_DimCliente
        FOREIGN KEY (sk_cliente) REFERENCES dim.DimCliente(sk_cliente);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactRetenciones_DimEmpleado')
    ALTER TABLE dm_atencion.FactRetenciones ADD CONSTRAINT FK_FactRetenciones_DimEmpleado
        FOREIGN KEY (sk_empleado) REFERENCES dim.DimEmpleado(sk_empleado);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactRetenciones_DimPlan')
    ALTER TABLE dm_atencion.FactRetenciones ADD CONSTRAINT FK_FactRetenciones_DimPlan
        FOREIGN KEY (sk_plan) REFERENCES dim.DimPlan(sk_plan);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_FactRetenciones_DimFechaVencimiento')
    ALTER TABLE dm_atencion.FactRetenciones ADD CONSTRAINT FK_FactRetenciones_DimFechaVencimiento
        FOREIGN KEY (sk_fecha_vencimiento) REFERENCES dim.DimFecha(sk_fecha);
GO

/* -----------------------------------------------------------------------------
   Índices de apoyo. El modelo anterior no tenía ninguno sobre los hechos.
   ----------------------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_FactVentas_Fecha' AND object_id = OBJECT_ID('dm_comercial.FactVentas'))
    CREATE INDEX IX_FactVentas_Fecha ON dm_comercial.FactVentas(sk_fecha_pago) INCLUDE (monto_neto, sk_plan, sk_cliente);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_FactMembresias_Corte' AND object_id = OBJECT_ID('dm_comercial.FactMembresias'))
    CREATE INDEX IX_FactMembresias_Corte ON dm_comercial.FactMembresias(sk_fecha_corte, estado_membresia)
        INCLUDE (id_membresia_bk, sk_cliente, sk_plan, sk_fecha_inicio, sk_fecha_fin, id_membresia_nueva_bk, aviso_emitido);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_FactAsistencias_Fecha' AND object_id = OBJECT_ID('dm_entrenamiento.FactAsistencias'))
    CREATE INDEX IX_FactAsistencias_Fecha ON dm_entrenamiento.FactAsistencias(sk_fecha_asistencia) INCLUDE (sk_cliente);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_FactSesiones_Fecha' AND object_id = OBJECT_ID('dm_entrenamiento.FactSesionesEntrenamiento'))
    CREATE INDEX IX_FactSesiones_Fecha ON dm_entrenamiento.FactSesionesEntrenamiento(sk_fecha_programada) INCLUDE (sk_cliente, estado_sesion, asistio);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_FactSeguimiento_Corte' AND object_id = OBJECT_ID('dm_entrenamiento.FactSeguimientoFisico'))
    CREATE INDEX IX_FactSeguimiento_Corte ON dm_entrenamiento.FactSeguimientoFisico(sk_fecha_corte, id_objetivo_bk)
        INCLUDE (sk_cliente, valor_inicial, valor_actual, valor_esperado, porcentaje_progreso, evaluacion_pendiente);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_FactReclamos_Fecha' AND object_id = OBJECT_ID('dm_atencion.FactReclamos'))
    CREATE INDEX IX_FactReclamos_Fecha ON dm_atencion.FactReclamos(sk_fecha_reclamo) INCLUDE (categoria, estado, resuelto_en_mostrador);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_FactRetenciones_Fecha' AND object_id = OBJECT_ID('dm_atencion.FactRetenciones'))
    CREATE INDEX IX_FactRetenciones_Fecha ON dm_atencion.FactRetenciones(sk_fecha_retencion) INCLUDE (id_membresia_bk, resultado, recuperada);
GO

/* =============================================================================
   ETL INCREMENTAL: staging -> Data Mart

   - Sólo procesa las filas del staging con StagingID > marca de agua.
   - MERGE por clave de negocio en dimensiones y hechos de evento.
   - Snapshots diarios por (clave de negocio + fecha de corte):
       * la serie arranca en el inicio del contrato/objetivo;
       * el estado se calcula para cada corte, nunca se copia el actual;
       * re-ejecutar el mismo día actualiza la misma fila;
       * una corrección histórica recalcula los cortes afectados;
       * las membresías vencidas se conservan @DiasObservacion días para poder
         observar renovación y recuperación.
   - Los borrados (OperacionCDC = 1) se aplican: baja física en hechos y baja
     lógica (es_actual = 0) en DimCliente.
   - Dimensiones primero y hechos después, para respetar las FOREIGN KEY.
   - Todo dentro de una transacción: si falla, no avanza la marca de agua.
   ============================================================================= */
CREATE OR ALTER PROCEDURE dbo.usp_Transformar_CargarDataMart
    @FechaCorte DATE = NULL,
    @RecalcularDesde DATE = NULL,
    @DiasObservacion INT = 90
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET DATEFIRST 1;

    /* Corte de análisis: si no se indica, se usa la fecha de hoy acotada al
       último día disponible en DimFecha (evita saltar al final del calendario). */
    DECLARE @Corte DATE = COALESCE(@FechaCorte, CAST(SYSDATETIME() AS DATE));
    DECLARE @UltimaFechaDisponible DATE =
        (SELECT MAX(fecha) FROM dbo.stg_fecha WHERE fecha BETWEEN '2000-01-01' AND '2100-12-31');

    IF @UltimaFechaDisponible IS NOT NULL AND @Corte > @UltimaFechaDisponible
        SET @Corte = @UltimaFechaDisponible;
    IF @UltimaFechaDisponible IS NULL
        SET @Corte = CAST(SYSDATETIME() AS DATE);

    IF @DiasObservacion IS NULL OR @DiasObservacion < 0 SET @DiasObservacion = 90;

    /* Límites de la marca de agua por tabla de staging. */
    DECLARE @DesdeFecha BIGINT, @HastaFecha BIGINT;
    DECLARE @DesdeCli   BIGINT, @HastaCli   BIGINT;
    DECLARE @DesdeEmp   BIGINT, @HastaEmp   BIGINT;
    DECLARE @DesdePla   BIGINT, @HastaPla   BIGINT;
    DECLARE @DesdeVM    BIGINT, @HastaVM    BIGINT;
    DECLARE @DesdeEnt   BIGINT, @HastaEnt   BIGINT;
    DECLARE @DesdeRec   BIGINT, @HastaRec   BIGINT;

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

        /* =====================================================================
           FASE A - DIMENSIONES
           ===================================================================== */

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
                CASE WHEN fecha_registro_origen BETWEEN '2000-01-01' AND @Corte THEN fecha_registro_origen END AS fecha_registro_origen,
                CASE WHEN fecha_inicio_validez BETWEEN '2000-01-01' AND @Corte THEN fecha_inicio_validez END AS fecha_inicio_validez,
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
                dc.fecha_fin_validez = COALESCE(dc.fecha_fin_validez, @Corte)
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

        /* -------- DIMENSIÓN EMPLEADO (SCD1, reestructurada) -------- */
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
                COALESCE(NULLIF(UPPER(LTRIM(RTRIM(codigo_empleado))), ''),
                         'EMP-' + RIGHT('000' + CAST(id_empleado_bk AS VARCHAR(6)), 3)) AS codigo_empleado,
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
            t.codigo_empleado = s.codigo_empleado,
            t.dni = s.dni,
            t.nombre_completo = s.nombre_completo,
            t.cargo = s.cargo,
            t.area = s.area
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (sk_empleado_origen, id_empleado_bk, codigo_empleado, dni, nombre_completo, cargo, area)
            VALUES (s.sk_empleado_origen, s.id_empleado_bk, s.codigo_empleado, s.dni, s.nombre_completo, s.cargo, s.area);

        /* -------- DIMENSIÓN PLAN (Plan + Operación + Promoción) -------- */
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
        IF OBJECT_ID('tempdb..#MapCliente') IS NOT NULL DROP TABLE #MapCliente;
        SELECT sk_cliente_origen, MAX(id_cliente_bk) AS id_cliente_bk
        INTO #MapCliente
        FROM dbo.stg_clientes
        WHERE sk_cliente_origen IS NOT NULL AND id_cliente_bk IS NOT NULL
        GROUP BY sk_cliente_origen;

        IF OBJECT_ID('tempdb..#MapEmpleado') IS NOT NULL DROP TABLE #MapEmpleado;
        SELECT sk_empleado_origen, MAX(id_empleado_bk) AS id_empleado_bk
        INTO #MapEmpleado
        FROM dbo.stg_empleados
        WHERE sk_empleado_origen IS NOT NULL AND id_empleado_bk IS NOT NULL
        GROUP BY sk_empleado_origen;

        IF OBJECT_ID('tempdb..#MapFecha') IS NOT NULL DROP TABLE #MapFecha;
        SELECT sk_fecha_origen, CONVERT(INT, CONVERT(CHAR(8), MIN(fecha), 112)) AS sk_fecha
        INTO #MapFecha
        FROM dbo.stg_fecha
        WHERE sk_fecha_origen IS NOT NULL AND fecha IS NOT NULL
          AND fecha >= '2000-01-01' AND fecha <= '2100-12-31'
        GROUP BY sk_fecha_origen;

        /* -------- CALIDAD: registrar imputaciones a centinelas -------- */
        ;WITH Imputaciones AS
        (
            SELECT 'IMP-01' AS codigo_regla, 'DimCliente' AS entidad, 'id_cliente_bk' AS campo,
                   c.StagingID AS staging_id, NULL AS bk, NULL AS valor,
                   'Miembro excluido: cliente sin clave de negocio (id_cliente_bk NULL)' AS motivo
            FROM dbo.stg_clientes c
            WHERE c.StagingID > @DesdeCli AND c.StagingID <= @HastaCli AND c.id_cliente_bk IS NULL
            UNION ALL
            SELECT 'IMP-02', 'DimFecha', 'fecha', f.StagingID, NULL, CAST(f.fecha AS VARCHAR(200)),
                   'Miembro excluido: fecha fuera de rango [2000-01-01, 2100-12-31]'
            FROM dbo.stg_fecha f
            WHERE f.StagingID > @DesdeFecha AND f.StagingID <= @HastaFecha
              AND (f.fecha IS NULL OR f.fecha < '2000-01-01' OR f.fecha > '2100-12-31')
            UNION ALL
            SELECT 'IMP-03', 'FactVentas', 'sk_cliente', v.StagingID, CAST(v.id_pago_bk AS VARCHAR(40)),
                   CAST(v.sk_cliente_origen AS VARCHAR(200)), 'Imputado al cliente centinela (-1)'
            FROM dbo.stg_ventas_membresias v
            LEFT JOIN #MapCliente mc ON mc.sk_cliente_origen = v.sk_cliente_origen
            WHERE v.EntidadOrigen = 'VENTA' AND v.id_pago_bk IS NOT NULL
              AND v.StagingID > @DesdeVM AND v.StagingID <= @HastaVM AND v.OperacionCDC IN (2, 4)
              AND (v.sk_cliente_origen IS NULL OR mc.id_cliente_bk IS NULL)
            UNION ALL
            SELECT 'IMP-04', 'FactVentas', 'sk_fecha_pago', v.StagingID, CAST(v.id_pago_bk AS VARCHAR(40)),
                   CAST(v.sk_fecha_pago_origen AS VARCHAR(200)), 'Imputado a la fecha centinela (-1)'
            FROM dbo.stg_ventas_membresias v
            LEFT JOIN #MapFecha mf ON mf.sk_fecha_origen = v.sk_fecha_pago_origen
            WHERE v.EntidadOrigen = 'VENTA' AND v.id_pago_bk IS NOT NULL
              AND v.StagingID > @DesdeVM AND v.StagingID <= @HastaVM AND v.OperacionCDC IN (2, 4)
              AND mf.sk_fecha IS NULL
            UNION ALL
            SELECT 'IMP-05', 'FactMembresias', 'sk_cliente', m.StagingID, CAST(m.id_membresia_bk AS VARCHAR(40)),
                   CAST(m.sk_cliente_origen AS VARCHAR(200)), 'Imputado al cliente centinela (-1)'
            FROM dbo.stg_ventas_membresias m
            LEFT JOIN #MapCliente mc ON mc.sk_cliente_origen = m.sk_cliente_origen
            WHERE m.EntidadOrigen = 'MEMBRESIA' AND m.id_membresia_bk IS NOT NULL
              AND m.StagingID > @DesdeVM AND m.StagingID <= @HastaVM AND m.OperacionCDC IN (2, 4)
              AND (m.sk_cliente_origen IS NULL OR mc.id_cliente_bk IS NULL)
            UNION ALL
            SELECT 'IMP-06', 'FactMembresias', 'sk_fecha_inicio', m.StagingID, CAST(m.id_membresia_bk AS VARCHAR(40)),
                   CAST(m.sk_fecha_inicio_origen AS VARCHAR(200)), 'Imputado a la fecha centinela (-1)'
            FROM dbo.stg_ventas_membresias m
            LEFT JOIN #MapFecha mfi ON mfi.sk_fecha_origen = m.sk_fecha_inicio_origen
            WHERE m.EntidadOrigen = 'MEMBRESIA' AND m.id_membresia_bk IS NOT NULL
              AND m.StagingID > @DesdeVM AND m.StagingID <= @HastaVM AND m.OperacionCDC IN (2, 4)
              AND mfi.sk_fecha IS NULL
            UNION ALL
            SELECT 'IMP-07', 'FactAsistencias', 'sk_cliente', a.StagingID, CAST(a.id_asistencia_bk AS VARCHAR(40)),
                   CAST(a.sk_cliente_origen AS VARCHAR(200)), 'Imputado al cliente centinela (-1)'
            FROM dbo.stg_entrenamiento a
            LEFT JOIN #MapCliente mc ON mc.sk_cliente_origen = a.sk_cliente_origen
            WHERE a.EntidadOrigen = 'ASISTENCIA' AND a.id_asistencia_bk IS NOT NULL
              AND a.StagingID > @DesdeEnt AND a.StagingID <= @HastaEnt AND a.OperacionCDC IN (2, 4)
              AND (a.sk_cliente_origen IS NULL OR mc.id_cliente_bk IS NULL)
            UNION ALL
            SELECT 'IMP-08', 'FactAsistencias', 'sk_fecha_asistencia', a.StagingID, CAST(a.id_asistencia_bk AS VARCHAR(40)),
                   CAST(a.sk_fecha_asistencia_origen AS VARCHAR(200)), 'Imputado a la fecha centinela (-1)'
            FROM dbo.stg_entrenamiento a
            LEFT JOIN #MapFecha mf ON mf.sk_fecha_origen = a.sk_fecha_asistencia_origen
            WHERE a.EntidadOrigen = 'ASISTENCIA' AND a.id_asistencia_bk IS NOT NULL
              AND a.StagingID > @DesdeEnt AND a.StagingID <= @HastaEnt AND a.OperacionCDC IN (2, 4)
              AND mf.sk_fecha IS NULL
            UNION ALL
            SELECT 'IMP-09', 'FactReclamos', 'sk_cliente', r.StagingID, CAST(r.id_reclamo_bk AS VARCHAR(40)),
                   CAST(r.sk_cliente_origen AS VARCHAR(200)), 'Imputado al cliente centinela (-1)'
            FROM dbo.stg_atencion_reclamos r
            LEFT JOIN #MapCliente mc ON mc.sk_cliente_origen = r.sk_cliente_origen
            WHERE r.EntidadOrigen = 'RECLAMO' AND r.id_reclamo_bk IS NOT NULL
              AND r.StagingID > @DesdeRec AND r.StagingID <= @HastaRec AND r.OperacionCDC IN (2, 4)
              AND (r.sk_cliente_origen IS NULL OR mc.id_cliente_bk IS NULL)
            UNION ALL
            SELECT 'IMP-10', 'FactReclamos', 'sk_fecha_reclamo', r.StagingID, CAST(r.id_reclamo_bk AS VARCHAR(40)),
                   CAST(r.sk_fecha_reclamo_origen AS VARCHAR(200)), 'Imputado a la fecha centinela (-1)'
            FROM dbo.stg_atencion_reclamos r
            LEFT JOIN #MapFecha mf ON mf.sk_fecha_origen = r.sk_fecha_reclamo_origen
            WHERE r.EntidadOrigen = 'RECLAMO' AND r.id_reclamo_bk IS NOT NULL
              AND r.StagingID > @DesdeRec AND r.StagingID <= @HastaRec AND r.OperacionCDC IN (2, 4)
              AND mf.sk_fecha IS NULL
            UNION ALL
            SELECT 'IMP-11', 'FactRetenciones', 'sk_cliente', rt.StagingID, CAST(rt.id_retencion_bk AS VARCHAR(40)),
                   CAST(rt.sk_cliente_origen AS VARCHAR(200)), 'Imputado al cliente centinela (-1)'
            FROM dbo.stg_atencion_reclamos rt
            LEFT JOIN #MapCliente mc ON mc.sk_cliente_origen = rt.sk_cliente_origen
            WHERE rt.EntidadOrigen = 'RETENCION' AND rt.id_retencion_bk IS NOT NULL
              AND rt.StagingID > @DesdeRec AND rt.StagingID <= @HastaRec AND rt.OperacionCDC IN (2, 4)
              AND (rt.sk_cliente_origen IS NULL OR mc.id_cliente_bk IS NULL)
            UNION ALL
            SELECT 'IMP-12', 'FactRetenciones', 'sk_fecha_retencion', rt.StagingID, CAST(rt.id_retencion_bk AS VARCHAR(40)),
                   CAST(rt.sk_fecha_retencion_origen AS VARCHAR(200)), 'Imputado a la fecha centinela (-1)'
            FROM dbo.stg_atencion_reclamos rt
            LEFT JOIN #MapFecha mf ON mf.sk_fecha_origen = rt.sk_fecha_retencion_origen
            WHERE rt.EntidadOrigen = 'RETENCION' AND rt.id_retencion_bk IS NOT NULL
              AND rt.StagingID > @DesdeRec AND rt.StagingID <= @HastaRec AND rt.OperacionCDC IN (2, 4)
              AND mf.sk_fecha IS NULL
            UNION ALL
            SELECT 'IMP-13', 'DimEmpleado', 'codigo_empleado', e.StagingID, CAST(e.id_empleado_bk AS VARCHAR(40)),
                   NULL, 'Codigo de empleado ausente: derivado de id_empleado_bk'
            FROM dbo.stg_empleados e
            WHERE e.StagingID > @DesdeEmp AND e.StagingID <= @HastaEmp AND e.OperacionCDC IN (2, 4)
              AND NULLIF(LTRIM(RTRIM(e.codigo_empleado)), '') IS NULL
            UNION ALL
            SELECT 'IMP-14', 'FactSeguimientoFisico', 'sk_fecha_meta', o.StagingID, CAST(o.id_objetivo_bk AS VARCHAR(40)),
                   NULL, 'Objetivo sin fecha meta: valor esperado plano al valor objetivo'
            FROM dbo.stg_entrenamiento o
            WHERE o.EntidadOrigen = 'OBJETIVO' AND o.id_objetivo_bk IS NOT NULL
              AND o.StagingID > @DesdeEnt AND o.StagingID <= @HastaEnt AND o.OperacionCDC IN (2, 4)
              AND o.sk_fecha_meta_origen IS NULL
            UNION ALL
            SELECT 'IMP-15', 'FactMembresias', 'sk_fecha_fin', m.StagingID, CAST(m.id_membresia_bk AS VARCHAR(40)),
                   CAST(m.sk_fecha_fin_origen AS VARCHAR(200)),
                   'Fecha fin anterior al inicio: ajustada al día de inicio'
            FROM dbo.stg_ventas_membresias m
            LEFT JOIN #MapFecha mfi ON mfi.sk_fecha_origen = m.sk_fecha_inicio_origen
            LEFT JOIN #MapFecha mff ON mff.sk_fecha_origen = m.sk_fecha_fin_origen
            WHERE m.EntidadOrigen = 'MEMBRESIA' AND m.id_membresia_bk IS NOT NULL
              AND m.StagingID > @DesdeVM AND m.StagingID <= @HastaVM AND m.OperacionCDC IN (2, 4)
              AND mfi.sk_fecha IS NOT NULL AND mff.sk_fecha IS NOT NULL
              AND mff.sk_fecha < mfi.sk_fecha
            UNION ALL
            SELECT 'IMP-16', 'FactMembresias', 'sk_fecha_aviso', a.StagingID, CAST(a.id_membresia_bk AS VARCHAR(40)),
                   CAST(a.sk_fecha_aviso_origen AS VARCHAR(200)),
                   'Aviso emitido después del vencimiento: descartado del snapshot'
            FROM dbo.stg_ventas_membresias a
            INNER JOIN dbo.stg_ventas_membresias m
                ON m.EntidadOrigen = 'MEMBRESIA' AND m.id_membresia_bk = a.id_membresia_bk
            LEFT JOIN #MapFecha mfa ON mfa.sk_fecha_origen = a.sk_fecha_aviso_origen
            LEFT JOIN #MapFecha mff ON mff.sk_fecha_origen = m.sk_fecha_fin_origen
            WHERE a.EntidadOrigen = 'AVISO' AND a.id_membresia_bk IS NOT NULL
              AND a.OperacionCDC IN (2, 4)
              AND mfa.sk_fecha IS NOT NULL AND mff.sk_fecha IS NOT NULL
              AND mfa.sk_fecha > mff.sk_fecha
        )
        INSERT INTO dq.RegistroImputaciones (codigo_regla, entidad, campo, staging_id, bk, valor, motivo)
        SELECT codigo_regla, entidad, campo, staging_id, bk, valor, motivo FROM Imputaciones;

        /* =====================================================================
           FASE B - HECHOS DE EVENTO
           ===================================================================== */

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
                ISNULL(df.sk_fecha, -1) AS sk_fecha_pago,
                ISNULL(c.sk_cliente, -1) AS sk_cliente, ISNULL(p.sk_plan, -1) AS sk_plan, ISNULL(e.sk_empleado, -1) AS sk_empleado,
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
            LEFT JOIN #MapFecha mf0 ON mf0.sk_fecha_origen = v.sk_fecha_pago_origen
            LEFT JOIN dim.DimFecha df ON df.sk_fecha = mf0.sk_fecha
            LEFT JOIN #MapCliente mc ON mc.sk_cliente_origen = v.sk_cliente_origen
            LEFT JOIN dim.DimCliente c ON c.id_cliente_bk = mc.id_cliente_bk
            LEFT JOIN #PlanOrigen tp ON tp.sk_plan_origen = v.sk_plan_origen
            LEFT JOIN dim.DimPlan p ON p.tipo_plan = ISNULL(tp.tipo_plan, 'NO_APLICA')
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

        /* -------- HECHO ASISTENCIAS (marcación real de acceso) -------- */
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
                ISNULL(mf.sk_fecha, -1) AS sk_fecha_asistencia,
                ISNULL(c.sk_cliente, -1) AS sk_cliente, ISNULL(p.sk_plan, -1) AS sk_plan, ISNULL(e.sk_empleado, -1) AS sk_empleado,
                CASE WHEN a.hora_ingreso BETWEEN 5 AND 23 THEN a.hora_ingreso END AS hora_ingreso,
                CASE WHEN ISNULL(a.cantidad_asistencias, 0) > 0 THEN 1 ELSE 0 END AS cantidad_asistencias,
                CASE WHEN a.hora_ingreso BETWEEN 5 AND 23 THEN 1 ELSE 0 END AS es_acceso_valido
            FROM AsistenciaCanonica a
            LEFT JOIN #MapFecha mf0 ON mf0.sk_fecha_origen = a.sk_fecha_asistencia_origen
            LEFT JOIN dim.DimFecha mf ON mf.sk_fecha = mf0.sk_fecha
            LEFT JOIN #MapCliente mc ON mc.sk_cliente_origen = a.sk_cliente_origen
            LEFT JOIN dim.DimCliente c ON c.id_cliente_bk = mc.id_cliente_bk
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
            t.sk_empleado = s.sk_empleado, t.hora_ingreso = s.hora_ingreso, t.cantidad_asistencias = s.cantidad_asistencias,
            t.es_acceso_valido = s.es_acceso_valido
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (id_asistencia_bk, sk_fecha_asistencia, sk_cliente, sk_plan, sk_empleado,
                    hora_ingreso, cantidad_asistencias, es_acceso_valido)
            VALUES (s.id_asistencia_bk, s.sk_fecha_asistencia, s.sk_cliente, s.sk_plan, s.sk_empleado,
                    s.hora_ingreso, s.cantidad_asistencias, s.es_acceso_valido);

        /* -------- HECHO SESIONES DE ENTRENAMIENTO -------- */
        ;WITH SesionCanonica AS
        (
            SELECT *,
                   ROW_NUMBER() OVER (PARTITION BY id_sesion_bk ORDER BY StagingID DESC) AS rn
            FROM dbo.stg_entrenamiento
            WHERE EntidadOrigen = 'SESION_PROGRAMADA' AND id_sesion_bk IS NOT NULL
              AND StagingID > @DesdeEnt AND StagingID <= @HastaEnt
              AND OperacionCDC IN (2, 4)
        )
        MERGE dm_entrenamiento.FactSesionesEntrenamiento AS t
        USING
        (
            SELECT
                s.id_sesion_bk,
                ISNULL(mf.sk_fecha, -1) AS sk_fecha_programada,
                ISNULL(c.sk_cliente, -1) AS sk_cliente, ISNULL(p.sk_plan, -1) AS sk_plan, ISNULL(e.sk_empleado, -1) AS sk_empleado,
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
                CASE WHEN UPPER(LTRIM(RTRIM(s.estado_sesion))) LIKE 'ASIST%' THEN 1 ELSE 0 END AS asistio,
                CASE WHEN s.duracion_minutos BETWEEN 1 AND 480 THEN s.duracion_minutos END AS duracion_minutos,
                CASE WHEN UPPER(LTRIM(RTRIM(s.estado_sesion))) LIKE 'CANCEL%' THEN mfc.sk_fecha END AS sk_fecha_cancelacion,
                CASE WHEN UPPER(LTRIM(RTRIM(s.estado_sesion))) LIKE 'CANCEL%'
                     THEN COALESCE(NULLIF(UPPER(LTRIM(RTRIM(s.motivo_cancelacion))), ''), 'NO ESPECIFICADO') END AS motivo_cancelacion
            FROM SesionCanonica s
            LEFT JOIN #MapFecha mf0 ON mf0.sk_fecha_origen = s.sk_fecha_programada_origen
            LEFT JOIN dim.DimFecha mf ON mf.sk_fecha = mf0.sk_fecha
            LEFT JOIN #MapFecha mfc0 ON mfc0.sk_fecha_origen = CONVERT(INT, CONVERT(CHAR(8), s.fecha_cancelacion, 112))
            LEFT JOIN dim.DimFecha mfc ON mfc.sk_fecha = mfc0.sk_fecha
            LEFT JOIN #MapCliente mc ON mc.sk_cliente_origen = s.sk_cliente_origen
            LEFT JOIN dim.DimCliente c ON c.id_cliente_bk = mc.id_cliente_bk
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
            t.estado_sesion = s.estado_sesion, t.asistio = s.asistio, t.duracion_minutos = s.duracion_minutos,
            t.sk_fecha_cancelacion = s.sk_fecha_cancelacion, t.motivo_cancelacion = s.motivo_cancelacion
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (id_sesion_bk, sk_fecha_programada, sk_cliente, sk_plan, sk_empleado,
                    tipo_sesion, hora_programada, estado_sesion, asistio, duracion_minutos,
                    sk_fecha_cancelacion, motivo_cancelacion)
            VALUES (s.id_sesion_bk, s.sk_fecha_programada, s.sk_cliente, s.sk_plan, s.sk_empleado,
                    s.tipo_sesion, s.hora_programada, s.estado_sesion, s.asistio, s.duracion_minutos,
                    s.sk_fecha_cancelacion, s.motivo_cancelacion);

        /* -------- HECHO RECLAMOS (con hitos de resolución y escalamiento) -------- */
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
                ISNULL(df.sk_fecha, -1) AS sk_fecha_reclamo,
                ISNULL(c.sk_cliente, -1) AS sk_cliente, ISNULL(e.sk_empleado, -1) AS sk_empleado,
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
                CASE WHEN r.fecha_resolucion >= df.fecha THEN mfr.sk_fecha END AS sk_fecha_resolucion,
                CASE WHEN COALESCE(r.fecha_cierre, CASE WHEN UPPER(LTRIM(RTRIM(r.estado))) LIKE '%CERR%' THEN r.fecha_resolucion END) >= df.fecha
                     THEN mfc.sk_fecha END AS sk_fecha_cierre,
                CASE WHEN r.fecha_resolucion >= df.fecha THEN DATEDIFF(DAY, df.fecha, r.fecha_resolucion) END AS dias_resolucion,
                CASE
                    WHEN (UPPER(LTRIM(RTRIM(r.estado))) LIKE '%RESUEL%' OR UPPER(LTRIM(RTRIM(r.estado))) LIKE '%CERR%')
                         AND r.resuelto_en_mostrador = 1 THEN 1
                    WHEN UPPER(LTRIM(RTRIM(r.estado))) LIKE '%RESUEL%' OR UPPER(LTRIM(RTRIM(r.estado))) LIKE '%CERR%' THEN 0
                    ELSE NULL
                END AS resuelto_en_mostrador,
                CASE
                    WHEN r.escalado = 1 THEN 1
                    WHEN UPPER(LTRIM(RTRIM(r.estado))) LIKE '%ESCAL%' THEN 1
                    ELSE 0
                END AS escalado,
                COALESCE(NULLIF(UPPER(LTRIM(RTRIM(r.area_responsable))), ''), 'NO ESPECIFICADO') AS area_responsable
            FROM ReclamoCanonico r
            LEFT JOIN #MapFecha mf0 ON mf0.sk_fecha_origen = r.sk_fecha_reclamo_origen
            LEFT JOIN dim.DimFecha df ON df.sk_fecha = mf0.sk_fecha
            LEFT JOIN #MapFecha mfr0 ON mfr0.sk_fecha_origen = CONVERT(INT, CONVERT(CHAR(8), r.fecha_resolucion, 112))
            LEFT JOIN dim.DimFecha mfr ON mfr.sk_fecha = mfr0.sk_fecha
            LEFT JOIN #MapFecha mfc0 ON mfc0.sk_fecha_origen = CONVERT(INT, CONVERT(CHAR(8), r.fecha_cierre, 112))
            LEFT JOIN dim.DimFecha mfc ON mfc.sk_fecha = mfc0.sk_fecha
            LEFT JOIN #MapCliente mc ON mc.sk_cliente_origen = r.sk_cliente_origen
            LEFT JOIN dim.DimCliente c ON c.id_cliente_bk = mc.id_cliente_bk
            LEFT JOIN #MapEmpleado me ON me.sk_empleado_origen = r.sk_empleado_origen
            LEFT JOIN dim.DimEmpleado e ON e.id_empleado_bk = me.id_empleado_bk
            WHERE r.rn = 1
        ) AS s
        ON t.id_reclamo_bk = s.id_reclamo_bk
        WHEN MATCHED THEN UPDATE SET
            t.sk_fecha_reclamo = s.sk_fecha_reclamo, t.sk_cliente = s.sk_cliente, t.sk_empleado = s.sk_empleado,
            t.categoria = s.categoria, t.estado = s.estado,
            t.sk_fecha_resolucion = s.sk_fecha_resolucion, t.sk_fecha_cierre = s.sk_fecha_cierre,
            t.dias_resolucion = s.dias_resolucion, t.resuelto_en_mostrador = s.resuelto_en_mostrador,
            t.escalado = s.escalado, t.area_responsable = s.area_responsable
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (id_reclamo_bk, sk_fecha_reclamo, sk_cliente, sk_empleado, categoria, estado,
                    sk_fecha_resolucion, sk_fecha_cierre, dias_resolucion, resuelto_en_mostrador,
                    escalado, area_responsable)
            VALUES (s.id_reclamo_bk, s.sk_fecha_reclamo, s.sk_cliente, s.sk_empleado, s.categoria, s.estado,
                    s.sk_fecha_resolucion, s.sk_fecha_cierre, s.dias_resolucion, s.resuelto_en_mostrador,
                    s.escalado, s.area_responsable);

        /* -------- HECHO RETENCIONES --------
           "Membresías no renovadas atendidas" y "membresías recuperadas" se
           derivan aquí: el vencimiento viene de la membresía y la recuperación
           del resultado o de una renovación posterior a la acción. */
        IF OBJECT_ID('tempdb..#MemVencimiento') IS NOT NULL DROP TABLE #MemVencimiento;
        SELECT m.id_membresia_bk,
               MIN(mf.sk_fecha) AS sk_fecha_fin,
               MAX(p.sk_plan) AS sk_plan
        INTO #MemVencimiento
        FROM dbo.stg_ventas_membresias m
        LEFT JOIN #MapFecha mf0 ON mf0.sk_fecha_origen = m.sk_fecha_fin_origen
        LEFT JOIN dim.DimFecha mf ON mf.sk_fecha = mf0.sk_fecha
        LEFT JOIN #PlanOrigen tp ON tp.sk_plan_origen = m.sk_plan_origen
        LEFT JOIN dim.DimPlan p ON p.tipo_plan = ISNULL(tp.tipo_plan, 'NO_APLICA')
                                AND p.tipo_operacion = 'MEMBRESIA'
                                AND p.promocion = ISNULL(tp.promocion, 'SIN PROMOCION')
        WHERE m.EntidadOrigen = 'MEMBRESIA' AND m.id_membresia_bk IS NOT NULL
          AND m.OperacionCDC IN (2, 4)
        GROUP BY m.id_membresia_bk;

        IF OBJECT_ID('tempdb..#RenovacionesClave') IS NOT NULL DROP TABLE #RenovacionesClave;
        SELECT r.id_membresia_anterior_bk,
               MIN(mf.sk_fecha) AS sk_fecha_renovacion
        INTO #RenovacionesClave
        FROM dbo.stg_ventas_membresias r
        LEFT JOIN #MapFecha mf0 ON mf0.sk_fecha_origen = r.sk_fecha_renovacion_origen
        LEFT JOIN dim.DimFecha mf ON mf.sk_fecha = mf0.sk_fecha
        WHERE r.EntidadOrigen = 'RENOVACION' AND r.id_membresia_anterior_bk IS NOT NULL
          AND r.OperacionCDC IN (2, 4)
        GROUP BY r.id_membresia_anterior_bk;

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
                ISNULL(mf.sk_fecha, -1) AS sk_fecha_retencion,
                ISNULL(c.sk_cliente, -1) AS sk_cliente, ISNULL(e.sk_empleado, -1) AS sk_empleado,
                ISNULL(mv.sk_plan, -1) AS sk_plan,
                r.id_membresia_bk,
                mv.sk_fecha_fin AS sk_fecha_vencimiento,
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
                CASE
                    WHEN UPPER(LTRIM(RTRIM(r.resultado))) LIKE '%RETEN%' THEN 1
                    WHEN mf.sk_fecha IS NOT NULL AND rc.sk_fecha_renovacion >= mf.sk_fecha THEN 1
                    ELSE 0
                END AS recuperada,
                CASE WHEN r.monto_oferta > 0 THEN r.monto_oferta END AS monto_oferta
            FROM RetencionCanonica r
            LEFT JOIN #MapFecha mf0 ON mf0.sk_fecha_origen = r.sk_fecha_retencion_origen
            LEFT JOIN dim.DimFecha mf ON mf.sk_fecha = mf0.sk_fecha
            LEFT JOIN #MapCliente mc ON mc.sk_cliente_origen = r.sk_cliente_origen
            LEFT JOIN dim.DimCliente c ON c.id_cliente_bk = mc.id_cliente_bk
            LEFT JOIN #MapEmpleado me ON me.sk_empleado_origen = r.sk_empleado_origen
            LEFT JOIN dim.DimEmpleado e ON e.id_empleado_bk = me.id_empleado_bk
            LEFT JOIN #MemVencimiento mv ON mv.id_membresia_bk = r.id_membresia_bk
            LEFT JOIN #RenovacionesClave rc ON rc.id_membresia_anterior_bk = r.id_membresia_bk
            WHERE r.rn = 1
        ) AS s
        ON t.id_retencion_bk = s.id_retencion_bk
        WHEN MATCHED THEN UPDATE SET
            t.sk_fecha_retencion = s.sk_fecha_retencion, t.sk_cliente = s.sk_cliente, t.sk_empleado = s.sk_empleado,
            t.sk_plan = s.sk_plan,
            t.id_membresia_bk = s.id_membresia_bk, t.sk_fecha_vencimiento = s.sk_fecha_vencimiento,
            t.canal = s.canal, t.motivo = s.motivo, t.resultado = s.resultado,
            t.recuperada = s.recuperada, t.monto_oferta = s.monto_oferta
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (id_retencion_bk, sk_fecha_retencion, sk_cliente, sk_empleado, sk_plan, id_membresia_bk,
                    sk_fecha_vencimiento, canal, motivo, resultado, recuperada, monto_oferta)
            VALUES (s.id_retencion_bk, s.sk_fecha_retencion, s.sk_cliente, s.sk_empleado, s.sk_plan, s.id_membresia_bk,
                    s.sk_fecha_vencimiento, s.canal, s.motivo, s.resultado, s.recuperada, s.monto_oferta);

        /* =====================================================================
           FASE C - SNAPSHOTS DIARIOS
           ===================================================================== */

        /* -------------------- FACT MEMBRESIAS --------------------
           Grano: id_membresia_bk + sk_fecha_corte. */
        IF OBJECT_ID('tempdb..#MemBase') IS NOT NULL DROP TABLE #MemBase;
        ;WITH MembresiaCanonica AS
        (
            SELECT *,
                   ROW_NUMBER() OVER (PARTITION BY id_membresia_bk ORDER BY StagingID DESC) AS rn
            FROM dbo.stg_ventas_membresias
            WHERE EntidadOrigen = 'MEMBRESIA' AND id_membresia_bk IS NOT NULL
              AND OperacionCDC IN (2, 4)
        )
        SELECT
            m.id_membresia_bk,
            ISNULL(c.sk_cliente, -1) AS sk_cliente,
            ISNULL(p.sk_plan, -1) AS sk_plan,
            ISNULL(e.sk_empleado, -1) AS sk_empleado,
            ISNULL(di.sk_fecha, -1) AS sk_fecha_inicio,
            CASE WHEN df.fecha < di.fecha THEN di.sk_fecha
                 ELSE ISNULL(df.sk_fecha, -1) END AS sk_fecha_fin,
            di.fecha AS fecha_inicio,
            CASE WHEN df.fecha < di.fecha THEN di.fecha
                 ELSE df.fecha END AS fecha_fin,
            CASE WHEN m.duracion_dias > 0 THEN m.duracion_dias END AS duracion_dias,
            CASE WHEN m.precio_final >= 0 THEN m.precio_final END AS precio_final,
            CASE WHEN m.es_renovacion = 1 THEN 1 ELSE 0 END AS es_renovacion,
            rn_ant.id_membresia_anterior_bk,
            rn_nva.id_membresia_nueva_bk,
            rn_ant.sk_fecha_renovacion,
            rn_ant.dias_anticipacion_renovacion,
            rn_ant.monto_renovacion,
            CASE WHEN EXISTS
                 (
                     SELECT 1 FROM dbo.stg_ventas_membresias x
                     WHERE x.EntidadOrigen = 'MEMBRESIA'
                       AND x.id_membresia_bk = m.id_membresia_bk
                       AND x.StagingID > @DesdeVM AND x.StagingID <= @HastaVM
                       AND x.OperacionCDC IN (1, 4)
                 ) THEN 1 ELSE 0 END AS forzar_recalculo,
            yc.ultimo_corte
        INTO #MemBase
        FROM MembresiaCanonica m
        LEFT JOIN #MapFecha mfi ON mfi.sk_fecha_origen = m.sk_fecha_inicio_origen
        LEFT JOIN dim.DimFecha di ON di.sk_fecha = mfi.sk_fecha
        LEFT JOIN #MapFecha mff ON mff.sk_fecha_origen = m.sk_fecha_fin_origen
        LEFT JOIN dim.DimFecha df ON df.sk_fecha = mff.sk_fecha
        LEFT JOIN #MapCliente mc ON mc.sk_cliente_origen = m.sk_cliente_origen
        LEFT JOIN dim.DimCliente c ON c.id_cliente_bk = mc.id_cliente_bk
        LEFT JOIN #PlanOrigen tp ON tp.sk_plan_origen = m.sk_plan_origen
        LEFT JOIN dim.DimPlan p ON p.tipo_plan = ISNULL(tp.tipo_plan, 'NO_APLICA')
                                AND p.tipo_operacion = 'MEMBRESIA'
                                AND p.promocion = ISNULL(tp.promocion, 'SIN PROMOCION')
        LEFT JOIN #MapEmpleado me ON me.sk_empleado_origen = m.sk_empleado_origen
        LEFT JOIN dim.DimEmpleado e ON e.id_empleado_bk = me.id_empleado_bk
        LEFT JOIN
        (
            SELECT r.id_membresia_anterior_bk, r.id_membresia_nueva_bk,
                   mf.sk_fecha AS sk_fecha_renovacion,
                   CASE WHEN r.dias_anticipacion BETWEEN 0 AND 30 THEN r.dias_anticipacion END AS dias_anticipacion_renovacion,
                   CASE WHEN r.monto_renovacion > 0 THEN r.monto_renovacion END AS monto_renovacion,
                   ROW_NUMBER() OVER (PARTITION BY r.id_membresia_anterior_bk
                                      ORDER BY mf.sk_fecha, r.StagingID) AS rn
            FROM dbo.stg_ventas_membresias r
            LEFT JOIN #MapFecha mf0 ON mf0.sk_fecha_origen = r.sk_fecha_renovacion_origen
            LEFT JOIN dim.DimFecha mf ON mf.sk_fecha = mf0.sk_fecha
            WHERE r.EntidadOrigen = 'RENOVACION' AND r.id_membresia_anterior_bk IS NOT NULL
              AND r.OperacionCDC IN (2, 4)
        ) rn_ant ON rn_ant.id_membresia_anterior_bk = m.id_membresia_bk AND rn_ant.rn = 1
        LEFT JOIN
        (
            SELECT r.id_membresia_nueva_bk,
                   ROW_NUMBER() OVER (PARTITION BY r.id_membresia_nueva_bk ORDER BY r.StagingID DESC) AS rn
            FROM dbo.stg_ventas_membresias r
            WHERE r.EntidadOrigen = 'RENOVACION' AND r.id_membresia_nueva_bk IS NOT NULL
              AND r.OperacionCDC IN (2, 4)
        ) rn_nva ON rn_nva.id_membresia_nueva_bk = m.id_membresia_bk AND rn_nva.rn = 1
        LEFT JOIN
        (
            SELECT fm.id_membresia_bk, MAX(dc.fecha) AS ultimo_corte
            FROM dm_comercial.FactMembresias fm
            INNER JOIN dim.DimFecha dc ON dc.sk_fecha = fm.sk_fecha_corte
            GROUP BY fm.id_membresia_bk
        ) yc ON yc.id_membresia_bk = m.id_membresia_bk
        WHERE m.rn = 1
          AND di.fecha IS NOT NULL
          AND di.fecha <= @Corte;

        /* Avisos por membresía y por fecha (cantidad del día). */
        IF OBJECT_ID('tempdb..#AvisosDia') IS NOT NULL DROP TABLE #AvisosDia;
        SELECT a.id_membresia_bk, mf.sk_fecha AS sk_fecha_aviso, COUNT(*) AS avisos
        INTO #AvisosDia
        FROM dbo.stg_ventas_membresias a
        LEFT JOIN #MapFecha mf0 ON mf0.sk_fecha_origen = a.sk_fecha_aviso_origen
        LEFT JOIN dim.DimFecha mf ON mf.sk_fecha = mf0.sk_fecha
        WHERE a.EntidadOrigen = 'AVISO' AND a.id_membresia_bk IS NOT NULL
          AND a.OperacionCDC IN (2, 4) AND mf.sk_fecha IS NOT NULL
        GROUP BY a.id_membresia_bk, mf.sk_fecha;

        IF OBJECT_ID('tempdb..#PrimerAviso') IS NOT NULL DROP TABLE #PrimerAviso;
        SELECT id_membresia_bk, sk_fecha_aviso, dias_antes_vencimiento, medio_aviso, estado_aviso
        INTO #PrimerAviso
        FROM
        (
            SELECT a.id_membresia_bk,
                   mf.sk_fecha AS sk_fecha_aviso,
                   CASE WHEN a.dias_antes_vencimiento BETWEEN 1 AND 30 THEN a.dias_antes_vencimiento END AS dias_antes_vencimiento,
                   CASE
                       WHEN UPPER(LTRIM(RTRIM(a.medio_aviso))) LIKE '%WHATS%' THEN 'WHATSAPP'
                       WHEN UPPER(LTRIM(RTRIM(a.medio_aviso))) LIKE '%CORRE%' OR UPPER(LTRIM(RTRIM(a.medio_aviso))) LIKE '%EMAIL%' THEN 'CORREO'
                       WHEN UPPER(LTRIM(RTRIM(a.medio_aviso))) LIKE '%SMS%' THEN 'SMS'
                       ELSE 'NO ESPECIFICADO'
                   END AS medio_aviso,
                   CASE
                       WHEN UPPER(LTRIM(RTRIM(a.estado_aviso))) LIKE '%ENV%' OR UPPER(LTRIM(RTRIM(a.estado_aviso))) = 'OK' THEN 'ENVIADO'
                       ELSE 'NO CONFIRMADO'
                   END AS estado_aviso,
                   ROW_NUMBER() OVER (PARTITION BY a.id_membresia_bk
                                      ORDER BY mf.sk_fecha, a.StagingID) AS rn
            FROM dbo.stg_ventas_membresias a
            LEFT JOIN #MapFecha mf0 ON mf0.sk_fecha_origen = a.sk_fecha_aviso_origen
            LEFT JOIN dim.DimFecha mf ON mf.sk_fecha = mf0.sk_fecha
            WHERE a.EntidadOrigen = 'AVISO' AND a.id_membresia_bk IS NOT NULL
              AND a.OperacionCDC IN (2, 4) AND mf.sk_fecha IS NOT NULL
        ) x
        WHERE rn = 1;

        /* Serie diaria: el estado se calcula para CADA corte. */
        IF OBJECT_ID('tempdb..#SnapshotMem') IS NOT NULL DROP TABLE #SnapshotMem;
        SELECT
            b.id_membresia_bk,
            c.sk_fecha AS sk_fecha_corte,
            b.sk_cliente, b.sk_plan, b.sk_empleado,
            b.sk_fecha_inicio, b.sk_fecha_fin,
            b.duracion_dias, b.precio_final,
            CASE
                WHEN b.fecha_fin IS NULL THEN 'DESCONOCIDA'
                WHEN c.fecha < b.fecha_inicio THEN 'PENDIENTE'
                WHEN c.fecha <= b.fecha_fin THEN 'ACTIVA'
                ELSE 'VENCIDA'
            END AS estado_membresia,
            CASE WHEN b.fecha_fin IS NOT NULL AND c.fecha > b.fecha_fin
                 THEN DATEDIFF(DAY, b.fecha_fin, c.fecha) END AS dias_desde_vencimiento,
            b.es_renovacion,
            b.id_membresia_anterior_bk, b.id_membresia_nueva_bk,
            b.sk_fecha_renovacion, b.dias_anticipacion_renovacion, b.monto_renovacion,
            CASE WHEN pa.sk_fecha_aviso IS NOT NULL AND pa.sk_fecha_aviso <= c.sk_fecha
                      AND pa.sk_fecha_aviso <= b.sk_fecha_fin THEN 1 ELSE 0 END AS aviso_emitido,
            CASE WHEN pa.sk_fecha_aviso <= b.sk_fecha_fin THEN pa.sk_fecha_aviso END AS sk_fecha_aviso,
            CASE WHEN pa.sk_fecha_aviso <= b.sk_fecha_fin THEN pa.dias_antes_vencimiento END AS dias_antes_vencimiento,
            CASE WHEN pa.sk_fecha_aviso <= b.sk_fecha_fin THEN pa.medio_aviso END AS medio_aviso,
            CASE WHEN pa.sk_fecha_aviso <= b.sk_fecha_fin THEN pa.estado_aviso END AS estado_aviso,
            ISNULL(ad.avisos, 0) AS avisos_emitidos_dia
        INTO #SnapshotMem
        FROM #MemBase b
        INNER JOIN dim.DimFecha c
            ON  c.fecha >= b.fecha_inicio
            AND c.fecha <= CASE
                               WHEN DATEADD(DAY, @DiasObservacion, b.fecha_fin) < @Corte
                                   THEN DATEADD(DAY, @DiasObservacion, b.fecha_fin)
                               ELSE @Corte
                           END
            AND c.fecha >= CASE
                               WHEN @RecalcularDesde IS NOT NULL THEN @RecalcularDesde
                               WHEN b.forzar_recalculo = 1 THEN b.fecha_inicio
                               WHEN b.ultimo_corte IS NULL THEN b.fecha_inicio
                               ELSE DATEADD(DAY, 1, b.ultimo_corte)
                           END
        LEFT JOIN #PrimerAviso pa ON pa.id_membresia_bk = b.id_membresia_bk
        LEFT JOIN #AvisosDia ad ON ad.id_membresia_bk = b.id_membresia_bk
                               AND ad.sk_fecha_aviso = c.sk_fecha
                               AND ad.sk_fecha_aviso <= b.sk_fecha_fin;

        MERGE dm_comercial.FactMembresias AS t
        USING #SnapshotMem AS s
        ON t.id_membresia_bk = s.id_membresia_bk
       AND t.sk_fecha_corte = s.sk_fecha_corte
        WHEN MATCHED AND (
                t.sk_cliente <> s.sk_cliente
             OR t.sk_plan <> s.sk_plan
             OR t.sk_empleado <> s.sk_empleado
             OR t.sk_fecha_inicio <> s.sk_fecha_inicio
             OR t.sk_fecha_fin <> s.sk_fecha_fin
             OR ISNULL(t.precio_final, -999999) <> ISNULL(s.precio_final, -999999)
             OR t.estado_membresia <> s.estado_membresia
             OR ISNULL(t.dias_desde_vencimiento, -1) <> ISNULL(s.dias_desde_vencimiento, -1)
             OR ISNULL(t.id_membresia_anterior_bk, -1) <> ISNULL(s.id_membresia_anterior_bk, -1)
             OR ISNULL(t.id_membresia_nueva_bk, -1) <> ISNULL(s.id_membresia_nueva_bk, -1)
             OR ISNULL(t.sk_fecha_renovacion, -1) <> ISNULL(s.sk_fecha_renovacion, -1)
             OR ISNULL(t.monto_renovacion, -999999) <> ISNULL(s.monto_renovacion, -999999)
             OR t.aviso_emitido <> s.aviso_emitido
             OR ISNULL(t.sk_fecha_aviso, -1) <> ISNULL(s.sk_fecha_aviso, -1)
             OR t.avisos_emitidos_dia <> s.avisos_emitidos_dia
            ) THEN UPDATE SET
                t.sk_cliente = s.sk_cliente,
                t.sk_plan = s.sk_plan,
                t.sk_empleado = s.sk_empleado,
                t.sk_fecha_inicio = s.sk_fecha_inicio,
                t.sk_fecha_fin = s.sk_fecha_fin,
                t.duracion_dias = s.duracion_dias,
                t.precio_final = s.precio_final,
                t.estado_membresia = s.estado_membresia,
                t.dias_desde_vencimiento = s.dias_desde_vencimiento,
                t.es_renovacion = s.es_renovacion,
                t.id_membresia_anterior_bk = s.id_membresia_anterior_bk,
                t.id_membresia_nueva_bk = s.id_membresia_nueva_bk,
                t.sk_fecha_renovacion = s.sk_fecha_renovacion,
                t.dias_anticipacion_renovacion = s.dias_anticipacion_renovacion,
                t.monto_renovacion = s.monto_renovacion,
                t.aviso_emitido = s.aviso_emitido,
                t.sk_fecha_aviso = s.sk_fecha_aviso,
                t.dias_antes_vencimiento = s.dias_antes_vencimiento,
                t.medio_aviso = s.medio_aviso,
                t.estado_aviso = s.estado_aviso,
                t.avisos_emitidos_dia = s.avisos_emitidos_dia
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (id_membresia_bk, sk_fecha_corte, sk_cliente, sk_plan, sk_empleado,
                    sk_fecha_inicio, sk_fecha_fin, duracion_dias, precio_final,
                    estado_membresia, dias_desde_vencimiento, es_renovacion,
                    id_membresia_anterior_bk, id_membresia_nueva_bk, sk_fecha_renovacion,
                    dias_anticipacion_renovacion, monto_renovacion,
                    aviso_emitido, sk_fecha_aviso, dias_antes_vencimiento, medio_aviso, estado_aviso,
                    avisos_emitidos_dia)
            VALUES (s.id_membresia_bk, s.sk_fecha_corte, s.sk_cliente, s.sk_plan, s.sk_empleado,
                    s.sk_fecha_inicio, s.sk_fecha_fin, s.duracion_dias, s.precio_final,
                    s.estado_membresia, s.dias_desde_vencimiento, s.es_renovacion,
                    s.id_membresia_anterior_bk, s.id_membresia_nueva_bk, s.sk_fecha_renovacion,
                    s.dias_anticipacion_renovacion, s.monto_renovacion,
                    s.aviso_emitido, s.sk_fecha_aviso, s.dias_antes_vencimiento, s.medio_aviso, s.estado_aviso,
                    s.avisos_emitidos_dia);

        /* -------------------- FACT SEGUIMIENTO FÍSICO --------------------
           Grano: sk_cliente + id_objetivo_bk + sk_fecha_corte. */
        IF OBJECT_ID('tempdb..#ObjBase') IS NOT NULL DROP TABLE #ObjBase;
        ;WITH ObjetivoCanonico AS
        (
            SELECT *,
                   ROW_NUMBER() OVER (PARTITION BY id_objetivo_bk ORDER BY StagingID DESC) AS rn
            FROM dbo.stg_entrenamiento
            WHERE EntidadOrigen = 'OBJETIVO' AND id_objetivo_bk IS NOT NULL
              AND OperacionCDC IN (2, 4)
        )
        SELECT
            o.id_objetivo_bk,
            ISNULL(c.sk_cliente, -1) AS sk_cliente,
            ISNULL(e.sk_empleado, -1) AS sk_empleado,
            ISNULL(di.sk_fecha, -1) AS sk_fecha_inicio,
            di.fecha AS fecha_inicio,
            COALESCE(dm2.sk_fecha, di.sk_fecha) AS sk_fecha_meta,
            COALESCE(dm2.fecha, DATEADD(DAY, 90, di.fecha)) AS fecha_meta,
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
            END AS estado_objetivo,
            CASE WHEN EXISTS
                 (
                     SELECT 1 FROM dbo.stg_entrenamiento x
                     WHERE x.EntidadOrigen = 'OBJETIVO'
                       AND x.id_objetivo_bk = o.id_objetivo_bk
                       AND x.StagingID > @DesdeEnt AND x.StagingID <= @HastaEnt
                       AND x.OperacionCDC IN (1, 4)
                 )
                 OR EXISTS
                 (
                     SELECT 1 FROM dbo.stg_entrenamiento y
                     WHERE y.EntidadOrigen IN ('EVALUACION', 'EVALUACION_PROGRAMADA')
                       AND y.id_objetivo_bk = o.id_objetivo_bk
                       AND y.StagingID > @DesdeEnt AND y.StagingID <= @HastaEnt
                       AND y.OperacionCDC IN (1, 2, 4)
                 ) THEN 1 ELSE 0 END AS forzar_recalculo,
            yc.ultimo_corte
        INTO #ObjBase
        FROM ObjetivoCanonico o
        LEFT JOIN #MapFecha mfi ON mfi.sk_fecha_origen = o.sk_fecha_inicio_origen
        LEFT JOIN dim.DimFecha di ON di.sk_fecha = mfi.sk_fecha
        LEFT JOIN #MapFecha mfm ON mfm.sk_fecha_origen = o.sk_fecha_meta_origen
        LEFT JOIN dim.DimFecha dm2 ON dm2.sk_fecha = mfm.sk_fecha
        LEFT JOIN #MapCliente mc ON mc.sk_cliente_origen = o.sk_cliente_origen
        LEFT JOIN dim.DimCliente c ON c.id_cliente_bk = mc.id_cliente_bk
        LEFT JOIN #MapEmpleado me ON me.sk_empleado_origen = o.sk_empleado_origen
        LEFT JOIN dim.DimEmpleado e ON e.id_empleado_bk = me.id_empleado_bk
        LEFT JOIN
        (
            SELECT fs.id_objetivo_bk, MAX(dc.fecha) AS ultimo_corte
            FROM dm_entrenamiento.FactSeguimientoFisico fs
            INNER JOIN dim.DimFecha dc ON dc.sk_fecha = fs.sk_fecha_corte
            GROUP BY fs.id_objetivo_bk
        ) yc ON yc.id_objetivo_bk = o.id_objetivo_bk
        WHERE o.rn = 1
          AND di.fecha IS NOT NULL
          AND di.fecha <= @Corte;

        /* Evaluaciones realizadas (canónicas, con fecha resuelta). */
        IF OBJECT_ID('tempdb..#EvalReal') IS NOT NULL DROP TABLE #EvalReal;
        ;WITH EvaluacionCanonica AS
        (
            SELECT *,
                   ROW_NUMBER() OVER (PARTITION BY id_evaluacion_bk ORDER BY StagingID DESC) AS rn
            FROM dbo.stg_entrenamiento
            WHERE EntidadOrigen = 'EVALUACION' AND id_evaluacion_bk IS NOT NULL
              AND OperacionCDC IN (2, 4)
        )
        SELECT
            ev.id_evaluacion_bk,
            ev.id_objetivo_bk,
            ISNULL(c.sk_cliente, -1) AS sk_cliente,
            ISNULL(e.sk_empleado, -1) AS sk_empleado,
            mf.sk_fecha AS sk_fecha_evaluacion,
            mf.fecha AS fecha_evaluacion,
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
        INTO #EvalReal
        FROM EvaluacionCanonica ev
        LEFT JOIN #MapFecha mf0 ON mf0.sk_fecha_origen = ev.sk_fecha_evaluacion_origen
        LEFT JOIN dim.DimFecha mf ON mf.sk_fecha = mf0.sk_fecha
        LEFT JOIN #MapCliente mc ON mc.sk_cliente_origen = ev.sk_cliente_origen
        LEFT JOIN dim.DimCliente c ON c.id_cliente_bk = mc.id_cliente_bk
        LEFT JOIN #MapEmpleado me ON me.sk_empleado_origen = ev.sk_empleado_origen
        LEFT JOIN dim.DimEmpleado e ON e.id_empleado_bk = me.id_empleado_bk
        WHERE ev.rn = 1
          AND ev.id_objetivo_bk IS NOT NULL
          AND mf.sk_fecha IS NOT NULL;

        /* Evaluaciones programadas (exigibles) por objetivo. */
        IF OBJECT_ID('tempdb..#EvalProg') IS NOT NULL DROP TABLE #EvalProg;
        ;WITH EvalProgCanonica AS
        (
            SELECT *,
                   ROW_NUMBER() OVER (PARTITION BY id_evaluacion_programada_bk ORDER BY StagingID DESC) AS rn
            FROM dbo.stg_entrenamiento
            WHERE EntidadOrigen = 'EVALUACION_PROGRAMADA' AND id_evaluacion_programada_bk IS NOT NULL
              AND OperacionCDC IN (2, 4)
        )
        SELECT
            ep.id_evaluacion_programada_bk,
            ep.id_objetivo_bk,
            ISNULL(c.sk_cliente, -1) AS sk_cliente,
            ISNULL(e.sk_empleado, -1) AS sk_empleado,
            mf.sk_fecha AS sk_fecha_programada,
            mf.fecha AS fecha_programada,
            CASE
                WHEN UPPER(LTRIM(RTRIM(ep.estado_evaluacion))) LIKE 'COMPLET%' THEN 'COMPLETADA'
                WHEN UPPER(LTRIM(RTRIM(ep.estado_evaluacion))) LIKE 'PENDIENT%' THEN 'PENDIENTE'
                WHEN UPPER(LTRIM(RTRIM(ep.estado_evaluacion))) LIKE 'CANCEL%' THEN 'CANCELADA'
                ELSE 'PROGRAMADA'
            END AS estado_evaluacion,
            ep.id_evaluacion_bk
        INTO #EvalProg
        FROM EvalProgCanonica ep
        LEFT JOIN #MapFecha mf0 ON mf0.sk_fecha_origen = ep.sk_fecha_programada_origen
        LEFT JOIN dim.DimFecha mf ON mf.sk_fecha = mf0.sk_fecha
        LEFT JOIN #MapCliente mc ON mc.sk_cliente_origen = ep.sk_cliente_origen
        LEFT JOIN dim.DimCliente c ON c.id_cliente_bk = mc.id_cliente_bk
        LEFT JOIN #MapEmpleado me ON me.sk_empleado_origen = ep.sk_empleado_origen
        LEFT JOIN dim.DimEmpleado e ON e.id_empleado_bk = me.id_empleado_bk
        WHERE ep.rn = 1
          AND ep.id_objetivo_bk IS NOT NULL
          AND mf.sk_fecha IS NOT NULL;

        IF OBJECT_ID('tempdb..#SnapshotSeg') IS NOT NULL DROP TABLE #SnapshotSeg;
        SELECT
            o.id_objetivo_bk,
            o.sk_cliente,
            COALESCE(ev.sk_empleado, o.sk_empleado) AS sk_empleado,
            c.sk_fecha AS sk_fecha_corte,
            o.sk_fecha_inicio,
            o.sk_fecha_meta,
            ev.id_evaluacion_bk,
            ep.id_evaluacion_programada_bk,
            o.tipo_objetivo, o.unidad_medida, o.estado_objetivo,
            o.valor_inicial,
            ev.valor_actual,
            CASE
                WHEN o.valor_inicial IS NULL OR o.valor_objetivo IS NULL THEN NULL
                WHEN o.fecha_meta <= o.fecha_inicio THEN o.valor_objetivo
                WHEN c.fecha >= o.fecha_meta THEN o.valor_objetivo
                ELSE o.valor_inicial + (o.valor_objetivo - o.valor_inicial)
                     * (CAST(DATEDIFF(DAY, o.fecha_inicio, c.fecha) AS DECIMAL(18,6))
                        / NULLIF(DATEDIFF(DAY, o.fecha_inicio, o.fecha_meta), 0))
            END AS valor_esperado,
            CAST(NULL AS DECIMAL(10,2)) AS avance_alcanzado,
            CAST(NULL AS DECIMAL(10,2)) AS avance_esperado,
            CAST(NULL AS DECIMAL(9,2)) AS porcentaje_progreso,
            CAST(0 AS BIT) AS evaluacion_pendiente,
            ev.peso, ev.altura, ev.grasa_corporal, ev.masa_muscular,
            CASE WHEN ep.id_evaluacion_programada_bk IS NOT NULL THEN 1 ELSE 0 END AS evaluacion_exigible,
            CASE WHEN ev.id_evaluacion_bk IS NOT NULL THEN 1 ELSE 0 END AS evaluacion_completada,
            COALESCE(ep.estado_evaluacion, 'NO PROGRAMADA') AS estado_evaluacion
        INTO #SnapshotSeg
        FROM #ObjBase o
        INNER JOIN dim.DimFecha c
            ON  c.fecha >= o.fecha_inicio
            AND c.fecha <= CASE
                               WHEN DATEADD(DAY, @DiasObservacion, o.fecha_meta) < @Corte
                                   THEN DATEADD(DAY, @DiasObservacion, o.fecha_meta)
                               ELSE @Corte
                           END
            AND c.fecha >= CASE
                               WHEN @RecalcularDesde IS NOT NULL THEN @RecalcularDesde
                               WHEN o.forzar_recalculo = 1 THEN o.fecha_inicio
                               WHEN o.ultimo_corte IS NULL THEN o.fecha_inicio
                               ELSE DATEADD(DAY, 1, o.ultimo_corte)
                           END
        OUTER APPLY
        (
            /* Última evaluación realizada con fecha <= corte (nunca posterior). */
            SELECT TOP (1)
                v.id_evaluacion_bk,
                v.sk_empleado,
                v.valor_actual,
                v.peso, v.altura, v.grasa_corporal, v.masa_muscular
            FROM
            (
                SELECT
                    er.id_evaluacion_bk,
                    er.sk_empleado,
                    /* Valor medido coherente con el tipo y la unidad del objetivo. */
                    CASE
                        WHEN o.unidad_medida = 'CM' THEN er.altura
                        WHEN o.unidad_medida = 'KG' AND o.tipo_objetivo = 'REDUCCION_GRASA' THEN er.peso
                        WHEN o.unidad_medida = 'KG' AND o.tipo_objetivo = 'AUMENTO_MASA' THEN er.masa_muscular
                        ELSE er.peso
                    END AS valor_actual,
                    er.peso, er.altura, er.grasa_corporal, er.masa_muscular,
                    er.fecha_evaluacion
                FROM #EvalReal er
                WHERE er.id_objetivo_bk = o.id_objetivo_bk
                  AND er.fecha_evaluacion <= c.fecha
            ) v
            ORDER BY v.fecha_evaluacion DESC, v.id_evaluacion_bk DESC
        ) ev
        OUTER APPLY
        (
            /* Evaluación exigible más reciente al corte. */
            SELECT TOP (1)
                ep2.id_evaluacion_programada_bk,
                ep2.estado_evaluacion,
                ep2.id_evaluacion_bk
            FROM #EvalProg ep2
            WHERE ep2.id_objetivo_bk = o.id_objetivo_bk
              AND ep2.fecha_programada <= c.fecha
              AND ep2.estado_evaluacion <> 'CANCELADA'
            ORDER BY ep2.fecha_programada DESC, ep2.id_evaluacion_programada_bk DESC
        ) ep;

        UPDATE #SnapshotSeg
        SET avance_alcanzado = CASE
                WHEN valor_inicial IS NOT NULL AND valor_actual IS NOT NULL
                    THEN valor_actual - valor_inicial
            END,
            avance_esperado = CASE
                WHEN valor_inicial IS NOT NULL AND valor_esperado IS NOT NULL
                    THEN valor_esperado - valor_inicial
            END;

        UPDATE #SnapshotSeg
        SET porcentaje_progreso = CASE
                WHEN avance_esperado IS NULL OR avance_esperado = 0 THEN NULL
                ELSE CAST(avance_alcanzado / avance_esperado * 100.0 AS DECIMAL(9,2))
            END,
            evaluacion_pendiente = CASE
                WHEN evaluacion_exigible = 1 AND evaluacion_completada = 0 THEN 1 ELSE 0
            END;

        MERGE dm_entrenamiento.FactSeguimientoFisico AS t
        USING #SnapshotSeg AS s
        ON  t.sk_cliente = s.sk_cliente
        AND t.id_objetivo_bk = s.id_objetivo_bk
        AND t.sk_fecha_corte = s.sk_fecha_corte
        WHEN MATCHED AND (
                t.sk_empleado <> s.sk_empleado
             OR t.sk_fecha_inicio <> s.sk_fecha_inicio
             OR t.sk_fecha_meta <> s.sk_fecha_meta
             OR ISNULL(t.id_evaluacion_bk, -1) <> ISNULL(s.id_evaluacion_bk, -1)
             OR ISNULL(t.id_evaluacion_programada_bk, -1) <> ISNULL(s.id_evaluacion_programada_bk, -1)
             OR ISNULL(t.valor_actual, -999999) <> ISNULL(s.valor_actual, -999999)
             OR ISNULL(t.valor_esperado, -999999) <> ISNULL(s.valor_esperado, -999999)
             OR ISNULL(t.porcentaje_progreso, -999999) <> ISNULL(s.porcentaje_progreso, -999999)
             OR t.evaluacion_exigible <> s.evaluacion_exigible
             OR t.evaluacion_completada <> s.evaluacion_completada
             OR t.evaluacion_pendiente <> s.evaluacion_pendiente
             OR t.estado_evaluacion <> s.estado_evaluacion
            ) THEN UPDATE SET
                t.sk_empleado = s.sk_empleado,
                t.sk_fecha_inicio = s.sk_fecha_inicio,
                t.sk_fecha_meta = s.sk_fecha_meta,
                t.id_evaluacion_bk = s.id_evaluacion_bk,
                t.id_evaluacion_programada_bk = s.id_evaluacion_programada_bk,
                t.tipo_objetivo = s.tipo_objetivo,
                t.unidad_medida = s.unidad_medida,
                t.estado_objetivo = s.estado_objetivo,
                t.valor_inicial = s.valor_inicial,
                t.valor_actual = s.valor_actual,
                t.valor_esperado = s.valor_esperado,
                t.avance_alcanzado = s.avance_alcanzado,
                t.avance_esperado = s.avance_esperado,
                t.porcentaje_progreso = s.porcentaje_progreso,
                t.peso = s.peso,
                t.altura = s.altura,
                t.grasa_corporal = s.grasa_corporal,
                t.masa_muscular = s.masa_muscular,
                t.evaluacion_exigible = s.evaluacion_exigible,
                t.evaluacion_completada = s.evaluacion_completada,
                t.evaluacion_pendiente = s.evaluacion_pendiente,
                t.estado_evaluacion = s.estado_evaluacion
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (id_objetivo_bk, sk_cliente, sk_empleado, sk_fecha_corte, sk_fecha_inicio, sk_fecha_meta,
                    id_evaluacion_bk, id_evaluacion_programada_bk, tipo_objetivo, unidad_medida, estado_objetivo,
                    valor_inicial, valor_actual, valor_esperado, avance_alcanzado, avance_esperado, porcentaje_progreso,
                    peso, altura, grasa_corporal, masa_muscular,
                    evaluacion_exigible, evaluacion_completada, evaluacion_pendiente, estado_evaluacion)
            VALUES (s.id_objetivo_bk, s.sk_cliente, s.sk_empleado, s.sk_fecha_corte, s.sk_fecha_inicio, s.sk_fecha_meta,
                    s.id_evaluacion_bk, s.id_evaluacion_programada_bk, s.tipo_objetivo, s.unidad_medida, s.estado_objetivo,
                    s.valor_inicial, s.valor_actual, s.valor_esperado, s.avance_alcanzado, s.avance_esperado, s.porcentaje_progreso,
                    s.peso, s.altura, s.grasa_corporal, s.masa_muscular,
                    s.evaluacion_exigible, s.evaluacion_completada, s.evaluacion_pendiente, s.estado_evaluacion);

        /* =====================================================================
           BORRADOS (última operación = DELETE)
           ===================================================================== */
        DELETE t FROM dm_comercial.FactVentas t INNER JOIN
        (
            SELECT id_pago_bk AS bk FROM
            (SELECT id_pago_bk, OperacionCDC, ROW_NUMBER() OVER (PARTITION BY id_pago_bk ORDER BY StagingID DESC) rn
             FROM dbo.stg_ventas_membresias
             WHERE EntidadOrigen = 'VENTA' AND id_pago_bk IS NOT NULL AND StagingID > @DesdeVM AND StagingID <= @HastaVM) x
            WHERE x.rn = 1 AND x.OperacionCDC = 1
        ) d ON d.bk = t.id_pago_bk;

        /* Membresía eliminada: se eliminan todos sus cortes. */
        DELETE t FROM dm_comercial.FactMembresias t INNER JOIN
        (
            SELECT id_membresia_bk AS bk FROM
            (SELECT id_membresia_bk, OperacionCDC, ROW_NUMBER() OVER (PARTITION BY id_membresia_bk ORDER BY StagingID DESC) rn
             FROM dbo.stg_ventas_membresias
             WHERE EntidadOrigen = 'MEMBRESIA' AND id_membresia_bk IS NOT NULL AND StagingID > @DesdeVM AND StagingID <= @HastaVM) x
            WHERE x.rn = 1 AND x.OperacionCDC = 1
        ) d ON d.bk = t.id_membresia_bk;

        DELETE t FROM dm_entrenamiento.FactAsistencias t INNER JOIN
        (
            SELECT id_asistencia_bk AS bk FROM
            (SELECT id_asistencia_bk, OperacionCDC, ROW_NUMBER() OVER (PARTITION BY id_asistencia_bk ORDER BY StagingID DESC) rn
             FROM dbo.stg_entrenamiento
             WHERE EntidadOrigen = 'ASISTENCIA' AND id_asistencia_bk IS NOT NULL AND StagingID > @DesdeEnt AND StagingID <= @HastaEnt) x
            WHERE x.rn = 1 AND x.OperacionCDC = 1
        ) d ON d.bk = t.id_asistencia_bk;

        DELETE t FROM dm_entrenamiento.FactSesionesEntrenamiento t INNER JOIN
        (
            SELECT id_sesion_bk AS bk FROM
            (SELECT id_sesion_bk, OperacionCDC, ROW_NUMBER() OVER (PARTITION BY id_sesion_bk ORDER BY StagingID DESC) rn
             FROM dbo.stg_entrenamiento
             WHERE EntidadOrigen = 'SESION_PROGRAMADA' AND id_sesion_bk IS NOT NULL AND StagingID > @DesdeEnt AND StagingID <= @HastaEnt) x
            WHERE x.rn = 1 AND x.OperacionCDC = 1
        ) d ON d.bk = t.id_sesion_bk;

        /* Objetivo eliminado: se eliminan todos sus cortes. */
        DELETE t FROM dm_entrenamiento.FactSeguimientoFisico t INNER JOIN
        (
            SELECT id_objetivo_bk AS bk FROM
            (SELECT id_objetivo_bk, OperacionCDC, ROW_NUMBER() OVER (PARTITION BY id_objetivo_bk ORDER BY StagingID DESC) rn
             FROM dbo.stg_entrenamiento
             WHERE EntidadOrigen = 'OBJETIVO' AND id_objetivo_bk IS NOT NULL AND StagingID > @DesdeEnt AND StagingID <= @HastaEnt) x
            WHERE x.rn = 1 AND x.OperacionCDC = 1
        ) d ON d.bk = t.id_objetivo_bk;

        DELETE t FROM dm_atencion.FactReclamos t INNER JOIN
        (
            SELECT id_reclamo_bk AS bk FROM
            (SELECT id_reclamo_bk, OperacionCDC, ROW_NUMBER() OVER (PARTITION BY id_reclamo_bk ORDER BY StagingID DESC) rn
             FROM dbo.stg_atencion_reclamos
             WHERE EntidadOrigen = 'RECLAMO' AND id_reclamo_bk IS NOT NULL AND StagingID > @DesdeRec AND StagingID <= @HastaRec) x
            WHERE x.rn = 1 AND x.OperacionCDC = 1
        ) d ON d.bk = t.id_reclamo_bk;

        DELETE t FROM dm_atencion.FactRetenciones t INNER JOIN
        (
            SELECT id_retencion_bk AS bk FROM
            (SELECT id_retencion_bk, OperacionCDC, ROW_NUMBER() OVER (PARTITION BY id_retencion_bk ORDER BY StagingID DESC) rn
             FROM dbo.stg_atencion_reclamos
             WHERE EntidadOrigen = 'RETENCION' AND id_retencion_bk IS NOT NULL AND StagingID > @DesdeRec AND StagingID <= @HastaRec) x
            WHERE x.rn = 1 AND x.OperacionCDC = 1
        ) d ON d.bk = t.id_retencion_bk;

        /* =====================================================================
           AVANCE DE MARCAS DE AGUA
           ===================================================================== */
        UPDATE dbo.etl_control SET ultimo_staging_id = @HastaFecha, ultima_carga = SYSUTCDATETIME(), filas_ultima_carga = @HastaFecha - @DesdeFecha WHERE proceso = 'stg_fecha';
        UPDATE dbo.etl_control SET ultimo_staging_id = @HastaCli,   ultima_carga = SYSUTCDATETIME(), filas_ultima_carga = @HastaCli   - @DesdeCli   WHERE proceso = 'stg_clientes';
        UPDATE dbo.etl_control SET ultimo_staging_id = @HastaEmp,   ultima_carga = SYSUTCDATETIME(), filas_ultima_carga = @HastaEmp   - @DesdeEmp   WHERE proceso = 'stg_empleados';
        UPDATE dbo.etl_control SET ultimo_staging_id = @HastaPla,   ultima_carga = SYSUTCDATETIME(), filas_ultima_carga = @HastaPla   - @DesdePla   WHERE proceso = 'stg_planes';
        UPDATE dbo.etl_control SET ultimo_staging_id = @HastaVM,    ultima_carga = SYSUTCDATETIME(), filas_ultima_carga = @HastaVM    - @DesdeVM    WHERE proceso = 'stg_ventas_membresias';
        UPDATE dbo.etl_control SET ultimo_staging_id = @HastaEnt,   ultima_carga = SYSUTCDATETIME(), filas_ultima_carga = @HastaEnt   - @DesdeEnt   WHERE proceso = 'stg_entrenamiento';
        UPDATE dbo.etl_control SET ultimo_staging_id = @HastaRec,   ultima_carga = SYSUTCDATETIME(), filas_ultima_carga = @HastaRec   - @DesdeRec   WHERE proceso = 'stg_atencion_reclamos';
        UPDATE dbo.etl_control
           SET ultimo_staging_id = CONVERT(BIGINT, CONVERT(CHAR(8), @Corte, 112)),
               ultima_carga = SYSUTCDATETIME(),
               filas_ultima_carga = (SELECT COUNT_BIG(*) FROM #SnapshotMem)
        WHERE proceso = 'snapshot_membresias';
        UPDATE dbo.etl_control
           SET ultimo_staging_id = CONVERT(BIGINT, CONVERT(CHAR(8), @Corte, 112)),
               ultima_carga = SYSUTCDATETIME(),
               filas_ultima_carga = (SELECT COUNT_BIG(*) FROM #SnapshotSeg)
        WHERE proceso = 'snapshot_seguimiento';

        COMMIT TRANSACTION;

        SELECT 'ETL_INCREMENTAL' AS Estado, @Corte AS FechaCorte,
               @DesdeFecha AS FechaDesdeStagingID, @HastaFecha AS FechaHastaStagingID;

        SELECT proceso, ultimo_staging_id, ultima_carga, filas_ultima_carga
        FROM dbo.etl_control
        ORDER BY proceso;

        SELECT 'DimFecha' AS Tabla, COUNT_BIG(*) AS Filas FROM dim.DimFecha
        UNION ALL SELECT 'DimCliente', COUNT_BIG(*) FROM dim.DimCliente
        UNION ALL SELECT 'DimEmpleado', COUNT_BIG(*) FROM dim.DimEmpleado
        UNION ALL SELECT 'DimPlan', COUNT_BIG(*) FROM dim.DimPlan
        UNION ALL SELECT 'FactVentas', COUNT_BIG(*) FROM dm_comercial.FactVentas
        UNION ALL SELECT 'FactMembresias', COUNT_BIG(*) FROM dm_comercial.FactMembresias
        UNION ALL SELECT 'FactAsistencias', COUNT_BIG(*) FROM dm_entrenamiento.FactAsistencias
        UNION ALL SELECT 'FactSesionesEntrenamiento', COUNT_BIG(*) FROM dm_entrenamiento.FactSesionesEntrenamiento
        UNION ALL SELECT 'FactSeguimientoFisico', COUNT_BIG(*) FROM dm_entrenamiento.FactSeguimientoFisico
        UNION ALL SELECT 'FactReclamos', COUNT_BIG(*) FROM dm_atencion.FactReclamos
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
   Deja el Data Mart limpio, reinicia las marcas de agua y ejecuta la primera
   carga. En producción esto NO se corre: el job ejecuta sólo el procedimiento.
   ============================================================================= */
DELETE FROM dm_atencion.FactRetenciones;
DELETE FROM dm_atencion.FactReclamos;
DELETE FROM dm_entrenamiento.FactSeguimientoFisico;
DELETE FROM dm_entrenamiento.FactSesionesEntrenamiento;
DELETE FROM dm_entrenamiento.FactAsistencias;
DELETE FROM dm_comercial.FactMembresias;
DELETE FROM dm_comercial.FactVentas;
DELETE FROM dim.DimPlan     WHERE sk_plan     <> -1;
DELETE FROM dim.DimEmpleado WHERE sk_empleado <> -1;
DELETE FROM dim.DimCliente  WHERE sk_cliente  <> -1;
DELETE FROM dim.DimFecha    WHERE sk_fecha    <> -1;
DELETE FROM dq.RegistroImputaciones;
UPDATE dbo.etl_control SET ultimo_staging_id = 0, ultima_carga = NULL, filas_ultima_carga = NULL;
GO

EXEC dbo.usp_Transformar_CargarDataMart @FechaCorte = '2026-09-29';
GO
