using Microsoft.AspNetCore.Mvc;
using VipCenterFit.Api.Data;

namespace VipCenterFit.Api.Controllers;

/// <summary>Estado de las marcas de agua del pipeline (lag CDC y ETL).</summary>
[ApiController]
[Route("api/v1/etl")]
[Tags("Operación del pipeline")]
public sealed class EtlEstadoController(EtlRepository repo) : ControllerBase
{
    [HttpGet("estado")]
    public async Task<IActionResult> Estado(CancellationToken ct)
        => Ok(await repo.EstadoAsync(ct));
}
