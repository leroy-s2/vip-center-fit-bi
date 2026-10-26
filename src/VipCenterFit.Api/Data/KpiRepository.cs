using Dapper;
using VipCenterFit.Api.OData;

namespace VipCenterFit.Api.Data;

/// <summary>
/// Lectura del Data Warehouse: vistas de KPIs (dbo.DM_*) y modelo en estrella
/// (dim.* y los 3 esquemas de data mart). Cada consulta agrega una clave
/// sintética RowKey no nula para poder exponer la misma forma por REST y OData.
/// </summary>
public sealed class KpiRepository(DbConnectionFactory factory)
{
    private async Task<IReadOnlyList<T>> QueryAsync<T>(string sql, object? param, CancellationToken ct = default)
    {
        await using var cn = factory.Dw();
        var rows = await cn.QueryAsync<T>(new CommandDefinition(sql, param, cancellationToken: ct));
        return rows.AsList();
    }

    private const string FiltroAnio =
        "WHERE (@DesdeAnio IS NULL OR v.Anio >= @DesdeAnio) AND (@HastaAnio IS NULL OR v.Anio <= @HastaAnio)";

    /// <summary>
    /// Ventana de importación de los hechos. Power BI debe enviar fechaDesde/fechaHasta;
    /// si no lo hace se usa el último año para no materializar todo el histórico.
    /// </summary>
    private static (DateTime Desde, DateTime Hasta) Ventana(DateTime? desde, DateTime? hasta)
    {
        var h = hasta ?? DateTime.UtcNow.Date;
        var d = desde ?? h.AddYears(-1);
        return (d, h);
    }

    /* ============================ VISTAS DE KPIs ============================ */

    public Task<IReadOnlyList<GerenciaIngresosDto>> GerenciaIngresosAsync(int? desdeAnio, int? hastaAnio, CancellationToken ct = default) =>
        QueryAsync<GerenciaIngresosDto>($"""
            SELECT CONCAT_WS('|', v.Anio, v.MesNumero) AS RowKey, v.*
            FROM dbo.DM_Gerencia_Ingresos v
            {FiltroAnio}
            ORDER BY v.Anio, v.MesNumero
            """, new { DesdeAnio = desdeAnio, HastaAnio = hastaAnio }, ct);

    public Task<IReadOnlyList<GerenciaMembresiasDto>> GerenciaMembresiasAsync(int? desdeAnio, int? hastaAnio, CancellationToken ct = default) =>
        QueryAsync<GerenciaMembresiasDto>($"""
            SELECT CONCAT_WS('|', v.Anio, v.MesNumero) AS RowKey, v.*
            FROM dbo.DM_Gerencia_Membresias v
            {FiltroAnio}
            ORDER BY v.Anio, v.MesNumero
            """, new { DesdeAnio = desdeAnio, HastaAnio = hastaAnio }, ct);

    public Task<IReadOnlyList<ComercialPlanDto>> ComercialPlanAsync(int? desdeAnio, int? hastaAnio, string? plan, CancellationToken ct = default) =>
        QueryAsync<ComercialPlanDto>($"""
            SELECT CONCAT_WS('|', v.Anio, v.MesNumero, v.TipoPlan) AS RowKey, v.*
            FROM dbo.DM_Comercial_Plan v
            {FiltroAnio} AND (@Plan IS NULL OR v.TipoPlan = @Plan)
            ORDER BY v.Anio, v.MesNumero, v.TipoPlan
            """, new { DesdeAnio = desdeAnio, HastaAnio = hastaAnio, Plan = plan }, ct);

    public Task<IReadOnlyList<ComercialPromocionesDto>> ComercialPromocionesAsync(int? desdeAnio, int? hastaAnio, string? promocion, CancellationToken ct = default) =>
        QueryAsync<ComercialPromocionesDto>($"""
            SELECT CONCAT_WS('|', v.Anio, v.MesNumero, v.Promocion) AS RowKey, v.*
            FROM dbo.DM_Comercial_Promociones v
            {FiltroAnio} AND (@Promocion IS NULL OR v.Promocion = @Promocion)
            ORDER BY v.Anio, v.MesNumero, v.Promocion
            """, new { DesdeAnio = desdeAnio, HastaAnio = hastaAnio, Promocion = promocion }, ct);

    public Task<IReadOnlyList<AvisosCoberturaDto>> AvisosCoberturaAsync(CancellationToken ct = default) =>
        QueryAsync<AvisosCoberturaDto>("""
            SELECT CONVERT(VARCHAR(10), v.FechaCorte, 23) AS RowKey, v.*
            FROM dbo.DM_Avisos_Cobertura v
            ORDER BY v.FechaCorte
            """, null, ct);

