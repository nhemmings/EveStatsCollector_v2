namespace EveStatsCollector.StaticData;

internal sealed class StaticDataImporter(
    StaticDataBuildChecker buildChecker,
    StaticDataDownloader   downloader,
    StaticDataRepository   repository,
    ILogger<StaticDataImporter> logger)
{
    public async Task RunIfOutdatedAsync(CancellationToken ct)
    {
        var pending = await buildChecker.GetPendingBuildAsync(ct);
        if (pending is null) return;

        var (buildNumber, releaseDate) = pending.Value;
        await ImportAsync(buildNumber, releaseDate, ct);
    }

    private async Task ImportAsync(int buildNumber, DateTimeOffset releaseDate, CancellationToken ct)
    {
        var tempDir = Directory.CreateTempSubdirectory("static_data_").FullName;
        try
        {
            var zipPath = Path.Combine(tempDir, "sde.zip");
            await downloader.DownloadAsync(buildNumber, zipPath, ct);

            var extractDir = Path.Combine(tempDir, "extracted");
            Directory.CreateDirectory(extractDir);
            StaticDataExtractor.Extract(zipPath, extractDir);

            var factions       = StaticDataParser.ParseJsonl<Faction>      (Path.Combine(extractDir, "factions.jsonl"));
            var regions        = StaticDataParser.ParseJsonl<Region>        (Path.Combine(extractDir, "mapRegions.jsonl"));
            var constellations = StaticDataParser.ParseJsonl<Constellation> (Path.Combine(extractDir, "mapConstellations.jsonl"));
            var solarSystems   = StaticDataParser.ParseJsonl<SolarSystem>   (Path.Combine(extractDir, "mapSolarSystems.jsonl"));

            logger.LogInformation(
                "Parsed static data: {Factions} factions, {Regions} regions, {Constellations} constellations, {Systems} solar systems",
                factions.Count, regions.Count, constellations.Count, solarSystems.Count);

            await repository.UpsertAsync(factions, regions, constellations, solarSystems, buildNumber, releaseDate, ct);

            logger.LogInformation("Static data import complete (build {Build})", buildNumber);
        }
        finally
        {
            Directory.Delete(tempDir, recursive: true);
        }
    }
}
