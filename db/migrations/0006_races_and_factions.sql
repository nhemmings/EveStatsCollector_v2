-- Player-character races (Caldari, Gallente, Amarr, Minmatar, and others).
CREATE TABLE races (
    race_id       SMALLINT  PRIMARY KEY,
    name          TEXT      NOT NULL,
    description   TEXT,
    icon_id       INTEGER,
    ship_type_id  INTEGER   -- starter ship type; refs types (created in 0007)
);

COMMENT ON TABLE  races              IS 'Playable character races in EVE (Amarr, Caldari, Gallente, Minmatar, and NPC races).';
COMMENT ON COLUMN races.ship_type_id IS 'The starter ship type associated with this race. FK to types.type_id added as DEFERRABLE constraint in migration 0007.';

-- Major NPC factions (Caldari State, Gallente Federation, Amarr Empire, etc.).
CREATE TABLE factions (
    faction_id              INTEGER   PRIMARY KEY,
    name                    TEXT      NOT NULL,
    description             TEXT,
    short_description       TEXT,
    solar_system_id         INTEGER,  -- faction capital; refs solar_systems (created in 0008)
    corporation_id          INTEGER,  -- main NPC corp; refs npc_corporations (created in 0009)
    militia_corporation_id  INTEGER,  -- faction warfare corp; refs npc_corporations
    icon_id                 INTEGER,
    size_factor             FLOAT4,
    unique_name             BOOLEAN   NOT NULL DEFAULT true
);

COMMENT ON TABLE  factions                       IS 'Major NPC factions (e.g. "Caldari State", "Gallente Federation"). Used to classify regions, solar systems, NPC corporations, and contraband rules.';
COMMENT ON COLUMN factions.solar_system_id        IS 'Capital solar system. FK to solar_systems added as DEFERRABLE constraint in migration 0008.';
COMMENT ON COLUMN factions.corporation_id         IS 'Primary NPC corporation. FK to npc_corporations added as DEFERRABLE constraint in migration 0009.';
COMMENT ON COLUMN factions.militia_corporation_id IS 'Faction warfare militia corporation. FK to npc_corporations added as DEFERRABLE constraint in migration 0009.';

-- Junction table: which races belong to each faction.
CREATE TABLE faction_races (
    faction_id  INTEGER   NOT NULL REFERENCES factions,
    race_id     SMALLINT  NOT NULL REFERENCES races,
    PRIMARY KEY (faction_id, race_id)
);

COMMENT ON TABLE faction_races IS 'Member races of each faction (e.g. Caldari State includes the Caldari race).';

CREATE INDEX idx_faction_races_race_id ON faction_races(race_id);
