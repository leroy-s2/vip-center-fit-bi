using Microsoft.AspNetCore.Mvc;
using VipCenterFit.Api.Data;
using VipCenterFit.Api.Models;

namespace VipCenterFit.Api.Controllers;

/// <summary>
/// Escritura transaccional en ORIGEN. Estos endpoints son los que golpea JMeter
/// para simular la operación del gimnasio; CDC captura cada cambio.
/// </summary>
[ApiController]
[Route("api/v1")]
[Tags("Escritura (ORIGEN)")]
public sealed class EscrituraController(OrigenRepository repo) : ControllerBase
{
    private static IActionResult Bad(string msg) => new BadRequestObjectResult(new { error = msg });

    [HttpPost("clientes")]
    public async Task<IActionResult> PostCliente([FromBody] ClienteRequest r, CancellationToken ct)
    {
        if (r.IdClienteBk is null) return Bad("idClienteBk es obligatorio.");
        if (string.IsNullOrWhiteSpace(r.NombreCompleto)) return Bad("nombreCompleto es obligatorio.");
        var n = await repo.InsertClienteAsync(r, ct);
        return Ok(new { entidad = "DimCliente", filasInsertadas = n, idClienteBk = r.IdClienteBk });
    }

    [HttpPost("empleados")]
    public async Task<IActionResult> PostEmpleado([FromBody] EmpleadoRequest r, CancellationToken ct)
    {
        if (r.IdEmpleadoBk is null) return Bad("idEmpleadoBk es obligatorio.");
        if (string.IsNullOrWhiteSpace(r.NombreCompleto)) return Bad("nombreCompleto es obligatorio.");
        var n = await repo.InsertEmpleadoAsync(r, ct);
        return Ok(new { entidad = "DimEmpleado", filasInsertadas = n, idEmpleadoBk = r.IdEmpleadoBk });
    }

    [HttpPost("membresias")]
    public async Task<IActionResult> PostMembresia([FromBody] MembresiaRequest r, CancellationToken ct)
    {
        if (r.IdMembresiaBk is null) return Bad("idMembresiaBk es obligatorio.");
        if (r.SkCliente is null || r.SkPlan is null) return Bad("skCliente y skPlan son obligatorios.");
        var n = await repo.InsertMembresiaAsync(r, ct);
        return Ok(new { entidad = "FactMembresias", filasInsertadas = n, idMembresiaBk = r.IdMembresiaBk });
    }

    [HttpPost("ventas")]
    public async Task<IActionResult> PostVenta([FromBody] VentaRequest r, CancellationToken ct)
    {
        if (r.IdPagoBk is null) return Bad("idPagoBk es obligatorio.");
        if (r.SkCliente is null || r.SkPlan is null) return Bad("skCliente y skPlan son obligatorios.");
        var n = await repo.InsertVentaAsync(r, ct);
        return Ok(new { entidad = "FactVentas", filasInsertadas = n, idPagoBk = r.IdPagoBk });
    }

    [HttpPost("renovaciones")]
    public async Task<IActionResult> PostRenovacion([FromBody] RenovacionRequest r, CancellationToken ct)
    {
        if (r.IdRenovacionBk is null) return Bad("idRenovacionBk es obligatorio.");
        if (r.SkCliente is null) return Bad("skCliente es obligatorio.");
        var n = await repo.InsertRenovacionAsync(r, ct);
        return Ok(new { entidad = "FactRenovaciones", filasInsertadas = n, idRenovacionBk = r.IdRenovacionBk });
    }

    [HttpPost("avisos")]
    public async Task<IActionResult> PostAviso([FromBody] AvisoRequest r, CancellationToken ct)
    {
        if (r.IdAvisoBk is null) return Bad("idAvisoBk es obligatorio.");
        if (r.SkCliente is null) return Bad("skCliente es obligatorio.");
        var n = await repo.InsertAvisoAsync(r, ct);
        return Ok(new { entidad = "FactAvisos", filasInsertadas = n, idAvisoBk = r.IdAvisoBk });
    }

