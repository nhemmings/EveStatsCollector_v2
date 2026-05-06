namespace EveStatsCollector.StaticData;

using System.IO.Compression;

internal static class StaticDataExtractor
{
    private static readonly HashSet<string> NeededFiles = new(
        ["factions.jsonl", "mapRegions.jsonl", "mapConstellations.jsonl", "mapSolarSystems.jsonl"],
        StringComparer.OrdinalIgnoreCase);

    public static void Extract(string zipPath, string destDir)
    {
        using var zip = ZipFile.OpenRead(zipPath);
        foreach (var entry in zip.Entries)
        {
            if (!NeededFiles.Contains(entry.Name)) continue;
            entry.ExtractToFile(Path.Combine(destDir, entry.Name), overwrite: true);
        }
    }
}
