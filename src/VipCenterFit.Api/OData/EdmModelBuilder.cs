using Microsoft.OData.Edm;
using Microsoft.OData.ModelBuilder;

namespace VipCenterFit.Api.OData;

/// <summary>
/// Modelo EDM de OData con dos familias de entity sets:
///   1) las vistas de KPI agregadas (dbo.DM_*), y
///   2) el modelo en estrella (4 dimensiones + 7 hechos) para que Power BI
///      importe el DW y construya las relaciones por las claves sk_*.
/// Todos los DTOs comparten la clave sintética RowKey (no nula).
/// </summary>
public static class EdmModelBuilder
{
    public static IEdmModel Build()
    {
        var builder = new ODataConventionModelBuilder();

        /* 1. Vistas de KPIs. */
        AddSet<GerenciaIngresosDto>(builder, "DM_Gerencia_Ingresos");
        AddSet<GerenciaMembresiasDto>(builder, "DM_Gerencia_Membresias");
        AddSet<ComercialPlanDto>(builder, "DM_Comercial_Plan");
        AddSet<ComercialPromocionesDto>(builder, "DM_Comercial_Promociones");
        AddSet<AvisosCoberturaDto>(builder, "DM_Avisos_Cobertura");
        AddSet<AtencionReclamosDto>(builder, "DM_Atencion_Reclamos");
        AddSet<AtencionRecepcionDto>(builder, "DM_Atencion_Recepcion");
        AddSet<AtencionRetencionDto>(builder, "DM_Atencion_Retencion");
        AddSet<EntrenamientoAsistenciaDto>(builder, "DM_Entrenamiento_Asistencia");
        AddSet<EntrenamientoAccesosDto>(builder, "DM_Entrenamiento_Accesos");
        AddSet<EntrenamientoProgresoDto>(builder, "DM_Entrenamiento_Progreso");
        AddSet<EntrenamientoBajoProgresoDto>(builder, "DM_Entrenamiento_BajoProgreso");
        AddSet<EntrenamientoEvaluacionesDto>(builder, "DM_Entrenamiento_Evaluaciones");
        AddSet<RutinasEntrenadorDto>(builder, "DM_Rutinas_Entrenador");

        /* 2. Modelo en estrella (dimensiones). */
        AddSet<DimFechaDto>(builder, "DimFecha");
        AddSet<DimClienteDto>(builder, "DimCliente");
        AddSet<DimEmpleadoDto>(builder, "DimEmpleado");
        AddSet<DimPlanDto>(builder, "DimPlan");

        /* 2. Modelo en estrella (hechos). Requieren ventana fechaDesde/fechaHasta. */
        AddSet<FactVentasDto>(builder, "FactVentas");
        AddSet<FactMembresiasDto>(builder, "FactMembresias");
        AddSet<FactAsistenciasDto>(builder, "FactAsistencias");
        AddSet<FactSesionesEntrenamientoDto>(builder, "FactSesionesEntrenamiento");
        AddSet<FactSeguimientoFisicoDto>(builder, "FactSeguimientoFisico");
        AddSet<FactReclamosDto>(builder, "FactReclamos");
        AddSet<FactRetencionesDto>(builder, "FactRetenciones");

        return builder.GetEdmModel();
    }

    private static void AddSet<T>(ODataConventionModelBuilder builder, string name) where T : class, IKpiRow
    {
        var set = builder.EntitySet<T>(name);
        set.EntityType.HasKey(e => e.RowKey);
    }
}
