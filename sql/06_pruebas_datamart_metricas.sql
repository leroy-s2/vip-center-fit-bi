/*=============================================================================
  PRUEBAS DEL DATA MART Y DE LAS MÉTRICAS

  Este archivo no transforma ni carga datos. Solo comprueba que 04 haya creado
  el modelo y que 05 esté devolviendo resultados coherentes antes de conectar
  Power BI.
=============================================================================*/

USE BI_VIP_CENTER_FIT_DW;
GO

SELECT
    DB_NAME() AS BaseDatos,
    '06_PRUEBAS_INICIADAS' AS Estado,
    SYSDATETIME() AS FechaPrueba;
GO

/* 1. Conteo de dimensiones y hechos cargados. */
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
GO

/* 1.1. Las vistas siempre devuelven una fila de diagnóstico, incluso si no tienen datos. */
SELECT Vista, Filas,
       CASE WHEN Filas > 0 THEN 'CON_DATOS' ELSE 'SIN_DATOS' END AS Estado
FROM
(
    SELECT 'DM_Gerencia_Ingresos' AS Vista, COUNT_BIG(*) AS Filas FROM dbo.DM_Gerencia_Ingresos
    UNION ALL SELECT 'DM_Gerencia_Membresias', COUNT_BIG(*) FROM dbo.DM_Gerencia_Membresias
    UNION ALL SELECT 'DM_Comercial_Plan', COUNT_BIG(*) FROM dbo.DM_Comercial_Plan
    UNION ALL SELECT 'DM_Avisos_Cobertura', COUNT_BIG(*) FROM dbo.DM_Avisos_Cobertura
    UNION ALL SELECT 'DM_Atencion_Reclamos', COUNT_BIG(*) FROM dbo.DM_Atencion_Reclamos
    UNION ALL SELECT 'DM_Entrenamiento_Asistencia', COUNT_BIG(*) FROM dbo.DM_Entrenamiento_Asistencia
    UNION ALL SELECT 'DM_Entrenamiento_Progreso', COUNT_BIG(*) FROM dbo.DM_Entrenamiento_Progreso
    UNION ALL SELECT 'DM_Entrenamiento_Cumplimiento', COUNT_BIG(*) FROM dbo.DM_Entrenamiento_Cumplimiento
) AS ResumenMetricas
ORDER BY Vista;
GO

/* 2. Validación de errores que no deberían llegar al Data Mart limpio. */
SELECT 'Ventas con monto negativo' AS Prueba,
       CASE WHEN EXISTS (SELECT 1 FROM dbo.FactVentas WHERE monto_neto < 0)
            THEN 'FALLA' ELSE 'OK' END AS Resultado;

SELECT 'Duplicados de pagos' AS Prueba,
       CASE WHEN EXISTS
       (
           SELECT id_pago_bk
           FROM dbo.FactVentas
           GROUP BY id_pago_bk
           HAVING COUNT(*) > 1
       ) THEN 'FALLA' ELSE 'OK' END AS Resultado;

SELECT 'Duplicados de membresías' AS Prueba,
       CASE WHEN EXISTS
       (
           SELECT id_membresia_bk
           FROM dbo.FactMembresias
           GROUP BY id_membresia_bk
           HAVING COUNT(*) > 1
       ) THEN 'FALLA' ELSE 'OK' END AS Resultado;

SELECT 'Fechas con mes inválido' AS Prueba,
       CASE WHEN EXISTS (SELECT 1 FROM dbo.DimFecha WHERE mes NOT BETWEEN 1 AND 12)
            THEN 'FALLA' ELSE 'OK' END AS Resultado;

SELECT 'Membresías con fecha final anterior al inicio' AS Prueba,
       CASE WHEN EXISTS
       (
           SELECT 1
           FROM dbo.FactMembresias fm
           INNER JOIN dbo.DimFecha fi ON fi.sk_fecha = fm.sk_fecha_inicio
           INNER JOIN dbo.DimFecha ff ON ff.sk_fecha = fm.sk_fecha_fin
           WHERE ff.fecha < fi.fecha
       ) THEN 'FALLA' ELSE 'OK' END AS Resultado;

