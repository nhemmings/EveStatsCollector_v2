namespace EveStatsCollector.StaticData;

internal sealed class StaticDataDownloader(
    IHttpClientFactory httpClientFactory,
    ILogger<StaticDataDownloader> logger)
{
    private const string ArchiveUrlTemplate =
        "https://developers.eveonline.com/static-data/tranquility/eve-online-static-data-{0}-jsonl.zip";

    public async Task DownloadAsync(int buildNumber, string destPath, CancellationToken ct)
    {
        var url = string.Format(ArchiveUrlTemplate, buildNumber);
        logger.LogInformation("Downloading static data archive from {Url}", url);

        using var http     = httpClientFactory.CreateClient("Sde");
        using var response = await http.GetAsync(url, HttpCompletionOption.ResponseHeadersRead, ct);
        response.EnsureSuccessStatusCode();

        await using var source = await response.Content.ReadAsStreamAsync(ct);
        await using var dest   = File.Create(destPath);

        var buffer      = new byte[81920];
        long totalBytes = 0;
        long reportedMb = 0;
        int  bytesRead;

        while ((bytesRead = await source.ReadAsync(buffer, ct)) > 0)
        {
            await dest.WriteAsync(buffer.AsMemory(0, bytesRead), ct);
            totalBytes += bytesRead;

            var currentMb = totalBytes / (10 * 1024 * 1024);
            if (currentMb > reportedMb)
            {
                reportedMb = currentMb;
                logger.LogDebug("Downloading static data: {MB:F0} MB", totalBytes / 1_000_000.0);
            }
        }

        logger.LogInformation("Download complete: {MB:F0} MB", totalBytes / 1_000_000.0);
    }
}
