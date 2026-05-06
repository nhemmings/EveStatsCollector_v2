namespace EveStatsCollector.Esi;

internal abstract class EsiSnapshotService<TCollector>(TCollector collector, ILogger logger)
    : BackgroundService
    where TCollector : IEsiCollector
{
    protected abstract string EntityName { get; }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            var expires   = await TryCollectAsync(stoppingToken);
            var jitter    = TimeSpan.FromSeconds(Random.Shared.Next(60, 121));
            var delay     = expires - DateTimeOffset.UtcNow + jitter;
            var nextFetch = DateTimeOffset.UtcNow + delay;
            logger.LogInformation("Next {Entity} fetch scheduled at {NextFetch:u}", EntityName, nextFetch);
            if (delay > TimeSpan.Zero)
                await Task.Delay(delay, stoppingToken)
                          .ConfigureAwait(ConfigureAwaitOptions.SuppressThrowing);
        }
    }

    private async Task<DateTimeOffset> TryCollectAsync(CancellationToken ct)
    {
        try
        {
            return await collector.CollectAsync(ct);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "{Entity} collection failed", EntityName);
            return DateTimeOffset.UtcNow + TimeSpan.FromHours(1);
        }
    }
}