SELECT 'Claves huérfanas en ventas' AS Prueba,
       CASE WHEN EXISTS
       (
           SELECT 1
           FROM dbo.FactVentas fv
           LEFT JOIN dbo.DimCliente c ON c.sk_cliente = fv.sk_cliente
           LEFT JOIN dbo.DimPlan p ON p.sk_plan = fv.sk_plan
           LEFT JOIN dbo.DimFecha f ON f.sk_fecha = fv.sk_fecha_pago
           WHERE c.sk_cliente IS NULL OR p.sk_plan IS NULL OR f.sk_fecha IS NULL
       ) THEN 'FALLA' ELSE 'OK' END AS Resultado;
GO

/* 3. Prueba de las métricas de Gerencia. */
SELECT TOP (30) *
FROM dbo.DM_Gerencia_Ingresos
ORDER BY Anio, MesNumero;

SELECT TOP (30) *
FROM dbo.DM_Gerencia_Membresias
ORDER BY Anio, MesNumero;
GO

/* 4. Prueba de las métricas comerciales. */
SELECT TOP (30) *
FROM dbo.DM_Comercial_Plan
ORDER BY Anio, MesNumero, TipoPlan;

SELECT TOP (30) *
FROM dbo.DM_Avisos_Cobertura
ORDER BY FechaCorte;
GO

/* 5. Prueba de Atención y Entrenamiento. */
SELECT TOP (30) *
FROM dbo.DM_Atencion_Reclamos
ORDER BY Anio, MesNumero, CategoriaAtencion;

SELECT TOP (30) *
FROM dbo.DM_Entrenamiento_Asistencia
ORDER BY Anio, MesNumero, id_cliente_bk;

SELECT TOP (30) *
FROM dbo.DM_Entrenamiento_Progreso
ORDER BY id_cliente_bk, id_objetivo_bk;
GO

/* 6. Validación de rangos de KPI. */
SELECT 'Crecimiento de ingresos' AS KPI,
       COUNT(*) AS ValoresFueraDeRango
FROM dbo.DM_Gerencia_Ingresos
WHERE TasaCrecimientoIngresos < -100;

SELECT 'Retención de clientes' AS KPI,
       COUNT(*) AS ValoresFueraDeRango
FROM dbo.DM_Gerencia_Membresias
WHERE TasaRetencionClientes IS NOT NULL
  AND (TasaRetencionClientes < 0 OR TasaRetencionClientes > 100);

SELECT 'Renovación de membresías' AS KPI,
       COUNT(*) AS ValoresFueraDeRango
FROM dbo.DM_Gerencia_Membresias
WHERE TasaRenovacionMembresias IS NOT NULL
  AND (TasaRenovacionMembresias < 0 OR TasaRenovacionMembresias > 100);

SELECT 'Progreso físico' AS KPI,
       COUNT(*) AS ValoresConResultadoInvalido
FROM dbo.DM_Entrenamiento_Progreso
WHERE PorcentajeProgreso IS NOT NULL
  AND PorcentajeProgreso < 0;

SELECT 'Promedio de días de resolución de reclamos' AS KPI,
       COUNT(*) AS ValoresFueraDeRango
FROM dbo.DM_Atencion_Reclamos
WHERE PromedioDiasResolucion IS NOT NULL
  AND PromedioDiasResolucion < 0;

SELECT 'Cumplimiento de objetivos' AS KPI,
       COUNT(*) AS ValoresFueraDeRango
FROM dbo.DM_Entrenamiento_Cumplimiento
WHERE TasaCumplimientoObjetivos IS NOT NULL
  AND (TasaCumplimientoObjetivos < 0 OR TasaCumplimientoObjetivos > 100);
GO

/* 7. Vista rápida de la marca CDC. */
SELECT *
FROM BI_VIP_CENTER_FIT_STG.stg.etl_cdc_control;
GO
