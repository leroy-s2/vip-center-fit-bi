using Dapper;
using Microsoft.AspNetCore.OData;
using VipCenterFit.Api.Data;
using VipCenterFit.Api.OData;

var builder = WebApplication.CreateBuilder(args);

// Dapper: mapea columnas con guion bajo a propiedades PascalCase (sk_cliente -> SkCliente).
DefaultTypeMap.MatchNamesWithUnderscores = true;

builder.Services
    .AddControllers()
    .AddOData(opt => opt
        .AddRouteComponents("odata", EdmModelBuilder.Build())
        .Select()
        .Filter()
        .OrderBy()
        .Expand()
        .Count()
        .SetMaxTop(2000));

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new()
    {
        Title = "VIP Center Fit - BI API",
        Version = "v1",
        Description =
            "Escritura transaccional en ORIGEN (lo que simula JMeter) y lectura de KPIs del " +
            "Data Warehouse (3 data marts: comercial, entrenamiento y atención). " +
            "Los endpoints OData (/odata/*) son para Power BI."
    });
});

builder.Services.AddSingleton<DbConnectionFactory>();
builder.Services.AddScoped<KpiRepository>();
builder.Services.AddScoped<OrigenRepository>();
builder.Services.AddScoped<EtlRepository>();

builder.Services.AddHealthChecks().AddCheck<SqlHealthCheck>("sqlserver");
builder.Services.AddCors(o => o.AddDefaultPolicy(p => p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));

var app = builder.Build();

app.UseSwagger();
app.UseSwaggerUI(c => c.SwaggerEndpoint("/swagger/v1/swagger.json", "VIP Center Fit - BI API v1"));

// API key simple. Se activa sólo si ApiKey tiene valor en la configuración.
var apiKey = app.Configuration["ApiKey"];
if (!string.IsNullOrWhiteSpace(apiKey))
{
    app.Use(async (ctx, next) =>
    {
        var path = ctx.Request.Path.Value ?? string.Empty;
        var abierto = path is "/" or "/health" or "/health/ready"
            || path.StartsWith("/swagger", StringComparison.OrdinalIgnoreCase)
            || path.StartsWith("/odata", StringComparison.OrdinalIgnoreCase);
        if (abierto)
        {
            await next();
            return;
        }
        if (!ctx.Request.Headers.TryGetValue("X-Api-Key", out var provided) || provided != apiKey)
        {
            ctx.Response.StatusCode = StatusCodes.Status401Unauthorized;
            await ctx.Response.WriteAsJsonAsync(new { error = "API key inválida o ausente (header X-Api-Key)." });
            return;
        }
        await next();
    });
}

app.UseCors();
app.MapControllers();
app.MapHealthChecks("/health");
app.MapHealthChecks("/health/ready");
app.MapGet("/", () => Results.Redirect("/swagger"));

app.Run();
