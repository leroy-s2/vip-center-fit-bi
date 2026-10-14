/*=============================================================================
  VIP CENTER FIT - ETAPA 5: DATA MART / MÉTRICAS

  Estas consultas trabajan únicamente con el modelo limpio del Data Mart.
  Las métricas se calculan en SQL para validarlas antes de conectarlas a
  Power BI.

  Brechas del Excel OFICIAL1 ya cerradas en el origen:
  - Tasa de asistencia: se incorpora FactSesionesProgramadas como denominador
    (sesiones programadas) de las asistencias registradas.
  - Resolución directa en mostrador: FactReclamos expone resuelto_en_mostrador.
  - Evaluaciones programadas: FactEvaluacionesProgramadas aporta la fecha prevista
    (exigibles, completadas y pendientes).
  - Retención en mostrador: FactRetenciones registra la acción y su resultado.
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

/* 2. Gerencia: clientes activos, membresías vencidas y renovaciones. */
CREATE OR ALTER VIEW dbo.DM_Gerencia_Membresias
AS
WITH Periodos AS
(
    SELECT
        DATEFROMPARTS(anio, mes, 1) AS PeriodoInicio,
        EOMONTH(DATEFROMPARTS(anio, mes, 1)) AS PeriodoFin,
        anio,
        mes,
        MAX(nombre_mes) AS nombre_mes
    FROM dbo.DimFecha
    WHERE anio >= 2000
    GROUP BY DATEFROMPARTS(anio, mes, 1), anio, mes
),
ClientesInicio AS
(
    SELECT p.PeriodoInicio, fm.sk_cliente
    FROM Periodos p
    INNER JOIN dbo.FactMembresias fm ON 1 = 1
    INNER JOIN dbo.DimFecha fi ON fi.sk_fecha = fm.sk_fecha_inicio
    INNER JOIN dbo.DimFecha ff ON ff.sk_fecha = fm.sk_fecha_fin
    WHERE fi.fecha <= p.PeriodoInicio
      AND ff.fecha >= p.PeriodoInicio
    GROUP BY p.PeriodoInicio, fm.sk_cliente
),
ClientesCierre AS
(
    SELECT p.PeriodoInicio, fm.sk_cliente
    FROM Periodos p
    INNER JOIN dbo.FactMembresias fm ON 1 = 1
    INNER JOIN dbo.DimFecha fi ON fi.sk_fecha = fm.sk_fecha_inicio
    INNER JOIN dbo.DimFecha ff ON ff.sk_fecha = fm.sk_fecha_fin
    WHERE fi.fecha <= p.PeriodoFin
      AND ff.fecha >= p.PeriodoFin
    GROUP BY p.PeriodoInicio, fm.sk_cliente
),
Retencion AS
(
    SELECT
        ci.PeriodoInicio,
        COUNT(*) AS ClientesActivosInicio,
        SUM(CASE WHEN cc.sk_cliente IS NOT NULL THEN 1 ELSE 0 END) AS ClientesInicioActivosCierre
    FROM ClientesInicio ci
    LEFT JOIN ClientesCierre cc
        ON cc.PeriodoInicio = ci.PeriodoInicio
       AND cc.sk_cliente = ci.sk_cliente
    GROUP BY ci.PeriodoInicio
),
Activas AS
(
    SELECT
        p.PeriodoInicio,
        COUNT(DISTINCT fm.id_membresia_bk) AS MembresiasActivas
    FROM Periodos p
    INNER JOIN dbo.FactMembresias fm ON 1 = 1
    INNER JOIN dbo.DimFecha fi ON fi.sk_fecha = fm.sk_fecha_inicio
    INNER JOIN dbo.DimFecha ff ON ff.sk_fecha = fm.sk_fecha_fin
    WHERE fi.fecha <= p.PeriodoFin
      AND ff.fecha >= p.PeriodoFin
    GROUP BY p.PeriodoInicio
),
Vencen AS
(
    SELECT
        p.PeriodoInicio,
        COUNT(DISTINCT fm.id_membresia_bk) AS MembresiasVencenPeriodo
    FROM Periodos p
    INNER JOIN dbo.FactMembresias fm ON 1 = 1
    INNER JOIN dbo.DimFecha ff ON ff.sk_fecha = fm.sk_fecha_fin
    WHERE ff.fecha BETWEEN p.PeriodoInicio AND p.PeriodoFin
    GROUP BY p.PeriodoInicio
),
Renovadas AS
(
    SELECT
        p.PeriodoInicio,
        COUNT(DISTINCT fr.id_membresia_anterior_bk) AS MembresiasCohorteRenovadas
    FROM Periodos p
    INNER JOIN dbo.FactRenovaciones fr ON 1 = 1
    INNER JOIN dbo.DimFecha dr ON dr.sk_fecha = fr.sk_fecha_renovacion
    INNER JOIN dbo.FactMembresias anterior
        ON anterior.id_membresia_bk = fr.id_membresia_anterior_bk
    INNER JOIN dbo.DimFecha vencimiento
        ON vencimiento.sk_fecha = anterior.sk_fecha_fin
    WHERE vencimiento.fecha BETWEEN p.PeriodoInicio AND p.PeriodoFin
      AND dr.fecha >= p.PeriodoInicio
      AND dr.fecha <= DATEADD(DAY, 31, p.PeriodoFin)
    GROUP BY p.PeriodoInicio
)
SELECT
    p.anio AS Anio,
    p.mes AS MesNumero,
    p.nombre_mes AS Mes,
    COALESCE(r.ClientesActivosInicio, 0) AS ClientesActivosInicio,
    COALESCE(r.ClientesInicioActivosCierre, 0) AS ClientesInicioActivosCierre,
    CASE
        WHEN COALESCE(r.ClientesActivosInicio, 0) = 0 THEN NULL
        ELSE r.ClientesInicioActivosCierre * 100.0 / r.ClientesActivosInicio
    END AS TasaRetencionClientes,
    COALESCE(a.MembresiasActivas, 0) AS MembresiasActivas,
    COALESCE(v.MembresiasVencenPeriodo, 0) AS MembresiasVencenPeriodo,
    COALESCE(re.MembresiasCohorteRenovadas, 0) AS MembresiasCohorteRenovadas,
    CASE
        WHEN COALESCE(v.MembresiasVencenPeriodo, 0) = 0 THEN NULL
        ELSE re.MembresiasCohorteRenovadas * 100.0 / v.MembresiasVencenPeriodo
    END AS TasaRenovacionMembresias
