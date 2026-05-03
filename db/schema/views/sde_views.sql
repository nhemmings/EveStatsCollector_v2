-- LLM-friendly views over the SDE tables for MCP queries.
-- Hand-maintained reference — never executed by DbUp.

CREATE VIEW v_solar_systems AS
SELECT
    ss.solar_system_id, ss.name, ss.security_status, ss.security_class,
    CASE
        WHEN ss.solar_system_id BETWEEN 31000000 AND 31999999 THEN 'wormhole'
        WHEN ss.solar_system_id >= 32000000 THEN 'abyssal'
        WHEN ss.security_status >= 0.45 THEN 'high-sec'
        WHEN ss.security_status > 0.0 THEN 'low-sec'
        ELSE 'null-sec'
    END AS space_type,
    c.constellation_id, c.name AS constellation_name,
    rg.region_id, rg.name AS region_name,
    f.name AS faction_name
FROM solar_systems ss
JOIN constellations c ON c.constellation_id = ss.constellation_id
JOIN regions rg ON rg.region_id = ss.region_id
LEFT JOIN factions f ON f.faction_id = rg.faction_id;
