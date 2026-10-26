using Microsoft.Extensions.Configuration;
using VipCenterFit.Api.Data;
using VipCenterFit.Api.Models;
using Xunit;

namespace VipCenterFit.Api.Tests;

/// <summary>
/// Pruebas de integración contra el SQL Server del bootstrap (localhost:14330).
/// Requieren que las 3 bases existan (npm run db:bootstrap).
///
/// Cubren el modelo de 7 hechos: las vistas de KPI, los granos de los
/// snapshots diarios y el round-trip de escritura con las columnas nuevas.
/// </summary>
public sealed class BiPipelineTests
{
    private const string Server = "Server=localhost,14330;User Id=sa;Password=YourStrong!Passw0rd;TrustServerCertificate=True;Encrypt=False";

    static BiPipelineTests()
    {
        // Los repositorios mapean columnas snake_case a propiedades PascalCase.
        Dapper.DefaultTypeMap.MatchNamesWithUnderscores = true;
    }

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

    /* --------------------------- KPIs del DW --------------------------- */

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
        Assert.All(filas, f => Assert.False(string.IsNullOrWhiteSpace(f.RowKey)));
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
    public async Task Kpi_Entrenamiento_Accesos_devuelve_filas()
    {
        var repo = new KpiRepository(Factory());
        var filas = await repo.EntrenamientoAccesosAsync(null, null, null);
        Assert.NotEmpty(filas);
        Assert.All(filas, f => Assert.True(f.AccesosRegistrados >= f.DiasConAcceso));
    }

    [Fact]
    public async Task Kpi_Entrenamiento_BajoProgreso_sin_duplicados_de_cliente()
    {
        var repo = new KpiRepository(Factory());
        var filas = await repo.EntrenamientoBajoProgresoAsync(null);
        Assert.Equal(filas.Count, filas.Select(f => f.SkCliente).Distinct().Count());
    }

    /* --------------------- Granos de los snapshots --------------------- */

    [Fact]
    public async Task Grano_FactMembresias_sin_duplicados()
    {
        await using var cn = Factory().Dw();
        var duplicados = await Dapper.SqlMapper.ExecuteScalarAsync<int>(cn, """
            SELECT COUNT(*) FROM (
                SELECT id_membresia_bk, sk_fecha_corte
                FROM dm_comercial.FactMembresias
                GROUP BY id_membresia_bk, sk_fecha_corte
                HAVING COUNT(*) > 1
            ) x
            """);
        Assert.Equal(0, duplicados);
    }

    [Fact]
    public async Task Grano_FactSeguimientoFisico_sin_duplicados()
    {
        await using var cn = Factory().Dw();
        var duplicados = await Dapper.SqlMapper.ExecuteScalarAsync<int>(cn, """
            SELECT COUNT(*) FROM (
                SELECT sk_cliente, id_objetivo_bk, sk_fecha_corte
                FROM dm_entrenamiento.FactSeguimientoFisico
                GROUP BY sk_cliente, id_objetivo_bk, sk_fecha_corte
                HAVING COUNT(*) > 1
            ) x
            """);
        Assert.Equal(0, duplicados);
    }

    [Fact]
    public async Task Snapshot_membresias_estado_coherente_con_el_corte()
    {
        await using var cn = Factory().Dw();
        var inconsistentes = await Dapper.SqlMapper.ExecuteScalarAsync<int>(cn, """
            SELECT COUNT(*)
            FROM dm_comercial.FactMembresias fm
            INNER JOIN dim.DimFecha fc ON fc.sk_fecha = fm.sk_fecha_corte
            INNER JOIN dim.DimFecha fi ON fi.sk_fecha = fm.sk_fecha_inicio
            INNER JOIN dim.DimFecha ff ON ff.sk_fecha = fm.sk_fecha_fin
            WHERE (fm.estado_membresia = 'ACTIVA' AND (fc.fecha < fi.fecha OR fc.fecha > ff.fecha))
               OR (fm.estado_membresia = 'VENCIDA' AND fc.fecha <= ff.fecha)
            """);
        Assert.Equal(0, inconsistentes);
    }

    [Fact]
    public async Task Siete_hechos_en_los_data_marts()
    {
        await using var cn = Factory().Dw();
        var hechos = await Dapper.SqlMapper.ExecuteScalarAsync<int>(cn, """
            SELECT COUNT(*)
            FROM sys.tables t
            INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
            WHERE s.name IN ('dm_comercial', 'dm_entrenamiento', 'dm_atencion')
              AND t.name LIKE 'Fact%'
            """);
        Assert.Equal(7, hechos);
    }

    /* --------------------------- ETL --------------------------- */

