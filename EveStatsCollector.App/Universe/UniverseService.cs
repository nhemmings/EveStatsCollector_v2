namespace EveStatsCollector.Universe;

using System.Collections.Frozen;
using Dapper;
using EveStatsCollector.StaticData;
using Npgsql;

internal sealed class UniverseService(
    StaticDataImporter importer,
    NpgsqlDataSource dataSource,
    ILogger<UniverseService> logger)
    : BackgroundService
{
    private volatile FrozenSet<int> _solarSystemIds   = FrozenSet<int>.Empty;
    private volatile FrozenSet<int> _constellationIds = FrozenSet<int>.Empty;
    private volatile FrozenSet<int> _regionIds        = FrozenSet<int>.Empty;

    public FrozenSet<int> SolarSystemIds   => _solarSystemIds;
    public FrozenSet<int> ConstellationIds => _constellationIds;
    public FrozenSet<int> RegionIds        => _regionIds;

    public override async Task StartAsync(CancellationToken cancellationToken)
    {
        await TryImportAsync(cancellationToken);
        await LoadCacheAsync(cancellationToken);
        await base.StartAsync(cancellationToken);
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromHours(24));
        while (await timer.WaitForNextTickAsync(stoppingToken))
        {
            await TryImportAsync(stoppingToken);
            await LoadCacheAsync(stoppingToken);
        }
    }

    private async Task TryImportAsync(CancellationToken ct)
    {
        try { await importer.RunIfOutdatedAsync(ct); }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch (Exception ex) { logger.LogError(ex, "SDE import failed"); }
    }

    private async Task LoadCacheAsync(CancellationToken ct)
    {
        try
        {
            await using var conn = await dataSource.OpenConnectionAsync(ct);
            var solarSystemIds   = (await conn.QueryAsync<int>("SELECT solar_system_id  FROM solar_systems")).ToArray();
            var constellationIds = (await conn.QueryAsync<int>("SELECT constellation_id FROM constellations")).ToArray();
            var regionIds        = (await conn.QueryAsync<int>("SELECT region_id        FROM regions")).ToArray();

            _solarSystemIds   = solarSystemIds.ToFrozenSet();
            _constellationIds = constellationIds.ToFrozenSet();
            _regionIds        = regionIds.ToFrozenSet();

            logger.LogInformation(
                "Universe cache loaded: {Systems} solar systems, {Constellations} constellations, {Regions} regions",
                solarSystemIds.Length, constellationIds.Length, regionIds.Length);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch (Exception ex) { logger.LogError(ex, "Universe cache load failed"); }
    }
}
