/*=============================================================================
  VIP CENTER FIT - ETAPA 5: DATA MART / MÉTRICAS

  Vistas de métricas del modelo de 7 hechos (AEQUITECTURA BI v2):

    dm_comercial      FactVentas, FactMembresias (snapshot diario)
    dm_entrenamiento  FactAsistencias, FactSesionesEntrenamiento, FactSeguimientoFisico
    dm_atencion       FactReclamos, FactRetenciones

  REGLA DE ORO DE LOS SNAPSHOTS
  -----------------------------
  FactMembresias y FactSeguimientoFisico tienen grano (clave de negocio + fecha
  de corte). Sus medidas de estado (membresías activas, progreso, evaluaciones
  pendientes) se leen EN UN CORTE: nunca se suman entre días. Por eso cada vista
  que las usa reduce primero a un corte vigente (fin de mes o último corte
  disponible). Las cantidades de eventos (avisos emitidos, ventas, reclamos) sí
  son aditivas.
=============================================================================*/

USE BI_VIP_CENTER_FIT_DW;
GO

/* 1. Gerencia: ingresos actuales, anteriores y crecimiento mensual. */
CREATE OR ALTER VIEW dbo.DM_Gerencia_Ingresos
AS
WITH Periodos AS
(
    SELECT
        DATEFROMPARTS(anio, mes, 1) AS PeriodoInicio,
        anio,
        mes,
        MAX(nombre_mes) AS nombre_mes
    FROM dbo.DimFecha
    WHERE anio >= 2000
    GROUP BY DATEFROMPARTS(anio, mes, 1), anio, mes
),
Serie AS
(
    SELECT
        p.PeriodoInicio,
        p.anio AS Anio,
        p.mes AS MesNumero,
        p.nombre_mes AS Mes,
        COALESCE(SUM(fv.monto_neto), 0) AS IngresosPeriodoActual,
        COUNT(DISTINCT fv.id_pago_bk) AS CantidadVentas
    FROM Periodos p
    LEFT JOIN dbo.DimFecha df
        ON df.anio = p.anio
       AND df.mes = p.mes
    LEFT JOIN dbo.FactVentas fv
        ON fv.sk_fecha_pago = df.sk_fecha
    GROUP BY p.PeriodoInicio, p.anio, p.mes, p.nombre_mes
),
ConAnterior AS
(
    SELECT
        *,
        LAG(IngresosPeriodoActual) OVER (ORDER BY PeriodoInicio) AS IngresosPeriodoAnterior
    FROM Serie
)
SELECT
    Anio,
    MesNumero,
    Mes,
    IngresosPeriodoActual,
    IngresosPeriodoAnterior,
    CantidadVentas,
    CASE
        WHEN IngresosPeriodoAnterior IS NULL OR IngresosPeriodoAnterior = 0 THEN NULL
        ELSE ((IngresosPeriodoActual - IngresosPeriodoAnterior) * 100.0)
             / IngresosPeriodoAnterior
    END AS TasaCrecimientoIngresos
FROM ConAnterior;
GO

/* 2. Gerencia: clientes activos, retención, membresías activas y renovación.
      Medidas de estado tomadas al corte de inicio y al corte de cierre del mes. */
