using Microsoft.AspNetCore.Mvc;
using VipCenterFit.Api.Data;

namespace VipCenterFit.Api.Controllers;

/// <summary>
/// Lectura de KPIs del Data Warehouse (modelo de 7 hechos, 3 data marts),
/// agrupada por actor del negocio.
/// </summary>
[ApiController]
[Route("api/v1/kpis")]
public sealed class KpisController(KpiRepository repo) : ControllerBase
{
    [HttpGet("gerencia/ingresos")]
    [Tags("KPI - Gerencia General")]
    public async Task<IActionResult> Ingresos([FromQuery] int? desde, [FromQuery] int? hasta, CancellationToken ct)
        => Ok(await repo.GerenciaIngresosAsync(desde, hasta, ct));

    [HttpGet("gerencia/membresias")]
    [Tags("KPI - Gerencia General")]
    public async Task<IActionResult> Membresias([FromQuery] int? desde, [FromQuery] int? hasta, CancellationToken ct)
        => Ok(await repo.GerenciaMembresiasAsync(desde, hasta, ct));

    [HttpGet("comercial/planes")]
    [Tags("KPI - Administración y Comercial")]
    public async Task<IActionResult> Planes([FromQuery] int? desde, [FromQuery] int? hasta, [FromQuery] string? plan, CancellationToken ct)
        => Ok(await repo.ComercialPlanAsync(desde, hasta, plan, ct));

    [HttpGet("comercial/promociones")]
    [Tags("KPI - Administración y Comercial")]
    public async Task<IActionResult> Promociones([FromQuery] int? desde, [FromQuery] int? hasta, [FromQuery] string? promocion, CancellationToken ct)
        => Ok(await repo.ComercialPromocionesAsync(desde, hasta, promocion, ct));

    [HttpGet("comercial/avisos-cobertura")]
    [Tags("KPI - Administración y Comercial")]
    public async Task<IActionResult> AvisosCobertura(CancellationToken ct)
        => Ok(await repo.AvisosCoberturaAsync(ct));

    [HttpGet("atencion/reclamos")]
    [Tags("KPI - Recepción")]
    public async Task<IActionResult> Reclamos([FromQuery] int? desde, [FromQuery] int? hasta, [FromQuery] string? categoria, CancellationToken ct)
        => Ok(await repo.AtencionReclamosAsync(desde, hasta, categoria, ct));

    [HttpGet("atencion/recepcion")]
    [Tags("KPI - Recepción")]
    public async Task<IActionResult> Recepcion([FromQuery] int? desde, [FromQuery] int? hasta, [FromQuery] string? categoria, CancellationToken ct)
        => Ok(await repo.AtencionRecepcionAsync(desde, hasta, categoria, ct));

    [HttpGet("atencion/retencion")]
    [Tags("KPI - Recepción")]
    public async Task<IActionResult> Retencion([FromQuery] int? desde, [FromQuery] int? hasta, [FromQuery] string? canal, [FromQuery] int? skCliente, CancellationToken ct)
        => Ok(await repo.AtencionRetencionAsync(desde, hasta, canal, skCliente, ct));

    [HttpGet("entrenamiento/asistencia")]
    [Tags("KPI - Entrenador")]
    public async Task<IActionResult> Asistencia([FromQuery] int? desde, [FromQuery] int? hasta, [FromQuery] int? skCliente, CancellationToken ct)
        => Ok(await repo.EntrenamientoAsistenciaAsync(desde, hasta, skCliente, ct));

    [HttpGet("entrenamiento/accesos")]
    [Tags("KPI - Entrenador")]
    public async Task<IActionResult> Accesos([FromQuery] int? desde, [FromQuery] int? hasta, [FromQuery] int? skCliente, CancellationToken ct)
        => Ok(await repo.EntrenamientoAccesosAsync(desde, hasta, skCliente, ct));

    [HttpGet("entrenamiento/progreso")]
    [Tags("KPI - Entrenador")]
    public async Task<IActionResult> Progreso([FromQuery] int? skCliente, [FromQuery] string? tipoObjetivo, CancellationToken ct)
        => Ok(await repo.EntrenamientoProgresoAsync(skCliente, tipoObjetivo, ct));

    [HttpGet("entrenamiento/bajo-progreso")]
    [Tags("KPI - Entrenador")]
    public async Task<IActionResult> BajoProgreso([FromQuery] int? skCliente, CancellationToken ct)
        => Ok(await repo.EntrenamientoBajoProgresoAsync(skCliente, ct));

    [HttpGet("entrenamiento/evaluaciones")]
    [Tags("KPI - Entrenador")]
    public async Task<IActionResult> Evaluaciones([FromQuery] int? desde, [FromQuery] int? hasta, [FromQuery] int? skCliente, CancellationToken ct)
        => Ok(await repo.EntrenamientoEvaluacionesAsync(desde, hasta, skCliente, ct));

    [HttpGet("entrenamiento/rutinas")]
    [Tags("KPI - Entrenador")]
    public async Task<IActionResult> Rutinas([FromQuery] int? desde, [FromQuery] int? hasta, [FromQuery] string? entrenador, CancellationToken ct)
        => Ok(await repo.RutinasEntrenadorAsync(desde, hasta, entrenador, ct));
}
