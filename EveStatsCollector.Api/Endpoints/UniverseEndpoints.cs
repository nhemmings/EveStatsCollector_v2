namespace EveStatsCollector.Api.Endpoints;

using Dapper;
using Npgsql;

public static class UniverseEndpoints
{
    public static IEndpointRouteBuilder MapUniverseEndpoints(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/api/regions", GetRegions).WithName("GetRegions");
        routes.MapGet("/api/constellations", GetConstellations).WithName("GetConstellations");
        return routes;
    }

    private static async Task<IResult> GetRegions(NpgsqlDataSource db)
    {
        using var conn = await db.OpenConnectionAsync();
        var results = await conn.QueryAsync<Region>(
            "SELECT region_id, name FROM regions ORDER BY name");
        return Results.Ok(results);
    }

    private static async Task<IResult> GetConstellations(NpgsqlDataSource db, int? regionId = null)
    {
        using var conn = await db.OpenConnectionAsync();
        var results = await conn.QueryAsync<Constellation>(
            """
            SELECT constellation_id, region_id, name FROM constellations
            WHERE (@regionId::int IS NULL OR region_id = @regionId)
            ORDER BY name
            """,
            new { regionId });
        return Results.Ok(results);
    }
}

internal record Region(int RegionId, string Name);

internal record Constellation(int ConstellationId, int RegionId, string Name);
