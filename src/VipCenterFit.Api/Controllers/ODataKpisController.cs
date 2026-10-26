using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.OData.Query;
using Microsoft.AspNetCore.OData.Routing.Controllers;
using VipCenterFit.Api.Data;
using VipCenterFit.Api.OData;

namespace VipCenterFit.Api.Controllers;

/// <summary>
/// Endpoints OData del Data Warehouse, pensados para Power BI (PBI Service puede
/// consumirlos sin gateway). Soportan $select, $filter, $orderby, $top, $skip y $count.
///
/// Dos familias:
///   - DM_*            vistas de KPI agregadas (medidas de estado ya resueltas al corte)
///   - Dim* / Fact*    modelo en estrella para importar y relacionar en Power BI
///
/// Los hechos exigen la ventana fechaDesde/fechaHasta (se aplica en SQL). Si se
/// omite, el repositorio usa el último año.
/// </summary>
[Route("odata")]
[Tags("OData (Power BI)")]
public sealed class ODataKpisController(KpiRepository repo) : ODataController
{
    /* --------------------------- Vistas de KPIs --------------------------- */

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

    [HttpGet("DM_Comercial_Promociones")]
    [EnableQuery]
    public IQueryable<ComercialPromocionesDto> ComercialPromociones() =>
        repo.ComercialPromocionesAsync(null, null, null).GetAwaiter().GetResult().AsQueryable();

    [HttpGet("DM_Avisos_Cobertura")]
    [EnableQuery]
    public IQueryable<AvisosCoberturaDto> AvisosCobertura() =>
        repo.AvisosCoberturaAsync().GetAwaiter().GetResult().AsQueryable();

    [HttpGet("DM_Atencion_Reclamos")]
    [EnableQuery]
    public IQueryable<AtencionReclamosDto> AtencionReclamos() =>
        repo.AtencionReclamosAsync(null, null, null).GetAwaiter().GetResult().AsQueryable();

    [HttpGet("DM_Atencion_Recepcion")]
    [EnableQuery]
    public IQueryable<AtencionRecepcionDto> AtencionRecepcion() =>
        repo.AtencionRecepcionAsync(null, null, null).GetAwaiter().GetResult().AsQueryable();

    [HttpGet("DM_Atencion_Retencion")]
    [EnableQuery]
    public IQueryable<AtencionRetencionDto> AtencionRetencion() =>
        repo.AtencionRetencionAsync(null, null, null, null).GetAwaiter().GetResult().AsQueryable();

    [HttpGet("DM_Entrenamiento_Asistencia")]
    [EnableQuery]
    public IQueryable<EntrenamientoAsistenciaDto> EntrenamientoAsistencia() =>
        repo.EntrenamientoAsistenciaAsync(null, null, null).GetAwaiter().GetResult().AsQueryable();

    [HttpGet("DM_Entrenamiento_Accesos")]
    [EnableQuery]
    public IQueryable<EntrenamientoAccesosDto> EntrenamientoAccesos() =>
        repo.EntrenamientoAccesosAsync(null, null, null).GetAwaiter().GetResult().AsQueryable();

    [HttpGet("DM_Entrenamiento_Progreso")]
    [EnableQuery]
    public IQueryable<EntrenamientoProgresoDto> EntrenamientoProgreso() =>
        repo.EntrenamientoProgresoAsync(null, null).GetAwaiter().GetResult().AsQueryable();

    [HttpGet("DM_Entrenamiento_BajoProgreso")]
    [EnableQuery]
    public IQueryable<EntrenamientoBajoProgresoDto> EntrenamientoBajoProgreso() =>
        repo.EntrenamientoBajoProgresoAsync(null).GetAwaiter().GetResult().AsQueryable();

    [HttpGet("DM_Entrenamiento_Evaluaciones")]
    [EnableQuery]
    public IQueryable<EntrenamientoEvaluacionesDto> EntrenamientoEvaluaciones() =>
        repo.EntrenamientoEvaluacionesAsync(null, null, null).GetAwaiter().GetResult().AsQueryable();

