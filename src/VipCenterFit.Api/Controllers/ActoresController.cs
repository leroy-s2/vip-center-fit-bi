using Microsoft.AspNetCore.Mvc;
using VipCenterFit.Api.Data;

namespace VipCenterFit.Api.Controllers;

/// <summary>Dashboard agregado por actor (Gerencia, Comercial, Recepción, Entrenador).</summary>
[ApiController]
[Route("api/v1/actores")]
[Tags("Dashboard por actor")]
public sealed class ActoresController(KpiRepository repo) : ControllerBase
{
    private static readonly string[] Actores = ["gerencia", "comercial", "recepcion", "entrenador"];

    [HttpGet("{actor}/dashboard")]
    public async Task<IActionResult> Dashboard(string actor, [FromQuery] int? desde, [FromQuery] int? hasta, CancellationToken ct)
    {
        switch (actor.ToLowerInvariant())
        {
            case "gerencia":
                return Ok(new
                {
                    actor = "gerencia",
                    titulo = "Crecimiento y retención",
                    ingresos = await repo.GerenciaIngresosAsync(desde, hasta, ct),
                    membresias = await repo.GerenciaMembresiasAsync(desde, hasta, ct),
                    ventas = await repo.VentasGerenciaAsync(desde, hasta, null, ct)
                });

            case "comercial":
                return Ok(new
                {
                    actor = "comercial",
                    titulo = "Planes y promociones",
                    planes = await repo.ComercialPlanAsync(desde, hasta, null, ct),
                    avisosCobertura = await repo.AvisosCoberturaAsync(ct),
                    promocionesVentas = await repo.ComercialPromocionesVentasAsync(desde, hasta, null, ct),
                    promocionesMembresias = await repo.ComercialPromocionesMembresiasAsync(desde, hasta, null, ct),
                    promocionesClientes = await repo.ComercialPromocionesClientesAsync(desde, hasta, null, ct)
                });

            case "recepcion":
                return Ok(new
                {
                    actor = "recepcion",
                    titulo = "Atención y fidelización",
                    reclamos = await repo.AtencionReclamosAsync(desde, hasta, null, ct),
                    recepcion = await repo.AtencionRecepcionAsync(desde, hasta, null, ct),
                    retencion = await repo.AtencionRetencionAsync(desde, hasta, null, null, ct)
                });

            case "entrenador":
                return Ok(new
                {
                    actor = "entrenador",
                    titulo = "Entrenamiento y progreso",
                    asistencia = await repo.EntrenamientoAsistenciaAsync(desde, hasta, null, ct),
                    progreso = await repo.EntrenamientoProgresoAsync(null, null, ct),
                    cumplimiento = await repo.EntrenamientoCumplimientoAsync(desde, hasta, null, ct),
                    rutinas = await repo.RutinasEntrenadorAsync(desde, hasta, null, ct),
                    evaluaciones = await repo.EntrenamientoEvaluacionesAsync(desde, hasta, null, ct)
                });

            default:
                return NotFound(new { error = "Actor no válido.", actores = Actores });
        }
    }
}