    [Fact]
    public async Task Etl_estado_devuelve_marcas()
    {
        var repo = new EtlRepository(Factory());
        var estado = await repo.EstadoAsync();
        Assert.NotNull(estado);
        Assert.NotEmpty(estado.MarcasEtl);
        Assert.Contains(estado.MarcasEtl, m => m.Proceso == "snapshot_membresias");
        Assert.Contains(estado.MarcasEtl, m => m.Proceso == "snapshot_seguimiento");
    }

    /* --------------------- Escritura en ORIGEN --------------------- */

    [Fact]
    public async Task Escritura_roundtrip_cliente()
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
    public async Task Escritura_roundtrip_empleado_con_codigo()
    {
        var origen = new OrigenRepository(Factory());
        const int bk = 777005;
        try
        {
            var n = await origen.InsertEmpleadoAsync(new EmpleadoRequest(
                bk, "00077005", "Empleado Codigo", "ENTRENADOR", "ENTRENAMIENTO", "EMP-TEST-05"), default);
            Assert.Equal(1, n);

            await using var cn = Factory().Origen();
            var codigo = await Dapper.SqlMapper.ExecuteScalarAsync<string>(cn,
                "SELECT codigo_empleado FROM dbo.DimEmpleado WHERE id_empleado_bk = @bk", new { bk });
            Assert.Equal("EMP-TEST-05", codigo);
        }
        finally
        {
            await using var cn = Factory().Origen();
            await Dapper.SqlMapper.ExecuteAsync(cn, "DELETE FROM dbo.DimEmpleado WHERE id_empleado_bk = @bk", new { bk });
        }
    }

    [Fact]
    public async Task Escritura_roundtrip_objetivo_con_fecha_meta()
    {
        var origen = new OrigenRepository(Factory());
        const int bk = 777006;
        try
        {
            var n = await origen.InsertObjetivoAsync(new ObjetivoRequest(
                bk, 20260901, 1, "REDUCCION_GRASA", 90m, 80m, "KG", "ACTIVO", 20261201), default);
            Assert.Equal(1, n);

            await using var cn = Factory().Origen();
            var meta = await Dapper.SqlMapper.ExecuteScalarAsync<int>(cn,
                "SELECT sk_fecha_meta FROM dbo.FactObjetivos WHERE id_objetivo_bk = @bk", new { bk });
            Assert.Equal(20261201, meta);
        }
        finally
        {
            await using var cn = Factory().Origen();
            await Dapper.SqlMapper.ExecuteAsync(cn, "DELETE FROM dbo.FactObjetivos WHERE id_objetivo_bk = @bk", new { bk });
        }
    }

    [Fact]
    public async Task Escritura_roundtrip_sesion_programada_cancelada()
    {
        var origen = new OrigenRepository(Factory());
        const int bk = 777002;
        try
        {
            var n = await origen.InsertSesionProgramadaAsync(new SesionProgramadaRequest(
                bk, 20260901, 1, 1, 2, "ENTRENAMIENTO", 10, "CANCELADA", 60,
                new DateTime(2026, 8, 31), "REPROGRAMADA"), default);
            Assert.Equal(1, n);

            await using var cn = Factory().Origen();
            var existe = await Dapper.SqlMapper.ExecuteScalarAsync<int>(cn,
                "SELECT COUNT(*) FROM dbo.FactSesionesProgramadas WHERE id_sesion_bk = @bk AND motivo_cancelacion = 'REPROGRAMADA'",
                new { bk });
            Assert.Equal(1, existe);
        }
        finally
        {
            await using var cn = Factory().Origen();
            await Dapper.SqlMapper.ExecuteAsync(cn, "DELETE FROM dbo.FactSesionesProgramadas WHERE id_sesion_bk = @bk", new { bk });
        }
    }

    [Fact]
    public async Task Escritura_roundtrip_reclamo_con_hitos()
    {
        var origen = new OrigenRepository(Factory());
        const int bk = 777007;
        try
        {
            var n = await origen.InsertReclamoAsync(new ReclamoRequest(
                bk, 20260901, 1, 2, "SERVICIO", "PENDIENTE", null, null, null,
                null, true, "ADMINISTRACION"), default);
            Assert.Equal(1, n);

            await using var cn = Factory().Origen();
            var escalado = await Dapper.SqlMapper.ExecuteScalarAsync<bool>(cn,
                "SELECT escalado FROM dbo.FactReclamos WHERE id_reclamo_bk = @bk", new { bk });
            Assert.True(escalado);
        }
        finally
        {
            await using var cn = Factory().Origen();
            await Dapper.SqlMapper.ExecuteAsync(cn, "DELETE FROM dbo.FactReclamos WHERE id_reclamo_bk = @bk", new { bk });
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
