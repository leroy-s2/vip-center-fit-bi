/*=============================================================================
  PRUEBA DEL ETL INCREMENTAL (staging -> Data Mart)

  Verifica que:
    1) Una corrida sin cambios NO procesa nada (la marca de agua no avanza).
    2) Un INSERT en la fuente llega al Data Mart sin recargar todo.
    3) Un UPDATE en la fuente se refleja (MERGE) sin duplicar la fila.
    4) Un DELETE en la fuente se propaga (baja lógica del cliente).

  Requiere SQL Server Agent activo para que el capture job de CDC llene las
  tablas cdc.*_CT (el script espera unos segundos tras cada cambio).

  Ejecutar después de 03_CDC_Ingesta.sql, 04 y 08.
=============================================================================*/

SET NOCOUNT ON;
GO

/* --- 0) Corrida en seco: sin cambios, la marca de agua no debe avanzar. --- */
USE BI_VIP_CENTER_FIT_DW;
GO

DECLARE @antes_cli BIGINT = (SELECT ultimo_staging_id FROM dbo.etl_control WHERE proceso = 'stg_clientes');
DECLARE @antes_vm  BIGINT = (SELECT ultimo_staging_id FROM dbo.etl_control WHERE proceso = 'stg_ventas_membresias');

EXEC dbo.usp_Transformar_CargarDataMart;

DECLARE @despues_cli BIGINT = (SELECT ultimo_staging_id FROM dbo.etl_control WHERE proceso = 'stg_clientes');
DECLARE @despues_vm  BIGINT = (SELECT ultimo_staging_id FROM dbo.etl_control WHERE proceso = 'stg_ventas_membresias');

SELECT
    '1) CORRIDA_SIN_CAMBIOS' AS Prueba,
    @antes_cli AS AntesClientes, @despues_cli AS DespuesClientes,
    @antes_vm AS AntesVentas, @despues_vm AS DespuesVentas,
    CASE WHEN @antes_cli = @despues_cli AND @antes_vm = @despues_vm THEN 'OK' ELSE 'FALLA' END AS Resultado;
GO

/* --- 1) INSERT: nuevo cliente en la fuente. --- */
USE BI_VIP_CENTER_FIT_DW_ORIGEN;
GO

DELETE FROM dbo.DimCliente WHERE id_cliente_bk = 999001;

INSERT INTO dbo.DimCliente
(
    id_cliente_bk, dni, nombre_completo, sexo, rango_etario,
    estado_cliente, fecha_registro_origen, fecha_inicio_validez, fecha_fin_validez, es_actual
)
VALUES
(
    999001, '00099001', 'Cliente Prueba Incremental', 'M', 'Adultos (>40)',
    'ACTIVO', '2026-09-01', '2026-09-01', NULL, 1
);

SELECT 'INSERT_GENERADO' AS Estado, 999001 AS id_cliente_bk;
GO

WAITFOR DELAY '00:00:10';
GO

USE BI_VIP_CENTER_FIT_STG;
GO
EXEC dbo.usp_Ingesta_CDC;
GO

USE BI_VIP_CENTER_FIT_DW;
GO
EXEC dbo.usp_Transformar_CargarDataMart;
GO

SELECT
    '2) INSERT_PROPAGADO' AS Prueba,
    (SELECT COUNT(*) FROM dim.DimCliente WHERE id_cliente_bk = 999001) AS FilasDim,
    (SELECT filas_ultima_carga FROM dbo.etl_control WHERE proceso = 'stg_clientes') AS FilasProcesadas,
    CASE WHEN EXISTS (SELECT 1 FROM dim.DimCliente WHERE id_cliente_bk = 999001 AND estado_cliente = 'ACTIVO') THEN 'OK' ELSE 'FALLA' END AS Resultado;
GO

/* --- 2) UPDATE: el cliente cambia de estado. --- */
USE BI_VIP_CENTER_FIT_DW_ORIGEN;
GO
UPDATE dbo.DimCliente SET estado_cliente = 'INACTIVO', nombre_completo = 'Cliente Prueba Incremental Editado' WHERE id_cliente_bk = 999001;
GO

WAITFOR DELAY '00:00:10';
GO

USE BI_VIP_CENTER_FIT_STG;
GO
EXEC dbo.usp_Ingesta_CDC;
GO

USE BI_VIP_CENTER_FIT_DW;
GO
EXEC dbo.usp_Transformar_CargarDataMart;
GO

SELECT
    '3) UPDATE_PROPAGADO' AS Prueba,
    (SELECT COUNT(*) FROM dim.DimCliente WHERE id_cliente_bk = 999001) AS FilasDim,
    (SELECT nombre_completo FROM dim.DimCliente WHERE id_cliente_bk = 999001) AS Nombre,
    CASE WHEN EXISTS (SELECT 1 FROM dim.DimCliente WHERE id_cliente_bk = 999001 AND estado_cliente = 'INACTIVO' AND nombre_completo = 'CLIENTE PRUEBA INCREMENTAL EDITADO') THEN 'OK' ELSE 'FALLA' END AS Resultado;
GO

/* --- 3) DELETE: se propaga como baja lógica (es_actual = 0). --- */
USE BI_VIP_CENTER_FIT_DW_ORIGEN;
GO
DELETE FROM dbo.DimCliente WHERE id_cliente_bk = 999001;
GO

WAITFOR DELAY '00:00:10';
GO

USE BI_VIP_CENTER_FIT_STG;
GO
EXEC dbo.usp_Ingesta_CDC;
GO

USE BI_VIP_CENTER_FIT_DW;
GO
EXEC dbo.usp_Transformar_CargarDataMart;
GO

SELECT
    '4) DELETE_PROPAGADO' AS Prueba,
    (SELECT es_actual FROM dim.DimCliente WHERE id_cliente_bk = 999001) AS EsActual,
    CASE WHEN EXISTS (SELECT 1 FROM dim.DimCliente WHERE id_cliente_bk = 999001 AND es_actual = 0) THEN 'OK' ELSE 'FALLA' END AS Resultado;
GO

/* --- Limpieza de la fila de prueba (la deja fuera del modelo). --- */
USE BI_VIP_CENTER_FIT_DW;
GO
DELETE FROM dim.DimCliente WHERE id_cliente_bk = 999001;
GO

SELECT 'PRUEBA_INCREMENTAL_FINALIZADA' AS Estado;
GO
