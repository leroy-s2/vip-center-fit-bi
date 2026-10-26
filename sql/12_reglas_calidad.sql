/*=============================================================================
  VIP CENTER FIT - ETAPA 4 (AUDITORÍA): REGLAS DE CALIDAD

  Materializa los "query requeridos" del blueprint para la etapa de
  transformación, en el orden del enunciado:

    1) Limpieza
    2) Estandarización
    3) Validación de fechas y estados
    4) Cálculo de cohortes
    5) Carga incremental
    6) Reglas de calidad (imputaciones del ETL)

  Se agregan las reglas SNP-* propias de los snapshots diarios
  (FactMembresias y FactSeguimientoFisico).

  Cada control debe devolver 0 filas si el Data Mart está limpio. El catálogo
  de reglas (ID, condición, severidad, acción) está en docs/CALIDAD.md.
=============================================================================*/

USE BI_VIP_CENTER_FIT_DW;
GO

/* Vista de resumen de imputaciones por regla. */
IF OBJECT_ID('dq.V_ImputacionesPorRegla', 'V') IS NOT NULL DROP VIEW dq.V_ImputacionesPorRegla;
GO
CREATE VIEW dq.V_ImputacionesPorRegla
AS
SELECT
    codigo_regla,
    entidad,
    campo,
    motivo,
    COUNT(*) AS FilasImputadas,
    MIN(fecha_registro) AS PrimeraImputacion,
    MAX(fecha_registro) AS UltimaImputacion
FROM dq.RegistroImputaciones
GROUP BY codigo_regla, entidad, campo, motivo;
GO

/* 1) LIMPIEZA: valores que debieron corregirse (deben dar 0). */
SELECT 'LIM-01 DNI no estándar' AS Control, COUNT(*) AS Filas
FROM dim.DimCliente
WHERE dni IS NOT NULL AND (LEN(dni) <> 8 OR dni LIKE '%[^0-9]%')
UNION ALL
SELECT 'LIM-02 Nombre vacío', COUNT(*) FROM dim.DimCliente
WHERE nombre_completo IS NULL OR LTRIM(RTRIM(nombre_completo)) = ''
UNION ALL
SELECT 'LIM-03 Monto negativo en ventas', COUNT(*) FROM dm_comercial.FactVentas WHERE monto_neto < 0
UNION ALL
SELECT 'LIM-04 Precio final negativo', COUNT(*) FROM dm_comercial.FactMembresias WHERE precio_final < 0
UNION ALL
SELECT 'LIM-05 Duración no positiva', COUNT(*) FROM dm_comercial.FactMembresias
WHERE duracion_dias IS NOT NULL AND duracion_dias <= 0
UNION ALL
SELECT 'LIM-06 Código de empleado vacío', COUNT(*) FROM dim.DimEmpleado
WHERE codigo_empleado IS NULL OR LTRIM(RTRIM(codigo_empleado)) = '';
GO

/* 2) ESTANDARIZACIÓN: valores fuera de dominio (deben dar 0). */
SELECT 'EST-01 Sexo fuera de dominio' AS Control, COUNT(*) AS Filas
FROM dim.DimCliente WHERE sexo NOT IN ('M', 'F', 'X')
UNION ALL
SELECT 'EST-02 Estado cliente fuera de dominio', COUNT(*) FROM dim.DimCliente
WHERE estado_cliente NOT IN ('ACTIVO', 'INACTIVO')
UNION ALL
SELECT 'EST-03 Método de pago fuera de dominio', COUNT(*) FROM dm_comercial.FactVentas
WHERE metodo_pago NOT IN ('YAPE', 'PLIN', 'TRANSFERENCIA', 'TARJETA', 'EFECTIVO', 'NO ESPECIFICADO')
UNION ALL
SELECT 'EST-04 Tipo de operación fuera de dominio', COUNT(*) FROM dim.DimPlan
WHERE tipo_operacion NOT IN ('VENTA', 'MEMBRESIA', 'ASISTENCIA', 'SESION', 'NO_ESPECIFICADO')
UNION ALL
SELECT 'EST-05 Estado de reclamo fuera de dominio', COUNT(*) FROM dm_atencion.FactReclamos
WHERE estado NOT IN ('RESUELTO', 'PENDIENTE', 'NO ESPECIFICADO')
UNION ALL
SELECT 'EST-06 Estado de membresía fuera de dominio', COUNT(*) FROM dm_comercial.FactMembresias
WHERE estado_membresia NOT IN ('ACTIVA', 'VENCIDA', 'PENDIENTE', 'DESCONOCIDA')
UNION ALL
SELECT 'EST-07 Estado de sesión fuera de dominio', COUNT(*) FROM dm_entrenamiento.FactSesionesEntrenamiento
WHERE estado_sesion NOT IN ('ASISTIDA', 'AUSENTE', 'CANCELADA', 'PROGRAMADA');
GO