CREATE OR ALTER VIEW dbo.DM_Gerencia_Membresias
AS
WITH Cortes AS
(
    SELECT DISTINCT
        d.anio, d.mes, d.nombre_mes,
        fm.sk_fecha_corte
    FROM dbo.FactMembresias fm
    INNER JOIN dbo.DimFecha d ON d.sk_fecha = fm.sk_fecha_corte
),
CorteCierre AS
(
    SELECT anio, mes, MAX(nombre_mes) AS nombre_mes, MAX(sk_fecha_corte) AS sk_corte_cierre
    FROM Cortes
    GROUP BY anio, mes
),
CorteInicio AS
(
    SELECT
        cc.anio,
        cc.mes,
        cc.nombre_mes,
        cc.sk_corte_cierre,
        (
            SELECT MAX(c2.sk_fecha_corte)
            FROM Cortes c2
            INNER JOIN dbo.DimFecha d2 ON d2.sk_fecha = c2.sk_fecha_corte
            WHERE d2.fecha <= DATEFROMPARTS(cc.anio, cc.mes, 1)
        ) AS sk_corte_inicio
    FROM CorteCierre cc
),
ActivosInicio AS
(
    SELECT ci.anio, ci.mes, COUNT(DISTINCT fm.sk_cliente) AS n
    FROM CorteInicio ci
    INNER JOIN dbo.FactMembresias fm
        ON fm.sk_fecha_corte = ci.sk_corte_inicio
       AND fm.estado_membresia = 'ACTIVA'
    GROUP BY ci.anio, ci.mes
),
Retenidos AS
(
    SELECT ci.anio, ci.mes, COUNT(DISTINCT fi.sk_cliente) AS n
    FROM CorteInicio ci
    INNER JOIN dbo.FactMembresias fi
        ON fi.sk_fecha_corte = ci.sk_corte_inicio
       AND fi.estado_membresia = 'ACTIVA'
    INNER JOIN dbo.FactMembresias fc
        ON fc.sk_fecha_corte = ci.sk_corte_cierre
       AND fc.estado_membresia = 'ACTIVA'
       AND fc.sk_cliente = fi.sk_cliente
    GROUP BY ci.anio, ci.mes
),
Activas AS
(
    SELECT ci.anio, ci.mes, COUNT(DISTINCT fm.id_membresia_bk) AS n
    FROM CorteInicio ci
    INNER JOIN dbo.FactMembresias fm
        ON fm.sk_fecha_corte = ci.sk_corte_cierre
       AND fm.estado_membresia = 'ACTIVA'
    GROUP BY ci.anio, ci.mes
),
Vencen AS
(
    SELECT d.anio, d.mes, COUNT(DISTINCT fm.id_membresia_bk) AS n
    FROM dbo.FactMembresias fm
    INNER JOIN dbo.DimFecha d ON d.sk_fecha = fm.sk_fecha_fin
    GROUP BY d.anio, d.mes
),
Renovadas AS
(
    SELECT d.anio, d.mes, COUNT(DISTINCT fm.id_membresia_bk) AS n
    FROM dbo.FactMembresias fm
    INNER JOIN dbo.DimFecha d ON d.sk_fecha = fm.sk_fecha_fin
    WHERE fm.id_membresia_nueva_bk IS NOT NULL
    GROUP BY d.anio, d.mes
)
SELECT
    ci.anio AS Anio,
    ci.mes AS MesNumero,
    ci.nombre_mes AS Mes,
    ci.sk_corte_cierre AS SkFechaCorteCierre,
    COALESCE(ai.n, 0) AS ClientesActivosInicio,
    COALESCE(re.n, 0) AS ClientesInicioActivosCierre,
    CASE
        WHEN COALESCE(ai.n, 0) = 0 THEN NULL
        ELSE re.n * 100.0 / ai.n
    END AS TasaRetencionClientes,
    COALESCE(ac.n, 0) AS MembresiasActivas,
    COALESCE(v.n, 0) AS MembresiasVencenPeriodo,
    COALESCE(r.n, 0) AS MembresiasCohorteRenovadas,
    CASE
        WHEN COALESCE(v.n, 0) = 0 THEN NULL
        ELSE r.n * 100.0 / v.n
    END AS TasaRenovacionMembresias
FROM CorteInicio ci
LEFT JOIN ActivosInicio ai ON ai.anio = ci.anio AND ai.mes = ci.mes
LEFT JOIN Retenidos re     ON re.anio = ci.anio AND re.mes = ci.mes
LEFT JOIN Activas ac       ON ac.anio = ci.anio AND ac.mes = ci.mes
LEFT JOIN Vencen v         ON v.anio = ci.anio AND v.mes = ci.mes
LEFT JOIN Renovadas r      ON r.anio = ci.anio AND r.mes = ci.mes;
GO