FROM Periodos p
LEFT JOIN Retencion r ON r.PeriodoInicio = p.PeriodoInicio
LEFT JOIN Activas a ON a.PeriodoInicio = p.PeriodoInicio
LEFT JOIN Vencen v ON v.PeriodoInicio = p.PeriodoInicio
LEFT JOIN Renovadas re ON re.PeriodoInicio = p.PeriodoInicio;
GO

/* 3. Comercial: ingresos, ventas, vencimientos y renovaciones por plan. */
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
        DATEFROMPARTS(dr.anio, dr.mes, 1) AS PeriodoInicio,
        anterior.sk_plan,
        COUNT(DISTINCT fr.id_membresia_anterior_bk) AS MembresiasRenovadas
    FROM dbo.FactRenovaciones fr
    INNER JOIN dbo.DimFecha dr ON dr.sk_fecha = fr.sk_fecha_renovacion
    INNER JOIN dbo.FactMembresias anterior
        ON anterior.id_membresia_bk = fr.id_membresia_anterior_bk
    GROUP BY DATEFROMPARTS(dr.anio, dr.mes, 1), anterior.sk_plan
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
LEFT JOIN Ingresos i ON i.PeriodoInicio = c.PeriodoInicio AND i.sk_plan = c.sk_plan
LEFT JOIN Vendidas v ON v.PeriodoInicio = c.PeriodoInicio AND v.sk_plan = c.sk_plan
LEFT JOIN Vencidas x ON x.PeriodoInicio = c.PeriodoInicio AND x.sk_plan = c.sk_plan
LEFT JOIN Renovadas r ON r.PeriodoInicio = c.PeriodoInicio AND r.sk_plan = c.sk_plan;
GO

