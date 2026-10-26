/*=============================================================================
  PRUEBAS DEL DATA MART Y DE LAS MÉTRICAS

  Este archivo no transforma ni carga datos. Solo comprueba que 04 haya creado
  el modelo de 7 hechos y que 05 devuelva resultados coherentes antes de
  conectar Power BI.

  Criterio: cada control estructural debe devolver 'OK'. Los listados de
  diagnóstico son informativos.
=============================================================================*/

USE BI_VIP_CENTER_FIT_DW;
GO

SELECT
    DB_NAME() AS BaseDatos,
    '06_PRUEBAS_INICIADAS' AS Estado,
    SYSDATETIME() AS FechaPrueba;
GO

/* 1. Conteo de dimensiones y de los 7 hechos. */
SELECT 'DimFecha' AS Tabla, COUNT_BIG(*) AS Filas FROM dbo.DimFecha
UNION ALL SELECT 'DimCliente', COUNT_BIG(*) FROM dbo.DimCliente
UNION ALL SELECT 'DimEmpleado', COUNT_BIG(*) FROM dbo.DimEmpleado
UNION ALL SELECT 'DimPlan', COUNT_BIG(*) FROM dbo.DimPlan
UNION ALL SELECT 'dm_comercial.FactVentas', COUNT_BIG(*) FROM dm_comercial.FactVentas
UNION ALL SELECT 'dm_comercial.FactMembresias', COUNT_BIG(*) FROM dm_comercial.FactMembresias
UNION ALL SELECT 'dm_entrenamiento.FactAsistencias', COUNT_BIG(*) FROM dm_entrenamiento.FactAsistencias
UNION ALL SELECT 'dm_entrenamiento.FactSesionesEntrenamiento', COUNT_BIG(*) FROM dm_entrenamiento.FactSesionesEntrenamiento
UNION ALL SELECT 'dm_entrenamiento.FactSeguimientoFisico', COUNT_BIG(*) FROM dm_entrenamiento.FactSeguimientoFisico
UNION ALL SELECT 'dm_atencion.FactReclamos', COUNT_BIG(*) FROM dm_atencion.FactReclamos
UNION ALL SELECT 'dm_atencion.FactRetenciones', COUNT_BIG(*) FROM dm_atencion.FactRetenciones;
GO

/* 1.1. Debe haber exactamente 7 tablas de hechos en los 3 data marts. */
SELECT 'EST-00 Siete hechos en los data marts' AS Control,
       CASE WHEN COUNT(*) = 7 THEN 'OK' ELSE 'FALLA' END AS Resultado,
       COUNT(*) AS HechosEncontrados
FROM sys.tables t
INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE s.name IN ('dm_comercial', 'dm_entrenamiento', 'dm_atencion')
  AND t.name LIKE 'Fact%';
GO

/* 1.2. Las vistas deben devolver filas cuando el DW tiene datos. */
SELECT Vista, Filas,
       CASE WHEN Filas > 0 THEN 'CON_DATOS' ELSE 'SIN_DATOS' END AS Estado
