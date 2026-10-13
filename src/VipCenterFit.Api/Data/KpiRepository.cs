using Dapper;
using VipCenterFit.Api.OData;

namespace VipCenterFit.Api.Data;

/// <summary>
/// Lectura de las vistas de KPIs del Data Warehouse (esquema dbo, vistas DM_*).
/// Cada consulta agrega una clave sintética RowKey no nula para poder exponer
/// la misma forma por REST y por OData.
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

    public Task<IReadOnlyList<EntrenamientoAsistenciaDto>> EntrenamientoAsistenciaAsync(int? desdeAnio, int? hastaAnio, int? skCliente, CancellationToken ct = default) =>
        QueryAsync<EntrenamientoAsistenciaDto>($"""
            SELECT CONCAT_WS('|', v.Anio, v.MesNumero, v.sk_cliente) AS RowKey, v.*
            FROM dbo.DM_Entrenamiento_Asistencia v
            {FiltroAnio} AND (@SkCliente IS NULL OR v.sk_cliente = @SkCliente)
            ORDER BY v.Anio, v.MesNumero, v.sk_cliente
            """, new { DesdeAnio = desdeAnio, HastaAnio = hastaAnio, SkCliente = skCliente }, ct);

    public Task<IReadOnlyList<EntrenamientoProgresoDto>> EntrenamientoProgresoAsync(int? skCliente, string? tipoObjetivo, CancellationToken ct = default) =>
        QueryAsync<EntrenamientoProgresoDto>("""
            SELECT CONCAT_WS('|', v.sk_cliente, v.id_objetivo_bk) AS RowKey, v.*
            FROM dbo.DM_Entrenamiento_Progreso v
            WHERE (@SkCliente IS NULL OR v.sk_cliente = @SkCliente)
              AND (@TipoObjetivo IS NULL OR v.tipo_objetivo = @TipoObjetivo)
            ORDER BY v.id_cliente_bk, v.id_objetivo_bk
            """, new { SkCliente = skCliente, TipoObjetivo = tipoObjetivo }, ct);

    public Task<IReadOnlyList<EntrenamientoCumplimientoDto>> EntrenamientoCumplimientoAsync(int? desdeAnio, int? hastaAnio, string? tipoObjetivo, CancellationToken ct = default) =>
        QueryAsync<EntrenamientoCumplimientoDto>($"""
            SELECT CONCAT_WS('|', v.Anio, v.MesNumero, v.TipoObjetivo) AS RowKey, v.*
            FROM dbo.DM_Entrenamiento_Cumplimiento v
            {FiltroAnio} AND (@TipoObjetivo IS NULL OR v.TipoObjetivo = @TipoObjetivo)
            ORDER BY v.Anio, v.MesNumero, v.TipoObjetivo
            """, new { DesdeAnio = desdeAnio, HastaAnio = hastaAnio, TipoObjetivo = tipoObjetivo }, ct);

    public Task<IReadOnlyList<VentasGerenciaDto>> VentasGerenciaAsync(int? desdeAnio, int? hastaAnio, string? plan, CancellationToken ct = default) =>
        QueryAsync<VentasGerenciaDto>($"""
            SELECT CONCAT_WS('|', v.Anio, v.Trimestre, v.MesNumero, v.Membresia) AS RowKey, v.*
            FROM dbo.DM_Ventas_Gerencia v
            {FiltroAnio} AND (@Plan IS NULL OR v.Membresia = @Plan)
            ORDER BY v.Anio, v.MesNumero, v.Membresia
            """, new { DesdeAnio = desdeAnio, HastaAnio = hastaAnio, Plan = plan }, ct);

    public Task<IReadOnlyList<RutinasEntrenadorDto>> RutinasEntrenadorAsync(int? desdeAnio, int? hastaAnio, string? entrenador, CancellationToken ct = default) =>
        QueryAsync<RutinasEntrenadorDto>($"""
            SELECT CONCAT_WS('|', v.Anio, v.MesNumero, v.Rango_Etario_Cliente, v.Nombre_Entrenador, v.Tipo_Plan) AS RowKey, v.*
            FROM dbo.DM_Rutinas_Entrenador v
            {FiltroAnio} AND (@Entrenador IS NULL OR v.Nombre_Entrenador = @Entrenador)
            ORDER BY v.Anio, v.MesNumero, v.Nombre_Entrenador
            """, new { DesdeAnio = desdeAnio, HastaAnio = hastaAnio, Entrenador = entrenador }, ct);

    public Task<IReadOnlyList<AtencionRecepcionDto>> AtencionRecepcionAsync(int? desdeAnio, int? hastaAnio, string? categoria, CancellationToken ct = default) =>
        QueryAsync<AtencionRecepcionDto>($"""
            SELECT CONCAT_WS('|', v.Anio, v.MesNumero, v.Cliente, v.Categoria_Atencion, v.Estado_Atencion) AS RowKey, v.*
            FROM dbo.DM_Atencion_Recepcion v
            {FiltroAnio} AND (@Categoria IS NULL OR v.Categoria_Atencion = @Categoria)
            ORDER BY v.Anio, v.MesNumero, v.Cliente
            """, new { DesdeAnio = desdeAnio, HastaAnio = hastaAnio, Categoria = categoria }, ct);

    public Task<IReadOnlyList<EntrenamientoEvaluacionesDto>> EntrenamientoEvaluacionesAsync(int? desdeAnio, int? hastaAnio, int? skCliente, CancellationToken ct = default) =>
        QueryAsync<EntrenamientoEvaluacionesDto>($"""
            SELECT CONCAT_WS('|', v.Anio, v.MesNumero, v.sk_cliente) AS RowKey, v.*
            FROM dbo.DM_Entrenamiento_Evaluaciones v
            {FiltroAnio} AND (@SkCliente IS NULL OR v.sk_cliente = @SkCliente)
            ORDER BY v.Anio, v.MesNumero, v.sk_cliente
            """, new { DesdeAnio = desdeAnio, HastaAnio = hastaAnio, SkCliente = skCliente }, ct);

    public Task<IReadOnlyList<AtencionRetencionDto>> AtencionRetencionAsync(int? desdeAnio, int? hastaAnio, string? canal, int? skCliente, CancellationToken ct = default) =>
        QueryAsync<AtencionRetencionDto>($"""
            SELECT CONCAT_WS('|', v.Anio, v.MesNumero, v.sk_cliente, v.Canal) AS RowKey, v.*
            FROM dbo.DM_Atencion_Retencion v
            {FiltroAnio} AND (@Canal IS NULL OR v.Canal = @Canal) AND (@SkCliente IS NULL OR v.sk_cliente = @SkCliente)
            ORDER BY v.Anio, v.MesNumero, v.sk_cliente
            """, new { DesdeAnio = desdeAnio, HastaAnio = hastaAnio, Canal = canal, SkCliente = skCliente }, ct);
}
