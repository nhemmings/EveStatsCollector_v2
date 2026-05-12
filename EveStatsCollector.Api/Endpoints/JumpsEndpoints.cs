namespace EveStatsCollector.Api.Endpoints;

using Dapper;
using Npgsql;

public static class JumpsEndpoints
{
    public static IEndpointRouteBuilder MapJumpsEndpoints(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/api/systems/jumps", GetSystemJumps).WithName("GetSystemJumps");
        return routes;
    }

    private static async Task<IResult> GetSystemJumps(NpgsqlDataSource db)
    {
        using var conn = await db.OpenConnectionAsync();
        var results = await conn.QueryAsync<SystemJumpStat>(
            """
            SELECT observation_time, solar_system_id, system_name, security_status,
                   constellation_name, region_name, ship_jumps
            FROM v_recent_system_jumps
            ORDER BY ship_jumps DESC
            """);
        return Results.Ok(results);
    }
}

internal record SystemJumpStat(
    DateTimeOffset ObservationTime,
    int SolarSystemId,
    string SystemName,
    double SecurityStatus,
    string ConstellationName,
    string RegionName,
    int ShipJumps);
