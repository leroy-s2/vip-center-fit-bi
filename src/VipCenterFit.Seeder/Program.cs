using System.Globalization;
using System.Text;

/*
  Seeder determinista. Genera datasets CSV reproducibles (a partir de --seed)
  que JMeter reproduce como si fuera una web operando el gimnasio.

  Uso:
    dotnet run --project src/VipCenterFit.Seeder -- --seed 1234 --clientes 200 --out jmeter/data

  Los encabezados de cada CSV coinciden con los nombres de campo (camelCase) que
  espera la API, incluidos los campos incorporados en la reestructuración a
  7 hechos (codigoEmpleado, skFechaMeta, hitos del reclamo y cancelación de
  sesión). Se cubren los 13 endpoints de escritura.
*/

var seed = GetInt("--seed", 1234);
var nClientes = GetInt("--clientes", 100);
var outDir = GetStr("--out", "jmeter/data");
Directory.CreateDirectory(outDir);

var rnd = new Random(seed);
var baseFecha = new DateTime(2026, 9, 1);
var planes = new[] { 1, 2, 3, 4, 5 };
var metodos = new[] { "YAPE", "PLIN", "TRANSFERENCIA", "TARJETA", "EFECTIVO" };
var categorias = new[] { "COBRO", "SERVICIO", "PERSONAL", "INSTALACION" };
var estados = new[] { "ACTIVO", "INACTIVO" };
var sexos = new[] { "M", "F" };
var rangos = new[] { "Jóvenes (<25)", "Adultos Jóvenes (25-40)", "Adultos (>40)" };
var tiposSesion = new[] { "ENTRENAMIENTO", "CLASE_GRUPAL", "EVALUACION" };
var estadosSesion = new[] { "ASISTIDA", "AUSENTE", "PROGRAMADA", "CANCELADA" };
var tiposEvaluacion = new[] { "FISICA", "MEDICION", "SEGUIMIENTO" };
var estadosEvaluacion = new[] { "COMPLETADA", "PROGRAMADA", "PENDIENTE", "CANCELADA" };
var canales = new[] { "MOSTRADOR", "LLAMADA", "WHATSAPP", "EMAIL" };
var motivos = new[] { "VENCIMIENTO", "PRECIO", "INSATISFACCION", "MUDANZA" };
var resultadosRetencion = new[] { "RETENIDO", "NO_RETENIDO" };
var cargos = new[] { "GERENTE", "ENTRENADOR", "RECEPCIONISTA", "ADMINISTRATIVO", "ENTRENADOR" };
var areas = new[] { "GERENCIA", "ENTRENAMIENTO", "RECEPCION", "ADMINISTRACION", "ENTRENAMIENTO" };
var tiposObjetivo = new[] { "REDUCCION_GRASA", "AUMENTO_MASA" };
var unidades = new[] { "KG", "CM" };
var estadosObjetivo = new[] { "ACTIVO", "CUMPLIDO", "CANCELADO" };
var motivosCancelacion = new[] { "CANCELADA POR EL CLIENTE", "REPROGRAMADA", "NO ASISTIO" };

var clientes = new StringBuilder("idClienteBk,dni,nombreCompleto,sexo,rangoEtario,estadoCliente,fechaRegistroOrigen,fechaInicioValidez,esActual\n");
var empleados = new StringBuilder("idEmpleadoBk,dni,nombreCompleto,cargo,area,codigoEmpleado\n");
var membresias = new StringBuilder("idMembresiaBk,skCliente,skPlan,skFechaInicio,skFechaFin,duracionDias,precioFinal,esRenovacion,estadoMembresia\n");
var ventas = new StringBuilder("idPagoBk,skFechaPago,skCliente,skPlan,montoNeto,descuentoAplicado,precioLista,metodoPago\n");
var renovaciones = new StringBuilder("idRenovacionBk,skFechaRenovacion,skCliente,skEmpleado,idMembresiaAnteriorBk,idMembresiaNuevaBk,diasAnticipacion,monto\n");
var avisos = new StringBuilder("idAvisoBk,skFechaAviso,skCliente,skEmpleado,idMembresiaBk,diasAntesVencimiento,medio,estado\n");
var asistencias = new StringBuilder("idAsistenciaBk,skFechaAsistencia,skCliente,skPlan,horaIngreso,cantidadAsistencias\n");
var objetivos = new StringBuilder("idObjetivoBk,skFechaInicio,skFechaMeta,skCliente,tipoObjetivo,valorInicial,valorObjetivo,unidadMedida,estado\n");
var evaluaciones = new StringBuilder("idEvaluacionBk,skFechaEvaluacion,skCliente,skEmpleado,idObjetivoBk,peso,altura,grasaCorporal,masaMuscular\n");
var reclamos = new StringBuilder("idReclamoBk,skFechaReclamo,skCliente,categoria,estado,fechaCierre,escalado,areaResponsable\n");
var sesionesProgramadas = new StringBuilder("idSesionBk,skFechaProgramada,skCliente,skPlan,skEmpleado,tipoSesion,horaProgramada,estadoSesion,duracionMinutos,fechaCancelacion,motivoCancelacion\n");
var evaluacionesProgramadas = new StringBuilder("idEvaluacionProgramadaBk,skFechaProgramada,skCliente,skEmpleado,idObjetivoBk,tipoEvaluacion,estadoEvaluacion\n");
var retenciones = new StringBuilder("idRetencionBk,skFechaRetencion,skCliente,skEmpleado,idMembresiaBk,canal,motivo,resultado,montoOferta\n");