/* 3. Comercial: ingresos, ventas, vencimientos y renovaciones por tipo de plan. */
CREATE OR ALTER VIEW dbo.DM_Comercial_Plan
AS
WITH Ingresos AS
(
    SELECT
        DATEFROMPARTS(df.anio, df.mes, 1) AS PeriodoInicio,
        fv.sk_plan,
        SUM(fv.monto_neto) AS IngresosPorPlan,
        COUNT(DISTINCT fv.id_pago_bk) AS VentasPorPlan
    FROM dbo.FactVentas fv
    INNER JOIN dbo.DimFecha df ON df.sk_fecha = fv.sk_fecha_pago
    GROUP BY DATEFROMPARTS(df.anio, df.mes, 1), fv.sk_plan
),
Vendidas AS
(
    SELECT
        DATEFROMPARTS(df.anio, df.mes, 1) AS PeriodoInicio,
        fm.sk_plan,
        COUNT(DISTINCT fm.id_membresia_bk) AS MembresiasVendidas
    FROM dbo.FactMembresias fm
    INNER JOIN dbo.DimFecha df ON df.sk_fecha = fm.sk_fecha_inicio
    GROUP BY DATEFROMPARTS(df.anio, df.mes, 1), fm.sk_plan
),
Vencidas AS
(
    SELECT
        DATEFROMPARTS(df.anio, df.mes, 1) AS PeriodoInicio,
        fm.sk_plan,
        COUNT(DISTINCT fm.id_membresia_bk) AS MembresiasVencen
    FROM dbo.FactMembresias fm
    INNER JOIN dbo.DimFecha df ON df.sk_fecha = fm.sk_fecha_fin
    GROUP BY DATEFROMPARTS(df.anio, df.mes, 1), fm.sk_plan
),
Renovadas AS
(
    SELECT
        DATEFROMPARTS(df.anio, df.mes, 1) AS PeriodoInicio,
        fm.sk_plan,
        COUNT(DISTINCT fm.id_membresia_bk) AS MembresiasRenovadas
    FROM dbo.FactMembresias fm
    INNER JOIN dbo.DimFecha df ON df.sk_fecha = fm.sk_fecha_fin
    WHERE fm.id_membresia_nueva_bk IS NOT NULL
    GROUP BY DATEFROMPARTS(df.anio, df.mes, 1), fm.sk_plan
),
Claves AS
(
    SELECT PeriodoInicio, sk_plan FROM Ingresos
    UNION
    SELECT PeriodoInicio, sk_plan FROM Vendidas
    UNION
    SELECT PeriodoInicio, sk_plan FROM Vencidas
    UNION
    SELECT PeriodoInicio, sk_plan FROM Renovadas
)
SELECT
    YEAR(c.PeriodoInicio) AS Anio,
    MONTH(c.PeriodoInicio) AS MesNumero,
    DATENAME(MONTH, c.PeriodoInicio) AS Mes,
    dp.tipo_plan AS TipoPlan,
    COALESCE(i.IngresosPorPlan, 0) AS IngresosPorTipoPlan,
    COALESCE(i.VentasPorPlan, 0) AS VentasPorPlan,
    COALESCE(v.MembresiasVendidas, 0) AS MembresiasVendidas,
    COALESCE(x.MembresiasVencen, 0) AS MembresiasVencen,
    COALESCE(r.MembresiasRenovadas, 0) AS MembresiasRenovadas,
    CASE
        WHEN COALESCE(x.MembresiasVencen, 0) = 0 THEN NULL
        ELSE r.MembresiasRenovadas * 100.0 / x.MembresiasVencen
    END AS TasaRenovacionPorPlan
FROM Claves c
INNER JOIN dbo.DimPlan dp ON dp.sk_plan = c.sk_plan
LEFT JOIN Ingresos i  ON i.PeriodoInicio = c.PeriodoInicio AND i.sk_plan = c.sk_plan
LEFT JOIN Vendidas v  ON v.PeriodoInicio = c.PeriodoInicio AND v.sk_plan = c.sk_plan
LEFT JOIN Vencidas x  ON x.PeriodoInicio = c.PeriodoInicio AND x.sk_plan = c.sk_plan
LEFT JOIN Renovadas r ON r.PeriodoInicio = c.PeriodoInicio AND r.sk_plan = c.sk_plan;
GO

