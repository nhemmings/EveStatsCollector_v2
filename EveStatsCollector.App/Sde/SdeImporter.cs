namespace EveStatsCollector.Sde;

using System.IO.Compression;
using System.Text.Json;
using Dapper;
using Npgsql;

internal sealed class SdeImporter(
    IHttpClientFactory httpClientFactory,
    NpgsqlDataSource dataSource,
    ILogger<SdeImporter> logger)
{
    private const string LatestMetadataUrl = "https://developers.eveonline.com/static-data/tranquility/latest.jsonl";
    private const string SdeZipUrlTemplate = "https://developers.eveonline.com/static-data/tranquility/eve-online-static-data-{0}-jsonl.zip";

    private static readonly string[] NeededFiles =
        ["factions.jsonl", "mapRegions.jsonl", "mapConstellations.jsonl", "mapSolarSystems.jsonl"];

    public async Task RunIfOutdatedAsync(CancellationToken ct)
    {
        var (latestBuild, latestRelease) = await FetchLatestBuildInfoAsync(ct);

        await using var conn = await dataSource.OpenConnectionAsync(ct);
        var currentBuild = await conn.QuerySingleOrDefaultAsync<int?>("SELECT MAX(build_number) FROM sde_imports");

        if (latestBuild == currentBuild)
        {
            logger.LogDebug("SDE is up to date (build {Build})", latestBuild);
            return;
        }

        logger.LogInformation("New SDE build available: {New} (current: {Current})",
            latestBuild, currentBuild?.ToString() ?? "none");

        await ImportAsync(latestBuild, latestRelease, ct);
    }

    private async Task<(int Build, DateTimeOffset ReleaseDate)> FetchLatestBuildInfoAsync(CancellationToken ct)
    {
        using var http = httpClientFactory.CreateClient("Sde");
        var content = await http.GetStringAsync(LatestMetadataUrl, ct);

        foreach (var line in content.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            using var doc = JsonDocument.Parse(line);
            // latest.jsonl has one JSON object per resource type; the SDE record has a "sde" key at the root
            if (!doc.RootElement.TryGetProperty("sde", out var sde)) continue;

            var build = sde.GetProperty("build").GetInt32();
            var releaseDate = sde.GetProperty("releaseDate").GetDateTimeOffset();
            return (build, releaseDate);
        }

        throw new InvalidOperationException($"Could not find SDE build record in {LatestMetadataUrl}. Raw response:\n{content[..Math.Min(500, content.Length)]}");
    }

    private async Task ImportAsync(int buildNumber, DateTimeOffset releaseDate, CancellationToken ct)
    {
        var tempDir = Directory.CreateTempSubdirectory("sde_").FullName;
        try
        {
            var zipPath = Path.Combine(tempDir, "sde.zip");
            await DownloadZipAsync(buildNumber, zipPath, ct);

            var extractDir = Path.Combine(tempDir, "extracted");
            Directory.CreateDirectory(extractDir);
            ExtractNeededFiles(zipPath, extractDir);

            var factions      = ParseJsonl<SdeFaction>     (Path.Combine(extractDir, "factions.jsonl"));
            var regions       = ParseJsonl<SdeRegion>      (Path.Combine(extractDir, "mapRegions.jsonl"));
            var constellations= ParseJsonl<SdeConstellation>(Path.Combine(extractDir, "mapConstellations.jsonl"));
            var solarSystems  = ParseJsonl<SdeSolarSystem> (Path.Combine(extractDir, "mapSolarSystems.jsonl"));

            logger.LogInformation(
                "Parsed SDE: {Factions} factions, {Regions} regions, {Constellations} constellations, {Systems} solar systems",
                factions.Count, regions.Count, constellations.Count, solarSystems.Count);

            await UpsertAsync(factions, regions, constellations, solarSystems, buildNumber, releaseDate, ct);

            logger.LogInformation("SDE import complete (build {Build})", buildNumber);
        }
        finally
        {
            Directory.Delete(tempDir, recursive: true);
        }
    }

    private async Task DownloadZipAsync(int build, string destPath, CancellationToken ct)
    {
        var url = string.Format(SdeZipUrlTemplate, build);
        logger.LogInformation("Downloading SDE from {Url}", url);

        using var http = httpClientFactory.CreateClient("Sde");
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
                logger.LogDebug("Downloading SDE: {MB:F0} MB", totalBytes / 1_000_000.0);
            }
        }

        logger.LogInformation("Download complete: {MB:F0} MB", totalBytes / 1_000_000.0);
    }

    private static void ExtractNeededFiles(string zipPath, string destDir)
    {
        var needed = new HashSet<string>(NeededFiles, StringComparer.OrdinalIgnoreCase);
        using var zip = ZipFile.OpenRead(zipPath);
        foreach (var entry in zip.Entries)
        {
            if (!needed.Contains(entry.Name)) continue;
            entry.ExtractToFile(Path.Combine(destDir, entry.Name), overwrite: true);
        }
    }

    private static List<T> ParseJsonl<T>(string path)
    {
        var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = false };
        var results = new List<T>();
        foreach (var line in File.ReadLines(path))
        {
            if (string.IsNullOrWhiteSpace(line)) continue;
            var item = JsonSerializer.Deserialize<T>(line, options);
            if (item is not null) results.Add(item);
        }
        return results;
    }

    private async Task UpsertAsync(
        List<SdeFaction>      factions,
        List<SdeRegion>       regions,
        List<SdeConstellation> constellations,
        List<SdeSolarSystem>  solarSystems,
        int                   buildNumber,
        DateTimeOffset        releaseDate,
        CancellationToken     ct)
    {
        await using var conn = await dataSource.OpenConnectionAsync(ct);
        await using var tx   = await conn.BeginTransactionAsync(ct);

        await conn.ExecuteAsync(
            """
            INSERT INTO factions (faction_id, name)
            VALUES (@FactionId, @FactionName)
            ON CONFLICT (faction_id) DO UPDATE SET name = EXCLUDED.name
            """,
            factions.Select(f => new { f.FactionId, f.FactionName }),
            transaction: tx);

        await conn.ExecuteAsync(
            """
            INSERT INTO regions (region_id, name, faction_id, wormhole_class, pos_x, pos_y, pos_z)
            VALUES (@RegionId, @Name, @FactionId, @WormholeClass, @PosX, @PosY, @PosZ)
            ON CONFLICT (region_id) DO UPDATE SET
                name           = EXCLUDED.name,
                faction_id     = EXCLUDED.faction_id,
                wormhole_class = EXCLUDED.wormhole_class,
                pos_x          = EXCLUDED.pos_x,
                pos_y          = EXCLUDED.pos_y,
                pos_z          = EXCLUDED.pos_z
            """,
            regions.Select(r =>
            {
                var c = r.Center ?? throw new InvalidOperationException($"Region {r.RegionId} '{r.RegionName}' has no center coordinates");
                return new { r.RegionId, Name = r.RegionName, r.FactionId, r.WormholeClass, PosX = c[0], PosY = c[1], PosZ = c[2] };
            }),
            transaction: tx);

        await conn.ExecuteAsync(
            """
            INSERT INTO constellations (constellation_id, region_id, name, faction_id, wormhole_class, pos_x, pos_y, pos_z)
            VALUES (@ConstellationId, @RegionId, @Name, @FactionId, @WormholeClass, @PosX, @PosY, @PosZ)
            ON CONFLICT (constellation_id) DO UPDATE SET
                region_id      = EXCLUDED.region_id,
                name           = EXCLUDED.name,
                faction_id     = EXCLUDED.faction_id,
                wormhole_class = EXCLUDED.wormhole_class,
                pos_x          = EXCLUDED.pos_x,
                pos_y          = EXCLUDED.pos_y,
                pos_z          = EXCLUDED.pos_z
            """,
            constellations.Select(c =>
            {
                var pos = c.Center ?? throw new InvalidOperationException($"Constellation {c.ConstellationId} '{c.ConstellationName}' has no center coordinates");
                return new { c.ConstellationId, c.RegionId, Name = c.ConstellationName, c.FactionId, c.WormholeClass, PosX = pos[0], PosY = pos[1], PosZ = pos[2] };
            }),
            transaction: tx);

        await conn.ExecuteAsync(
            """
            INSERT INTO solar_systems (
                solar_system_id, constellation_id, region_id, name,
                security_status, security_class, star_id, luminosity, radius,
                is_border, is_corridor, is_fringe, is_hub, is_international, is_regional,
                pos_x, pos_y, pos_z)
            VALUES (
                @SolarSystemId, @ConstellationId, @RegionId, @Name,
                @SecurityStatus, @SecurityClass, @StarId, @Luminosity, @Radius,
                @IsBorder, @IsCorridor, @IsFringe, @IsHub, @IsInternational, @IsRegional,
                @PosX, @PosY, @PosZ)
            ON CONFLICT (solar_system_id) DO UPDATE SET
                constellation_id = EXCLUDED.constellation_id,
                region_id        = EXCLUDED.region_id,
                name             = EXCLUDED.name,
                security_status  = EXCLUDED.security_status,
                security_class   = EXCLUDED.security_class,
                star_id          = EXCLUDED.star_id,
                luminosity       = EXCLUDED.luminosity,
                radius           = EXCLUDED.radius,
                is_border        = EXCLUDED.is_border,
                is_corridor      = EXCLUDED.is_corridor,
                is_fringe        = EXCLUDED.is_fringe,
                is_hub           = EXCLUDED.is_hub,
                is_international = EXCLUDED.is_international,
                is_regional      = EXCLUDED.is_regional,
                pos_x            = EXCLUDED.pos_x,
                pos_y            = EXCLUDED.pos_y,
                pos_z            = EXCLUDED.pos_z
            """,
            solarSystems.Select(s =>
            {
                var pos = s.Center ?? throw new InvalidOperationException($"Solar system {s.SolarSystemId} '{s.SolarSystemName}' has no center coordinates");
                return new
                {
                    s.SolarSystemId,
                    s.ConstellationId,
                    s.RegionId,
                    Name            = s.SolarSystemName,
                    SecurityStatus  = s.Security,
                    s.SecurityClass,
                    StarId          = s.Star?.Id,
                    s.Luminosity,
                    s.Radius,
                    s.IsBorder,
                    s.IsCorridor,
                    s.IsFringe,
                    s.IsHub,
                    s.IsInternational,
                    s.IsRegional,
                    PosX            = pos[0],
                    PosY            = pos[1],
                    PosZ            = pos[2],
                };
            }),
            transaction: tx);

        await conn.ExecuteAsync(
            """
            INSERT INTO sde_imports (build_number, release_date)
            VALUES (@BuildNumber, @ReleaseDate)
            ON CONFLICT (build_number) DO NOTHING
            """,
            new { BuildNumber = buildNumber, ReleaseDate = releaseDate },
            transaction: tx);

        await tx.CommitAsync(ct);
    }
}
