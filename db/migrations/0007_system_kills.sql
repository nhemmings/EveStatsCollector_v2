CREATE TABLE system_kill_snapshots (
    snapshot_id            BIGSERIAL    PRIMARY KEY,
    fetched_at             TIMESTAMPTZ  NOT NULL DEFAULT now(),
    resource_last_modified TIMESTAMPTZ  NOT NULL,
    etag                   TEXT,
    system_count           INTEGER      NOT NULL
);

COMMENT ON TABLE  system_kill_snapshots IS 'Catalog of hourly system-kill observations pulled from ESI /universe/system_kills/. CCP aggregates kill counts over ~1-hour windows; each row is one CCP-generated snapshot. resource_last_modified marks the END of the observation window. A new row is only inserted on 200 (ETag mismatch), not on 304.';
COMMENT ON COLUMN system_kill_snapshots.fetched_at IS 'UTC timestamp when this application fetched the data from ESI.';
COMMENT ON COLUMN system_kill_snapshots.resource_last_modified IS 'Last-Modified response header — the moment CCP computed this snapshot. Kills in system_kill_counts for this snapshot occurred in the ~1 hour ending at this time.';
COMMENT ON COLUMN system_kill_snapshots.etag IS 'ETag from the ESI response, sent as If-None-Match on the next request. NULL if ESI did not return one.';
COMMENT ON COLUMN system_kill_snapshots.system_count IS 'Number of solar systems included in this snapshot (ESI omits systems with zero kills).';

CREATE INDEX idx_system_kill_snapshots_resource_last_modified
    ON system_kill_snapshots(resource_last_modified);

CREATE TABLE system_kill_counts (
    snapshot_id      BIGINT   NOT NULL REFERENCES system_kill_snapshots ON DELETE CASCADE,
    solar_system_id  INTEGER  NOT NULL,
    npc_kills        INTEGER  NOT NULL,
    pod_kills        INTEGER  NOT NULL,
    ship_kills       INTEGER  NOT NULL,
    PRIMARY KEY (snapshot_id, solar_system_id)
);

COMMENT ON TABLE  system_kill_counts IS 'Kill counts per solar system for each hourly ESI snapshot. Only systems with at least one kill are included. Join to system_kill_snapshots on snapshot_id to get the observation time window. Join to solar_systems on solar_system_id for name/security/location.';
COMMENT ON COLUMN system_kill_counts.solar_system_id IS 'EVE solar system ID. Matches solar_systems(solar_system_id) but no FK enforced initially; see migration 0008_system_kill_fk.';
COMMENT ON COLUMN system_kill_counts.npc_kills IS 'NPC kills in this system during the ~1-hour window ending at the snapshot resource_last_modified.';
COMMENT ON COLUMN system_kill_counts.pod_kills IS 'Pod (capsule) kills in this system during the ~1-hour observation window.';
COMMENT ON COLUMN system_kill_counts.ship_kills IS 'Ship kills in this system during the ~1-hour observation window.';

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

COMMENT ON VIEW v_recent_system_kills IS 'Kill counts in the most recent hourly observation, with system name, security status, constellation, and region. For historical data, query system_kill_counts joined to system_kill_snapshots directly.';