/* 4. Comercial: promociones (ingresos, membresías vendidas y clientes captados). */
CREATE OR ALTER VIEW dbo.DM_Comercial_Promociones
AS
WITH Ingresos AS
(
    SELECT
        DATEFROMPARTS(df.anio, df.mes, 1) AS PeriodoInicio,
        dp.sk_plan,
        SUM(fv.monto_neto) AS IngresosPorPromocion,
        COUNT(DISTINCT fv.id_pago_bk) AS VentasPorPromocion,
        SUM(fv.descuento_aplicado) AS DescuentoOtorgado
    FROM dbo.FactVentas fv
    INNER JOIN dbo.DimFecha df ON df.sk_fecha = fv.sk_fecha_pago
    INNER JOIN dbo.DimPlan dp ON dp.sk_plan = fv.sk_plan
    WHERE dp.promocion <> 'SIN PROMOCION'
    GROUP BY DATEFROMPARTS(df.anio, df.mes, 1), dp.sk_plan
),
Vendidas AS
(
    SELECT
        DATEFROMPARTS(df.anio, df.mes, 1) AS PeriodoInicio,
        fm.sk_plan,
        COUNT(DISTINCT fm.id_membresia_bk) AS MembresiasVendidas,
        COUNT(DISTINCT fm.sk_cliente) AS ClientesCaptados
    FROM dbo.FactMembresias fm
    INNER JOIN dbo.DimFecha df ON df.sk_fecha = fm.sk_fecha_inicio
    INNER JOIN dbo.DimPlan dp ON dp.sk_plan = fm.sk_plan
    WHERE dp.promocion <> 'SIN PROMOCION'
    GROUP BY DATEFROMPARTS(df.anio, df.mes, 1), fm.sk_plan
),
Claves AS
(
    SELECT PeriodoInicio, sk_plan FROM Ingresos
    UNION
    SELECT PeriodoInicio, sk_plan FROM Vendidas
)
SELECT
    YEAR(c.PeriodoInicio) AS Anio,
    MONTH(c.PeriodoInicio) AS MesNumero,
    DATENAME(MONTH, c.PeriodoInicio) AS Mes,
    dp.tipo_plan AS TipoPlan,
    dp.promocion AS Promocion,
    COALESCE(i.IngresosPorPromocion, 0) AS IngresosPorPromocion,
    COALESCE(i.VentasPorPromocion, 0) AS VentasPorPromocion,
    COALESCE(i.DescuentoOtorgado, 0) AS DescuentoOtorgado,
    COALESCE(v.MembresiasVendidas, 0) AS MembresiasVendidas,
    COALESCE(v.ClientesCaptados, 0) AS ClientesCaptados
FROM Claves c
INNER JOIN dbo.DimPlan dp ON dp.sk_plan = c.sk_plan
LEFT JOIN Ingresos i ON i.PeriodoInicio = c.PeriodoInicio AND i.sk_plan = c.sk_plan
LEFT JOIN Vendidas v ON v.PeriodoInicio = c.PeriodoInicio AND v.sk_plan = c.sk_plan;
GO

/* 5. Cobertura de avisos: membresías que vencen en los siguientes 7 días.
      Los avisos emitidos son una cantidad del día (aditiva); la cobertura se
      evalúa al corte. */
CREATE OR ALTER VIEW dbo.DM_Avisos_Cobertura
AS
WITH Cortes AS
(
    SELECT DISTINCT fm.sk_fecha_corte, d.fecha AS FechaCorte
    FROM dbo.FactMembresias fm
    INNER JOIN dbo.DimFecha d ON d.sk_fecha = fm.sk_fecha_corte
),
Proximas AS
(
    SELECT
        fm.sk_fecha_corte,
        fm.id_membresia_bk,
        fm.aviso_emitido
    FROM dbo.FactMembresias fm
    INNER JOIN dbo.DimFecha c ON c.sk_fecha = fm.sk_fecha_corte
    INNER JOIN dbo.DimFecha f ON f.sk_fecha = fm.sk_fecha_fin
    WHERE fm.estado_membresia = 'ACTIVA'
      AND f.fecha >= c.fecha
      AND f.fecha <= DATEADD(DAY, 7, c.fecha)
)
SELECT
    c.FechaCorte,
    COUNT(DISTINCT p.id_membresia_bk) AS MembresiasProximasVencer,
    COUNT(DISTINCT CASE WHEN p.aviso_emitido = 1 THEN p.id_membresia_bk END) AS MembresiasConAviso,
    (
        SELECT COALESCE(SUM(fm2.avisos_emitidos_dia), 0)
        FROM dbo.FactMembresias fm2
        WHERE fm2.sk_fecha_corte = c.sk_fecha_corte
    ) AS AvisosEmitidosDia,
    CASE
        WHEN COUNT(DISTINCT p.id_membresia_bk) = 0 THEN NULL
        ELSE COUNT(DISTINCT CASE WHEN p.aviso_emitido = 1 THEN p.id_membresia_bk END) * 100.0
             / COUNT(DISTINCT p.id_membresia_bk)
    END AS TasaCoberturaAvisos