FROM
(
    SELECT 'DM_Gerencia_Ingresos' AS Vista, COUNT_BIG(*) AS Filas FROM dbo.DM_Gerencia_Ingresos
    UNION ALL SELECT 'DM_Gerencia_Membresias', COUNT_BIG(*) FROM dbo.DM_Gerencia_Membresias
    UNION ALL SELECT 'DM_Comercial_Plan', COUNT_BIG(*) FROM dbo.DM_Comercial_Plan
    UNION ALL SELECT 'DM_Comercial_Promociones', COUNT_BIG(*) FROM dbo.DM_Comercial_Promociones
    UNION ALL SELECT 'DM_Avisos_Cobertura', COUNT_BIG(*) FROM dbo.DM_Avisos_Cobertura
    UNION ALL SELECT 'DM_Atencion_Reclamos', COUNT_BIG(*) FROM dbo.DM_Atencion_Reclamos
    UNION ALL SELECT 'DM_Atencion_Recepcion', COUNT_BIG(*) FROM dbo.DM_Atencion_Recepcion
    UNION ALL SELECT 'DM_Atencion_Retencion', COUNT_BIG(*) FROM dbo.DM_Atencion_Retencion
    UNION ALL SELECT 'DM_Entrenamiento_Asistencia', COUNT_BIG(*) FROM dbo.DM_Entrenamiento_Asistencia
    UNION ALL SELECT 'DM_Entrenamiento_Accesos', COUNT_BIG(*) FROM dbo.DM_Entrenamiento_Accesos
    UNION ALL SELECT 'DM_Entrenamiento_Progreso', COUNT_BIG(*) FROM dbo.DM_Entrenamiento_Progreso
    UNION ALL SELECT 'DM_Entrenamiento_BajoProgreso', COUNT_BIG(*) FROM dbo.DM_Entrenamiento_BajoProgreso
    UNION ALL SELECT 'DM_Entrenamiento_Evaluaciones', COUNT_BIG(*) FROM dbo.DM_Entrenamiento_Evaluaciones
    UNION ALL SELECT 'DM_Rutinas_Entrenador', COUNT_BIG(*) FROM dbo.DM_Rutinas_Entrenador
) AS ResumenMetricas
ORDER BY Vista;
GO

/* 2. Granos declarados: deben ser únicos. */
SELECT 'GRA-01 Grano FactVentas (id_pago_bk)' AS Control,
       CASE WHEN EXISTS (
           SELECT id_pago_bk FROM dm_comercial.FactVentas GROUP BY id_pago_bk HAVING COUNT(*) > 1
       ) THEN 'FALLA' ELSE 'OK' END AS Resultado;

SELECT 'GRA-02 Grano FactMembresias (id_membresia_bk + fecha_corte)' AS Control,
       CASE WHEN EXISTS (
           SELECT id_membresia_bk, sk_fecha_corte
           FROM dm_comercial.FactMembresias
           GROUP BY id_membresia_bk, sk_fecha_corte
           HAVING COUNT(*) > 1
       ) THEN 'FALLA' ELSE 'OK' END AS Resultado;

SELECT 'GRA-03 Grano FactSeguimientoFisico (cliente + objetivo + fecha_corte)' AS Control,
       CASE WHEN EXISTS (
           SELECT sk_cliente, id_objetivo_bk, sk_fecha_corte
           FROM dm_entrenamiento.FactSeguimientoFisico
           GROUP BY sk_cliente, id_objetivo_bk, sk_fecha_corte
           HAVING COUNT(*) > 1
       ) THEN 'FALLA' ELSE 'OK' END AS Resultado;

SELECT 'GRA-04 Grano FactSesionesEntrenamiento (id_sesion_bk)' AS Control,
       CASE WHEN EXISTS (
           SELECT id_sesion_bk FROM dm_entrenamiento.FactSesionesEntrenamiento GROUP BY id_sesion_bk HAVING COUNT(*) > 1
       ) THEN 'FALLA' ELSE 'OK' END AS Resultado;

SELECT 'GRA-05 Grano FactAsistencias (id_asistencia_bk)' AS Control,
       CASE WHEN EXISTS (
           SELECT id_asistencia_bk FROM dm_entrenamiento.FactAsistencias GROUP BY id_asistencia_bk HAVING COUNT(*) > 1
       ) THEN 'FALLA' ELSE 'OK' END AS Resultado;

SELECT 'GRA-06 Grano FactReclamos (id_reclamo_bk)' AS Control,
       CASE WHEN EXISTS (
           SELECT id_reclamo_bk FROM dm_atencion.FactReclamos GROUP BY id_reclamo_bk HAVING COUNT(*) > 1
       ) THEN 'FALLA' ELSE 'OK' END AS Resultado;

SELECT 'GRA-07 Grano FactRetenciones (id_retencion_bk)' AS Control,
       CASE WHEN EXISTS (
           SELECT id_retencion_bk FROM dm_atencion.FactRetenciones GROUP BY id_retencion_bk HAVING COUNT(*) > 1
       ) THEN 'FALLA' ELSE 'OK' END AS Resultado;
GO

