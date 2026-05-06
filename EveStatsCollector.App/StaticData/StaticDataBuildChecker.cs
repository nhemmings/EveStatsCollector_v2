namespace EveStatsCollector.StaticData;

using System.Text.Json;
using Dapper;
using Npgsql;

internal sealed class StaticDataBuildChecker(
    IHttpClientFactory httpClientFactory,
    NpgsqlDataSource dataSource,
    ILogger<StaticDataBuildChecker> logger)
{
    private const string LatestMetadataUrl =
        "https://developers.eveonline.com/static-data/tranquility/latest.jsonl";

    // Returns the latest build info if a newer build is available; null if already up to date.
    public async Task<(int Build, DateTimeOffset ReleaseDate)?> GetPendingBuildAsync(CancellationToken ct)
    {
        var (latestBuild, releaseDate) = await FetchLatestBuildInfoAsync(ct);

        await using var conn = await dataSource.OpenConnectionAsync(ct);
        var currentBuild = await conn.QuerySingleOrDefaultAsync<int?>(
            "SELECT MAX(build_number) FROM sde_imports");

        if (latestBuild == currentBuild)
        {
            logger.LogDebug("Static data is up to date (build {Build})", latestBuild);
            return null;
        }

        logger.LogInformation("New static data build available: {New} (current: {Current})",
            latestBuild, currentBuild?.ToString() ?? "none");

        return (latestBuild, releaseDate);
    }

    private async Task<(int Build, DateTimeOffset ReleaseDate)> FetchLatestBuildInfoAsync(CancellationToken ct)
    {
        using var http = httpClientFactory.CreateClient("Sde");
        var content = await http.GetStringAsync(LatestMetadataUrl, ct);

        foreach (var line in content.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            using var doc = JsonDocument.Parse(line);
            var root = doc.RootElement;
            if (!root.TryGetProperty("_key", out var key) || key.GetString() != "sde") continue;

            var build = root.GetProperty("buildNumber").GetInt32();
            var releaseDate = root.GetProperty("releaseDate").GetDateTimeOffset();
            return (build, releaseDate);
        }

        throw new InvalidOperationException(
            $"Could not find SDE build record in {LatestMetadataUrl}. Raw response:\n{content[..Math.Min(500, content.Length)]}");
    }
}
