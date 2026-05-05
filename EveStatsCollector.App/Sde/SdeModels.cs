namespace EveStatsCollector.Sde;

using System.Text.Json.Serialization;

// JSON property names match EVE SDE JSONL conventions (build 3328718).
// If deserialization yields unexpected nulls, verify names against the actual JSONL files.

internal sealed record LocalizedString(
    [property: JsonPropertyName("en")] string? En);

internal sealed record SdeFaction(
    [property: JsonPropertyName("_key")]  int            FactionId,
    [property: JsonPropertyName("name")]  LocalizedString Name);

internal sealed record SdeRegion(
    [property: JsonPropertyName("_key")]            int             Id,
    [property: JsonPropertyName("name")]            LocalizedString Name,
    [property: JsonPropertyName("factionID")]       int?            FactionId,
    [property: JsonPropertyName("wormholeClassID")] short?          WormholeClass,
    [property: JsonPropertyName("position")]        SdePosition?    Position);

internal sealed record SdePosition(
    [property: JsonPropertyName("x")] double X,
    [property: JsonPropertyName("y")] double Y,
    [property: JsonPropertyName("z")] double Z);

internal sealed record SdeConstellation(
    [property: JsonPropertyName("_key")]            int             Id,
    [property: JsonPropertyName("name")]            LocalizedString Name,
    [property: JsonPropertyName("regionID")]        int             RegionId,
    [property: JsonPropertyName("factionID")]       int?            FactionId,
    [property: JsonPropertyName("wormholeClassID")] short?          WormholeClass,
    [property: JsonPropertyName("position")]        SdePosition?    Position);

internal sealed record SdeSolarSystem(
    [property: JsonPropertyName("_key")]            int             Id,
    [property: JsonPropertyName("constellationID")] int             ConstellationId,
    [property: JsonPropertyName("regionID")]        int             RegionId,
    [property: JsonPropertyName("name")]            LocalizedString Name,
    [property: JsonPropertyName("securityStatus")]  float           SecurityStatus,
    [property: JsonPropertyName("securityClass")]   string?         SecurityClass   = null,
    [property: JsonPropertyName("starID")]          int?            StarId          = null,
    [property: JsonPropertyName("luminosity")]      float?          Luminosity      = null,
    [property: JsonPropertyName("radius")]          double?         Radius          = null,
    [property: JsonPropertyName("border")]          bool            IsBorder        = false,
    [property: JsonPropertyName("corridor")]        bool            IsCorridor      = false,
    [property: JsonPropertyName("fringe")]          bool            IsFringe        = false,
    [property: JsonPropertyName("hub")]             bool            IsHub           = false,
    [property: JsonPropertyName("international")]   bool            IsInternational = false,
    [property: JsonPropertyName("regional")]        bool            IsRegional      = false,
    [property: JsonPropertyName("position")]        SdePosition?    Position        = null);
