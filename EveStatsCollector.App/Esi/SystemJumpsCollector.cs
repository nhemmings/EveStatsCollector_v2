namespace EveStatsCollector.Esi;

using System.Text.Json;
using System.Text.Json.Serialization;
using Dapper;
using EveStatsCollector.Universe;
using Npgsql;

internal sealed class SystemJumpsCollector(
    IHttpClientFactory httpClientFactory,
    NpgsqlDataSource dataSource,
    UniverseService universeService,
    ILogger<SystemJumpsCollector> logger) : IEsiCollector
{
    private const string Endpoint = "universe/system_jumps/";
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
            logger.LogDebug("System jumps unchanged (ETag match)");
            return expires;
        }

        response.EnsureSuccessStatusCode();

        var lastModified = response.Content.Headers.LastModified
            ?? throw new InvalidOperationException("ESI system_jumps response missing Last-Modified header");
        var newEtag = response.Headers.ETag?.ToString();

        var json  = await response.Content.ReadAsStringAsync(ct);
        var jumps = JsonSerializer.Deserialize<List<EsiSystemJump>>(json)!;

        await PersistAsync(jumps, lastModified.UtcDateTime, newEtag, ct);

        logger.LogInformation(
            "System jumps collected: {Count} systems, observation window ending {LastModified:u}",
            jumps.Count, lastModified);

        return expires;
    }

    private async Task<string?> GetLastEtagAsync(CancellationToken ct)
    {
        await using var conn = await dataSource.OpenConnectionAsync(ct);
        return await conn.QuerySingleOrDefaultAsync<string?>(
            "SELECT etag FROM system_jump_snapshots ORDER BY snapshot_id DESC LIMIT 1");
    }

    private async Task PersistAsync(
        List<EsiSystemJump> jumps,
        DateTime resourceLastModified,
        string? etag,
        CancellationToken ct)
    {
        await using var conn = await dataSource.OpenConnectionAsync(ct);
        await using var tx   = await conn.BeginTransactionAsync(ct);

        var knownIds = universeService.SolarSystemIds;

        var missing = jumps.Where(j => !knownIds.Contains(j.SolarSystemId)).ToList();
        if (missing.Count > 0)
            logger.LogWarning(
                "Skipping {SkippedCount} systems not present in solar_systems: {SystemIds}",
                missing.Count,
                missing.Select(j => j.SolarSystemId));

        var toInsert = jumps.Where(j => knownIds.Contains(j.SolarSystemId)).ToList();

        var snapshotId = await conn.QuerySingleAsync<long>(
            """
            INSERT INTO system_jump_snapshots (fetched_at, resource_last_modified, etag, system_count)
            VALUES (@FetchedAt, @ResourceLastModified, @Etag, @SystemCount)
            RETURNING snapshot_id
            """,
            new
            {
                FetchedAt            = DateTime.UtcNow,
                ResourceLastModified = resourceLastModified,
                Etag                 = etag,
                SystemCount          = jumps.Count,
            },
            transaction: tx);

        if (toInsert.Count > 0)
            await conn.ExecuteAsync(
                """
                INSERT INTO system_jump_counts (snapshot_id, solar_system_id, ship_jumps)
                VALUES (@SnapshotId, @SolarSystemId, @ShipJumps)
                """,
                toInsert.Select(j => new { SnapshotId = snapshotId, j.SolarSystemId, j.ShipJumps }),
                transaction: tx);

        await tx.CommitAsync(ct);
    }
}

internal sealed record EsiSystemJump(
    [property: JsonPropertyName("system_id")]  int SolarSystemId,
    [property: JsonPropertyName("ship_jumps")] int ShipJumps);
