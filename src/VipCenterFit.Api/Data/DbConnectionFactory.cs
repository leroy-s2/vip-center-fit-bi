using Microsoft.Data.SqlClient;

namespace VipCenterFit.Api.Data;

/// <summary>
/// Fábrica de conexiones a las tres bases del pipeline BI.
/// Las cadenas se toman de ConnectionStrings (Origen, Stg, Dw) y pueden
/// sobreescribirse por variables de entorno (ConnectionStrings__Origen, etc.).
/// </summary>
public sealed class DbConnectionFactory(IConfiguration configuration)
{
    private readonly string _origen = GetRequired(configuration, "Origen");
    private readonly string _stg = GetRequired(configuration, "Stg");
    private readonly string _dw = GetRequired(configuration, "Dw");

    private static string GetRequired(IConfiguration cfg, string name) =>
        cfg.GetConnectionString(name)
        ?? throw new InvalidOperationException($"Falta la cadena de conexión '{name}'.");

    /// <summary>OLTP de origen: donde ESCRIBE la API (lo que simula JMeter).</summary>
    public SqlConnection Origen() => new(_origen);

    /// <summary>Staging: marca de agua CDC (sólo lectura para observabilidad).</summary>
    public SqlConnection Stg() => new(_stg);

    /// <summary>Data Warehouse: lectura de las vistas de KPIs (3 data marts).</summary>
    public SqlConnection Dw() => new(_dw);

    public string OrigenName { get; } = "BI_VIP_CENTER_FIT_DW_ORIGEN";
}