    public Task<IReadOnlyList<AtencionReclamosDto>> AtencionReclamosAsync(int? desdeAnio, int? hastaAnio, string? categoria, CancellationToken ct = default) =>
        QueryAsync<AtencionReclamosDto>($"""
            SELECT CONCAT_WS('|', v.Anio, v.MesNumero, v.CategoriaAtencion) AS RowKey, v.*
            FROM dbo.DM_Atencion_Reclamos v
            {FiltroAnio} AND (@Categoria IS NULL OR v.CategoriaAtencion = @Categoria)
            ORDER BY v.Anio, v.MesNumero, v.CategoriaAtencion
            """, new { DesdeAnio = desdeAnio, HastaAnio = hastaAnio, Categoria = categoria }, ct);

    public Task<IReadOnlyList<AtencionRetencionDto>> AtencionRetencionAsync(int? desdeAnio, int? hastaAnio, string? canal, int? skCliente, CancellationToken ct = default) =>
        QueryAsync<AtencionRetencionDto>($"""
            SELECT CONCAT_WS('|', v.Anio, v.MesNumero, v.SkCliente, v.Canal) AS RowKey, v.*
            FROM dbo.DM_Atencion_Retencion v
            {FiltroAnio} AND (@Canal IS NULL OR v.Canal = @Canal) AND (@SkCliente IS NULL OR v.SkCliente = @SkCliente)
            ORDER BY v.Anio, v.MesNumero, v.SkCliente
            """, new { DesdeAnio = desdeAnio, HastaAnio = hastaAnio, Canal = canal, SkCliente = skCliente }, ct);

    public Task<IReadOnlyList<AtencionRecepcionDto>> AtencionRecepcionAsync(int? desdeAnio, int? hastaAnio, string? categoria, CancellationToken ct = default) =>
        QueryAsync<AtencionRecepcionDto>($"""
            SELECT CONCAT_WS('|', v.Anio, v.MesNumero, v.Cliente, v.CategoriaAtencion, v.EstadoAtencion) AS RowKey, v.*
            FROM dbo.DM_Atencion_Recepcion v
            {FiltroAnio} AND (@Categoria IS NULL OR v.CategoriaAtencion = @Categoria)
            ORDER BY v.Anio, v.MesNumero, v.Cliente
            """, new { DesdeAnio = desdeAnio, HastaAnio = hastaAnio, Categoria = categoria }, ct);

    public Task<IReadOnlyList<EntrenamientoAsistenciaDto>> EntrenamientoAsistenciaAsync(int? desdeAnio, int? hastaAnio, int? skCliente, CancellationToken ct = default) =>
        QueryAsync<EntrenamientoAsistenciaDto>($"""
            SELECT CONCAT_WS('|', v.Anio, v.MesNumero, v.SkCliente) AS RowKey, v.*
            FROM dbo.DM_Entrenamiento_Asistencia v
            {FiltroAnio} AND (@SkCliente IS NULL OR v.SkCliente = @SkCliente)
            ORDER BY v.Anio, v.MesNumero, v.SkCliente
            """, new { DesdeAnio = desdeAnio, HastaAnio = hastaAnio, SkCliente = skCliente }, ct);

    public Task<IReadOnlyList<EntrenamientoAccesosDto>> EntrenamientoAccesosAsync(int? desdeAnio, int? hastaAnio, int? skCliente, CancellationToken ct = default) =>
        QueryAsync<EntrenamientoAccesosDto>($"""
            SELECT CONCAT_WS('|', v.Anio, v.MesNumero, v.SkCliente) AS RowKey, v.*
            FROM dbo.DM_Entrenamiento_Accesos v
            {FiltroAnio} AND (@SkCliente IS NULL OR v.SkCliente = @SkCliente)
            ORDER BY v.Anio, v.MesNumero, v.SkCliente
            """, new { DesdeAnio = desdeAnio, HastaAnio = hastaAnio, SkCliente = skCliente }, ct);

    public Task<IReadOnlyList<EntrenamientoProgresoDto>> EntrenamientoProgresoAsync(int? skCliente, string? tipoObjetivo, CancellationToken ct = default) =>
        QueryAsync<EntrenamientoProgresoDto>("""
            SELECT CONCAT_WS('|', v.SkCliente, v.IdObjetivoBk) AS RowKey, v.*
            FROM dbo.DM_Entrenamiento_Progreso v
            WHERE (@SkCliente IS NULL OR v.SkCliente = @SkCliente)
              AND (@TipoObjetivo IS NULL OR v.TipoObjetivo = @TipoObjetivo)
            ORDER BY v.IdClienteBk, v.IdObjetivoBk
            """, new { SkCliente = skCliente, TipoObjetivo = tipoObjetivo }, ct);