const int bkBase = 900000;

/* Catálogo de empleados: 5 filas, una por rol operativo. */
for (var e = 0; e < 5; e++)
{
    var ebk = bkBase + e + 1;
    empleados.Append(CultureInfo.InvariantCulture,
        $"{ebk},{ebk:D8},Empleado Seeder {ebk},{cargos[e]},{areas[e]},EMP-{ebk:D6}\n");
}

var sesionId = 0;
var evaluacionProgramadaId = 0;
for (var i = 0; i < nClientes; i++)
{
    var bk = bkBase + 1000 + i;
    var sk = 1000 + i;
    var fecha = baseFecha.AddDays(rnd.Next(0, 120));
    clientes.Append(CultureInfo.InvariantCulture,
        $"{bk},{bk:D8},Cliente Seeder {bk},{sexos[rnd.Next(sexos.Length)]},{rangos[rnd.Next(rangos.Length)]},{estados[rnd.Next(estados.Length)]},{fecha:yyyy-MM-dd},{fecha:yyyy-MM-dd},true\n");

    // Una membresía por cliente.
    var inicio = baseFecha.AddDays(rnd.Next(0, 90));
    var dur = new[] { 30, 90, 180, 365 }[rnd.Next(4)];
    var fin = inicio.AddDays(dur);
    var plan = planes[rnd.Next(planes.Length)];
    var empleado = rnd.Next(2, 6);
    var precio = rnd.Next(50, 900);
    membresias.Append(CultureInfo.InvariantCulture,
        $"{bk},{sk},{plan},{inicio:yyyyMMdd},{fin:yyyyMMdd},{dur},{precio}.00,false,ACTIVA\n");

    // Venta asociada.
    ventas.Append(CultureInfo.InvariantCulture,
        $"{bk},{inicio:yyyyMMdd},{sk},{plan},{precio}.00,0.00,{precio}.00,{metodos[rnd.Next(metodos.Length)]}\n");

    // Aviso de renovación 7 días antes del vencimiento.
    avisos.Append(CultureInfo.InvariantCulture,
        $"{bk},{fin.AddDays(-7):yyyyMMdd},{sk},{empleado},{bk},7,{new[] { "WHATSAPP", "CORREO", "SMS" }[rnd.Next(3)]},ENVIADO\n");

    // Renovación en la mitad de los casos: contrato anterior -> contrato nuevo.
    if (rnd.Next(0, 2) == 0)
    {
        var fb = rnd.Next(1, 30);
        renovaciones.Append(CultureInfo.InvariantCulture,
            $"{bk},{fin.AddDays(-fb):yyyyMMdd},{sk},{empleado},{bk},{bk * 10},{fb},{precio}.00\n");
        membresias.Append(CultureInfo.InvariantCulture,
            $"{bk * 10},{sk},{plan},{fin:yyyyMMdd},{fin.AddDays(dur):yyyyMMdd},{dur},{precio}.00,true,ACTIVA\n");
    }

    // 1 a 5 accesos reales.
    var nAsis = rnd.Next(1, 6);
    for (var a = 0; a < nAsis; a++)
    {
        var fa = inicio.AddDays(rnd.Next(1, dur));
        asistencias.Append(CultureInfo.InvariantCulture,
            $"{bk * 10 + a},{fa:yyyyMMdd},{sk},{plan},{rnd.Next(6, 21)},1\n");
    }

    // Objetivo físico con fecha meta (90 días).
    var tipoObjetivo = tiposObjetivo[rnd.Next(tiposObjetivo.Length)];
    var valorInicial = tipoObjetivo == "REDUCCION_GRASA" ? rnd.Next(70, 100) : rnd.Next(40, 60);
    var valorObjetivo = tipoObjetivo == "REDUCCION_GRASA" ? valorInicial - rnd.Next(3, 10) : valorInicial + rnd.Next(3, 10);
    objetivos.Append(CultureInfo.InvariantCulture,
        $"{bk},{inicio:yyyyMMdd},{inicio.AddDays(90):yyyyMMdd},{sk},{tipoObjetivo},{valorInicial}.00,{valorObjetivo}.00,{unidades[rnd.Next(unidades.Length)]},{estadosObjetivo[rnd.Next(estadosObjetivo.Length)]}\n");

    // Dos evaluaciones de seguimiento del objetivo.
    for (var ev = 1; ev <= 2; ev++)
    {
        var fe = inicio.AddDays(rnd.Next(1, 80));
        evaluaciones.Append(CultureInfo.InvariantCulture,
            $"{bk * 10 + ev},{fe:yyyyMMdd},{sk},{empleado},{bk},{rnd.Next(50, 95)}.00,{rnd.Next(150, 190) / 100.0m:F2},{rnd.Next(10, 35)}.00,{rnd.Next(20, 40)}.00\n");
    }

    // Reclamo ocasional, con hitos de cierre y escalamiento.
    if (rnd.Next(0, 4) == 0)
    {
        var fr = inicio.AddDays(rnd.Next(0, 30));
        var resuelto = rnd.Next(0, 2) == 0;
        var escalado = !resuelto;
        reclamos.Append(CultureInfo.InvariantCulture,
            $"{bk},{fr:yyyyMMdd},{sk},{categorias[rnd.Next(categorias.Length)]},{(resuelto ? "RESUELTO" : "PENDIENTE")},{(resuelto ? fr.AddDays(2) : fr.AddDays(30)):yyyy-MM-dd},{(escalado ? "true" : "false")},{(escalado ? "ADMINISTRACION" : "RECEPCION")}\n");
    }

    // 1 a 3 sesiones programadas (con cancelación cuando corresponde).
    var nSes = rnd.Next(1, 4);
    for (var s = 0; s < nSes; s++)
    {
        sesionId++;
        var fs = inicio.AddDays(rnd.Next(0, dur));
        var estadoSesion = estadosSesion[rnd.Next(estadosSesion.Length)];
        var cancelada = estadoSesion == "CANCELADA";
        sesionesProgramadas.Append(CultureInfo.InvariantCulture,
            $"{bk * 10 + sesionId},{fs:yyyyMMdd},{sk},{plan},{empleado},{tiposSesion[rnd.Next(tiposSesion.Length)]},{rnd.Next(6, 21)},{estadoSesion},60,{(cancelada ? fs.AddDays(-1) : fs):yyyy-MM-dd},{(cancelada ? motivosCancelacion[rnd.Next(motivosCancelacion.Length)] : "NO APLICA")}\n");
    }

    // Una evaluación programada.
    evaluacionProgramadaId++;
    var fep = inicio.AddDays(rnd.Next(0, dur));
    evaluacionesProgramadas.Append(CultureInfo.InvariantCulture,
        $"{bk * 10 + evaluacionProgramadaId},{fep:yyyyMMdd},{sk},{empleado},{bk},{tiposEvaluacion[rnd.Next(tiposEvaluacion.Length)]},{estadosEvaluacion[rnd.Next(estadosEvaluacion.Length)]}\n");

    // Retención ocasional en mostrador.
    if (rnd.Next(0, 3) == 0)
    {
        var frt = inicio.AddDays(rnd.Next(0, 30));
        retenciones.Append(CultureInfo.InvariantCulture,
            $"{bk},{frt:yyyyMMdd},{sk},{empleado},{bk},{canales[rnd.Next(canales.Length)]},{motivos[rnd.Next(motivos.Length)]},{resultadosRetencion[rnd.Next(resultadosRetencion.Length)]},{rnd.Next(0, 100)}.00\n");
    }
}

