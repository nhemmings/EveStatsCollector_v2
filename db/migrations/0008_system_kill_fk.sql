ALTER TABLE system_kill_counts
    ADD CONSTRAINT fk_system_kill_counts_solar_system
    FOREIGN KEY (solar_system_id) REFERENCES solar_systems(solar_system_id);

COMMENT ON COLUMN system_kill_counts.solar_system_id IS 'EVE solar system ID. FK to solar_systems(solar_system_id). Rows where the system is not present in solar_systems are skipped at collection time with a warning logged.';

COMMENT ON COLUMN system_kill_snapshots.system_count IS 'Number of solar systems in the ESI response for this snapshot. May exceed the actual row count in system_kill_counts if some systems were not yet present in the local solar_systems table when the snapshot was collected.';
