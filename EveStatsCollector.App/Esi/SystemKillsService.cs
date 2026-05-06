namespace EveStatsCollector.Esi;

internal sealed class SystemKillsService(SystemKillsCollector collector, ILogger<SystemKillsService> logger)
    : EsiSnapshotService<SystemKillsCollector>(collector, logger)
{
    protected override string EntityName => "system kills";
}
