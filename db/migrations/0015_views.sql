-- v_types: items with their full classification context.
CREATE VIEW v_types AS
SELECT
    t.type_id,
    t.name,
    t.description,
    t.published,
    t.mass,
    t.volume,
    t.capacity,
    t.base_price,
    t.portion_size,
    t.meta_level,
    g.group_id,
    g.name              AS group_name,
    c.category_id,
    c.name              AS category_name,
    mg.meta_group_id,
    mg.name             AS meta_group_name,
    mkg.market_group_id,
    mkg.name            AS market_group_name,
    f.name              AS faction_name,
    r.name              AS race_name
FROM       types        t
JOIN       groups       g   ON g.group_id        = t.group_id
JOIN       categories   c   ON c.category_id     = g.category_id
LEFT JOIN  meta_groups  mg  ON mg.meta_group_id  = t.meta_group_id
LEFT JOIN  market_groups mkg ON mkg.market_group_id = t.market_group_id
LEFT JOIN  factions     f   ON f.faction_id      = t.faction_id
LEFT JOIN  races        r   ON r.race_id         = t.race_id;

COMMENT ON VIEW v_types IS 'Every item type with its group, category, meta-group, and market-group names resolved. Use for general item lookups.';

-- v_market_types: published items available on the market.
CREATE VIEW v_market_types AS
SELECT *
FROM   v_types
WHERE  published        = true
  AND  market_group_id IS NOT NULL;

COMMENT ON VIEW v_market_types IS 'Published item types that appear on the in-game market. Subset of v_types filtered to traded items only.';

-- v_solar_systems: systems with region/constellation context and security banding.
CREATE VIEW v_solar_systems AS
SELECT
    ss.solar_system_id,
    ss.name,
    ss.security_status,
    ss.security_class,
    CASE
        WHEN ss.solar_system_id BETWEEN 31000000 AND 31999999 THEN 'wormhole'
        WHEN ss.solar_system_id >= 32000000                   THEN 'abyssal'
        WHEN ss.security_status >= 0.45                       THEN 'high-sec'
        WHEN ss.security_status >  0.0                        THEN 'low-sec'
        ELSE                                                       'null-sec'
    END                AS space_type,
    c.constellation_id,
    c.name             AS constellation_name,
    rg.region_id,
    rg.name            AS region_name,
    f.name             AS faction_name
FROM       solar_systems  ss
JOIN       constellations c   ON c.constellation_id = ss.constellation_id
JOIN       regions        rg  ON rg.region_id        = ss.region_id
LEFT JOIN  factions       f   ON f.faction_id        = rg.faction_id;

COMMENT ON VIEW v_solar_systems IS 'Solar systems with constellation, region, faction, and a human-readable space_type label (high-sec / low-sec / null-sec / wormhole / abyssal).';

-- v_jumps: stargate connections with system and region names on both ends.
CREATE VIEW v_jumps AS
SELECT
    sg.stargate_id,
    sg.solar_system_id          AS from_system_id,
    ss_f.name                   AS from_system_name,
    rg_f.name                   AS from_region_name,
    sg.dest_solar_system_id     AS to_system_id,
    ss_t.name                   AS to_system_name,
    rg_t.name                   AS to_region_name
FROM       stargates      sg
JOIN       solar_systems  ss_f  ON ss_f.solar_system_id = sg.solar_system_id
JOIN       solar_systems  ss_t  ON ss_t.solar_system_id = sg.dest_solar_system_id
JOIN       regions        rg_f  ON rg_f.region_id        = ss_f.region_id
JOIN       regions        rg_t  ON rg_t.region_id        = ss_t.region_id;

COMMENT ON VIEW v_jumps IS 'All stargate connections as directed edges with resolved system and region names. Useful for jump-count queries and route analysis.';

-- v_type_attributes: dogma attribute values with human-readable names and units.
CREATE VIEW v_type_attributes AS
SELECT
    t.type_id,
    t.name                   AS type_name,
    da.attribute_id,
    da.name                  AS attribute_name,
    da.display_name          AS attribute_display_name,
    tda.value,
    du.display_name          AS unit,
    da.high_is_good
