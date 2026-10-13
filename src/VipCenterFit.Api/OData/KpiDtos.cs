namespace VipCenterFit.Api.OData;

/*
  DTOs de las vistas de KPIs del Data Warehouse. Se usan tanto en los endpoints
  REST (/api/v1/kpis/...) como en los entity sets OData (/odata/...).

  RowKey: clave sintética no nula (calculada en SQL con CONCAT_WS) para que OData
  siempre tenga una clave válida, ya que varias vistas no tienen clave natural.
*/

/// <summary>Entidad de KPI con clave sintética para OData.</summary>
public interface IKpiRow
{
    string RowKey { get; }
}

public record GerenciaIngresosDto(
    string RowKey, int Anio, int MesNumero, string Mes,
    decimal IngresosPeriodoActual, decimal? IngresosPeriodoAnterior,
    int CantidadVentas, decimal? TasaCrecimientoIngresos) : IKpiRow;

public record GerenciaMembresiasDto(
    string RowKey, int Anio, int MesNumero, string Mes,
    int ClientesActivosInicio, int ClientesInicioActivosCierre, decimal? TasaRetencionClientes,
    int MembresiasActivas, int MembresiasVencenPeriodo, int MembresiasCohorteRenovadas,
    decimal? TasaRenovacionMembresias) : IKpiRow;

public record ComercialPlanDto(
    string RowKey, int Anio, int MesNumero, string Mes, string TipoPlan,
    decimal IngresosPorTipoPlan, int VentasPorPlan, int MembresiasVendidas,
    int MembresiasVencen, int MembresiasRenovadas, decimal? TasaRenovacionPorPlan) : IKpiRow;

public record AvisosCoberturaDto(
    string RowKey, DateTime FechaCorte, int MembresiasProximasVencer,
    int AvisosRenovacionEmitidos, decimal? TasaCoberturaAvisos) : IKpiRow;

public record AtencionReclamosDto(
    string RowKey, int Anio, int MesNumero, string Mes, string CategoriaAtencion,
    int ReclamosRegistrados, int ReclamosResueltosSegunEstado, int ReclamosPendientes,
    decimal? TasaResolucionSegunEstado, int ReclamosResueltosMostrador,
    decimal? TasaResolucionDirectaMostrador, decimal? PromedioDiasResolucion) : IKpiRow;

public record EntrenamientoAsistenciaDto(
    string RowKey, int Anio, int MesNumero, string Mes, int SkCliente, int? IdClienteBk,
    string Cliente, int SesionesAsistidasRegistradas, int SesionesProgramadas,
    decimal? TasaAsistencia) : IKpiRow;

public record EntrenamientoEvaluacionesDto(
    string RowKey, int Anio, int MesNumero, string Mes, int SkCliente, int? IdClienteBk,
    string Cliente, int EvaluacionesProgramadas, int EvaluacionesCompletadas,
    int EvaluacionesPendientes, decimal? TasaCumplimientoEvaluaciones) : IKpiRow;

public record AtencionRetencionDto(
    string RowKey, int Anio, int MesNumero, string Mes, int SkCliente, int? IdClienteBk,
    string Cliente, string Canal, int AccionesRetencion, int ClientesRetenidos,
    decimal? TasaExitoRetencion) : IKpiRow;

public record EntrenamientoProgresoDto(
    string RowKey, int SkCliente, int? IdClienteBk, string Cliente, int? IdObjetivoBk,
    string TipoObjetivo, string UnidadMedida, decimal? ValorInicialObjetivo,
    decimal? ValorActualObjetivo, decimal? ValorObjetivo, decimal? AvanceAlcanzado,
    decimal? AvanceEsperado, decimal? PorcentajeProgreso, DateTime? FechaUltimaEvaluacion,
    int? TieneBajoProgreso) : IKpiRow;

public record EntrenamientoCumplimientoDto(
    string RowKey, int Anio, int MesNumero, string Mes, string TipoObjetivo,
    int ObjetivosRegistrados, int ObjetivosConProgreso, int ObjetivosCumplidos,
    decimal? TasaCumplimientoObjetivos, decimal? PromedioPorcentajeProgreso) : IKpiRow;

public record VentasGerenciaDto(
    string RowKey, int Anio, int Trimestre, int MesNumero, string Mes, string Membresia,
    decimal TotalIngresos, int CantidadVentas) : IKpiRow;

public record RutinasEntrenadorDto(
    string RowKey, int Anio, int MesNumero, string Mes, string? RangoEtarioCliente,
    string? NombreEntrenador, string? TipoPlan, int TotalAsistencias) : IKpiRow;

public record AtencionRecepcionDto(
    string RowKey, int Anio, int MesNumero, string PeriodoMes, string? Sexo,
    string? RangoEtario, string Cliente, string CategoriaAtencion,
    string EstadoAtencion, int TotalAtenciones) : IKpiRow;

public record EtlEstadoDto(
    string Origen, string? UltimoLsnCdc, DateTime? UltimaCargaCdc, long? FilasUltimaCargaCdc,
    List<EtlMarcaAguaDto> MarcasEtl);

public record EtlMarcaAguaDto(
    string Proceso, long UltimoStagingId, DateTime? UltimaCarga, long? FilasUltimaCarga);