FROM Cortes c
LEFT JOIN Proximas p ON p.sk_fecha_corte = c.sk_fecha_corte
GROUP BY c.FechaCorte, c.sk_fecha_corte;
GO

/* 6. Recepción: reclamos registrados, resueltos, directos en mostrador y tiempos. */
CREATE OR ALTER VIEW dbo.DM_Atencion_Reclamos
AS
SELECT
    df.anio AS Anio,
    df.mes AS MesNumero,
    df.nombre_mes AS Mes,
    fr.categoria AS CategoriaAtencion,
    COUNT(DISTINCT fr.id_reclamo_bk) AS ReclamosRegistrados,
    COUNT(DISTINCT CASE WHEN fr.estado = 'RESUELTO' THEN fr.id_reclamo_bk END) AS ReclamosResueltosSegunEstado,
    COUNT(DISTINCT CASE WHEN fr.estado = 'PENDIENTE' THEN fr.id_reclamo_bk END) AS ReclamosPendientes,
    CASE
        WHEN COUNT(DISTINCT fr.id_reclamo_bk) = 0 THEN NULL
        ELSE COUNT(DISTINCT CASE WHEN fr.estado = 'RESUELTO' THEN fr.id_reclamo_bk END) * 100.0
             / COUNT(DISTINCT fr.id_reclamo_bk)
    END AS TasaResolucionSegunEstado,
    COUNT(DISTINCT CASE WHEN fr.estado = 'RESUELTO' AND fr.resuelto_en_mostrador = 1 THEN fr.id_reclamo_bk END) AS ReclamosResueltosMostrador,
    CASE
        WHEN COUNT(DISTINCT fr.id_reclamo_bk) = 0 THEN NULL
        ELSE COUNT(DISTINCT CASE WHEN fr.estado = 'RESUELTO' AND fr.resuelto_en_mostrador = 1 THEN fr.id_reclamo_bk END) * 100.0
             / COUNT(DISTINCT fr.id_reclamo_bk)
    END AS TasaResolucionDirectaMostrador,
    COUNT(DISTINCT CASE WHEN fr.escalado = 1 THEN fr.id_reclamo_bk END) AS ReclamosEscalados,
    AVG(CASE WHEN fr.estado = 'RESUELTO' THEN fr.dias_resolucion END) AS PromedioDiasResolucion
FROM dbo.FactReclamos fr
INNER JOIN dbo.DimFecha df ON df.sk_fecha = fr.sk_fecha_reclamo
GROUP BY df.anio, df.mes, df.nombre_mes, fr.categoria;
GO

/* 7. Recepción: acciones de retención, no renovadas atendidas y recuperadas. */
CREATE OR ALTER VIEW dbo.DM_Atencion_Retencion
AS
WITH MembresiaRenovada AS
(
    SELECT
        fm.id_membresia_bk,
        MAX(CASE WHEN fm.id_membresia_nueva_bk IS NOT NULL THEN 1 ELSE 0 END) AS Renovada
    FROM dbo.FactMembresias fm
    GROUP BY fm.id_membresia_bk
)
SELECT
    df.anio AS Anio,
    df.mes AS MesNumero,
    df.nombre_mes AS Mes,
    dc.sk_cliente AS SkCliente,
    dc.id_cliente_bk AS IdClienteBk,
    dc.nombre_completo AS Cliente,
    r.canal AS Canal,
    COUNT(DISTINCT r.id_retencion_bk) AS AccionesRetencion,
    COUNT(DISTINCT CASE WHEN ISNULL(mr.Renovada, 0) = 0 THEN r.id_membresia_bk END) AS MembresiasNoRenovadasAtendidas,
    COUNT(DISTINCT CASE WHEN r.recuperada = 1 THEN r.id_membresia_bk END) AS MembresiasRecuperadas,
    CASE
        WHEN COUNT(DISTINCT CASE WHEN ISNULL(mr.Renovada, 0) = 0 THEN r.id_membresia_bk END) = 0 THEN NULL
        ELSE COUNT(DISTINCT CASE WHEN r.recuperada = 1 THEN r.id_membresia_bk END) * 100.0
             / COUNT(DISTINCT CASE WHEN ISNULL(mr.Renovada, 0) = 0 THEN r.id_membresia_bk END)
    END AS TasaExitoRetencion
