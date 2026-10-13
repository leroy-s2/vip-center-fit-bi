using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.OData.Query;
using Microsoft.AspNetCore.OData.Routing.Controllers;
using VipCenterFit.Api.Data;
using VipCenterFit.Api.OData;

namespace VipCenterFit.Api.Controllers;

/// <summary>
/// Endpoints OData sobre las vistas de KPIs del Data Warehouse, pensados para
/// Power BI (PBI Service puede consumirlos sin gateway). Soportan $select,
/// $filter, $orderby, $top, $skip y $count.
/// </summary>
[Route("odata")]
[Tags("OData (Power BI)")]
public sealed class ODataKpisController(KpiRepository repo) : ODataController
{
    [HttpGet("DM_Gerencia_Ingresos")]
    [EnableQuery]
    public IQueryable<GerenciaIngresosDto> GerenciaIngresos() =>
        repo.GerenciaIngresosAsync(null, null).GetAwaiter().GetResult().AsQueryable();

    [HttpGet("DM_Gerencia_Membresias")]
    [EnableQuery]
    public IQueryable<GerenciaMembresiasDto> GerenciaMembresias() =>
        repo.GerenciaMembresiasAsync(null, null).GetAwaiter().GetResult().AsQueryable();

    [HttpGet("DM_Comercial_Plan")]
    [EnableQuery]
    public IQueryable<ComercialPlanDto> ComercialPlan() =>
        repo.ComercialPlanAsync(null, null, null).GetAwaiter().GetResult().AsQueryable();

    [HttpGet("DM_Avisos_Cobertura")]
    [EnableQuery]
    public IQueryable<AvisosCoberturaDto> AvisosCobertura() =>
        repo.AvisosCoberturaAsync().GetAwaiter().GetResult().AsQueryable();

    [HttpGet("DM_Atencion_Reclamos")]
    [EnableQuery]
    public IQueryable<AtencionReclamosDto> AtencionReclamos() =>
        repo.AtencionReclamosAsync(null, null, null).GetAwaiter().GetResult().AsQueryable();

    [HttpGet("DM_Entrenamiento_Asistencia")]
    [EnableQuery]
    public IQueryable<EntrenamientoAsistenciaDto> EntrenamientoAsistencia() =>
        repo.EntrenamientoAsistenciaAsync(null, null, null).GetAwaiter().GetResult().AsQueryable();

    [HttpGet("DM_Entrenamiento_Progreso")]
    [EnableQuery]
    public IQueryable<EntrenamientoProgresoDto> EntrenamientoProgreso() =>
        repo.EntrenamientoProgresoAsync(null, null).GetAwaiter().GetResult().AsQueryable();

    [HttpGet("DM_Entrenamiento_Cumplimiento")]
    [EnableQuery]
    public IQueryable<EntrenamientoCumplimientoDto> EntrenamientoCumplimiento() =>
        repo.EntrenamientoCumplimientoAsync(null, null, null).GetAwaiter().GetResult().AsQueryable();

    [HttpGet("DM_Ventas_Gerencia")]
    [EnableQuery]
    public IQueryable<VentasGerenciaDto> VentasGerencia() =>
        repo.VentasGerenciaAsync(null, null, null).GetAwaiter().GetResult().AsQueryable();

    [HttpGet("DM_Rutinas_Entrenador")]
    [EnableQuery]
    public IQueryable<RutinasEntrenadorDto> RutinasEntrenador() =>
        repo.RutinasEntrenadorAsync(null, null, null).GetAwaiter().GetResult().AsQueryable();

    [HttpGet("DM_Atencion_Recepcion")]
    [EnableQuery]
    public IQueryable<AtencionRecepcionDto> AtencionRecepcion() =>
        repo.AtencionRecepcionAsync(null, null, null).GetAwaiter().GetResult().AsQueryable();

    [HttpGet("DM_Entrenamiento_Evaluaciones")]
    [EnableQuery]
    public IQueryable<EntrenamientoEvaluacionesDto> EntrenamientoEvaluaciones() =>
        repo.EntrenamientoEvaluacionesAsync(null, null, null).GetAwaiter().GetResult().AsQueryable();

    [HttpGet("DM_Atencion_Retencion")]
    [EnableQuery]
    public IQueryable<AtencionRetencionDto> AtencionRetencion() =>
        repo.AtencionRetencionAsync(null, null, null, null).GetAwaiter().GetResult().AsQueryable();
}
