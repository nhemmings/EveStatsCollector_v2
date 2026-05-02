-- NPC corporations and stations.
-- Hand-maintained reference — never executed by DbUp.
-- Note: npc_corporations.station_id and factions.corporation_id / militia_corporation_id have
-- DEFERRABLE INITIALLY DEFERRED FK constraints added in migration 0009 once all tables exist.
-- Shown here without those constraints for readability.

CREATE TABLE npc_corporations (
    corporation_id                 INTEGER    PRIMARY KEY,
    name                           TEXT       NOT NULL,
    description                    TEXT,
    ticker_name                    TEXT,
    faction_id                     INTEGER    REFERENCES factions,
    race_id                        SMALLINT   REFERENCES races,
    solar_system_id                INTEGER    REFERENCES solar_systems,
    station_id                     INTEGER,
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

CREATE TABLE npc_corporation_races (
    corporation_id  INTEGER    NOT NULL REFERENCES npc_corporations,
    race_id         SMALLINT   NOT NULL REFERENCES races,
    PRIMARY KEY (corporation_id, race_id)
);

CREATE TABLE npc_stations (
    station_id                  INTEGER    PRIMARY KEY,
    name                        TEXT,
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
