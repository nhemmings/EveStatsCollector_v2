-- Every item, ship, module, charge, skill, and structure in EVE Online.
CREATE TABLE types (
    type_id                   INTEGER       PRIMARY KEY,
    group_id                  INTEGER       NOT NULL REFERENCES groups,
    name                      TEXT          NOT NULL,
    description               TEXT,
    mass                      FLOAT8,
    volume                    FLOAT8,
    capacity                  FLOAT8,
    radius                    FLOAT8,
    base_price                NUMERIC(18,2),
    portion_size              INTEGER       NOT NULL DEFAULT 1,
    published                 BOOLEAN       NOT NULL DEFAULT false,
    market_group_id           INTEGER       REFERENCES market_groups,
    meta_group_id             SMALLINT      REFERENCES meta_groups,
    meta_level                SMALLINT,
    faction_id                INTEGER       REFERENCES factions,
    race_id                   SMALLINT      REFERENCES races,
    graphic_id                INTEGER,
    icon_id                   INTEGER,
    sound_id                  INTEGER,
    variation_parent_type_id  INTEGER       REFERENCES types
);

COMMENT ON TABLE  types                          IS 'Every item in EVE: ships, modules, ammunition, skills, ore, blueprints, structures, etc. The central reference table for all market and industry data.';
COMMENT ON COLUMN types.type_id                  IS 'Unique item type identifier. Stable across patches; used throughout the ESI API.';
COMMENT ON COLUMN types.name                     IS 'English display name (e.g. "Rifter", "Tritanium", "Small Shield Booster II").';
COMMENT ON COLUMN types.published                IS 'False for internal or removed items not visible in the game client.';
COMMENT ON COLUMN types.portion_size             IS 'How many units are produced in one manufacturing run or reprocessed at once (usually 1; higher for ammo and minerals).';
COMMENT ON COLUMN types.volume                   IS 'Volume in m³. Determines how much cargo space the item occupies.';
COMMENT ON COLUMN types.capacity                 IS 'Internal cargo or drone bay capacity in m³ (ships and containers only).';
COMMENT ON COLUMN types.base_price               IS 'NPC base price in ISK, used as a fallback for insurance and trade calculations.';
COMMENT ON COLUMN types.meta_group_id            IS 'Technology tier: 1=Tech I, 2=Tech II, 4=Faction, 5=Officer, 6=Deadspace, etc.';
COMMENT ON COLUMN types.meta_level               IS 'Numeric power progression within a type family (higher = more powerful).';
COMMENT ON COLUMN types.market_group_id          IS 'Leaf market group this type appears under. NULL if the type is not sold on the market.';
COMMENT ON COLUMN types.variation_parent_type_id IS 'For Tech II / faction / officer variants, the Tech I base type they derive from.';

CREATE INDEX idx_types_group_id              ON types(group_id);
CREATE INDEX idx_types_market_group_id       ON types(market_group_id)          WHERE market_group_id          IS NOT NULL;
CREATE INDEX idx_types_published             ON types(published)                 WHERE published                = true;
CREATE INDEX idx_types_meta_group_id         ON types(meta_group_id)             WHERE meta_group_id            IS NOT NULL;
CREATE INDEX idx_types_faction_id            ON types(faction_id)                WHERE faction_id               IS NOT NULL;
CREATE INDEX idx_types_race_id               ON types(race_id)                   WHERE race_id                  IS NOT NULL;
CREATE INDEX idx_types_variation_parent      ON types(variation_parent_type_id)  WHERE variation_parent_type_id IS NOT NULL;
CREATE INDEX idx_types_name                  ON types(name);
