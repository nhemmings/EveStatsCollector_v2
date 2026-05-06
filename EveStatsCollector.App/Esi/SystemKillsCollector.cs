namespace EveStatsCollector.Esi;

using System.Text.Json;
using System.Text.Json.Serialization;
using Dapper;
using EveStatsCollector.Universe;
using Npgsql;

internal sealed class SystemKillsCollector(
    IHttpClientFactory httpClientFactory,
    NpgsqlDataSource dataSource,
    UniverseService universeService,
    ILogger<SystemKillsCollector> logger) : IEsiCollector
{
    private const string Endpoint = "universe/system_kills/";
    private static readonly TimeSpan FallbackCacheDuration = TimeSpan.FromHours(1);

    public async Task<DateTimeOffset> CollectAsync(CancellationToken ct)
    {
        var etag = await GetLastEtagAsync(ct);

        using var http    = httpClientFactory.CreateClient("Esi");
        using var request = new HttpRequestMessage(HttpMethod.Get, Endpoint);
        if (etag is not null)
            request.Headers.TryAddWithoutValidation("If-None-Match", etag);

        using var response = await http.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, ct);

        var expires = response.Content.Headers.Expires
                   ?? DateTimeOffset.UtcNow + FallbackCacheDuration;

        if (response.StatusCode == System.Net.HttpStatusCode.NotModified)
        {
            logger.LogDebug("System kills unchanged (ETag match)");
            return expires;
        }

        response.EnsureSuccessStatusCode();

        var lastModified = response.Content.Headers.LastModified
            ?? throw new InvalidOperationException("ESI system_kills response missing Last-Modified header");
        var newEtag = response.Headers.ETag?.ToString();

        var json  = await response.Content.ReadAsStringAsync(ct);
        var kills = JsonSerializer.Deserialize<List<EsiSystemKill>>(json)!;

        await PersistAsync(kills, lastModified.UtcDateTime, newEtag, ct);

        logger.LogInformation(
            "System kills collected: {Count} systems, observation window ending {LastModified:u}",
            kills.Count, lastModified);

        return expires;
    }

    private async Task<string?> GetLastEtagAsync(CancellationToken ct)
    {
        await using var conn = await dataSource.OpenConnectionAsync(ct);
        return await conn.QuerySingleOrDefaultAsync<string?>(
            "SELECT etag FROM system_kill_snapshots ORDER BY snapshot_id DESC LIMIT 1");
    }

    private async Task PersistAsync(
        List<EsiSystemKill> kills,
        DateTime resourceLastModified,
        string? etag,
        CancellationToken ct)
    {
        await using var conn = await dataSource.OpenConnectionAsync(ct);
        await using var tx   = await conn.BeginTransactionAsync(ct);

        var knownIds = universeService.SolarSystemIds;

        var missing = kills.Where(k => !knownIds.Contains(k.SolarSystemId)).ToList();
        if (missing.Count > 0)
            logger.LogWarning(
                "Skipping {SkippedCount} systems not present in solar_systems: {SystemIds}",
                missing.Count,
                missing.Select(k => k.SolarSystemId));

        var toInsert = kills.Where(k => knownIds.Contains(k.SolarSystemId)).ToList();

        var snapshotId = await conn.QuerySingleAsync<long>(
            """
            INSERT INTO system_kill_snapshots (fetched_at, resource_last_modified, etag, system_count)
            VALUES (@FetchedAt, @ResourceLastModified, @Etag, @SystemCount)
            RETURNING snapshot_id
            """,
            new
            {
                FetchedAt            = DateTime.UtcNow,
                ResourceLastModified = resourceLastModified,
                Etag                 = etag,
                SystemCount          = kills.Count,
            },
            transaction: tx);

        if (toInsert.Count > 0)
            await conn.ExecuteAsync(
                """
                INSERT INTO system_kill_counts (snapshot_id, solar_system_id, npc_kills, pod_kills, ship_kills)
                VALUES (@SnapshotId, @SolarSystemId, @NpcKills, @PodKills, @ShipKills)
                """,
                toInsert.Select(k => new { SnapshotId = snapshotId, k.SolarSystemId, k.NpcKills, k.PodKills, k.ShipKills }),
                transaction: tx);

        await tx.CommitAsync(ct);
    }
}

internal sealed record EsiSystemKill(
    [property: JsonPropertyName("system_id")]   int SolarSystemId,
    [property: JsonPropertyName("npc_kills")]   int NpcKills,
    [property: JsonPropertyName("pod_kills")]   int PodKills,
    [property: JsonPropertyName("ship_kills")]  int ShipKills);
