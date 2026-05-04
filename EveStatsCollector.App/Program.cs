using DbUp;
using EveStatsCollector;
using EveStatsCollector.Sde;
using Npgsql;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using Serilog;

Log.Logger = new LoggerConfiguration()
    .Enrich.FromLogContext()
    .WriteTo.Console()
    .CreateBootstrapLogger();

try
{
    var builder = Host.CreateApplicationBuilder(args);

    // Logging — Serilog reads sink/level config from appsettings.json
    builder.Services.AddSerilog((_, loggerConfiguration) => loggerConfiguration
        .ReadFrom.Configuration(builder.Configuration)
        .Enrich.FromLogContext());

    // Telemetry — OTLP endpoint read from OTEL_EXPORTER_OTLP_ENDPOINT (default: localhost:4317)
    builder.Services
        .AddOpenTelemetry()
        .ConfigureResource(r => r.AddService("EveStatsCollector"))
        .WithTracing(t => t
            .AddHttpClientInstrumentation()
            .AddOtlpExporter())
        .WithMetrics(m => m
            .AddHttpClientInstrumentation()
            .AddOtlpExporter());

    // ESI HTTP client — User-Agent and base address only; rate-limiting middleware added later
    var esi = builder.Configuration.GetSection("Esi");
    builder.Services.AddHttpClient("Esi", client =>
    {
        client.BaseAddress = new Uri(esi["BaseUrl"]!);
        client.DefaultRequestHeaders.UserAgent.ParseAdd(esi["UserAgent"]!);
    });

    // SDE HTTP client — used for metadata checks and large zip downloads (~100 MB)
    builder.Services.AddHttpClient("Sde", client =>
    {
        client.DefaultRequestHeaders.UserAgent.ParseAdd(esi["UserAgent"]!);
        client.Timeout = TimeSpan.FromMinutes(10);
    });

    // PostgreSQL data source for application queries
    builder.Services.AddSingleton(
        NpgsqlDataSource.Create(builder.Configuration.GetConnectionString("EveStats")!));

    builder.Services.AddSingleton<SdeImporter>();
    builder.Services.AddHostedService<SdeImportService>();
    builder.Services.AddHostedService<Worker>();

    // Run DbUp migrations synchronously before starting the host
    var migrationsConnStr = builder.Configuration.GetConnectionString("EveStatsMigrations")!;
    var appPassword       = builder.Configuration["DbMigrations:AppPassword"]!;
    var readonlyPassword  = builder.Configuration["DbMigrations:ReadonlyPassword"]!;
    var migrationsPath    = Path.Combine(AppContext.BaseDirectory, "migrations");

    EnsureDatabase.For.PostgresqlDatabase(migrationsConnStr);
    var upgradeResult = DeployChanges.To
        .PostgresqlDatabase(migrationsConnStr)
        .WithScriptsFromFileSystem(migrationsPath)
        .WithVariable("AppPassword", appPassword)
        .WithVariable("ReadonlyPassword", readonlyPassword)
        .WithTransaction()
        .LogToConsole()
        .Build()
        .PerformUpgrade();

    if (!upgradeResult.Successful)
        throw new Exception("Database migration failed", upgradeResult.Error);

    var host = builder.Build();
    host.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "Application terminated unexpectedly during startup");
}
finally
{
    Log.CloseAndFlush();
}
