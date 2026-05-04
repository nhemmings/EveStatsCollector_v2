namespace EveStatsCollector.Sde;

using System.Text.Json.Serialization;

// JSON property names match EVE SDE JSONL conventions (build 3328718).
// If deserialization yields unexpected nulls, verify names against the actual JSONL files.

internal sealed record SdeFaction(
    [property: JsonPropertyName("factionID")]   int    FactionId,
    [property: JsonPropertyName("factionName")] string FactionName);

internal sealed record SdeRegion(
    [property: JsonPropertyName("regionID")]        int       RegionId,
    [property: JsonPropertyName("regionName")]      string    RegionName,
    [property: JsonPropertyName("factionID")]       int?      FactionId,
    [property: JsonPropertyName("wormholeClassID")] short?    WormholeClass,
    [property: JsonPropertyName("center")]          double[]? Center);

internal sealed record SdeConstellation(
    [property: JsonPropertyName("constellationID")]   int       ConstellationId,
    [property: JsonPropertyName("constellationName")] string    ConstellationName,
    [property: JsonPropertyName("regionID")]          int       RegionId,
    [property: JsonPropertyName("factionID")]         int?      FactionId,
    [property: JsonPropertyName("wormholeClassID")]   short?    WormholeClass,
    [property: JsonPropertyName("center")]            double[]? Center);

internal sealed record SdeSolarSystem(
    [property: JsonPropertyName("solarSystemID")]   int       SolarSystemId,
    [property: JsonPropertyName("constellationID")] int       ConstellationId,
    [property: JsonPropertyName("regionID")]        int       RegionId,
    [property: JsonPropertyName("solarSystemName")] string    SolarSystemName,
    [property: JsonPropertyName("security")]        float     Security,
    [property: JsonPropertyName("securityClass")]   string?   SecurityClass   = null,
    [property: JsonPropertyName("star")]            SdeStar?  Star            = null,
    [property: JsonPropertyName("luminosity")]      float?    Luminosity      = null,
    [property: JsonPropertyName("radius")]          double?   Radius          = null,
    [property: JsonPropertyName("border")]          bool      IsBorder        = false,
    [property: JsonPropertyName("corridor")]        bool      IsCorridor      = false,
    [property: JsonPropertyName("fringe")]          bool      IsFringe        = false,
    [property: JsonPropertyName("hub")]             bool      IsHub           = false,
    [property: JsonPropertyName("international")]   bool      IsInternational = false,
    [property: JsonPropertyName("regional")]        bool      IsRegional      = false,
    [property: JsonPropertyName("center")]          double[]? Center          = null);

internal sealed record SdeStar(
    [property: JsonPropertyName("id")] int Id);
