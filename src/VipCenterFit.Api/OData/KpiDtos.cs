namespace VipCenterFit.Api.OData;

/*
  DTOs del Data Warehouse (modelo de 7 hechos).

  - Sección 1: vistas de KPIs (dbo.DM_*). Se usan en REST (/api/v1/kpis/...)
    y en los entity sets OData agregados.
  - Sección 2: modelo en estrella (4 dimensiones + 7 hechos) que Power BI puede
    importar por OData y relacionar por las claves sk_*.

  RowKey: clave sintética no nula (calculada en SQL con CONCAT_WS) para que
  OData siempre tenga una clave válida, ya que las vistas y los hechos no
  tienen una clave natural simple.
*/

/// <summary>Entidad de KPI con clave sintética para OData.</summary>
public interface IKpiRow
{
    string RowKey { get; }
}

/* ============================ 1. VISTAS DE KPIs ============================ */

public record GerenciaIngresosDto(
    string RowKey, int Anio, int MesNumero, string Mes,
    decimal IngresosPeriodoActual, decimal? IngresosPeriodoAnterior,
    int CantidadVentas, decimal? TasaCrecimientoIngresos) : IKpiRow;

public record GerenciaMembresiasDto(
    string RowKey, int Anio, int MesNumero, string Mes, int SkFechaCorteCierre,
    int ClientesActivosInicio, int ClientesInicioActivosCierre, decimal? TasaRetencionClientes,
    int MembresiasActivas, int MembresiasVencenPeriodo, int MembresiasCohorteRenovadas,
    decimal? TasaRenovacionMembresias) : IKpiRow;

public record ComercialPlanDto(
    string RowKey, int Anio, int MesNumero, string Mes, string TipoPlan,
    decimal IngresosPorTipoPlan, int VentasPorPlan, int MembresiasVendidas,
    int MembresiasVencen, int MembresiasRenovadas, decimal? TasaRenovacionPorPlan) : IKpiRow;

public record ComercialPromocionesDto(
    string RowKey, int Anio, int MesNumero, string Mes, string TipoPlan, string Promocion,
    decimal IngresosPorPromocion, int VentasPorPromocion, decimal? DescuentoOtorgado,
    int MembresiasVendidas, int ClientesCaptados) : IKpiRow;

public record AvisosCoberturaDto(
    string RowKey, DateTime FechaCorte, int MembresiasProximasVencer,
    int MembresiasConAviso, int AvisosEmitidosDia, decimal? TasaCoberturaAvisos) : IKpiRow;

public record AtencionReclamosDto(
    string RowKey, int Anio, int MesNumero, string Mes, string CategoriaAtencion,
    int ReclamosRegistrados, int ReclamosResueltosSegunEstado, int ReclamosPendientes,
    decimal? TasaResolucionSegunEstado, int ReclamosResueltosMostrador,
    decimal? TasaResolucionDirectaMostrador, int ReclamosEscalados,
    decimal? PromedioDiasResolucion) : IKpiRow;

public record AtencionRetencionDto(
    string RowKey, int Anio, int MesNumero, string Mes, int SkCliente, int? IdClienteBk,
    string Cliente, string Canal, int AccionesRetencion,
    int MembresiasNoRenovadasAtendidas, int MembresiasRecuperadas,
    decimal? TasaExitoRetencion) : IKpiRow;

public record AtencionRecepcionDto(
    string RowKey, int Anio, int MesNumero, string PeriodoMes, string? Sexo,
    string? RangoEtario, string Cliente, string CategoriaAtencion,
    string EstadoAtencion, int TotalAtenciones) : IKpiRow;

public record EntrenamientoAsistenciaDto(
    string RowKey, int Anio, int MesNumero, string Mes, int SkCliente, int? IdClienteBk,
    string Cliente, int SesionesProgramadas, int SesionesAsistidasRegistradas,
    decimal? TasaAsistencia) : IKpiRow;

public record EntrenamientoAccesosDto(
    string RowKey, int Anio, int MesNumero, string Mes, int SkCliente, int? IdClienteBk,
    string Cliente, int AccesosRegistrados, int DiasConAcceso) : IKpiRow;

public record EntrenamientoProgresoDto(
    string RowKey, int SkCliente, int? IdClienteBk, string Cliente, int IdObjetivoBk,
    DateTime FechaCorte, string TipoObjetivo, string UnidadMedida, string EstadoObjetivo,
    decimal? ValorInicialObjetivo, decimal? ValorActualObjetivo, decimal? ValorEsperado,
    decimal? AvanceAlcanzado, decimal? AvanceEsperado, decimal? PorcentajeProgreso,
    int? TieneBajoProgreso, bool EvaluacionExigible, bool EvaluacionCompletada,
    bool EvaluacionPendiente) : IKpiRow;

public record EntrenamientoBajoProgresoDto(
    string RowKey, int SkCliente, int? IdClienteBk, string Cliente, DateTime FechaCorte,
    int ObjetivosEvaluados, int ObjetivosBajoProgreso) : IKpiRow;

public record EntrenamientoEvaluacionesDto(
    string RowKey, int Anio, int MesNumero, string Mes, int SkCliente, int? IdClienteBk,
    string Cliente, int EvaluacionesExigibles, int EvaluacionesCompletadas,
    int EvaluacionesPendientes, decimal? TasaCumplimientoEvaluaciones) : IKpiRow;