    [HttpGet("DM_Rutinas_Entrenador")]
    [EnableQuery]
    public IQueryable<RutinasEntrenadorDto> RutinasEntrenador() =>
        repo.RutinasEntrenadorAsync(null, null, null).GetAwaiter().GetResult().AsQueryable();

    /* --------------------- Modelo en estrella: dimensiones --------------------- */

    [HttpGet("DimFecha")]
    [EnableQuery]
    public IQueryable<DimFechaDto> DimFecha() =>
        repo.DimFechaAsync().GetAwaiter().GetResult().AsQueryable();

    [HttpGet("DimCliente")]
    [EnableQuery]
    public IQueryable<DimClienteDto> DimCliente() =>
        repo.DimClienteAsync().GetAwaiter().GetResult().AsQueryable();

    [HttpGet("DimEmpleado")]
    [EnableQuery]
    public IQueryable<DimEmpleadoDto> DimEmpleado() =>
        repo.DimEmpleadoAsync().GetAwaiter().GetResult().AsQueryable();

    [HttpGet("DimPlan")]
    [EnableQuery]
    public IQueryable<DimPlanDto> DimPlan() =>
        repo.DimPlanAsync().GetAwaiter().GetResult().AsQueryable();

    /* ---------------------- Modelo en estrella: hechos ---------------------- */

    [HttpGet("FactVentas")]
    [EnableQuery]
    public IQueryable<FactVentasDto> FactVentas([FromQuery] DateTime? fechaDesde, [FromQuery] DateTime? fechaHasta) =>
        repo.FactVentasAsync(fechaDesde, fechaHasta).GetAwaiter().GetResult().AsQueryable();

    [HttpGet("FactMembresias")]
    [EnableQuery]
    public IQueryable<FactMembresiasDto> FactMembresias([FromQuery] DateTime? fechaDesde, [FromQuery] DateTime? fechaHasta) =>
        repo.FactMembresiasAsync(fechaDesde, fechaHasta).GetAwaiter().GetResult().AsQueryable();

    [HttpGet("FactAsistencias")]
    [EnableQuery]
    public IQueryable<FactAsistenciasDto> FactAsistencias([FromQuery] DateTime? fechaDesde, [FromQuery] DateTime? fechaHasta) =>
        repo.FactAsistenciasAsync(fechaDesde, fechaHasta).GetAwaiter().GetResult().AsQueryable();

    [HttpGet("FactSesionesEntrenamiento")]
    [EnableQuery]
    public IQueryable<FactSesionesEntrenamientoDto> FactSesionesEntrenamiento([FromQuery] DateTime? fechaDesde, [FromQuery] DateTime? fechaHasta) =>
        repo.FactSesionesEntrenamientoAsync(fechaDesde, fechaHasta).GetAwaiter().GetResult().AsQueryable();

    [HttpGet("FactSeguimientoFisico")]
    [EnableQuery]
    public IQueryable<FactSeguimientoFisicoDto> FactSeguimientoFisico([FromQuery] DateTime? fechaDesde, [FromQuery] DateTime? fechaHasta) =>
        repo.FactSeguimientoFisicoAsync(fechaDesde, fechaHasta).GetAwaiter().GetResult().AsQueryable();

    [HttpGet("FactReclamos")]
    [EnableQuery]
    public IQueryable<FactReclamosDto> FactReclamos([FromQuery] DateTime? fechaDesde, [FromQuery] DateTime? fechaHasta) =>
        repo.FactReclamosAsync(fechaDesde, fechaHasta).GetAwaiter().GetResult().AsQueryable();

    [HttpGet("FactRetenciones")]
    [EnableQuery]
    public IQueryable<FactRetencionesDto> FactRetenciones([FromQuery] DateTime? fechaDesde, [FromQuery] DateTime? fechaHasta) =>
        repo.FactRetencionesAsync(fechaDesde, fechaHasta).GetAwaiter().GetResult().AsQueryable();
}
