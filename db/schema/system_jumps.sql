-- System jump statistics collected hourly from ESI.
-- Hand-maintained reference — never executed by DbUp.

CREATE TABLE system_jump_snapshots (
    snapshot_id            BIGSERIAL    PRIMARY KEY,
    fetched_at             TIMESTAMPTZ  NOT NULL DEFAULT now(),
    resource_last_modified TIMESTAMPTZ  NOT NULL,
    etag                   TEXT,
    system_count           INTEGER      NOT NULL
);

CREATE INDEX idx_system_jump_snapshots_resource_last_modified
    ON system_jump_snapshots(resource_last_modified);

CREATE TABLE system_jump_counts (
    snapshot_id      BIGINT   NOT NULL REFERENCES system_jump_snapshots ON DELETE CASCADE,
    solar_system_id  INTEGER  NOT NULL REFERENCES solar_systems(solar_system_id),
    ship_jumps       INTEGER  NOT NULL,
    PRIMARY KEY (snapshot_id, solar_system_id)
);

CREATE INDEX idx_system_jump_counts_solar_system_id
    ON system_jump_counts(solar_system_id);

CREATE VIEW v_recent_system_jumps AS
SELECT
    sn.resource_last_modified  AS observation_time,
    ss.solar_system_id,
    ss.name                    AS system_name,
    ss.security_status,
    c.name                     AS constellation_name,
    r.name                     AS region_name,
    jc.ship_jumps
FROM  system_jump_counts    jc
JOIN  system_jump_snapshots sn ON sn.snapshot_id     = jc.snapshot_id
JOIN  solar_systems         ss ON ss.solar_system_id = jc.solar_system_id
JOIN  constellations        c  ON c.constellation_id = ss.constellation_id
JOIN  regions               r  ON r.region_id        = ss.region_id
WHERE sn.snapshot_id = (SELECT MAX(snapshot_id) FROM system_jump_snapshots);
