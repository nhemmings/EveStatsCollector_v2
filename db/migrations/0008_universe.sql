-- Universe regions (e.g. The Forge, Delve, Derelik).
CREATE TABLE regions (
    region_id      INTEGER   PRIMARY KEY,
    name           TEXT      NOT NULL,
    description    TEXT,
    faction_id     INTEGER   REFERENCES factions,
    wormhole_class SMALLINT,
    pos_x          FLOAT8    NOT NULL,
    pos_y          FLOAT8    NOT NULL,
    pos_z          FLOAT8    NOT NULL
);

COMMENT ON TABLE  regions               IS 'Top-level geographic divisions of the EVE universe (e.g. "The Forge", "Delve", "Derelik"). Regions contain constellations.';
COMMENT ON COLUMN regions.faction_id    IS 'Controlling NPC faction, if any. NULL for null-sec and wormhole regions.';
COMMENT ON COLUMN regions.wormhole_class IS 'Wormhole class (1–6) for wormhole regions; NULL for k-space.';
COMMENT ON COLUMN regions.pos_x         IS 'X coordinate in metres (EVE universe coordinate system, FLOAT8 needed for scale).';

CREATE INDEX idx_regions_faction_id ON regions(faction_id) WHERE faction_id IS NOT NULL;

-- Constellations — groups of solar systems within a region.
CREATE TABLE constellations (
    constellation_id  INTEGER   PRIMARY KEY,
    region_id         INTEGER   NOT NULL REFERENCES regions,
    name              TEXT      NOT NULL,
    faction_id        INTEGER   REFERENCES factions,
    wormhole_class    SMALLINT,
    pos_x             FLOAT8    NOT NULL,
    pos_y             FLOAT8    NOT NULL,
    pos_z             FLOAT8    NOT NULL
);

COMMENT ON TABLE  constellations            IS 'Mid-level geographic divisions. Each constellation contains several solar systems and belongs to one region.';
COMMENT ON COLUMN constellations.faction_id IS 'Controlling NPC faction, if different from the region. Usually NULL.';

CREATE INDEX idx_constellations_region_id  ON constellations(region_id);
CREATE INDEX idx_constellations_faction_id ON constellations(faction_id) WHERE faction_id IS NOT NULL;

-- Solar systems — every star system in the EVE universe.
CREATE TABLE solar_systems (
    solar_system_id   INTEGER   PRIMARY KEY,
    constellation_id  INTEGER   NOT NULL REFERENCES constellations,
    region_id         INTEGER   NOT NULL REFERENCES regions,
    name              TEXT      NOT NULL,
    security_status   FLOAT4    NOT NULL,
    security_class    VARCHAR(2),
    star_id           INTEGER,
    luminosity        FLOAT4,
    radius            FLOAT8,
    is_border         BOOLEAN   NOT NULL DEFAULT false,
    is_corridor       BOOLEAN   NOT NULL DEFAULT false,
    is_fringe         BOOLEAN   NOT NULL DEFAULT false,
    is_hub            BOOLEAN   NOT NULL DEFAULT false,
    is_international  BOOLEAN   NOT NULL DEFAULT false,
    is_regional       BOOLEAN   NOT NULL DEFAULT false,
    pos_x             FLOAT8    NOT NULL,
    pos_y             FLOAT8    NOT NULL,
    pos_z             FLOAT8    NOT NULL
);

COMMENT ON TABLE  solar_systems                  IS 'Every solar system in EVE. Includes k-space (30xxxxxx), wormhole (31xxxxxx), and abyssal (32xxxxxx) systems.';
COMMENT ON COLUMN solar_systems.security_status  IS 'True security status from -1.0 (most dangerous) to ~1.0 (safest). >= 0.45 = high-sec, 0.0–0.45 = low-sec, < 0.0 = null-sec.';
COMMENT ON COLUMN solar_systems.security_class   IS 'Letter code used by CCP for security banding (e.g. "B", "C").';
COMMENT ON COLUMN solar_systems.region_id        IS 'Denormalised from constellation for query convenience.';
COMMENT ON COLUMN solar_systems.is_hub           IS 'True for major trade hub systems.';
COMMENT ON COLUMN solar_systems.is_border        IS 'True for systems on the border of a region.';
COMMENT ON COLUMN solar_systems.is_fringe        IS 'True for dead-end systems at the edge of a constellation.';

CREATE INDEX idx_solar_systems_constellation_id ON solar_systems(constellation_id);
CREATE INDEX idx_solar_systems_region_id        ON solar_systems(region_id);
CREATE INDEX idx_solar_systems_security_status  ON solar_systems(security_status);
CREATE INDEX idx_solar_systems_name             ON solar_systems(name);

-- Stargates — jump connections between solar systems.
CREATE TABLE stargates (
    stargate_id           INTEGER   PRIMARY KEY,
    solar_system_id       INTEGER   NOT NULL REFERENCES solar_systems,
    dest_solar_system_id  INTEGER   NOT NULL REFERENCES solar_systems,
    dest_stargate_id      INTEGER   NOT NULL,
    type_id               INTEGER   NOT NULL REFERENCES types,
    pos_x                 FLOAT8    NOT NULL,
    pos_y                 FLOAT8    NOT NULL,
    pos_z                 FLOAT8    NOT NULL
);

COMMENT ON TABLE  stargates                    IS 'Stargate connections between solar systems. Each gate has a paired partner in the destination system.';
COMMENT ON COLUMN stargates.dest_stargate_id   IS 'The partner stargate ID in the destination system.';
COMMENT ON COLUMN stargates.dest_solar_system_id IS 'Destination solar system. With solar_system_id, forms a directed edge in the jump graph.';
COMMENT ON COLUMN stargates.type_id            IS 'Gate type (Empire, Faction, Jovian, etc.) which affects its visual appearance.';

CREATE INDEX idx_stargates_solar_system_id      ON stargates(solar_system_id);
CREATE INDEX idx_stargates_dest_solar_system_id ON stargates(dest_solar_system_id);

-- Deferred FK: factions.solar_system_id → solar_systems.
-- factions was created in 0006 before solar_systems existed; constraint added here once the table is in place.
ALTER TABLE factions
    ADD CONSTRAINT fk_factions_solar_system
        FOREIGN KEY (solar_system_id)
        REFERENCES solar_systems (solar_system_id)
        DEFERRABLE INITIALLY DEFERRED;
