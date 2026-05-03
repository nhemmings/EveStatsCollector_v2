-- Universe geography: factions, regions, constellations, solar systems.
-- Hand-maintained reference — never executed by DbUp.

CREATE TABLE factions (
    faction_id  INTEGER  PRIMARY KEY,
    name        TEXT     NOT NULL
);

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
