using System.Globalization;
using System.Text;

/*
  Seeder determinista. Genera datasets CSV reproducibles (a partir de --seed)
  que JMeter reproduce como si fuera una web operando el gimnasio.

  Uso:
    dotnet run --project src/VipCenterFit.Seeder -- --seed 1234 --clientes 200 --out jmeter/data

  Los encabezados de cada CSV coinciden con los nombres de campo (camelCase) que
  espera la API, para que las variables de JMeter se usen tal cual en el JSON.
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

var clientes = new StringBuilder("idClienteBk,dni,nombreCompleto,sexo,rangoEtario,estadoCliente,fechaRegistroOrigen,fechaInicioValidez,esActual\n");
var membresias = new StringBuilder("idMembresiaBk,skCliente,skPlan,skFechaInicio,skFechaFin,duracionDias,precioFinal,esRenovacion,estadoMembresia\n");
var ventas = new StringBuilder("idPagoBk,skFechaPago,skCliente,skPlan,montoNeto,descuentoAplicado,precioLista,metodoPago\n");
var asistencias = new StringBuilder("idAsistenciaBk,skFechaAsistencia,skCliente,skPlan,horaIngreso,cantidadAsistencias\n");
var reclamos = new StringBuilder("idReclamoBk,skFechaReclamo,skCliente,categoria,estado\n");
var sesionesProgramadas = new StringBuilder("idSesionBk,skFechaProgramada,skCliente,skPlan,skEmpleado,tipoSesion,horaProgramada,estadoSesion,duracionMinutos\n");
var evaluacionesProgramadas = new StringBuilder("idEvaluacionProgramadaBk,skFechaProgramada,skCliente,skEmpleado,idObjetivoBk,tipoEvaluacion,estadoEvaluacion\n");
var retenciones = new StringBuilder("idRetencionBk,skFechaRetencion,skCliente,skEmpleado,idMembresiaBk,canal,motivo,resultado,montoOferta\n");

const int bkBase = 900000;
var sesionId = 0;
var evaluacionProgramadaId = 0;
for (var i = 0; i < nClientes; i++)
{
    var bk = bkBase + i + 1;
    var sk = 1000 + i;
    var fecha = baseFecha.AddDays(rnd.Next(0, 120));
    clientes.Append(CultureInfo.InvariantCulture,
        $"{bk},{bk:D8},Cliente Seeder {bk},{sexos[rnd.Next(sexos.Length)]},{rangos[rnd.Next(rangos.Length)]},{estados[rnd.Next(estados.Length)]},{fecha:yyyy-MM-dd},{fecha:yyyy-MM-dd},true\n");

    // Una membresía por cliente.
    var inicio = baseFecha.AddDays(rnd.Next(0, 90));
    var dur = new[] { 30, 90, 180, 365 }[rnd.Next(4)];
    var fin = inicio.AddDays(dur);
    var plan = planes[rnd.Next(planes.Length)];
    membresias.Append(CultureInfo.InvariantCulture,
        $"{bk},{sk},{plan},{inicio:yyyyMMdd},{fin:yyyyMMdd},{dur},{rnd.Next(50, 900)}.00,false,ACTIVA\n");

    // Venta asociada.
    ventas.Append(CultureInfo.InvariantCulture,
        $"{bk},{inicio:yyyyMMdd},{sk},{plan},{rnd.Next(50, 900)}.00,0.00,{rnd.Next(50, 900)}.00,{metodos[rnd.Next(metodos.Length)]}\n");

    // 1 a 5 asistencias.
    var nAsis = rnd.Next(1, 6);
    for (var a = 0; a < nAsis; a++)
    {
        var fa = inicio.AddDays(rnd.Next(1, dur));
        asistencias.Append(CultureInfo.InvariantCulture,
            $"{bk * 10 + a},{fa:yyyyMMdd},{sk},{plan},{rnd.Next(6, 21)},1\n");
    }

    if (rnd.Next(0, 4) == 0)
    {
        var fr = inicio.AddDays(rnd.Next(0, 30));
        reclamos.Append(CultureInfo.InvariantCulture,
            $"{bk},{fr:yyyyMMdd},{sk},{categorias[rnd.Next(categorias.Length)]},{(rnd.Next(0, 2) == 0 ? "RESUELTO" : "PENDIENTE")}\n");
    }

    // 1 a 3 sesiones programadas.
    var nSes = rnd.Next(1, 4);
    for (var s = 0; s < nSes; s++)
    {
        sesionId++;
        var fs = inicio.AddDays(rnd.Next(0, dur));
        sesionesProgramadas.Append(CultureInfo.InvariantCulture,
            $"{bk * 10 + sesionId},{fs:yyyyMMdd},{sk},{plan},{rnd.Next(2, 6)},{tiposSesion[rnd.Next(tiposSesion.Length)]},{rnd.Next(6, 21)},{estadosSesion[rnd.Next(estadosSesion.Length)]},60\n");
    }

    // Una evaluación programada.
    evaluacionProgramadaId++;
    var fep = inicio.AddDays(rnd.Next(0, dur));
    evaluacionesProgramadas.Append(CultureInfo.InvariantCulture,
        $"{bk * 10 + evaluacionProgramadaId},{fep:yyyyMMdd},{sk},{rnd.Next(2, 6)},{rnd.Next(1, 236)},{tiposEvaluacion[rnd.Next(tiposEvaluacion.Length)]},{estadosEvaluacion[rnd.Next(estadosEvaluacion.Length)]}\n");

    // Retención ocasional en mostrador.
    if (rnd.Next(0, 3) == 0)
    {
        var frt = inicio.AddDays(rnd.Next(0, 30));
        retenciones.Append(CultureInfo.InvariantCulture,
            $"{bk},{frt:yyyyMMdd},{sk},{rnd.Next(2, 6)},{bk},{canales[rnd.Next(canales.Length)]},{motivos[rnd.Next(motivos.Length)]},{resultadosRetencion[rnd.Next(resultadosRetencion.Length)]},{rnd.Next(0, 100)}.00\n");
    }
}

File.WriteAllText(Path.Combine(outDir, "clientes.csv"), clientes.ToString());
File.WriteAllText(Path.Combine(outDir, "membresias.csv"), membresias.ToString());
File.WriteAllText(Path.Combine(outDir, "ventas.csv"), ventas.ToString());
File.WriteAllText(Path.Combine(outDir, "asistencias.csv"), asistencias.ToString());
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