public record RutinasEntrenadorDto(
    string RowKey, int Anio, int MesNumero, string Mes, string? RangoEtarioCliente,
    string? CodigoEmpleado, string? NombreEntrenador, string? Area, string? TipoPlan,
    int TotalAsistencias) : IKpiRow;

public record EtlEstadoDto(
    string Origen, string? UltimoLsnCdc, DateTime? UltimaCargaCdc, long? FilasUltimaCargaCdc,
    List<EtlMarcaAguaDto> MarcasEtl);

public record EtlMarcaAguaDto(
    string Proceso, long UltimoStagingId, DateTime? UltimaCarga, long? FilasUltimaCarga);

/* ===================== 2. MODELO EN ESTRELLA PARA POWER BI ===================== */

/* Dimensiones. La clave de OData es RowKey; las claves reales sk_* viajan como
   columnas para que Power BI construya las relaciones del modelo. */

public record DimFechaDto(
    string RowKey, int SkFecha, DateTime Fecha, int Anio, int Trimestre, int Semestre,
    int Mes, string NombreMes, int Dia, string DiaSemana, bool EsFinDeSemana) : IKpiRow;

public record DimClienteDto(
    string RowKey, int SkCliente, int? SkClienteOrigen, int IdClienteBk, string? Dni,
    string NombreCompleto, string Sexo, string? RangoEtario, string EstadoCliente,
    DateTime? FechaRegistroOrigen, DateTime? FechaInicioValidez, DateTime? FechaFinValidez,
    bool EsActual) : IKpiRow;

public record DimEmpleadoDto(
    string RowKey, int SkEmpleado, int? SkEmpleadoOrigen, int IdEmpleadoBk,
    string CodigoEmpleado, string? Dni, string NombreCompleto, string Cargo,
    string Area) : IKpiRow;

public record DimPlanDto(
    string RowKey, int SkPlan, string TipoPlan, string TipoOperacion, string Promocion) : IKpiRow;

/* Hechos. */

public record FactVentasDto(
    string RowKey, long SkVenta, int IdPagoBk, int SkFechaPago, int SkCliente, int SkPlan,
    int SkEmpleado, int? IdMembresiaBk, decimal MontoNeto, decimal? DescuentoAplicado,
    decimal? PrecioLista, string MetodoPago) : IKpiRow;

public record FactMembresiasDto(
    string RowKey, long SkMembresia, int IdMembresiaBk, int SkFechaCorte, int SkCliente,
    int SkPlan, int SkEmpleado, int SkFechaInicio, int SkFechaFin, int? DuracionDias,
    decimal? PrecioFinal, string EstadoMembresia, int? DiasDesdeVencimiento,
    bool EsRenovacion, int? IdMembresiaAnteriorBk, int? IdMembresiaNuevaBk,
    int? SkFechaRenovacion, int? DiasAnticipacionRenovacion, decimal? MontoRenovacion,
    bool AvisoEmitido, int? SkFechaAviso, int? DiasAntesVencimiento, string? MedioAviso,
    string? EstadoAviso, int AvisosEmitidosDia) : IKpiRow;

public record FactAsistenciasDto(
    string RowKey, long SkAsistencia, int IdAsistenciaBk, int SkFechaAsistencia,
    int SkCliente, int SkPlan, int SkEmpleado, int? HoraIngreso, int CantidadAsistencias,
    bool EsAccesoValido) : IKpiRow;

public record FactSesionesEntrenamientoDto(
    string RowKey, long SkSesion, int IdSesionBk, int SkFechaProgramada, int SkCliente,
    int SkPlan, int SkEmpleado, string TipoSesion, int? HoraProgramada,
    string EstadoSesion, bool Asistio, int? DuracionMinutos, int? SkFechaCancelacion,
    string? MotivoCancelacion) : IKpiRow;

public record FactSeguimientoFisicoDto(
    string RowKey, long SkSeguimiento, int IdObjetivoBk, int SkCliente, int SkEmpleado,
    int SkFechaCorte, int SkFechaInicio, int SkFechaMeta, int? IdEvaluacionBk,
    int? IdEvaluacionProgramadaBk, string TipoObjetivo, string UnidadMedida,
    string EstadoObjetivo, decimal? ValorInicial, decimal? ValorActual, decimal? ValorEsperado,
    decimal? AvanceAlcanzado, decimal? AvanceEsperado, decimal? PorcentajeProgreso,
    decimal? Peso, decimal? Altura, decimal? GrasaCorporal, decimal? MasaMuscular,
    bool EvaluacionExigible, bool EvaluacionCompletada, bool EvaluacionPendiente,
    string EstadoEvaluacion) : IKpiRow;

public record FactReclamosDto(
    string RowKey, long SkReclamo, int IdReclamoBk, int SkFechaReclamo, int SkCliente,
    int SkEmpleado, string Categoria, string Estado, int? SkFechaResolucion,
    int? SkFechaCierre, int? DiasResolucion, bool? ResueltoEnMostrador, bool Escalado,
    string? AreaResponsable) : IKpiRow;

public record FactRetencionesDto(
    string RowKey, long SkRetencion, int IdRetencionBk, int SkFechaRetencion, int SkCliente,
    int SkEmpleado, int? IdMembresiaBk, int? SkFechaVencimiento, string Canal,
    string Motivo, string Resultado, bool Recuperada, decimal? MontoOferta) : IKpiRow;