/* 3. Serie de cortes: continua (sin huecos) y en orden. */
SELECT 'SNP-01 Serie de cortes sin huecos (FactMembresias)' AS Control,
       CASE WHEN EXISTS
       (
           SELECT 1
           FROM
           (
               SELECT
                   id_membresia_bk,
                   sk_fecha_corte,
                   LAG(sk_fecha_corte) OVER (PARTITION BY id_membresia_bk ORDER BY sk_fecha_corte) AS anterior
               FROM dm_comercial.FactMembresias
           ) x
           INNER JOIN dim.DimFecha fa ON fa.sk_fecha = x.anterior
           INNER JOIN dim.DimFecha fc ON fc.sk_fecha = x.sk_fecha_corte
           WHERE x.anterior IS NOT NULL
             AND DATEDIFF(DAY, fa.fecha, fc.fecha) > 1
       ) THEN 'FALLA' ELSE 'OK' END AS Resultado;

SELECT 'SNP-02 Serie de cortes sin huecos (FactSeguimientoFisico)' AS Control,
       CASE WHEN EXISTS
       (
           SELECT 1
           FROM
           (
               SELECT
                   id_objetivo_bk,
                   sk_fecha_corte,
                   LAG(sk_fecha_corte) OVER (PARTITION BY id_objetivo_bk ORDER BY sk_fecha_corte) AS anterior
               FROM dm_entrenamiento.FactSeguimientoFisico
           ) x
           INNER JOIN dim.DimFecha fa ON fa.sk_fecha = x.anterior
           INNER JOIN dim.DimFecha fc ON fc.sk_fecha = x.sk_fecha_corte
           WHERE x.anterior IS NOT NULL
             AND DATEDIFF(DAY, fa.fecha, fc.fecha) > 1
       ) THEN 'FALLA' ELSE 'OK' END AS Resultado;

SELECT 'SNP-03 Cortes anteriores al inicio del contrato' AS Control,
       CASE WHEN EXISTS
       (
           SELECT 1
           FROM dm_comercial.FactMembresias fm
           INNER JOIN dim.DimFecha fc ON fc.sk_fecha = fm.sk_fecha_corte
           INNER JOIN dim.DimFecha fi ON fi.sk_fecha = fm.sk_fecha_inicio
           WHERE fc.fecha < fi.fecha
       ) THEN 'FALLA' ELSE 'OK' END AS Resultado;

SELECT 'SNP-04 Estado coherente con la fecha del corte' AS Control,
       CASE WHEN EXISTS
       (
           SELECT 1
           FROM dm_comercial.FactMembresias fm
           INNER JOIN dim.DimFecha fc ON fc.sk_fecha = fm.sk_fecha_corte
           INNER JOIN dim.DimFecha fi ON fi.sk_fecha = fm.sk_fecha_inicio
           INNER JOIN dim.DimFecha ff ON ff.sk_fecha = fm.sk_fecha_fin
           WHERE (fm.estado_membresia = 'ACTIVA'    AND (fc.fecha < fi.fecha OR fc.fecha > ff.fecha))
              OR (fm.estado_membresia = 'VENCIDA'   AND fc.fecha <= ff.fecha)
       ) THEN 'FALLA' ELSE 'OK' END AS Resultado;

SELECT 'SNP-05 Aviso no retrocede en la serie' AS Control,
       CASE WHEN EXISTS
       (
           SELECT 1
           FROM
           (
               SELECT
                   id_membresia_bk,
                   aviso_emitido,
                   LAG(aviso_emitido) OVER (PARTITION BY id_membresia_bk ORDER BY sk_fecha_corte) AS anterior
               FROM dm_comercial.FactMembresias
           ) x
           WHERE x.anterior = 1 AND x.aviso_emitido = 0
       ) THEN 'FALLA' ELSE 'OK' END AS Resultado;

SELECT 'SNP-06 Objetivo con fecha meta anterior al inicio' AS Control,
       CASE WHEN EXISTS
       (
           SELECT 1
           FROM dm_entrenamiento.FactSeguimientoFisico fs
           INNER JOIN dim.DimFecha fi ON fi.sk_fecha = fs.sk_fecha_inicio
           INNER JOIN dim.DimFecha fm ON fm.sk_fecha = fs.sk_fecha_meta
           WHERE fm.fecha < fi.fecha
       ) THEN 'FALLA' ELSE 'OK' END AS Resultado;
