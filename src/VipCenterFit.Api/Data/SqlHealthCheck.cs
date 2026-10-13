using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace VipCenterFit.Api.Data;

/// <summary>Health check de disponibilidad de SQL Server (usa la base Origen).</summary>
public sealed class SqlHealthCheck(DbConnectionFactory factory) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context, CancellationToken cancellationToken = default)
    {
        try
        {
            await using var cn = factory.Origen();
            await cn.OpenAsync(cancellationToken);
            await using var cmd = cn.CreateCommand();
            cmd.CommandText = "SELECT 1";
            await cmd.ExecuteScalarAsync(cancellationToken);
            return HealthCheckResult.Healthy("SQL Server responde.");
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy("SQL Server no responde.", ex);
        }
    }
}
