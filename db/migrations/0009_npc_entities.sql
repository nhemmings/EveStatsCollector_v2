-- NPC corporations (Caldari Navy, Sisters of EVE, Jita 4-4 owner, etc.).
CREATE TABLE npc_corporations (
    corporation_id                 INTEGER    PRIMARY KEY,
    name                           TEXT       NOT NULL,
    description                    TEXT,
    ticker_name                    TEXT,
    faction_id                     INTEGER    REFERENCES factions,
    race_id                        SMALLINT   REFERENCES races,
    solar_system_id                INTEGER    REFERENCES solar_systems,
    station_id                     INTEGER,   -- home station; refs npc_stations (created below)
    extent                         CHAR(1),
    size                           CHAR(1),
    size_factor                    FLOAT4,
    tax_rate                       FLOAT4,
    member_limit                   INTEGER,
    min_security                   FLOAT4,
    minimum_join_standing          SMALLINT,
    ceo_id                         INTEGER,
    icon_id                        INTEGER,
    initial_price                  INTEGER,
    shares                         BIGINT,
    send_char_termination_message  BOOLEAN,
    has_player_personnel_manager   BOOLEAN,
    unique_name                    BOOLEAN    NOT NULL DEFAULT true,
    deleted                        BOOLEAN    NOT NULL DEFAULT false,
    main_activity_id               SMALLINT,
    secondary_activity_id          SMALLINT,
    enemy_id                       INTEGER    REFERENCES npc_corporations,
    friend_id                      INTEGER    REFERENCES npc_corporations
);

COMMENT ON TABLE  npc_corporations            IS 'NPC corporations such as Caldari Navy, Sisters of EVE, and station owners. Not player corporations.';
COMMENT ON COLUMN npc_corporations.extent     IS 'Geographic scope: G=global, N=national, R=regional, C=constellation, S=solarsystem, L=local.';
COMMENT ON COLUMN npc_corporations.station_id IS 'Home NPC station. References npc_stations.station_id (enforced at import time).';
COMMENT ON COLUMN npc_corporations.enemy_id   IS 'Rival NPC corporation (self-referencing).';
COMMENT ON COLUMN npc_corporations.friend_id  IS 'Allied NPC corporation (self-referencing).';
COMMENT ON COLUMN npc_corporations.deleted    IS 'True for corporations that have been removed from the game.';

CREATE INDEX idx_npc_corporations_faction_id      ON npc_corporations(faction_id)      WHERE faction_id      IS NOT NULL;
CREATE INDEX idx_npc_corporations_race_id         ON npc_corporations(race_id)         WHERE race_id         IS NOT NULL;
CREATE INDEX idx_npc_corporations_solar_system_id ON npc_corporations(solar_system_id) WHERE solar_system_id IS NOT NULL;

-- Junction: which races are permitted to join each NPC corporation.
CREATE TABLE npc_corporation_races (
    corporation_id  INTEGER    NOT NULL REFERENCES npc_corporations,
    race_id         SMALLINT   NOT NULL REFERENCES races,
    PRIMARY KEY (corporation_id, race_id)
);

CREATE INDEX idx_npc_corporation_races_race_id ON npc_corporation_races(race_id);

-- NPC stations — fixed, CCP-owned stations (not player-built structures).
CREATE TABLE npc_stations (
    station_id                  INTEGER    PRIMARY KEY,
    solar_system_id             INTEGER    NOT NULL REFERENCES solar_systems,
    type_id                     INTEGER    NOT NULL REFERENCES types,
    owner_id                    INTEGER    NOT NULL REFERENCES npc_corporations,
    operation_id                SMALLINT,
    orbit_id                    INTEGER,
    celestial_index             SMALLINT,
    orbit_index                 SMALLINT,
    reprocessing_efficiency     FLOAT4     NOT NULL DEFAULT 0.5,
    reprocessing_stations_take  FLOAT4     NOT NULL DEFAULT 0.05,
    reprocessing_hangar_flag    SMALLINT,
    use_operation_name          BOOLEAN    NOT NULL DEFAULT false,
    pos_x                       FLOAT8     NOT NULL,
    pos_y                       FLOAT8     NOT NULL,
    pos_z                       FLOAT8     NOT NULL
);

COMMENT ON TABLE  npc_stations                          IS 'Permanent NPC-owned stations (e.g. Jita 4-4, Amarr VIII). Player-built structures (Citadels) are tracked separately via the ESI API.';
COMMENT ON COLUMN npc_stations.owner_id                 IS 'The NPC corporation that owns and operates this station.';
COMMENT ON COLUMN npc_stations.reprocessing_efficiency  IS 'Base reprocessing yield (0.0–1.0). Actual yield depends on player skills and standings.';
COMMENT ON COLUMN npc_stations.reprocessing_stations_take IS 'Fraction of reprocessed minerals the station keeps as a fee.';
COMMENT ON COLUMN npc_stations.orbit_id                 IS 'ID of the celestial body this station orbits (planet, moon, or asteroid belt).';

CREATE INDEX idx_npc_stations_solar_system_id ON npc_stations(solar_system_id);
CREATE INDEX idx_npc_stations_owner_id        ON npc_stations(owner_id);
CREATE INDEX idx_npc_stations_type_id         ON npc_stations(type_id);
