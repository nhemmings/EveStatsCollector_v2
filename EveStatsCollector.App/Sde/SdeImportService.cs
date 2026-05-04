namespace EveStatsCollector.Sde;

internal sealed class SdeImportService(SdeImporter importer, ILogger<SdeImportService> logger)
    : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromHours(24));
        do
        {
            await TryImportAsync(stoppingToken);
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }

    private async Task TryImportAsync(CancellationToken ct)
    {
        try
        {
            await importer.RunIfOutdatedAsync(ct);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "SDE import failed");
        }
    }
}