/* 4. Cobertura de avisos para membresías que vencen en los siguientes 7 días. */
CREATE OR ALTER VIEW dbo.DM_Avisos_Cobertura
AS
SELECT
    corte.fecha AS FechaCorte,
    COUNT(DISTINCT CASE
        WHEN inicio.fecha <= corte.fecha
         AND fin.fecha > corte.fecha
         AND fin.fecha <= DATEADD(DAY, 7, corte.fecha)
        THEN fm.id_membresia_bk END) AS MembresiasProximasVencer,
    COUNT(DISTINCT CASE
        WHEN av.estado = 'ENVIADO'
         AND da.fecha = corte.fecha
         AND fm.id_membresia_bk IS NOT NULL
         AND inicio.fecha <= corte.fecha
         AND fin.fecha > corte.fecha
         AND fin.fecha <= DATEADD(DAY, 7, corte.fecha)
        THEN av.id_aviso_bk END) AS AvisosRenovacionEmitidos,
    CASE
        WHEN COUNT(DISTINCT CASE
            WHEN inicio.fecha <= corte.fecha
             AND fin.fecha > corte.fecha
             AND fin.fecha <= DATEADD(DAY, 7, corte.fecha)
            THEN fm.id_membresia_bk END) = 0 THEN NULL
        ELSE COUNT(DISTINCT CASE
            WHEN av.estado = 'ENVIADO'
             AND da.fecha = corte.fecha
             AND fm.id_membresia_bk IS NOT NULL
             AND inicio.fecha <= corte.fecha
             AND fin.fecha > corte.fecha
             AND fin.fecha <= DATEADD(DAY, 7, corte.fecha)
            THEN av.id_aviso_bk END) * 100.0
             / COUNT(DISTINCT CASE
                 WHEN inicio.fecha <= corte.fecha
                  AND fin.fecha > corte.fecha
                  AND fin.fecha <= DATEADD(DAY, 7, corte.fecha)
                 THEN fm.id_membresia_bk END)
    END AS TasaCoberturaAvisos
FROM dbo.DimFecha corte
LEFT JOIN dbo.FactMembresias fm ON 1 = 1
LEFT JOIN dbo.DimFecha inicio ON inicio.sk_fecha = fm.sk_fecha_inicio
LEFT JOIN dbo.DimFecha fin ON fin.sk_fecha = fm.sk_fecha_fin
LEFT JOIN dbo.FactAvisos av ON av.id_membresia_bk = fm.id_membresia_bk
LEFT JOIN dbo.DimFecha da ON da.sk_fecha = av.sk_fecha_aviso
GROUP BY corte.fecha;
GO

/* 5. Recepción: reclamos registrados, resueltos, directos en mostrador y tiempos. */
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
    AVG(CASE WHEN fr.estado = 'RESUELTO' THEN fr.dias_resolucion END) AS PromedioDiasResolucion
FROM dbo.FactReclamos fr
INNER JOIN dbo.DimFecha df ON df.sk_fecha = fr.sk_fecha_reclamo
GROUP BY df.anio, df.mes, df.nombre_mes, fr.categoria;
GO

/* 6. Entrenamiento: sesiones programadas y asistidas (tasa de asistencia).

   El Excel empareja "sesiones asistidas" con "sesiones programadas"; por eso ambas
   salen de la misma entidad (FactSesionesProgramadas, según su estado_sesion).
   FactAsistencias sigue siendo el fact de check-ins del gimnasio (lo usa DM_Rutinas_Entrenador). */
CREATE OR ALTER VIEW dbo.DM_Entrenamiento_Asistencia
AS
SELECT
    df.anio AS Anio,
    df.mes AS MesNumero,
    df.nombre_mes AS Mes,
    c.sk_cliente,
    c.id_cliente_bk,
    c.nombre_completo AS Cliente,
    COUNT(DISTINCT CASE WHEN sp.estado_sesion = 'ASISTIDA' THEN sp.id_sesion_bk END) AS SesionesAsistidasRegistradas,
    COUNT(DISTINCT sp.id_sesion_bk) AS SesionesProgramadas,
    CASE
        WHEN COUNT(DISTINCT sp.id_sesion_bk) = 0 THEN NULL
        ELSE COUNT(DISTINCT CASE WHEN sp.estado_sesion = 'ASISTIDA' THEN sp.id_sesion_bk END) * 100.0
             / COUNT(DISTINCT sp.id_sesion_bk)
    END AS TasaAsistencia