FROM dbo.FactRetenciones r
INNER JOIN dbo.DimFecha df ON df.sk_fecha = r.sk_fecha_retencion
INNER JOIN dbo.DimCliente dc ON dc.sk_cliente = r.sk_cliente
LEFT JOIN MembresiaRenovada mr ON mr.id_membresia_bk = r.id_membresia_bk
GROUP BY df.anio, df.mes, df.nombre_mes, dc.sk_cliente, dc.id_cliente_bk,
         dc.nombre_completo, r.canal;
GO

/* 8. Recepción: atención registrada por segmento y categoría. */
CREATE OR ALTER VIEW dbo.DM_Atencion_Recepcion
AS
SELECT
    df.anio AS Anio,
    df.mes AS MesNumero,
    df.nombre_mes AS PeriodoMes,
    dc.sexo AS Sexo,
    dc.rango_etario AS RangoEtario,
    dc.nombre_completo AS Cliente,
    fr.categoria AS CategoriaAtencion,
    fr.estado AS EstadoAtencion,
    COUNT(DISTINCT fr.id_reclamo_bk) AS TotalAtenciones
FROM dbo.FactReclamos fr
INNER JOIN dbo.DimFecha df ON fr.sk_fecha_reclamo = df.sk_fecha
INNER JOIN dbo.DimCliente dc ON fr.sk_cliente = dc.sk_cliente
GROUP BY df.anio, df.mes, df.nombre_mes, dc.sexo, dc.rango_etario,
         dc.nombre_completo, fr.categoria, fr.estado;
GO

/* 9. Entrenamiento: sesiones programadas (no canceladas) vs. asistidas. */
CREATE OR ALTER VIEW dbo.DM_Entrenamiento_Asistencia
AS
SELECT
    df.anio AS Anio,
    df.mes AS MesNumero,
    df.nombre_mes AS Mes,
    c.sk_cliente AS SkCliente,
    c.id_cliente_bk AS IdClienteBk,
    c.nombre_completo AS Cliente,
    COUNT(DISTINCT CASE WHEN se.estado_sesion <> 'CANCELADA' THEN se.id_sesion_bk END) AS SesionesProgramadas,
    COUNT(DISTINCT CASE WHEN se.asistio = 1 THEN se.id_sesion_bk END) AS SesionesAsistidasRegistradas,
    CASE
        WHEN COUNT(DISTINCT CASE WHEN se.estado_sesion <> 'CANCELADA' THEN se.id_sesion_bk END) = 0 THEN NULL
        ELSE COUNT(DISTINCT CASE WHEN se.asistio = 1 THEN se.id_sesion_bk END) * 100.0
             / COUNT(DISTINCT CASE WHEN se.estado_sesion <> 'CANCELADA' THEN se.id_sesion_bk END)
    END AS TasaAsistencia
FROM dbo.FactSesionesEntrenamiento se
INNER JOIN dbo.DimFecha df ON df.sk_fecha = se.sk_fecha_programada
INNER JOIN dbo.DimCliente c ON c.sk_cliente = se.sk_cliente
GROUP BY df.anio, df.mes, df.nombre_mes, c.sk_cliente, c.id_cliente_bk, c.nombre_completo;
GO

/* 10. Entrenamiento: accesos reales al gimnasio (no equivalen a sesiones). */
CREATE OR ALTER VIEW dbo.DM_Entrenamiento_Accesos
AS
SELECT
    df.anio AS Anio,
    df.mes AS MesNumero,
    df.nombre_mes AS Mes,
    c.sk_cliente AS SkCliente,
    c.id_cliente_bk AS IdClienteBk,
    c.nombre_completo AS Cliente,
    COUNT(DISTINCT fa.id_asistencia_bk) AS AccesosRegistrados,
    COUNT(DISTINCT fa.sk_fecha_asistencia) AS DiasConAcceso