GO

/* 4. Validaciones heredadas del modelo limpio. */
SELECT 'LIM-01 Ventas con monto negativo' AS Control,
       CASE WHEN EXISTS (SELECT 1 FROM dbo.FactVentas WHERE monto_neto < 0)
            THEN 'FALLA' ELSE 'OK' END AS Resultado;

SELECT 'LIM-02 Membresías con fin anterior al inicio' AS Control,
       CASE WHEN EXISTS
       (
           SELECT 1
           FROM dbo.FactMembresias fm
           INNER JOIN dbo.DimFecha fi ON fi.sk_fecha = fm.sk_fecha_inicio
           INNER JOIN dbo.DimFecha ff ON ff.sk_fecha = fm.sk_fecha_fin
           WHERE ff.fecha < fi.fecha
       ) THEN 'FALLA' ELSE 'OK' END AS Resultado;

SELECT 'LIM-03 Fechas con mes inválido' AS Control,
       CASE WHEN EXISTS (SELECT 1 FROM dbo.DimFecha WHERE mes NOT BETWEEN 1 AND 12)
            THEN 'FALLA' ELSE 'OK' END AS Resultado;

SELECT 'REF-01 Claves huérfanas en ventas' AS Control,
       CASE WHEN EXISTS
       (
           SELECT 1
           FROM dbo.FactVentas fv
           LEFT JOIN dbo.DimCliente c ON c.sk_cliente = fv.sk_cliente
           LEFT JOIN dbo.DimPlan p ON p.sk_plan = fv.sk_plan
           LEFT JOIN dbo.DimFecha f ON f.sk_fecha = fv.sk_fecha_pago
           WHERE c.sk_cliente IS NULL OR p.sk_plan IS NULL OR f.sk_fecha IS NULL
       ) THEN 'FALLA' ELSE 'OK' END AS Resultado;

SELECT 'REF-02 DimEmpleado sin código de negocio' AS Control,
       CASE WHEN EXISTS (SELECT 1 FROM dbo.DimEmpleado WHERE codigo_empleado IS NULL)
            THEN 'FALLA' ELSE 'OK' END AS Resultado;
GO

/* 5. Métricas de estado: no deben sumarse entre días.
      Se compara el valor del corte contra la suma diaria; solo el corte es válido. */
SELECT
    'CTL-01 Membresías activas al último corte' AS Control,
    COUNT(DISTINCT CASE WHEN fm.estado_membresia = 'ACTIVA' THEN fm.id_membresia_bk END) AS ValorEnElCorte,
    SUM(CASE WHEN fm.estado_membresia = 'ACTIVA' THEN 1 ELSE 0 END) AS SumaDiariaNoValida
FROM dbo.FactMembresias fm
WHERE fm.sk_fecha_corte = (SELECT MAX(sk_fecha_corte) FROM dbo.FactMembresias);
GO

/* 6. Rangos válidos de los KPIs (0 filas fuera de rango). */
SELECT 'KPI-01 Crecimiento de ingresos' AS KPI, COUNT(*) AS ValoresFueraDeRango
FROM dbo.DM_Gerencia_Ingresos WHERE TasaCrecimientoIngresos < -100;

SELECT 'KPI-02 Retención de clientes' AS KPI, COUNT(*) AS ValoresFueraDeRango
FROM dbo.DM_Gerencia_Membresias
WHERE TasaRetencionClientes IS NOT NULL AND (TasaRetencionClientes < 0 OR TasaRetencionClientes > 100);

SELECT 'KPI-03 Renovación de membresías' AS KPI, COUNT(*) AS ValoresFueraDeRango
FROM dbo.DM_Gerencia_Membresias
WHERE TasaRenovacionMembresias IS NOT NULL AND (TasaRenovacionMembresias < 0 OR TasaRenovacionMembresias > 100);

