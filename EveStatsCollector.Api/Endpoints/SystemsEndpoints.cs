namespace EveStatsCollector.Api.Endpoints;

using Dapper;
using Npgsql;

public static class SystemsEndpoints
{
    public static IEndpointRouteBuilder MapSystemsEndpoints(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/api/systems", GetSystems).WithName("GetSystems");
        return routes;
    }

    private static async Task<IResult> GetSystems(
        NpgsqlDataSource db,
        int? regionId = null,
        string? spaceType = null)
    {
        using var conn = await db.OpenConnectionAsync();
        var results = await conn.QueryAsync<SolarSystem>(
            """
            SELECT solar_system_id, name, security_status, security_class, space_type,
                   constellation_id, constellation_name, region_id, region_name, faction_name
            FROM v_solar_systems
            WHERE (@regionId::int IS NULL OR region_id = @regionId)
              AND (@spaceType::text IS NULL OR space_type = @spaceType)
            ORDER BY name
            """,
            new { regionId, spaceType });
        return Results.Ok(results);
    }
}

internal record SolarSystem(
    int SolarSystemId,
    string Name,
    double SecurityStatus,
    string? SecurityClass,
    string SpaceType,
    int ConstellationId,
    string ConstellationName,
    int RegionId,
    string RegionName,
    string? FactionName);