/* 3) VALIDACIÓN DE FECHAS Y ESTADOS (deben dar 0). */
SELECT 'FEC-01 Membresía con fin < inicio' AS Control, COUNT(*) AS Filas
FROM dm_comercial.FactMembresias fm
INNER JOIN dim.DimFecha fi ON fi.sk_fecha = fm.sk_fecha_inicio
INNER JOIN dim.DimFecha ff ON ff.sk_fecha = fm.sk_fecha_fin
WHERE ff.fecha < fi.fecha
UNION ALL
SELECT 'FEC-02 Estado ACTIVA con el corte fuera de la vigencia', COUNT(*)
FROM dm_comercial.FactMembresias fm
INNER JOIN dim.DimFecha fc ON fc.sk_fecha = fm.sk_fecha_corte
INNER JOIN dim.DimFecha fi ON fi.sk_fecha = fm.sk_fecha_inicio
INNER JOIN dim.DimFecha ff ON ff.sk_fecha = fm.sk_fecha_fin
WHERE fm.estado_membresia = 'ACTIVA'
  AND (fc.fecha < fi.fecha OR fc.fecha > ff.fecha)
UNION ALL
SELECT 'FEC-03 Fechas fuera de rango en DimFecha', COUNT(*) FROM dim.DimFecha
WHERE sk_fecha <> -1 AND (fecha < '2000-01-01' OR fecha > '2100-12-31')
UNION ALL
SELECT 'FEC-04 Hora de ingreso fuera de rango', COUNT(*) FROM dm_entrenamiento.FactAsistencias
WHERE hora_ingreso IS NOT NULL AND (hora_ingreso < 5 OR hora_ingreso > 23)
UNION ALL
SELECT 'FEC-05 Objetivo con fecha meta anterior al inicio', COUNT(*)
FROM dm_entrenamiento.FactSeguimientoFisico fs
INNER JOIN dim.DimFecha fi ON fi.sk_fecha = fs.sk_fecha_inicio
INNER JOIN dim.DimFecha fm ON fm.sk_fecha = fs.sk_fecha_meta
WHERE fm.fecha < fi.fecha;
GO

/* 3b) INTEGRIDAD REFERENCIAL: ninguna FK de hecho debe quedar NULL (imputadas a -1). */
SELECT 'REF-01 FactVentas.sk_empleado NULL' AS Control, COUNT(*) AS Filas FROM dm_comercial.FactVentas WHERE sk_empleado IS NULL
UNION ALL SELECT 'REF-02 FactMembresias.sk_empleado NULL', COUNT(*) FROM dm_comercial.FactMembresias WHERE sk_empleado IS NULL
UNION ALL SELECT 'REF-03 FactAsistencias.sk_plan NULL', COUNT(*) FROM dm_entrenamiento.FactAsistencias WHERE sk_plan IS NULL
UNION ALL SELECT 'REF-04 FactAsistencias.sk_empleado NULL', COUNT(*) FROM dm_entrenamiento.FactAsistencias WHERE sk_empleado IS NULL
UNION ALL SELECT 'REF-05 FactSesionesEntrenamiento.sk_plan NULL', COUNT(*) FROM dm_entrenamiento.FactSesionesEntrenamiento WHERE sk_plan IS NULL
UNION ALL SELECT 'REF-06 FactReclamos.sk_empleado NULL', COUNT(*) FROM dm_atencion.FactReclamos WHERE sk_empleado IS NULL
UNION ALL SELECT 'REF-07 FactSeguimientoFisico.sk_empleado NULL', COUNT(*) FROM dm_entrenamiento.FactSeguimientoFisico WHERE sk_empleado IS NULL;
GO