FROM dbo.FactSesionesProgramadas sp
INNER JOIN dbo.DimFecha df ON df.sk_fecha = sp.sk_fecha_programada
INNER JOIN dbo.DimCliente c ON c.sk_cliente = sp.sk_cliente
GROUP BY df.anio, df.mes, df.nombre_mes, c.sk_cliente, c.id_cliente_bk, c.nombre_completo;
GO

/* 7. Entrenamiento: progreso observable por cliente y objetivo. */
CREATE OR ALTER VIEW dbo.DM_Entrenamiento_Progreso
AS
WITH UltimaEvaluacion AS
(
    SELECT
        fe.sk_cliente,
        fe.id_objetivo_bk,
        fe.peso AS valor_actual,
        df.fecha AS fecha_evaluacion,
        ROW_NUMBER() OVER
        (
            PARTITION BY fe.sk_cliente, fe.id_objetivo_bk
            ORDER BY df.fecha DESC, fe.id_evaluacion_bk DESC
        ) AS rn
    FROM dbo.FactEvaluaciones fe
    INNER JOIN dbo.DimFecha df ON df.sk_fecha = fe.sk_fecha_evaluacion
    WHERE fe.id_objetivo_bk IS NOT NULL
),
Calculo AS
(
    SELECT
        fo.sk_cliente,
        fo.id_objetivo_bk,
        fo.tipo_objetivo,
        fo.unidad_medida,
        fo.valor_inicial,
        fo.valor_objetivo,
        ue.valor_actual,
        ue.fecha_evaluacion,
        CASE
            WHEN fo.tipo_objetivo = 'REDUCCION_GRASA'
                THEN fo.valor_inicial - ue.valor_actual
            ELSE ue.valor_actual - fo.valor_inicial
        END AS AvanceAlcanzado,
        CASE
            WHEN fo.tipo_objetivo = 'REDUCCION_GRASA'
                THEN fo.valor_inicial - fo.valor_objetivo
            ELSE fo.valor_objetivo - fo.valor_inicial
        END AS AvanceEsperado
    FROM dbo.FactObjetivos fo
    INNER JOIN UltimaEvaluacion ue
        ON ue.sk_cliente = fo.sk_cliente
       AND ue.id_objetivo_bk = fo.id_objetivo_bk
       AND ue.rn = 1
)
SELECT
    c.sk_cliente,
    dc.id_cliente_bk,
    dc.nombre_completo AS Cliente,
    c.id_objetivo_bk,
    c.tipo_objetivo,
    c.unidad_medida,
    c.valor_inicial AS ValorInicialObjetivo,
    c.valor_actual AS ValorActualObjetivo,
    c.valor_objetivo AS ValorObjetivo,
    c.AvanceAlcanzado,
    c.AvanceEsperado,
    CASE
        WHEN c.AvanceEsperado IS NULL OR c.AvanceEsperado = 0 THEN NULL
        ELSE c.AvanceAlcanzado * 100.0 / c.AvanceEsperado
    END AS PorcentajeProgreso,
    c.fecha_evaluacion AS FechaUltimaEvaluacion,
    CASE
        WHEN c.AvanceEsperado IS NULL OR c.AvanceEsperado = 0 THEN NULL
        WHEN c.AvanceAlcanzado * 100.0 / c.AvanceEsperado < 100 THEN 1
        ELSE 0
    END AS TieneBajoProgreso
FROM Calculo c
INNER JOIN dbo.DimCliente dc ON dc.sk_cliente = c.sk_cliente;
GO

