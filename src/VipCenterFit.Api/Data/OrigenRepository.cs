using Dapper;
using VipCenterFit.Api.Models;

namespace VipCenterFit.Api.Data;

/// <summary>
/// Escritura transaccional en ORIGEN (BI_VIP_CENTER_FIT_DW_ORIGEN). Es lo que
/// simula JMeter: la "web" del gimnasio inserta/actualiza/borra filas operativas
/// y el CDC captura esos cambios hacia el Data Warehouse.
/// </summary>
public sealed class OrigenRepository(DbConnectionFactory factory)
{
    private async Task<int> ExecAsync(string sql, object param, CancellationToken ct)
    {
        await using var cn = factory.Origen();
        return await cn.ExecuteAsync(new CommandDefinition(sql, param, cancellationToken: ct));
    }

    public Task<int> InsertClienteAsync(ClienteRequest r, CancellationToken ct) => ExecAsync("""
        INSERT INTO dbo.DimCliente
            (id_cliente_bk, dni, nombre_completo, sexo, rango_etario, estado_cliente,
             fecha_registro_origen, fecha_inicio_validez, fecha_fin_validez, es_actual)
        VALUES
            (@IdClienteBk, @Dni, @NombreCompleto, @Sexo, @RangoEtario, @EstadoCliente,
             @FechaRegistroOrigen, @FechaInicioValidez, @FechaFinValidez, @EsActual)
        """, r, ct);

    public Task<int> InsertEmpleadoAsync(EmpleadoRequest r, CancellationToken ct) => ExecAsync("""
        INSERT INTO dbo.DimEmpleado (id_empleado_bk, dni, nombre_completo, cargo, area, codigo_empleado)
        VALUES (@IdEmpleadoBk, @Dni, @NombreCompleto, @Cargo, @Area, @CodigoEmpleado)
        """, r, ct);

    public Task<int> InsertMembresiaAsync(MembresiaRequest r, CancellationToken ct) => ExecAsync("""
        INSERT INTO dbo.FactMembresias
            (id_membresia_bk, sk_cliente, sk_plan, sk_empleado, sk_fecha_inicio,
             sk_fecha_fin, duracion_dias, precio_final, es_renovacion, estado_membresia,
             dias_anticipacion_renovacion)
        VALUES
            (@IdMembresiaBk, @SkCliente, @SkPlan, @SkEmpleado, @SkFechaInicio,
             @SkFechaFin, @DuracionDias, @PrecioFinal, @EsRenovacion, @EstadoMembresia,
             @DiasAnticipacionRenovacion)
        """, r, ct);

    public Task<int> InsertVentaAsync(VentaRequest r, CancellationToken ct) => ExecAsync("""
        INSERT INTO dbo.FactVentas
            (id_pago_bk, sk_fecha_pago, sk_cliente, sk_plan, sk_empleado,
             id_membresia_bk, monto_neto, descuento_aplicado, precio_lista, metodo_pago)
        VALUES
            (@IdPagoBk, @SkFechaPago, @SkCliente, @SkPlan, @SkEmpleado,
             @IdMembresiaBk, @MontoNeto, @DescuentoAplicado, @PrecioLista, @MetodoPago)
        """, r, ct);

    public Task<int> InsertRenovacionAsync(RenovacionRequest r, CancellationToken ct) => ExecAsync("""
        INSERT INTO dbo.FactRenovaciones
            (id_renovacion_bk, sk_fecha_renovacion, sk_cliente, sk_empleado,
             id_membresia_anterior_bk, id_membresia_nueva_bk, dias_anticipacion, monto)
        VALUES
            (@IdRenovacionBk, @SkFechaRenovacion, @SkCliente, @SkEmpleado,
             @IdMembresiaAnteriorBk, @IdMembresiaNuevaBk, @DiasAnticipacion, @Monto)
        """, r, ct);

    public Task<int> InsertAvisoAsync(AvisoRequest r, CancellationToken ct) => ExecAsync("""
        INSERT INTO dbo.FactAvisos
            (id_aviso_bk, sk_fecha_aviso, sk_cliente, sk_empleado, id_membresia_bk,
             dias_antes_vencimiento, medio, estado)
        VALUES
            (@IdAvisoBk, @SkFechaAviso, @SkCliente, @SkEmpleado, @IdMembresiaBk,
             @DiasAntesVencimiento, @Medio, @Estado)
        """, r, ct);

