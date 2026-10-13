using Microsoft.Extensions.Configuration;
using VipCenterFit.Api.Data;
using VipCenterFit.Api.Models;
using Xunit;

namespace VipCenterFit.Api.Tests;

/// <summary>
/// Pruebas de integración contra el SQL Server del bootstrap (localhost:14330).
/// Requieren que las 3 bases existan (npm run db:bootstrap).
/// </summary>
public sealed class BiPipelineTests
{
    private const string Server = "Server=localhost,14330;User Id=sa;Password=YourStrong!Passw0rd;TrustServerCertificate=True;Encrypt=False";

    private static DbConnectionFactory Factory()
    {
        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:Origen"] = $"{Server};Database=BI_VIP_CENTER_FIT_DW_ORIGEN",
                ["ConnectionStrings:Stg"] = $"{Server};Database=BI_VIP_CENTER_FIT_STG",
                ["ConnectionStrings:Dw"] = $"{Server};Database=BI_VIP_CENTER_FIT_DW"
            })
            .Build();
        return new DbConnectionFactory(config);
    }

    [Fact]
    public async Task Kpi_Ingresos_devuelve_filas()
    {
        var repo = new KpiRepository(Factory());
        var filas = await repo.GerenciaIngresosAsync(null, null);
        Assert.NotEmpty(filas);
        Assert.All(filas, f => Assert.False(string.IsNullOrWhiteSpace(f.RowKey)));
    }

    [Fact]
    public async Task Kpi_Comercial_Plan_devuelve_filas()
    {
        var repo = new KpiRepository(Factory());
        var filas = await repo.ComercialPlanAsync(null, null, null);
        Assert.NotEmpty(filas);
    }

    [Fact]
    public async Task Escritura_roundtrip_en_origen()
    {
        var origen = new OrigenRepository(Factory());
        const int bk = 777001;
        try
        {
            var n = await origen.InsertClienteAsync(new ClienteRequest(
                bk, "00077001", "Test Roundtrip", "M", "Adultos (>40)", "ACTIVO",
                new DateTime(2026, 9, 1), new DateTime(2026, 9, 1), null, true), default);
            Assert.Equal(1, n);

            await using var cn = Factory().Origen();
            var existe = await Dapper.SqlMapper.ExecuteScalarAsync<int>(cn,
                "SELECT COUNT(*) FROM dbo.DimCliente WHERE id_cliente_bk = @bk", new { bk });
            Assert.Equal(1, existe);
        }
        finally
        {
            await using var cn = Factory().Origen();
            await Dapper.SqlMapper.ExecuteAsync(cn, "DELETE FROM dbo.DimCliente WHERE id_cliente_bk = @bk", new { bk });
        }
    }

    [Fact]
    public async Task Etl_estado_devuelve_marcas()
    {
        var repo = new EtlRepository(Factory());
        var estado = await repo.EstadoAsync();
        Assert.NotNull(estado);
        Assert.NotEmpty(estado.MarcasEtl);
    }

    [Fact]
    public async Task Kpi_Entrenamiento_Evaluaciones_devuelve_filas()
    {
        var repo = new KpiRepository(Factory());
        var filas = await repo.EntrenamientoEvaluacionesAsync(null, null, null);
        Assert.NotEmpty(filas);
        Assert.All(filas, f => Assert.False(string.IsNullOrWhiteSpace(f.RowKey)));
    }

    [Fact]
    public async Task Kpi_Atencion_Retencion_devuelve_filas()
    {
        var repo = new KpiRepository(Factory());
        var filas = await repo.AtencionRetencionAsync(null, null, null, null);
        Assert.NotEmpty(filas);
        Assert.All(filas, f => Assert.False(string.IsNullOrWhiteSpace(f.RowKey)));
    }

    [Fact]
    public async Task Escritura_roundtrip_sesion_programada()
    {
        var origen = new OrigenRepository(Factory());
        const int bk = 777002;
        try
        {
            var n = await origen.InsertSesionProgramadaAsync(new SesionProgramadaRequest(
                bk, 20260901, 1, 1, 2, "ENTRENAMIENTO", 10, "ASISTIDA", 60), default);
            Assert.Equal(1, n);

            await using var cn = Factory().Origen();
            var existe = await Dapper.SqlMapper.ExecuteScalarAsync<int>(cn,
                "SELECT COUNT(*) FROM dbo.FactSesionesProgramadas WHERE id_sesion_bk = @bk", new { bk });
            Assert.Equal(1, existe);
        }
        finally
        {
            await using var cn = Factory().Origen();
            await Dapper.SqlMapper.ExecuteAsync(cn, "DELETE FROM dbo.FactSesionesProgramadas WHERE id_sesion_bk = @bk", new { bk });
        }
    }

    [Fact]
    public async Task Escritura_roundtrip_evaluacion_programada()
    {
        var origen = new OrigenRepository(Factory());
        const int bk = 777003;
        try
        {
            var n = await origen.InsertEvaluacionProgramadaAsync(new EvaluacionProgramadaRequest(
                bk, 20260901, 1, 2, 1, "FISICA", "PROGRAMADA", null), default);
            Assert.Equal(1, n);

            await using var cn = Factory().Origen();
            var existe = await Dapper.SqlMapper.ExecuteScalarAsync<int>(cn,
                "SELECT COUNT(*) FROM dbo.FactEvaluacionesProgramadas WHERE id_evaluacion_programada_bk = @bk", new { bk });
            Assert.Equal(1, existe);
        }
        finally
        {
            await using var cn = Factory().Origen();
            await Dapper.SqlMapper.ExecuteAsync(cn, "DELETE FROM dbo.FactEvaluacionesProgramadas WHERE id_evaluacion_programada_bk = @bk", new { bk });
        }
    }

    [Fact]
    public async Task Escritura_roundtrip_retencion()
    {
        var origen = new OrigenRepository(Factory());
        const int bk = 777004;
        try
        {
            var n = await origen.InsertRetencionAsync(new RetencionRequest(
                bk, 20260901, 1, 2, 900001, "MOSTRADOR", "PRECIO", "RETENIDO", 49.90m), default);
            Assert.Equal(1, n);

            await using var cn = Factory().Origen();
            var existe = await Dapper.SqlMapper.ExecuteScalarAsync<int>(cn,
                "SELECT COUNT(*) FROM dbo.FactRetenciones WHERE id_retencion_bk = @bk", new { bk });
            Assert.Equal(1, existe);
        }
        finally
        {
            await using var cn = Factory().Origen();
            await Dapper.SqlMapper.ExecuteAsync(cn, "DELETE FROM dbo.FactRetenciones WHERE id_retencion_bk = @bk", new { bk });
        }
    }
}