/* 7.1. Entrenamiento: cumplimiento agregado de objetivos. */
CREATE OR ALTER VIEW dbo.DM_Entrenamiento_Cumplimiento
AS
WITH ObjetivoPeriodo AS
(
    SELECT
        fo.id_objetivo_bk,
        fo.sk_cliente,
        fo.tipo_objetivo,
        df.anio AS Anio,
        df.mes AS MesNumero,
        df.nombre_mes AS Mes
    FROM dbo.FactObjetivos fo
    INNER JOIN dbo.DimFecha df ON df.sk_fecha = fo.sk_fecha_inicio
),
Evaluado AS
(
    SELECT
        op.Anio, op.MesNumero, op.Mes, op.tipo_objetivo,
        op.id_objetivo_bk, pr.PorcentajeProgreso
    FROM ObjetivoPeriodo op
    LEFT JOIN dbo.DM_Entrenamiento_Progreso pr
        ON pr.id_objetivo_bk = op.id_objetivo_bk
       AND pr.sk_cliente = op.sk_cliente
)
SELECT
    Anio,
    MesNumero,
    Mes,
    tipo_objetivo AS TipoObjetivo,
    COUNT(*) AS ObjetivosRegistrados,
    COUNT(CASE WHEN PorcentajeProgreso IS NOT NULL THEN 1 END) AS ObjetivosConProgreso,
    COUNT(CASE WHEN PorcentajeProgreso >= 100 THEN 1 END) AS ObjetivosCumplidos,
    CASE
        WHEN COUNT(CASE WHEN PorcentajeProgreso IS NOT NULL THEN 1 END) = 0 THEN NULL
        ELSE COUNT(CASE WHEN PorcentajeProgreso >= 100 THEN 1 END) * 100.0
             / COUNT(CASE WHEN PorcentajeProgreso IS NOT NULL THEN 1 END)
    END AS TasaCumplimientoObjetivos,
    AVG(PorcentajeProgreso) AS PromedioPorcentajeProgreso
FROM Evaluado
GROUP BY Anio, MesNumero, Mes, tipo_objetivo;
GO

/* 7.2. Entrenamiento: evaluaciones programadas (exigibles, completadas, pendientes). */
CREATE OR ALTER VIEW dbo.DM_Entrenamiento_Evaluaciones
AS
SELECT
    df.anio AS Anio,
    df.mes AS MesNumero,
    df.nombre_mes AS Mes,
    c.sk_cliente,
    c.id_cliente_bk,
    c.nombre_completo AS Cliente,
    COUNT(DISTINCT ep.id_evaluacion_programada_bk) AS EvaluacionesProgramadas,
    COUNT(DISTINCT CASE WHEN ep.estado_evaluacion = 'COMPLETADA' THEN ep.id_evaluacion_programada_bk END) AS EvaluacionesCompletadas,
    COUNT(DISTINCT CASE
        WHEN ep.estado_evaluacion IN ('PROGRAMADA', 'PENDIENTE')
         AND df.fecha <= '2026-09-29'
        THEN ep.id_evaluacion_programada_bk END) AS EvaluacionesPendientes,
    CASE
        WHEN COUNT(DISTINCT ep.id_evaluacion_programada_bk) = 0 THEN NULL
        ELSE COUNT(DISTINCT CASE WHEN ep.estado_evaluacion = 'COMPLETADA' THEN ep.id_evaluacion_programada_bk END) * 100.0
             / COUNT(DISTINCT ep.id_evaluacion_programada_bk)
    END AS TasaCumplimientoEvaluaciones
FROM dbo.FactEvaluacionesProgramadas ep
INNER JOIN dbo.DimFecha df ON df.sk_fecha = ep.sk_fecha_programada
INNER JOIN dbo.DimCliente c ON c.sk_cliente = ep.sk_cliente
GROUP BY df.anio, df.mes, df.nombre_mes, c.sk_cliente, c.id_cliente_bk, c.nombre_completo;
GO

/* 8. Vistas compatibles con los nombres de la primera versión. */
CREATE OR ALTER VIEW dbo.DM_Ventas_Gerencia
AS
SELECT
    df.anio AS Anio,
    df.trimestre AS Trimestre,
    df.mes AS MesNumero,
    df.nombre_mes AS Mes,
    dp.tipo_plan AS Membresia,
    SUM(fv.monto_neto) AS Total_Ingresos,
    COUNT(DISTINCT fv.id_pago_bk) AS Cantidad_Ventas