FROM       type_dogma_attributes  tda
JOIN       types                  t   ON t.type_id        = tda.type_id
JOIN       dogma_attributes       da  ON da.attribute_id  = tda.attribute_id
LEFT JOIN  dogma_units            du  ON du.unit_id        = da.unit_id;

COMMENT ON VIEW v_type_attributes IS 'Dogma attribute values joined to their attribute definitions and units. Use to look up item stats by name (e.g. cpuOutput, shieldCapacity, maxTargetRange).';

-- v_reprocessing: what each item yields when reprocessed.
CREATE VIEW v_reprocessing AS
SELECT
    t.type_id,
    t.name          AS type_name,
    g.name          AS type_group,
    mt.type_id      AS material_type_id,
    mt.name         AS material_name,
    tm.quantity
FROM       type_materials  tm
JOIN       types           t   ON t.type_id  = tm.type_id
JOIN       types           mt  ON mt.type_id = tm.material_type_id
JOIN       groups          g   ON g.group_id = t.group_id;

COMMENT ON VIEW v_reprocessing IS 'Base reprocessing yields for all items. Quantities are before efficiency, skills, and structure bonuses are applied.';

-- v_blueprint_inputs: materials required by each blueprint activity.
CREATE VIEW v_blueprint_inputs AS
SELECT
    ba.blueprint_type_id,
    bt.name                AS blueprint_name,
    ba.activity,
    ba.time_seconds,
    bm.material_type_id,
    mt.name                AS material_name,
    bm.quantity
FROM       blueprint_activities  ba
JOIN       types                 bt  ON bt.type_id           = ba.blueprint_type_id
JOIN       blueprint_materials   bm  ON bm.blueprint_type_id = ba.blueprint_type_id
                                    AND bm.activity          = ba.activity
JOIN       types                 mt  ON mt.type_id           = bm.material_type_id;

COMMENT ON VIEW v_blueprint_inputs IS 'Input materials for each blueprint activity with resolved type names. Base quantities before material efficiency research.';

-- v_blueprint_outputs: products from each blueprint activity.
CREATE VIEW v_blueprint_outputs AS
SELECT
    ba.blueprint_type_id,
    bt.name                AS blueprint_name,
    ba.activity,
    ba.time_seconds,
    bp.product_type_id,
    pt.name                AS product_name,
    bp.quantity,
    bp.probability
FROM       blueprint_activities  ba
JOIN       types                 bt  ON bt.type_id            = ba.blueprint_type_id
JOIN       blueprint_products    bp  ON bp.blueprint_type_id  = ba.blueprint_type_id
                                    AND bp.activity           = ba.activity
JOIN       types                 pt  ON pt.type_id            = bp.product_type_id;

COMMENT ON VIEW v_blueprint_outputs IS 'Products of each blueprint activity. For invention, probability < 1.0 indicates a chance-based output.';

-- v_npc_stations: stations with their system and owning corporation name.
CREATE VIEW v_npc_stations AS
SELECT
    ns.station_id,
    t.name                AS station_type,
    ss.solar_system_id,
    ss.name               AS solar_system_name,
    rg.name               AS region_name,
    ss.security_status,
    nc.corporation_id     AS owner_id,
    nc.name               AS owner_name,
    f.name                AS faction_name,
    ns.reprocessing_efficiency,
    ns.reprocessing_stations_take
FROM       npc_stations    ns
JOIN       solar_systems   ss  ON ss.solar_system_id = ns.solar_system_id
JOIN       regions         rg  ON rg.region_id        = ss.region_id
JOIN       npc_corporations nc  ON nc.corporation_id   = ns.owner_id
JOIN       types           t   ON t.type_id           = ns.type_id
LEFT JOIN  factions        f   ON f.faction_id        = rg.faction_id;

COMMENT ON VIEW v_npc_stations IS 'NPC stations with resolved system, region, owner corporation, and faction names. Useful for market location queries.';
