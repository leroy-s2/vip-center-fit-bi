/*=============================================================================
  PRUEBA DEMOSTRATIVA DEL CDC

  Ejecutar después de:
    02_Staging_Estructura.sql
    03_Ingesta_Programada.sql
    04_Transformacion_DataMart.sql
    05_Metricas_DataMart.sql
    03_CDC_Ingesta.sql

  La prueba genera un INSERT controlado en FactVentas, muestra la tabla de
  cambios de CDC, ejecuta la ingesta y muestra el registro que llegó a staging.
=============================================================================*/

USE BI_VIP_CENTER_FIT_DW_ORIGEN;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.tables
    WHERE name = 'FactVentas'
      AND is_tracked_by_cdc = 1
)
BEGIN
    THROW 51001, 'FactVentas no tiene CDC habilitado. Ejecute primero 03_CDC_Ingesta.sql.', 1;
END;
GO

DECLARE @TestPagoID INT;
DECLARE @SKFecha INT;
DECLARE @SKCliente INT;
DECLARE @SKPlan INT;
DECLARE @SKPromocion INT;
DECLARE @SKEmpleado INT;
DECLARE @IDMembresia INT;

SELECT @TestPagoID = ISNULL(MAX(id_pago_bk), 0) + 1
FROM dbo.FactVentas;

SELECT TOP (1) @SKFecha = sk_fecha FROM dbo.DimFecha ORDER BY sk_fecha;
SELECT TOP (1) @SKCliente = sk_cliente FROM dbo.DimCliente ORDER BY sk_cliente;
SELECT TOP (1) @SKPlan = sk_plan FROM dbo.DimPlan ORDER BY sk_plan;
SELECT TOP (1) @SKPromocion = sk_promocion FROM dbo.DimPromocion ORDER BY sk_promocion;
SELECT TOP (1) @SKEmpleado = sk_empleado FROM dbo.DimEmpleado ORDER BY sk_empleado;
SELECT TOP (1) @IDMembresia = id_membresia_bk FROM dbo.FactMembresias ORDER BY id_membresia_bk;

INSERT INTO dbo.FactVentas
(
    id_pago_bk, sk_fecha_pago, sk_cliente, sk_plan, sk_promocion,
    sk_empleado, id_membresia_bk, monto_neto, descuento_aplicado,
    precio_lista, metodo_pago
)
VALUES
(
    @TestPagoID, @SKFecha, @SKCliente, @SKPlan, @SKPromocion,
    @SKEmpleado, @IDMembresia, 99.90, 0, 99.90, 'PRUEBA_CDC'
);

SELECT
    'INSERT_GENERADO' AS Estado,
    @TestPagoID AS id_pago_bk,
    'Espere unos segundos para que SQL Server Agent procese el log de CDC.' AS Mensaje;
GO

WAITFOR DELAY '00:00:10';

/* Tabla de cambios de CDC, equivalente a cdc.dbo_DetalleVenta_CT. */
SELECT TOP (50)
    __$start_lsn,
    __$seqval,
    __$operation,
    CASE __$operation
        WHEN 1 THEN 'DELETE'
        WHEN 2 THEN 'INSERT'
        WHEN 3 THEN 'UPDATE - ANTES'
        WHEN 4 THEN 'UPDATE - DESPUES'
    END AS TipoOperacion,
    id_pago_bk,
    sk_fecha_pago,
    sk_cliente,
    sk_plan,
    monto_neto,
    metodo_pago
FROM cdc.dbo_FactVentas_CT
ORDER BY __$start_lsn DESC, __$seqval DESC;
GO

USE BI_VIP_CENTER_FIT_STG;
GO

EXEC dbo.usp_Ingesta_CDC;
GO

/* Registro CDC que finalmente llegó a Staging. */
SELECT TOP (50)
    StagingID,
    CargaID,
    OperacionCDC,
    CASE OperacionCDC
        WHEN 1 THEN 'DELETE'
        WHEN 2 THEN 'INSERT'
        WHEN 3 THEN 'UPDATE - ANTES'
        WHEN 4 THEN 'UPDATE - DESPUES'
    END AS TipoOperacion,
    id_pago_bk,
    monto_neto,
    metodo_pago,
    FechaIngesta
FROM stg.stg_ventas_membresias
WHERE EntidadOrigen = 'VENTA'
ORDER BY StagingID DESC;
GO

/* Marca de agua y resumen del procesamiento. */
SELECT *
FROM stg.etl_cdc_control
WHERE capture_instance = 'GLOBAL';

SELECT
    'stg_ventas_membresias' AS Tabla,
    EntidadOrigen,
    COUNT_BIG(*) AS Filas
FROM stg.stg_ventas_membresias
GROUP BY EntidadOrigen
ORDER BY EntidadOrigen;
GO

/* Limpieza opcional:
   elimine manualmente el id_pago_bk mostrado como INSERT_GENERADO si no desea
   conservar el registro de prueba en la fuente.
*/