    [HttpPost("asistencias")]
    public async Task<IActionResult> PostAsistencia([FromBody] AsistenciaRequest r, CancellationToken ct)
    {
        if (r.IdAsistenciaBk is null) return Bad("idAsistenciaBk es obligatorio.");
        if (r.SkCliente is null) return Bad("skCliente es obligatorio.");
        var n = await repo.InsertAsistenciaAsync(r, ct);
        return Ok(new { entidad = "FactAsistencias", filasInsertadas = n, idAsistenciaBk = r.IdAsistenciaBk });
    }

    [HttpPost("objetivos")]
    public async Task<IActionResult> PostObjetivo([FromBody] ObjetivoRequest r, CancellationToken ct)
    {
        if (r.IdObjetivoBk is null) return Bad("idObjetivoBk es obligatorio.");
        if (r.SkCliente is null) return Bad("skCliente es obligatorio.");
        var n = await repo.InsertObjetivoAsync(r, ct);
        return Ok(new { entidad = "FactObjetivos", filasInsertadas = n, idObjetivoBk = r.IdObjetivoBk });
    }

    [HttpPost("evaluaciones")]
    public async Task<IActionResult> PostEvaluacion([FromBody] EvaluacionRequest r, CancellationToken ct)
    {
        if (r.IdEvaluacionBk is null) return Bad("idEvaluacionBk es obligatorio.");
        if (r.SkCliente is null) return Bad("skCliente es obligatorio.");
        var n = await repo.InsertEvaluacionAsync(r, ct);
        return Ok(new { entidad = "FactEvaluaciones", filasInsertadas = n, idEvaluacionBk = r.IdEvaluacionBk });
    }

    [HttpPost("reclamos")]
    public async Task<IActionResult> PostReclamo([FromBody] ReclamoRequest r, CancellationToken ct)
    {
        if (r.IdReclamoBk is null) return Bad("idReclamoBk es obligatorio.");
        if (r.SkCliente is null) return Bad("skCliente es obligatorio.");
        var n = await repo.InsertReclamoAsync(r, ct);
        return Ok(new { entidad = "FactReclamos", filasInsertadas = n, idReclamoBk = r.IdReclamoBk });
    }

    [HttpPost("sesiones-programadas")]
    public async Task<IActionResult> PostSesionProgramada([FromBody] SesionProgramadaRequest r, CancellationToken ct)
    {
        if (r.IdSesionBk is null) return Bad("idSesionBk es obligatorio.");
        if (r.SkCliente is null) return Bad("skCliente es obligatorio.");
        var n = await repo.InsertSesionProgramadaAsync(r, ct);
        return Ok(new { entidad = "FactSesionesProgramadas", filasInsertadas = n, idSesionBk = r.IdSesionBk });
    }

    [HttpPost("evaluaciones-programadas")]
    public async Task<IActionResult> PostEvaluacionProgramada([FromBody] EvaluacionProgramadaRequest r, CancellationToken ct)
    {
        if (r.IdEvaluacionProgramadaBk is null) return Bad("idEvaluacionProgramadaBk es obligatorio.");
        if (r.SkCliente is null) return Bad("skCliente es obligatorio.");
        var n = await repo.InsertEvaluacionProgramadaAsync(r, ct);
        return Ok(new { entidad = "FactEvaluacionesProgramadas", filasInsertadas = n, idEvaluacionProgramadaBk = r.IdEvaluacionProgramadaBk });
    }

    [HttpPost("retenciones")]
    public async Task<IActionResult> PostRetencion([FromBody] RetencionRequest r, CancellationToken ct)
    {
        if (r.IdRetencionBk is null) return Bad("idRetencionBk es obligatorio.");
        if (r.SkCliente is null) return Bad("skCliente es obligatorio.");
        var n = await repo.InsertRetencionAsync(r, ct);
        return Ok(new { entidad = "FactRetenciones", filasInsertadas = n, idRetencionBk = r.IdRetencionBk });
    }
}