    public Task<IReadOnlyList<EntrenamientoBajoProgresoDto>> EntrenamientoBajoProgresoAsync(int? skCliente, CancellationToken ct = default) =>
        QueryAsync<EntrenamientoBajoProgresoDto>("""
            SELECT CONVERT(VARCHAR(20), v.SkCliente) AS RowKey, v.*
            FROM dbo.DM_Entrenamiento_BajoProgreso v
            WHERE (@SkCliente IS NULL OR v.SkCliente = @SkCliente)
            ORDER BY v.ObjetivosBajoProgreso DESC, v.SkCliente
            """, new { SkCliente = skCliente }, ct);

    public Task<IReadOnlyList<EntrenamientoEvaluacionesDto>> EntrenamientoEvaluacionesAsync(int? desdeAnio, int? hastaAnio, int? skCliente, CancellationToken ct = default) =>
        QueryAsync<EntrenamientoEvaluacionesDto>($"""
            SELECT CONCAT_WS('|', v.Anio, v.MesNumero, v.SkCliente) AS RowKey, v.*
            FROM dbo.DM_Entrenamiento_Evaluaciones v
            {FiltroAnio} AND (@SkCliente IS NULL OR v.SkCliente = @SkCliente)
            ORDER BY v.Anio, v.MesNumero, v.SkCliente
            """, new { DesdeAnio = desdeAnio, HastaAnio = hastaAnio, SkCliente = skCliente }, ct);

    public Task<IReadOnlyList<RutinasEntrenadorDto>> RutinasEntrenadorAsync(int? desdeAnio, int? hastaAnio, string? entrenador, CancellationToken ct = default) =>
        QueryAsync<RutinasEntrenadorDto>($"""
            SELECT CONCAT_WS('|', v.Anio, v.MesNumero, ISNULL(v.CodigoEmpleado, ''), ISNULL(v.RangoEtarioCliente, ''), ISNULL(v.TipoPlan, '')) AS RowKey, v.*
            FROM dbo.DM_Rutinas_Entrenador v
            {FiltroAnio} AND (@Entrenador IS NULL OR v.NombreEntrenador = @Entrenador)
            ORDER BY v.Anio, v.MesNumero, v.NombreEntrenador
            """, new { DesdeAnio = desdeAnio, HastaAnio = hastaAnio, Entrenador = entrenador }, ct);

    /* ======================= MODELO EN ESTRELLA (Power BI) =======================
       Los hechos exigen una ventana de fechas: se aplica en SQL antes de que
       OData filtre u ordene en memoria. */

    public Task<IReadOnlyList<DimFechaDto>> DimFechaAsync(CancellationToken ct = default) =>
        QueryAsync<DimFechaDto>("""
            SELECT CONVERT(VARCHAR(20), v.sk_fecha) AS RowKey, v.*
            FROM dim.DimFecha v
            ORDER BY v.sk_fecha
            """, null, ct);

    public Task<IReadOnlyList<DimClienteDto>> DimClienteAsync(CancellationToken ct = default) =>
        QueryAsync<DimClienteDto>("""
            SELECT CONVERT(VARCHAR(20), v.sk_cliente) AS RowKey, v.*
            FROM dim.DimCliente v
            ORDER BY v.sk_cliente
            """, null, ct);

    public Task<IReadOnlyList<DimEmpleadoDto>> DimEmpleadoAsync(CancellationToken ct = default) =>
        QueryAsync<DimEmpleadoDto>("""
            SELECT CONVERT(VARCHAR(20), v.sk_empleado) AS RowKey, v.*
            FROM dim.DimEmpleado v
            ORDER BY v.sk_empleado
            """, null, ct);

    public Task<IReadOnlyList<DimPlanDto>> DimPlanAsync(CancellationToken ct = default) =>
        QueryAsync<DimPlanDto>("""
            SELECT CONVERT(VARCHAR(20), v.sk_plan) AS RowKey, v.*
            FROM dim.DimPlan v
            ORDER BY v.sk_plan
            """, null, ct);

    public Task<IReadOnlyList<FactVentasDto>> FactVentasAsync(DateTime? desde, DateTime? hasta, CancellationToken ct = default)
    {
        var (d, h) = Ventana(desde, hasta);
        return QueryAsync<FactVentasDto>("""
            SELECT CONVERT(VARCHAR(20), v.sk_venta) AS RowKey, v.*
            FROM dm_comercial.FactVentas v
            INNER JOIN dim.DimFecha f ON f.sk_fecha = v.sk_fecha_pago
            WHERE f.fecha BETWEEN @Desde AND @Hasta
            ORDER BY v.sk_fecha_pago, v.sk_venta
            """, new { Desde = d, Hasta = h }, ct);
    }

