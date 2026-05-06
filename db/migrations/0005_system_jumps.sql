CREATE TABLE system_jump_snapshots (
    snapshot_id            BIGSERIAL    PRIMARY KEY,
    fetched_at             TIMESTAMPTZ  NOT NULL DEFAULT now(),
    resource_last_modified TIMESTAMPTZ  NOT NULL,
    etag                   TEXT,
    system_count           INTEGER      NOT NULL
);

COMMENT ON TABLE  system_jump_snapshots IS 'Catalog of hourly system-jump observations pulled from ESI /universe/system_jumps/. CCP aggregates ship jumps over ~1-hour windows; each row here is one CCP-generated snapshot. The resource_last_modified column marks the END of the observation window — jumps recorded in system_jump_counts for this row occurred in the ~1 hour ending at that time. A new row is only inserted when ESI returns a 200 (ETag mismatch), not on 304.';
COMMENT ON COLUMN system_jump_snapshots.fetched_at IS 'UTC timestamp when this application fetched the data from ESI.';
COMMENT ON COLUMN system_jump_snapshots.resource_last_modified IS 'Last-Modified response header value from ESI — the moment CCP computed this snapshot. Jumps in system_jump_counts for this snapshot occurred in the ~1 hour ending at this time. Use this column to filter or aggregate over time ranges.';
COMMENT ON COLUMN system_jump_snapshots.etag IS 'ETag from the ESI response, sent as If-None-Match on the next request. NULL if ESI did not return one.';
COMMENT ON COLUMN system_jump_snapshots.system_count IS 'Number of solar systems included in this snapshot (ESI omits systems with zero jumps).';

CREATE INDEX idx_system_jump_snapshots_resource_last_modified
    ON system_jump_snapshots(resource_last_modified);

CREATE TABLE system_jump_counts (
    snapshot_id      BIGINT   NOT NULL REFERENCES system_jump_snapshots ON DELETE CASCADE,
    solar_system_id  INTEGER  NOT NULL,
    ship_jumps       INTEGER  NOT NULL,
    PRIMARY KEY (snapshot_id, solar_system_id)
);

COMMENT ON TABLE  system_jump_counts IS 'Ship jump counts per solar system for each hourly ESI snapshot. Only systems with at least one jump are included. Join to system_jump_snapshots on snapshot_id to get the observation time window. Join to solar_systems on solar_system_id for system name, security status, and location. To query jumps over a time range, filter system_jump_snapshots.resource_last_modified and join here.';
COMMENT ON COLUMN system_jump_counts.solar_system_id IS 'EVE solar system ID. Matches solar_systems(solar_system_id) but no FK is enforced, so data collection can proceed before the SDE is fully imported.';
COMMENT ON COLUMN system_jump_counts.ship_jumps IS 'Total ship jumps through this system in the ~1-hour window ending at the snapshot resource_last_modified time.';

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

COMMENT ON VIEW v_recent_system_jumps IS 'Ship jumps in the most recent hourly observation, with system name, security status, constellation, and region. For historical data, query system_jump_counts joined to system_jump_snapshots directly.';