File.WriteAllText(Path.Combine(outDir, "clientes.csv"), clientes.ToString());
File.WriteAllText(Path.Combine(outDir, "empleados.csv"), empleados.ToString());
File.WriteAllText(Path.Combine(outDir, "membresias.csv"), membresias.ToString());
File.WriteAllText(Path.Combine(outDir, "ventas.csv"), ventas.ToString());
File.WriteAllText(Path.Combine(outDir, "renovaciones.csv"), renovaciones.ToString());
File.WriteAllText(Path.Combine(outDir, "avisos.csv"), avisos.ToString());
File.WriteAllText(Path.Combine(outDir, "asistencias.csv"), asistencias.ToString());
File.WriteAllText(Path.Combine(outDir, "objetivos.csv"), objetivos.ToString());
File.WriteAllText(Path.Combine(outDir, "evaluaciones.csv"), evaluaciones.ToString());
File.WriteAllText(Path.Combine(outDir, "reclamos.csv"), reclamos.ToString());
File.WriteAllText(Path.Combine(outDir, "sesiones_programadas.csv"), sesionesProgramadas.ToString());
File.WriteAllText(Path.Combine(outDir, "evaluaciones_programadas.csv"), evaluacionesProgramadas.ToString());
File.WriteAllText(Path.Combine(outDir, "retenciones.csv"), retenciones.ToString());

Console.WriteLine($"Seeder determinista: seed={seed}, clientes={nClientes}. CSV en '{outDir}'.");

int GetInt(string name, int def)
{
    var i = Array.IndexOf(args, name);
    return i >= 0 && i + 1 < args.Length && int.TryParse(args[i + 1], out var v) ? v : def;
}

string GetStr(string name, string def)
{
    var i = Array.IndexOf(args, name);
    return i >= 0 && i + 1 < args.Length ? args[i + 1] : def;
}
