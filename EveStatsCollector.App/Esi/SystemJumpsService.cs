namespace EveStatsCollector.Esi;

internal sealed class SystemJumpsService(SystemJumpsCollector collector, ILogger<SystemJumpsService> logger)
    : EsiSnapshotService<SystemJumpsCollector>(collector, logger)
{
    protected override string EntityName => "system jumps";
}
