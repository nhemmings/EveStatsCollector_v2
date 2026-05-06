namespace EveStatsCollector.Esi;

internal interface IEsiCollector
{
    Task<DateTimeOffset> CollectAsync(CancellationToken ct);
}