FROM dbo.FactAsistencias fa
INNER JOIN dbo.DimFecha df ON df.sk_fecha = fa.sk_fecha_asistencia
INNER JOIN dbo.DimCliente c ON c.sk_cliente = fa.sk_cliente
WHERE fa.es_acceso_valido = 1
GROUP BY df.anio, df.mes, df.nombre_mes, c.sk_cliente, c.id_cliente_bk, c.nombre_completo;
GO

/* 11. Entrenamiento: progreso por cliente y objetivo, al último corte. */
CREATE OR ALTER VIEW dbo.DM_Entrenamiento_Progreso
AS
WITH UltimoCorte AS
(
    SELECT
        fs.*,
        ROW_NUMBER() OVER (PARTITION BY fs.id_objetivo_bk ORDER BY fs.sk_fecha_corte DESC) AS rn
    FROM dbo.FactSeguimientoFisico fs
)
SELECT
    u.sk_cliente AS SkCliente,
    dc.id_cliente_bk AS IdClienteBk,
    dc.nombre_completo AS Cliente,
    u.id_objetivo_bk AS IdObjetivoBk,
    dcorte.fecha AS FechaCorte,
    u.tipo_objetivo AS TipoObjetivo,
    u.unidad_medida AS UnidadMedida,
    u.estado_objetivo AS EstadoObjetivo,
    u.valor_inicial AS ValorInicialObjetivo,
    u.valor_actual AS ValorActualObjetivo,
    u.valor_esperado AS ValorEsperado,
    u.avance_alcanzado AS AvanceAlcanzado,
    u.avance_esperado AS AvanceEsperado,
    u.porcentaje_progreso AS PorcentajeProgreso,
    CASE
        WHEN u.porcentaje_progreso IS NULL THEN NULL
        WHEN u.porcentaje_progreso < 100 THEN 1
        ELSE 0
    END AS TieneBajoProgreso,
    u.evaluacion_exigible AS EvaluacionExigible,
    u.evaluacion_completada AS EvaluacionCompletada,
    u.evaluacion_pendiente AS EvaluacionPendiente
FROM UltimoCorte u
INNER JOIN dbo.DimCliente dc ON dc.sk_cliente = u.sk_cliente
INNER JOIN dbo.DimFecha dcorte ON dcorte.sk_fecha = u.sk_fecha_corte
WHERE u.rn = 1;
GO

/* 12. Entrenamiento: clientes con al menos un objetivo por debajo del 100%. */
CREATE OR ALTER VIEW dbo.DM_Entrenamiento_BajoProgreso
AS
SELECT
    p.SkCliente AS SkCliente,
    p.IdClienteBk AS IdClienteBk,
    p.Cliente,
    MAX(p.FechaCorte) AS FechaCorte,
    COUNT(*) AS ObjetivosEvaluados,
    SUM(CASE WHEN p.PorcentajeProgreso < 100 THEN 1 ELSE 0 END) AS ObjetivosBajoProgreso
FROM dbo.DM_Entrenamiento_Progreso p
WHERE p.PorcentajeProgreso IS NOT NULL
GROUP BY p.SkCliente, p.IdClienteBk, p.Cliente
HAVING SUM(CASE WHEN p.PorcentajeProgreso < 100 THEN 1 ELSE 0 END) > 0;
GO