/* 3c) SNAPSHOTS: reglas propias de los hechos con fecha de corte. */
SELECT 'SNP-01 Corte duplicado (FactMembresias)' AS Control, COUNT(*) AS Filas
FROM
(
    SELECT id_membresia_bk, sk_fecha_corte
    FROM dm_comercial.FactMembresias
    GROUP BY id_membresia_bk, sk_fecha_corte
    HAVING COUNT(*) > 1
) x
UNION ALL
SELECT 'SNP-02 Corte duplicado (FactSeguimientoFisico)', COUNT(*)
FROM
(
    SELECT sk_cliente, id_objetivo_bk, sk_fecha_corte
    FROM dm_entrenamiento.FactSeguimientoFisico
    GROUP BY sk_cliente, id_objetivo_bk, sk_fecha_corte
    HAVING COUNT(*) > 1
) y
UNION ALL
SELECT 'SNP-03 Corte anterior al inicio del contrato', COUNT(*)
FROM dm_comercial.FactMembresias fm
INNER JOIN dim.DimFecha fc ON fc.sk_fecha = fm.sk_fecha_corte
INNER JOIN dim.DimFecha fi ON fi.sk_fecha = fm.sk_fecha_inicio
WHERE fc.fecha < fi.fecha
UNION ALL
SELECT 'SNP-04 Aviso retrocede en la serie', COUNT(*)
FROM
(
    SELECT id_membresia_bk, aviso_emitido,
           LAG(aviso_emitido) OVER (PARTITION BY id_membresia_bk ORDER BY sk_fecha_corte) AS anterior
    FROM dm_comercial.FactMembresias
) z
WHERE z.anterior = 1 AND z.aviso_emitido = 0
UNION ALL
SELECT 'SNP-05 Aviso con fecha posterior al vencimiento', COUNT(*)
FROM dm_comercial.FactMembresias fm
INNER JOIN dim.DimFecha fa ON fa.sk_fecha = fm.sk_fecha_aviso
INNER JOIN dim.DimFecha ff ON ff.sk_fecha = fm.sk_fecha_fin
WHERE fa.fecha > ff.fecha
UNION ALL
SELECT 'SNP-06 Evaluación completada sin registro de evaluación', COUNT(*)
FROM dm_entrenamiento.FactSeguimientoFisico
WHERE evaluacion_completada = 1 AND id_evaluacion_bk IS NULL
UNION ALL
SELECT 'SNP-07 Evaluación pendiente inconsistente', COUNT(*)
FROM dm_entrenamiento.FactSeguimientoFisico
WHERE evaluacion_pendiente = 1 AND NOT (evaluacion_exigible = 1 AND evaluacion_completada = 0);
GO

/* 4) CÁLCULO DE COHORTES: control de monotonía de la vista de gerencia. */
SELECT
    Anio, MesNumero, Mes, ClientesActivosInicio, ClientesInicioActivosCierre,
    TasaRetencionClientes, TasaRenovacionMembresias,
    CASE WHEN ClientesInicioActivosCierre > ClientesActivosInicio THEN 'REVISAR' ELSE 'OK' END AS Control
FROM dbo.DM_Gerencia_Membresias
ORDER BY Anio, MesNumero;
GO

/* 5) CARGA INCREMENTAL: estado de las marcas de agua (incluye snapshots). */
SELECT
    proceso, ultimo_staging_id, ultima_carga, filas_ultima_carga,
    CASE WHEN ultima_carga IS NULL THEN 'SIN_CARGA' ELSE 'OK' END AS Estado
FROM dbo.etl_control
ORDER BY proceso;
GO

/* 6) REGLAS DE CALIDAD: imputaciones del ETL (dq.RegistroImputaciones). */
SELECT codigo_regla, entidad, campo, motivo, FilasImputadas, UltimaImputacion
FROM dq.V_ImputacionesPorRegla
ORDER BY FilasImputadas DESC, codigo_regla;
GO
