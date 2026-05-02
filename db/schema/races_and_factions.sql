-- Races, factions, and faction-race membership.
-- Hand-maintained reference — never executed by DbUp.
-- Note: races.ship_type_id and factions.solar_system_id / corporation_id /
-- militia_corporation_id have DEFERRABLE INITIALLY DEFERRED FK constraints
-- added in migrations 0007, 0008, and 0009 respectively once the referenced
-- tables exist. Shown here without those constraints for readability.

CREATE TABLE races (
    race_id       SMALLINT  PRIMARY KEY,
    name          TEXT      NOT NULL,
    description   TEXT,
    icon_id       INTEGER,
    ship_type_id  INTEGER
);

CREATE TABLE factions (
    faction_id              INTEGER   PRIMARY KEY,
    name                    TEXT      NOT NULL,
    description             TEXT,
    short_description       TEXT,
    solar_system_id         INTEGER,
    corporation_id          INTEGER,
    militia_corporation_id  INTEGER,
    icon_id                 INTEGER,
    size_factor             FLOAT4,
    unique_name             BOOLEAN   NOT NULL DEFAULT true
);

CREATE TABLE faction_races (
    faction_id  INTEGER   NOT NULL REFERENCES factions,
    race_id     SMALLINT  NOT NULL REFERENCES races,
    PRIMARY KEY (faction_id, race_id)
);