/* 13. Entrenamiento: evaluaciones exigibles, completadas y pendientes al corte. */
CREATE OR ALTER VIEW dbo.DM_Entrenamiento_Evaluaciones
AS
WITH CortesMes AS
(
    SELECT
        d.anio,
        d.mes,
        MAX(d.nombre_mes) AS nombre_mes,
        MAX(fs.sk_fecha_corte) AS sk_fecha_corte
    FROM dbo.FactSeguimientoFisico fs
    INNER JOIN dbo.DimFecha d ON d.sk_fecha = fs.sk_fecha_corte
    GROUP BY d.anio, d.mes
)
SELECT
    cm.anio AS Anio,
    cm.mes AS MesNumero,
    cm.nombre_mes AS Mes,
    c.sk_cliente AS SkCliente,
    c.id_cliente_bk AS IdClienteBk,
    c.nombre_completo AS Cliente,
    COUNT(DISTINCT CASE WHEN fs.evaluacion_exigible = 1 THEN fs.id_objetivo_bk END) AS EvaluacionesExigibles,
    COUNT(DISTINCT CASE WHEN fs.evaluacion_completada = 1 THEN fs.id_objetivo_bk END) AS EvaluacionesCompletadas,
    COUNT(DISTINCT CASE WHEN fs.evaluacion_pendiente = 1 THEN fs.id_objetivo_bk END) AS EvaluacionesPendientes,
    CASE
        WHEN COUNT(DISTINCT CASE WHEN fs.evaluacion_exigible = 1 THEN fs.id_objetivo_bk END) = 0 THEN NULL
        ELSE COUNT(DISTINCT CASE WHEN fs.evaluacion_completada = 1 THEN fs.id_objetivo_bk END) * 100.0
             / COUNT(DISTINCT CASE WHEN fs.evaluacion_exigible = 1 THEN fs.id_objetivo_bk END)
    END AS TasaCumplimientoEvaluaciones
FROM CortesMes cm
INNER JOIN dbo.FactSeguimientoFisico fs ON fs.sk_fecha_corte = cm.sk_fecha_corte
INNER JOIN dbo.DimCliente c ON c.sk_cliente = fs.sk_cliente
GROUP BY cm.anio, cm.mes, cm.nombre_mes, c.sk_cliente, c.id_cliente_bk, c.nombre_completo;
GO

/* 14. Entrenamiento: sesiones asistidas por entrenador, segmento y plan. */
CREATE OR ALTER VIEW dbo.DM_Rutinas_Entrenador
AS
SELECT
    df.anio AS Anio,
    df.mes AS MesNumero,
    df.nombre_mes AS Mes,
    dc.rango_etario AS RangoEtarioCliente,
    de.codigo_empleado AS CodigoEmpleado,
    de.nombre_completo AS NombreEntrenador,
    de.area AS Area,
    dp.tipo_plan AS TipoPlan,
    COUNT(DISTINCT se.id_sesion_bk) AS TotalAsistencias
FROM dbo.FactSesionesEntrenamiento se
INNER JOIN dbo.DimFecha df ON se.sk_fecha_programada = df.sk_fecha
INNER JOIN dbo.DimCliente dc ON se.sk_cliente = dc.sk_cliente
LEFT JOIN dbo.DimEmpleado de ON se.sk_empleado = de.sk_empleado
LEFT JOIN dbo.DimPlan dp ON se.sk_plan = dp.sk_plan
WHERE se.asistio = 1
GROUP BY df.anio, df.mes, df.nombre_mes, dc.rango_etario,
         de.codigo_empleado, de.nombre_completo, de.area, dp.tipo_plan;
GO

/* Pruebas rápidas de las salidas SQL antes de conectar Power BI. */
SELECT TOP (20) * FROM dbo.DM_Gerencia_Ingresos ORDER BY Anio, MesNumero;
SELECT TOP (20) * FROM dbo.DM_Gerencia_Membresias ORDER BY Anio, MesNumero;
SELECT TOP (20) * FROM dbo.DM_Comercial_Plan ORDER BY Anio, MesNumero, TipoPlan;
SELECT TOP (20) * FROM dbo.DM_Comercial_Promociones ORDER BY Anio, MesNumero, Promocion;
SELECT TOP (20) * FROM dbo.DM_Avisos_Cobertura ORDER BY FechaCorte;
SELECT TOP (20) * FROM dbo.DM_Atencion_Reclamos ORDER BY Anio, MesNumero;
SELECT TOP (20) * FROM dbo.DM_Atencion_Retencion ORDER BY Anio, MesNumero;
SELECT TOP (20) * FROM dbo.DM_Entrenamiento_Accesos ORDER BY Anio, MesNumero;
SELECT TOP (20) * FROM dbo.DM_Entrenamiento_Progreso ORDER BY IdClienteBk, IdObjetivoBk;
SELECT TOP (20) * FROM dbo.DM_Entrenamiento_BajoProgreso ORDER BY ObjetivosBajoProgreso DESC;
SELECT TOP (20) * FROM dbo.DM_Entrenamiento_Evaluaciones ORDER BY Anio, MesNumero;
GO
