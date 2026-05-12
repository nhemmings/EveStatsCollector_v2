namespace EveStatsCollector.Api.Endpoints;

using Dapper;
using Npgsql;

public static class KillsEndpoints
{
    public static IEndpointRouteBuilder MapKillsEndpoints(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/api/systems/kills", GetSystemKills).WithName("GetSystemKills");
        return routes;
    }

    private static async Task<IResult> GetSystemKills(NpgsqlDataSource db)
    {
        using var conn = await db.OpenConnectionAsync();
        var results = await conn.QueryAsync<SystemKillStat>(
            """
            SELECT observation_time, solar_system_id, system_name, security_status,
                   constellation_name, region_name, npc_kills, pod_kills, ship_kills
            FROM v_recent_system_kills
            ORDER BY ship_kills + npc_kills + pod_kills DESC
            """);
        return Results.Ok(results);
    }
}

internal record SystemKillStat(
    DateTimeOffset ObservationTime,
    int SolarSystemId,
    string SystemName,
    double SecurityStatus,
    string ConstellationName,
    string RegionName,
    int NpcKills,
    int PodKills,
    int ShipKills);