FROM dbo.FactVentas fv
INNER JOIN dbo.DimFecha df ON fv.sk_fecha_pago = df.sk_fecha
INNER JOIN dbo.DimPlan dp ON fv.sk_plan = dp.sk_plan
GROUP BY df.anio, df.trimestre, df.mes, df.nombre_mes, dp.tipo_plan;
GO

CREATE OR ALTER VIEW dbo.DM_Rutinas_Entrenador
AS
SELECT
    df.anio AS Anio,
    df.mes AS MesNumero,
    df.nombre_mes AS Mes,
    dc.rango_etario AS Rango_Etario_Cliente,
    de.nombre_completo AS Nombre_Entrenador,
    dp.tipo_plan AS Tipo_Plan,
    COUNT(DISTINCT fa.id_asistencia_bk) AS Total_Asistencias
FROM dbo.FactAsistencias fa
INNER JOIN dbo.DimFecha df ON fa.sk_fecha_asistencia = df.sk_fecha
INNER JOIN dbo.DimCliente dc ON fa.sk_cliente = dc.sk_cliente
LEFT JOIN dbo.DimEmpleado de ON fa.sk_empleado = de.sk_empleado
LEFT JOIN dbo.DimPlan dp ON fa.sk_plan = dp.sk_plan
GROUP BY df.anio, df.mes, df.nombre_mes, dc.rango_etario,
         de.nombre_completo, dp.tipo_plan;
GO

CREATE OR ALTER VIEW dbo.DM_Atencion_Recepcion
AS
SELECT
    df.anio AS Anio,
    df.mes AS MesNumero,
    df.nombre_mes AS Periodo_Mes,
    dc.sexo AS Sexo,
    dc.rango_etario AS Rango_Etario,
    dc.nombre_completo AS Cliente,
    fr.categoria AS Categoria_Atencion,
    fr.estado AS Estado_Atencion,
    COUNT(DISTINCT fr.id_reclamo_bk) AS Total_Atenciones
FROM dbo.FactReclamos fr
INNER JOIN dbo.DimFecha df ON fr.sk_fecha_reclamo = df.sk_fecha
INNER JOIN dbo.DimCliente dc ON fr.sk_cliente = dc.sk_cliente
GROUP BY df.anio, df.mes, df.nombre_mes, dc.sexo, dc.rango_etario,
         dc.nombre_completo, fr.categoria, fr.estado;
GO

CREATE OR ALTER VIEW dbo.DM_Atencion_Retencion
AS
SELECT
    df.anio AS Anio,
    df.mes AS MesNumero,
    df.nombre_mes AS Mes,
    c.sk_cliente,
    c.id_cliente_bk,
    c.nombre_completo AS Cliente,
    r.canal AS Canal,
    COUNT(DISTINCT r.id_retencion_bk) AS AccionesRetencion,
    COUNT(DISTINCT CASE WHEN r.resultado = 'RETENIDO' THEN r.id_retencion_bk END) AS ClientesRetenidos,
    CASE
        WHEN COUNT(DISTINCT r.id_retencion_bk) = 0 THEN NULL
        ELSE COUNT(DISTINCT CASE WHEN r.resultado = 'RETENIDO' THEN r.id_retencion_bk END) * 100.0
             / COUNT(DISTINCT r.id_retencion_bk)
    END AS TasaExitoRetencion
FROM dbo.FactRetenciones r
INNER JOIN dbo.DimFecha df ON df.sk_fecha = r.sk_fecha_retencion
INNER JOIN dbo.DimCliente c ON c.sk_cliente = r.sk_cliente
GROUP BY df.anio, df.mes, df.nombre_mes, c.sk_cliente, c.id_cliente_bk, c.nombre_completo, r.canal;
GO

/* ------------------- Métricas de promoción (data mart comercial) -------------------
   Se alimentan de DimPlan.promocion (planes promocionales de periodo corto del
   catálogo). Todas consideran solo promociones reales (promocion <> 'SIN PROMOCION'). */

/* 9. Comercial: ingresos, ventas y descuento otorgado por promoción.
   Dimensiones: Fecha, Plan. */
