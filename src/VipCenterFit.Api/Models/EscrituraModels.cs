namespace VipCenterFit.Api.Models;

/*
  Cuerpos de las peticiones de escritura. Reflejan las columnas de las tablas
  transaccionales de BI_VIP_CENTER_FIT_DW_ORIGEN. La API valida en esta capa
  porque el origen (a propósito) no tiene PRIMARY KEY ni FOREIGN KEY.
*/

public record ClienteRequest(
    int? IdClienteBk, string? Dni, string? NombreCompleto, string? Sexo,
    string? RangoEtario, string? EstadoCliente, DateTime? FechaRegistroOrigen,
    DateTime? FechaInicioValidez, DateTime? FechaFinValidez, bool? EsActual);

public record EmpleadoRequest(
    int? IdEmpleadoBk, string? Dni, string? NombreCompleto, string? Cargo, string? Area);

public record MembresiaRequest(
    int? IdMembresiaBk, int? SkCliente, int? SkPlan, int? SkEmpleado,
    int? SkFechaInicio, int? SkFechaFin, int? DuracionDias, decimal? PrecioFinal,
    bool? EsRenovacion, string? EstadoMembresia, int? DiasAnticipacionRenovacion);

public record VentaRequest(
    int? IdPagoBk, int? SkFechaPago, int? SkCliente, int? SkPlan,
    int? SkEmpleado, int? IdMembresiaBk, decimal? MontoNeto, decimal? DescuentoAplicado,
    decimal? PrecioLista, string? MetodoPago);

public record RenovacionRequest(
    int? IdRenovacionBk, int? SkFechaRenovacion, int? SkCliente, int? SkEmpleado,
    int? IdMembresiaAnteriorBk, int? IdMembresiaNuevaBk, int? DiasAnticipacion, decimal? Monto);

public record AvisoRequest(
    int? IdAvisoBk, int? SkFechaAviso, int? SkCliente, int? SkEmpleado,
    int? IdMembresiaBk, int? DiasAntesVencimiento, string? Medio, string? Estado);

public record AsistenciaRequest(
    int? IdAsistenciaBk, int? SkFechaAsistencia, int? SkCliente, int? SkPlan,
    int? SkEmpleado, int? HoraIngreso, int? CantidadAsistencias);

public record ObjetivoRequest(
    int? IdObjetivoBk, int? SkFechaInicio, int? SkCliente, string? TipoObjetivo,
    decimal? ValorInicial, decimal? ValorObjetivo, string? UnidadMedida, string? Estado);

public record EvaluacionRequest(
    int? IdEvaluacionBk, int? SkFechaEvaluacion, int? SkCliente, int? SkEmpleado,
    int? IdObjetivoBk, decimal? Peso, decimal? Altura, decimal? GrasaCorporal, decimal? MasaMuscular);

public record ReclamoRequest(
    int? IdReclamoBk, int? SkFechaReclamo, int? SkCliente, int? SkEmpleado,
    string? Categoria, string? Estado, DateTime? FechaResolucion, int? DiasResolucion,
    bool? ResueltoEnMostrador);

public record SesionProgramadaRequest(
    int? IdSesionBk, int? SkFechaProgramada, int? SkCliente, int? SkPlan, int? SkEmpleado,
    string? TipoSesion, int? HoraProgramada, string? EstadoSesion, int? DuracionMinutos);

public record EvaluacionProgramadaRequest(
    int? IdEvaluacionProgramadaBk, int? SkFechaProgramada, int? SkCliente, int? SkEmpleado,
    int? IdObjetivoBk, string? TipoEvaluacion, string? EstadoEvaluacion, int? IdEvaluacionBk);

public record RetencionRequest(
    int? IdRetencionBk, int? SkFechaRetencion, int? SkCliente, int? SkEmpleado, int? IdMembresiaBk,
    string? Canal, string? Motivo, string? Resultado, decimal? MontoOferta);
