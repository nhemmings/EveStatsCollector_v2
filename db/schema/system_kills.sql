-- System kill statistics collected hourly from ESI.
-- Hand-maintained reference — never executed by DbUp.

CREATE TABLE system_kill_snapshots (
    snapshot_id            BIGSERIAL    PRIMARY KEY,
    fetched_at             TIMESTAMPTZ  NOT NULL DEFAULT now(),
    resource_last_modified TIMESTAMPTZ  NOT NULL,
    etag                   TEXT,
    system_count           INTEGER      NOT NULL
);

CREATE INDEX idx_system_kill_snapshots_resource_last_modified
    ON system_kill_snapshots(resource_last_modified);

CREATE TABLE system_kill_counts (
    snapshot_id      BIGINT   NOT NULL REFERENCES system_kill_snapshots ON DELETE CASCADE,
    solar_system_id  INTEGER  NOT NULL REFERENCES solar_systems(solar_system_id),
    npc_kills        INTEGER  NOT NULL,
    pod_kills        INTEGER  NOT NULL,
    ship_kills       INTEGER  NOT NULL,
    PRIMARY KEY (snapshot_id, solar_system_id)
);

CREATE INDEX idx_system_kill_counts_solar_system_id
    ON system_kill_counts(solar_system_id);

CREATE VIEW v_recent_system_kills AS
SELECT
    sn.resource_last_modified  AS observation_time,
    ss.solar_system_id,
    ss.name                    AS system_name,
    ss.security_status,
    c.name                     AS constellation_name,
    r.name                     AS region_name,
    kc.npc_kills,
    kc.pod_kills,
    kc.ship_kills
FROM  system_kill_counts    kc
JOIN  system_kill_snapshots sn ON sn.snapshot_id     = kc.snapshot_id
JOIN  solar_systems         ss ON ss.solar_system_id = kc.solar_system_id
JOIN  constellations        c  ON c.constellation_id = ss.constellation_id
JOIN  regions               r  ON r.region_id        = ss.region_id
WHERE sn.snapshot_id = (SELECT MAX(snapshot_id) FROM system_kill_snapshots);