SELECT 'KPI-04 Renovación por plan' AS KPI, COUNT(*) AS ValoresFueraDeRango
FROM dbo.DM_Comercial_Plan
WHERE TasaRenovacionPorPlan IS NOT NULL AND (TasaRenovacionPorPlan < 0 OR TasaRenovacionPorPlan > 100);

SELECT 'KPI-05 Cobertura de avisos' AS KPI, COUNT(*) AS ValoresFueraDeRango
FROM dbo.DM_Avisos_Cobertura
WHERE TasaCoberturaAvisos IS NOT NULL AND (TasaCoberturaAvisos < 0 OR TasaCoberturaAvisos > 100);

SELECT 'KPI-06 Resolución directa en mostrador' AS KPI, COUNT(*) AS ValoresFueraDeRango
FROM dbo.DM_Atencion_Reclamos
WHERE TasaResolucionDirectaMostrador IS NOT NULL
  AND (TasaResolucionDirectaMostrador < 0 OR TasaResolucionDirectaMostrador > 100);

SELECT 'KPI-07 Éxito de retención' AS KPI, COUNT(*) AS ValoresFueraDeRango
FROM dbo.DM_Atencion_Retencion
WHERE TasaExitoRetencion IS NOT NULL AND (TasaExitoRetencion < 0 OR TasaExitoRetencion > 100);

SELECT 'KPI-08 Tasa de asistencia' AS KPI, COUNT(*) AS ValoresFueraDeRango
FROM dbo.DM_Entrenamiento_Asistencia
WHERE TasaAsistencia IS NOT NULL AND (TasaAsistencia < 0 OR TasaAsistencia > 100);

SELECT 'KPI-09 Cumplimiento de evaluaciones' AS KPI, COUNT(*) AS ValoresFueraDeRango
FROM dbo.DM_Entrenamiento_Evaluaciones
WHERE TasaCumplimientoEvaluaciones IS NOT NULL
  AND (TasaCumplimientoEvaluaciones < 0 OR TasaCumplimientoEvaluaciones > 100);

SELECT 'KPI-10 Porcentaje de progreso negativo' AS KPI, COUNT(*) AS ValoresFueraDeRango
FROM dbo.DM_Entrenamiento_Progreso
WHERE PorcentajeProgreso IS NOT NULL AND PorcentajeProgreso < 0;
GO

/* 7. Listados de diagnóstico. */
SELECT TOP (30) * FROM dbo.DM_Gerencia_Ingresos ORDER BY Anio, MesNumero;
SELECT TOP (30) * FROM dbo.DM_Gerencia_Membresias ORDER BY Anio, MesNumero;
SELECT TOP (30) * FROM dbo.DM_Comercial_Plan ORDER BY Anio, MesNumero, TipoPlan;
SELECT TOP (30) * FROM dbo.DM_Comercial_Promociones ORDER BY Anio, MesNumero, Promocion;
SELECT TOP (30) * FROM dbo.DM_Avisos_Cobertura ORDER BY FechaCorte;
SELECT TOP (30) * FROM dbo.DM_Atencion_Reclamos ORDER BY Anio, MesNumero, CategoriaAtencion;
SELECT TOP (30) * FROM dbo.DM_Atencion_Retencion ORDER BY Anio, MesNumero;
SELECT TOP (30) * FROM dbo.DM_Entrenamiento_Asistencia ORDER BY Anio, MesNumero, IdClienteBk;
SELECT TOP (30) * FROM dbo.DM_Entrenamiento_Accesos ORDER BY Anio, MesNumero, IdClienteBk;
SELECT TOP (30) * FROM dbo.DM_Entrenamiento_Progreso ORDER BY IdClienteBk, IdObjetivoBk;
SELECT TOP (30) * FROM dbo.DM_Entrenamiento_BajoProgreso ORDER BY ObjetivosBajoProgreso DESC;
GO

/* 8. Estado de las marcas de agua (incluye los snapshots). */
SELECT proceso, ultimo_staging_id, ultima_carga, filas_ultima_carga
FROM dbo.etl_control
ORDER BY proceso;

SELECT *
FROM BI_VIP_CENTER_FIT_STG.stg.etl_cdc_control;
GO
