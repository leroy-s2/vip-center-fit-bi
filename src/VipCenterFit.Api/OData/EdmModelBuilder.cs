using Microsoft.OData.Edm;
using Microsoft.OData.ModelBuilder;

namespace VipCenterFit.Api.OData;

/// <summary>
/// Modelo EDM de OData con un entity set por cada vista de KPI del Data Warehouse.
/// Todos comparten la clave sintética RowKey (no nula), de modo que Power BI y
/// cualquier cliente OData puedan filtrar, ordenar y paginar.
/// </summary>
public static class EdmModelBuilder
{
    public static IEdmModel Build()
    {
        var builder = new ODataConventionModelBuilder();

        AddSet<GerenciaIngresosDto>(builder, "DM_Gerencia_Ingresos");
        AddSet<GerenciaMembresiasDto>(builder, "DM_Gerencia_Membresias");
        AddSet<ComercialPlanDto>(builder, "DM_Comercial_Plan");
        AddSet<AvisosCoberturaDto>(builder, "DM_Avisos_Cobertura");
        AddSet<PromocionesVentasDto>(builder, "DM_Promociones_Ventas");
        AddSet<PromocionesMembresiasDto>(builder, "DM_Promociones_Membresias");
        AddSet<PromocionesClientesDto>(builder, "DM_Promociones_Clientes");
        AddSet<AtencionReclamosDto>(builder, "DM_Atencion_Reclamos");
        AddSet<EntrenamientoAsistenciaDto>(builder, "DM_Entrenamiento_Asistencia");
        AddSet<EntrenamientoProgresoDto>(builder, "DM_Entrenamiento_Progreso");
        AddSet<EntrenamientoCumplimientoDto>(builder, "DM_Entrenamiento_Cumplimiento");
        AddSet<VentasGerenciaDto>(builder, "DM_Ventas_Gerencia");
        AddSet<RutinasEntrenadorDto>(builder, "DM_Rutinas_Entrenador");
        AddSet<AtencionRecepcionDto>(builder, "DM_Atencion_Recepcion");
        AddSet<EntrenamientoEvaluacionesDto>(builder, "DM_Entrenamiento_Evaluaciones");
        AddSet<AtencionRetencionDto>(builder, "DM_Atencion_Retencion");

        return builder.GetEdmModel();
    }

    private static void AddSet<T>(ODataConventionModelBuilder builder, string name) where T : class, IKpiRow
    {
        var set = builder.EntitySet<T>(name);
        set.EntityType.HasKey(e => e.RowKey);
    }
}