CREATE OR ALTER VIEW dbo.DM_Promociones_Ventas
AS
SELECT
    df.anio AS Anio,
    df.mes AS MesNumero,
    df.nombre_mes AS Mes,
    dp.tipo_plan AS TipoPlan,
    dp.promocion AS Promocion,
    SUM(fv.monto_neto) AS IngresosPorPromocion,
    COUNT(DISTINCT fv.id_pago_bk) AS VentasPorPromocion,
    SUM(fv.descuento_aplicado) AS DescuentoOtorgado
FROM dbo.FactVentas fv
INNER JOIN dbo.DimFecha df ON df.sk_fecha = fv.sk_fecha_pago
INNER JOIN dbo.DimPlan dp ON dp.sk_plan = fv.sk_plan
WHERE dp.promocion <> 'SIN PROMOCION'
GROUP BY df.anio, df.mes, df.nombre_mes, dp.tipo_plan, dp.promocion;
GO

/* 10. Comercial: membresías vendidas y renovadas por promoción y empleado.
   Dimensiones: Fecha, Empleado, Plan. */
CREATE OR ALTER VIEW dbo.DM_Promociones_Membresias
AS
SELECT
    df.anio AS Anio,
    df.mes AS MesNumero,
    df.nombre_mes AS Mes,
    dp.promocion AS Promocion,
    de.nombre_completo AS Empleado,
    COUNT(DISTINCT fm.id_membresia_bk) AS MembresiasVendidas,
    COUNT(DISTINCT CASE WHEN fm.es_renovacion = 1 THEN fm.id_membresia_bk END) AS MembresiasRenovadas
FROM dbo.FactMembresias fm
INNER JOIN dbo.DimFecha df ON df.sk_fecha = fm.sk_fecha_inicio
INNER JOIN dbo.DimPlan dp ON dp.sk_plan = fm.sk_plan
LEFT JOIN dbo.DimEmpleado de ON de.sk_empleado = fm.sk_empleado
WHERE dp.promocion <> 'SIN PROMOCION'
GROUP BY df.anio, df.mes, df.nombre_mes, dp.promocion, de.nombre_completo;
GO

/* 11. Comercial: clientes captados por promoción y segmento (sexo/rango etario).
   Dimensiones: Fecha, Cliente, Plan. */
CREATE OR ALTER VIEW dbo.DM_Promociones_Clientes
AS
SELECT
    df.anio AS Anio,
    df.mes AS MesNumero,
    df.nombre_mes AS Mes,
    dp.promocion AS Promocion,
    dc.sexo AS Sexo,
    dc.rango_etario AS RangoEtario,
    COUNT(DISTINCT fm.sk_cliente) AS ClientesCaptados
FROM dbo.FactMembresias fm
INNER JOIN dbo.DimFecha df ON df.sk_fecha = fm.sk_fecha_inicio
INNER JOIN dbo.DimPlan dp ON dp.sk_plan = fm.sk_plan
INNER JOIN dbo.DimCliente dc ON dc.sk_cliente = fm.sk_cliente
WHERE dp.promocion <> 'SIN PROMOCION'
GROUP BY df.anio, df.mes, df.nombre_mes, dp.promocion, dc.sexo, dc.rango_etario;
GO

/* Pruebas rápidas de las salidas SQL antes de conectar Power BI. */
SELECT TOP (20) * FROM dbo.DM_Gerencia_Ingresos ORDER BY Anio, MesNumero;
SELECT TOP (20) * FROM dbo.DM_Gerencia_Membresias ORDER BY Anio, MesNumero;
SELECT TOP (20) * FROM dbo.DM_Comercial_Plan ORDER BY Anio, MesNumero, TipoPlan;
SELECT TOP (20) * FROM dbo.DM_Atencion_Reclamos ORDER BY Anio, MesNumero;
SELECT TOP (20) * FROM dbo.DM_Entrenamiento_Progreso ORDER BY id_cliente_bk, id_objetivo_bk;
SELECT TOP (20) * FROM dbo.DM_Promociones_Ventas ORDER BY Anio, MesNumero, Promocion;
SELECT TOP (20) * FROM dbo.DM_Promociones_Membresias ORDER BY Anio, MesNumero, Promocion;
SELECT TOP (20) * FROM dbo.DM_Promociones_Clientes ORDER BY Anio, MesNumero, Promocion;
GO
