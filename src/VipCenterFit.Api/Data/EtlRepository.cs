using Dapper;
using VipCenterFit.Api.OData;

namespace VipCenterFit.Api.Data;

/// <summary>Estado de las marcas de agua del pipeline (observabilidad del ETL).</summary>
public sealed class EtlRepository(DbConnectionFactory factory)
{
    public async Task<EtlEstadoDto> EstadoAsync(CancellationToken ct = default)
    {
        await using var stg = factory.Stg();
        var cdc = await stg.QueryFirstOrDefaultAsync<(byte[]? lsn, DateTime? carga, long? filas)>(
            new CommandDefinition(
                "SELECT last_lsn AS lsn, ultima_carga AS carga, filas_ultima_carga AS filas FROM stg.etl_cdc_control WHERE capture_instance = 'GLOBAL'",
                cancellationToken: ct));

        await using var dw = factory.Dw();
        var marcas = await dw.QueryAsync<EtlMarcaAguaDto>(
            new CommandDefinition(
                "SELECT proceso AS Proceso, ultimo_staging_id AS UltimoStagingId, ultima_carga AS UltimaCarga, filas_ultima_carga AS FilasUltimaCarga FROM dbo.etl_control ORDER BY proceso",
                cancellationToken: ct));

        return new EtlEstadoDto(
            factory.OrigenName,
            cdc.lsn is null ? null : Convert.ToHexString(cdc.lsn),
            cdc.carga,
            cdc.filas,
            marcas.AsList());
    }
}