    public Task<int> InsertAsistenciaAsync(AsistenciaRequest r, CancellationToken ct) => ExecAsync("""
        INSERT INTO dbo.FactAsistencias
            (id_asistencia_bk, sk_fecha_asistencia, sk_cliente, sk_plan, sk_empleado,
             hora_ingreso, cantidad_asistencias)
        VALUES
            (@IdAsistenciaBk, @SkFechaAsistencia, @SkCliente, @SkPlan, @SkEmpleado,
             @HoraIngreso, @CantidadAsistencias)
        """, r, ct);

    public Task<int> InsertObjetivoAsync(ObjetivoRequest r, CancellationToken ct) => ExecAsync("""
        INSERT INTO dbo.FactObjetivos
            (id_objetivo_bk, sk_fecha_inicio, sk_fecha_meta, sk_cliente, tipo_objetivo, valor_inicial,
             valor_objetivo, unidad_medida, estado)
        VALUES
            (@IdObjetivoBk, @SkFechaInicio, @SkFechaMeta, @SkCliente, @TipoObjetivo, @ValorInicial,
             @ValorObjetivo, @UnidadMedida, @Estado)
        """, r, ct);

    public Task<int> InsertEvaluacionAsync(EvaluacionRequest r, CancellationToken ct) => ExecAsync("""
        INSERT INTO dbo.FactEvaluaciones
            (id_evaluacion_bk, sk_fecha_evaluacion, sk_cliente, sk_empleado, id_objetivo_bk,
             peso, altura, grasa_corporal, masa_muscular)
        VALUES
            (@IdEvaluacionBk, @SkFechaEvaluacion, @SkCliente, @SkEmpleado, @IdObjetivoBk,
             @Peso, @Altura, @GrasaCorporal, @MasaMuscular)
        """, r, ct);

    public Task<int> InsertReclamoAsync(ReclamoRequest r, CancellationToken ct) => ExecAsync("""
        INSERT INTO dbo.FactReclamos
            (id_reclamo_bk, sk_fecha_reclamo, sk_cliente, sk_empleado, categoria, estado,
             fecha_resolucion, fecha_cierre, dias_resolucion, resuelto_en_mostrador,
             escalado, area_responsable)
        VALUES
            (@IdReclamoBk, @SkFechaReclamo, @SkCliente, @SkEmpleado, @Categoria, @Estado,
             @FechaResolucion, @FechaCierre, @DiasResolucion, @ResueltoEnMostrador,
             @Escalado, @AreaResponsable)
        """, r, ct);

    public Task<int> InsertSesionProgramadaAsync(SesionProgramadaRequest r, CancellationToken ct) => ExecAsync("""
        INSERT INTO dbo.FactSesionesProgramadas
            (id_sesion_bk, sk_fecha_programada, sk_cliente, sk_plan, sk_empleado,
             tipo_sesion, hora_programada, estado_sesion, duracion_minutos,
             fecha_cancelacion, motivo_cancelacion)
        VALUES
            (@IdSesionBk, @SkFechaProgramada, @SkCliente, @SkPlan, @SkEmpleado,
             @TipoSesion, @HoraProgramada, @EstadoSesion, @DuracionMinutos,
             @FechaCancelacion, @MotivoCancelacion)
        """, r, ct);

    public Task<int> InsertEvaluacionProgramadaAsync(EvaluacionProgramadaRequest r, CancellationToken ct) => ExecAsync("""
        INSERT INTO dbo.FactEvaluacionesProgramadas
            (id_evaluacion_programada_bk, sk_fecha_programada, sk_cliente, sk_empleado,
             id_objetivo_bk, tipo_evaluacion, estado_evaluacion, id_evaluacion_bk)
        VALUES
            (@IdEvaluacionProgramadaBk, @SkFechaProgramada, @SkCliente, @SkEmpleado,
             @IdObjetivoBk, @TipoEvaluacion, @EstadoEvaluacion, @IdEvaluacionBk)
        """, r, ct);

    public Task<int> InsertRetencionAsync(RetencionRequest r, CancellationToken ct) => ExecAsync("""
        INSERT INTO dbo.FactRetenciones
            (id_retencion_bk, sk_fecha_retencion, sk_cliente, sk_empleado, id_membresia_bk,
             canal, motivo, resultado, monto_oferta)
        VALUES
            (@IdRetencionBk, @SkFechaRetencion, @SkCliente, @SkEmpleado, @IdMembresiaBk,
             @Canal, @Motivo, @Resultado, @MontoOferta)
        """, r, ct);
}