    public Task<IReadOnlyList<FactMembresiasDto>> FactMembresiasAsync(DateTime? desde, DateTime? hasta, CancellationToken ct = default)
    {
        var (d, h) = Ventana(desde, hasta);
        return QueryAsync<FactMembresiasDto>("""
            SELECT CONCAT_WS('|', v.id_membresia_bk, v.sk_fecha_corte) AS RowKey, v.*
            FROM dm_comercial.FactMembresias v
            INNER JOIN dim.DimFecha f ON f.sk_fecha = v.sk_fecha_corte
            WHERE f.fecha BETWEEN @Desde AND @Hasta
            ORDER BY v.sk_fecha_corte, v.id_membresia_bk
            """, new { Desde = d, Hasta = h }, ct);
    }

    public Task<IReadOnlyList<FactAsistenciasDto>> FactAsistenciasAsync(DateTime? desde, DateTime? hasta, CancellationToken ct = default)
    {
        var (d, h) = Ventana(desde, hasta);
        return QueryAsync<FactAsistenciasDto>("""
            SELECT CONVERT(VARCHAR(20), v.sk_asistencia) AS RowKey, v.*
            FROM dm_entrenamiento.FactAsistencias v
            INNER JOIN dim.DimFecha f ON f.sk_fecha = v.sk_fecha_asistencia
            WHERE f.fecha BETWEEN @Desde AND @Hasta
            ORDER BY v.sk_fecha_asistencia, v.sk_asistencia
            """, new { Desde = d, Hasta = h }, ct);
    }

    public Task<IReadOnlyList<FactSesionesEntrenamientoDto>> FactSesionesEntrenamientoAsync(DateTime? desde, DateTime? hasta, CancellationToken ct = default)
    {
        var (d, h) = Ventana(desde, hasta);
        return QueryAsync<FactSesionesEntrenamientoDto>("""
            SELECT CONVERT(VARCHAR(20), v.sk_sesion) AS RowKey, v.*
            FROM dm_entrenamiento.FactSesionesEntrenamiento v
            INNER JOIN dim.DimFecha f ON f.sk_fecha = v.sk_fecha_programada
            WHERE f.fecha BETWEEN @Desde AND @Hasta
            ORDER BY v.sk_fecha_programada, v.sk_sesion
            """, new { Desde = d, Hasta = h }, ct);
    }

    public Task<IReadOnlyList<FactSeguimientoFisicoDto>> FactSeguimientoFisicoAsync(DateTime? desde, DateTime? hasta, CancellationToken ct = default)
    {
        var (d, h) = Ventana(desde, hasta);
        return QueryAsync<FactSeguimientoFisicoDto>("""
            SELECT CONCAT_WS('|', v.sk_cliente, v.id_objetivo_bk, v.sk_fecha_corte) AS RowKey, v.*
            FROM dm_entrenamiento.FactSeguimientoFisico v
            INNER JOIN dim.DimFecha f ON f.sk_fecha = v.sk_fecha_corte
            WHERE f.fecha BETWEEN @Desde AND @Hasta
            ORDER BY v.sk_fecha_corte, v.id_objetivo_bk
            """, new { Desde = d, Hasta = h }, ct);
    }

    public Task<IReadOnlyList<FactReclamosDto>> FactReclamosAsync(DateTime? desde, DateTime? hasta, CancellationToken ct = default)
    {
        var (d, h) = Ventana(desde, hasta);
        return QueryAsync<FactReclamosDto>("""
            SELECT CONVERT(VARCHAR(20), v.sk_reclamo) AS RowKey, v.*
            FROM dm_atencion.FactReclamos v
            INNER JOIN dim.DimFecha f ON f.sk_fecha = v.sk_fecha_reclamo
            WHERE f.fecha BETWEEN @Desde AND @Hasta
            ORDER BY v.sk_fecha_reclamo, v.sk_reclamo
            """, new { Desde = d, Hasta = h }, ct);
    }

    public Task<IReadOnlyList<FactRetencionesDto>> FactRetencionesAsync(DateTime? desde, DateTime? hasta, CancellationToken ct = default)
    {
        var (d, h) = Ventana(desde, hasta);
        return QueryAsync<FactRetencionesDto>("""
            SELECT CONVERT(VARCHAR(20), v.sk_retencion) AS RowKey, v.*
            FROM dm_atencion.FactRetenciones v
            INNER JOIN dim.DimFecha f ON f.sk_fecha = v.sk_fecha_retencion
            WHERE f.fecha BETWEEN @Desde AND @Hasta
            ORDER BY v.sk_fecha_retencion, v.sk_retencion
            """, new { Desde = d, Hasta = h }, ct);
    }
}
