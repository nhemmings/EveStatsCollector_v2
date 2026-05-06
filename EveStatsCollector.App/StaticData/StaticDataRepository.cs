namespace EveStatsCollector.StaticData;

using Dapper;
using Npgsql;

internal sealed class StaticDataRepository(NpgsqlDataSource dataSource)
{
    public async Task UpsertAsync(
        List<Faction>       factions,
        List<Region>        regions,
        List<Constellation> constellations,
        List<SolarSystem>   solarSystems,
        int                 buildNumber,
        DateTimeOffset      releaseDate,
        CancellationToken   ct)
    {
        await using var conn = await dataSource.OpenConnectionAsync(ct);
        await using var tx   = await conn.BeginTransactionAsync(ct);

        await conn.ExecuteAsync(
            """
            INSERT INTO factions (faction_id, name)
            VALUES (@FactionId, @FactionName)
            ON CONFLICT (faction_id) DO UPDATE SET name = EXCLUDED.name
            """,
            factions.Select(f => new
            {
                f.FactionId,
                FactionName = f.Name.En ?? throw new InvalidOperationException($"Faction {f.FactionId} has no English name"),
            }),
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
                var pos = r.Position ?? throw new InvalidOperationException($"Region {r.Id} has no position");
                return new
                {
                    RegionId      = r.Id,
                    Name          = r.Name.En ?? throw new InvalidOperationException($"Region {r.Id} has no English name"),
                    r.FactionId,
                    r.WormholeClass,
                    PosX          = pos.X,
                    PosY          = pos.Y,
                    PosZ          = pos.Z,
                };
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
                var pos = c.Position ?? throw new InvalidOperationException($"Constellation {c.Id} has no position");
                return new
                {
                    ConstellationId = c.Id,
                    c.RegionId,
                    Name            = c.Name.En ?? throw new InvalidOperationException($"Constellation {c.Id} has no English name"),
                    c.FactionId,
                    c.WormholeClass,
                    PosX            = pos.X,
                    PosY            = pos.Y,
                    PosZ            = pos.Z,
                };
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
                var pos = s.Position ?? throw new InvalidOperationException($"Solar system {s.Id} has no position");
                return new
                {
                    SolarSystemId    = s.Id,
                    s.ConstellationId,
                    s.RegionId,
                    Name             = s.Name.En ?? throw new InvalidOperationException($"Solar system {s.Id} has no English name"),
                    s.SecurityStatus,
                    s.SecurityClass,
                    s.StarId,
                    s.Luminosity,
                    s.Radius,
                    s.IsBorder,
                    s.IsCorridor,
                    s.IsFringe,
                    s.IsHub,
                    s.IsInternational,
                    s.IsRegional,
                    PosX             = pos.X,
                    PosY             = pos.Y,
                    PosZ             = pos.Z,
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
