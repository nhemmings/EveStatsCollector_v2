using Dapper;
using EveStatsCollector.Api.Endpoints;
using Npgsql;
using OpenTelemetry.Exporter;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using Scalar.AspNetCore;
using Serilog;

// Map PostgreSQL snake_case column names to C# PascalCase properties
DefaultTypeMap.MatchNamesWithUnderscores = true;

Log.Logger = new LoggerConfiguration()
    .Enrich.FromLogContext()
    .WriteTo.Console()
    .CreateBootstrapLogger();

try
{
    var builder = WebApplication.CreateBuilder(args);

    builder.Services.AddSerilog((_, loggerConfiguration) => loggerConfiguration
        .ReadFrom.Configuration(builder.Configuration)
        .Enrich.FromLogContext());

    var otlpEndpoint = builder.Configuration["OpenTelemetry:OtlpEndpoint"];
    builder.Services
        .AddOpenTelemetry()
        .ConfigureResource(r => r.AddService("EveStatsCollector.Api"))
        .WithTracing(t => t
            .AddAspNetCoreInstrumentation()
            .AddSource("Npgsql")
            .AddOtlpExporter(o =>
            {
                o.Protocol = OtlpExportProtocol.HttpProtobuf;
                if (otlpEndpoint is not null)
                    o.Endpoint = new Uri(otlpEndpoint);
            }));

    builder.Services.AddSingleton(
        NpgsqlDataSource.Create(builder.Configuration.GetConnectionString("EveStatsReadonly")!));

    var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
    builder.Services.AddCors(options =>
        options.AddDefaultPolicy(policy => policy
            .WithOrigins(allowedOrigins)
            .AllowAnyHeader()
            .AllowAnyMethod()));

    // Serialize response properties as camelCase
    builder.Services.ConfigureHttpJsonOptions(options =>
        options.SerializerOptions.PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase);

    builder.Services.AddOpenApi();

    var app = builder.Build();

    app.UseSerilogRequestLogging();
    app.UseCors();

    if (app.Environment.IsDevelopment())
    {
        app.MapOpenApi();
        app.MapScalarApiReference();
    }

    app.MapSystemsEndpoints();
    app.MapJumpsEndpoints();
    app.MapKillsEndpoints();
    app.MapUniverseEndpoints();

    app.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "Application terminated unexpectedly during startup");
}
finally
{
    Log.CloseAndFlush();
}
