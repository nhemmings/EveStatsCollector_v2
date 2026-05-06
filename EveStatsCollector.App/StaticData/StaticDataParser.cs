namespace EveStatsCollector.StaticData;

using System.Text.Json;

internal static class StaticDataParser
{
    private static readonly JsonSerializerOptions Options =
        new() { PropertyNameCaseInsensitive = false };

    public static List<T> ParseJsonl<T>(string path)
    {
        var results = new List<T>();
        foreach (var line in File.ReadLines(path))
        {
            if (string.IsNullOrWhiteSpace(line)) continue;
            var item = JsonSerializer.Deserialize<T>(line, Options);
            if (item is not null) results.Add(item);
        }
        return results;
    }
}
