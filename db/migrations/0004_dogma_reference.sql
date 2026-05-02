-- Units of measurement used by dogma attributes (e.g. metres, seconds, MW).
CREATE TABLE dogma_units (
    unit_id      SMALLINT  PRIMARY KEY,
    name         TEXT      NOT NULL,
    display_name TEXT,
    description  TEXT
);

COMMENT ON TABLE  dogma_units              IS 'Units of measurement for dogma attribute values (e.g. "m", "MW", "tf").';
COMMENT ON COLUMN dogma_units.name         IS 'Internal unit name (e.g. "Length", "Mass").';
COMMENT ON COLUMN dogma_units.display_name IS 'Short symbol shown in the UI (e.g. "m", "kg").';

-- Groupings for dogma attributes shown in the fitting window.
CREATE TABLE dogma_attribute_categories (
    category_id  SMALLINT  PRIMARY KEY,
    name         TEXT      NOT NULL,
    description  TEXT
);

COMMENT ON TABLE dogma_attribute_categories IS 'Groupings for dogma attributes as displayed in the EVE fitting and info windows.';

-- Attribute definitions — the schema for item statistics.
CREATE TABLE dogma_attributes (
    attribute_id           INTEGER   PRIMARY KEY,
    name                   TEXT      NOT NULL,
    display_name           TEXT,
    description            TEXT,
    tooltip_description    TEXT,
    tooltip_title          TEXT,
    attribute_category_id  SMALLINT  REFERENCES dogma_attribute_categories,
    unit_id                SMALLINT  REFERENCES dogma_units,
    data_type              SMALLINT  NOT NULL DEFAULT 0,
    default_value          FLOAT8,
    icon_id                INTEGER,
    published              BOOLEAN   NOT NULL DEFAULT false,
    stackable              BOOLEAN   NOT NULL DEFAULT true,
    high_is_good           BOOLEAN   NOT NULL DEFAULT true,
    display_when_zero      BOOLEAN   NOT NULL DEFAULT false
);

COMMENT ON TABLE  dogma_attributes                IS 'Definitions of all item attributes (e.g. "cpuOutput", "shieldCapacity"). Pair with type_dogma_attributes for actual per-type values.';
COMMENT ON COLUMN dogma_attributes.name           IS 'Internal camelCase attribute name used in formulas (e.g. "cpuOutput", "maxTargetRange").';
COMMENT ON COLUMN dogma_attributes.display_name   IS 'Human-readable English label shown in the EVE UI.';
COMMENT ON COLUMN dogma_attributes.data_type      IS '0=boolean, 1=integer, 2=float, 3=long, 4=string, 9=float (legacy distinction).';
COMMENT ON COLUMN dogma_attributes.high_is_good   IS 'True if a higher value is beneficial for the module owner.';
COMMENT ON COLUMN dogma_attributes.stackable      IS 'False if stacking penalties apply when multiple instances of this attribute are active.';

CREATE INDEX idx_dogma_attributes_category_id ON dogma_attributes(attribute_category_id);
CREATE INDEX idx_dogma_attributes_published   ON dogma_attributes(published) WHERE published = true;

-- Effect definitions — module activation behaviours (e.g. shield booster, weapon fire).
CREATE TABLE dogma_effects (
    effect_id                           INTEGER   PRIMARY KEY,
    name                                TEXT      NOT NULL,
    display_name                        TEXT,
    description                         TEXT,
    guid                                TEXT,
    effect_category_id                  SMALLINT,
    icon_id                             INTEGER,
    distribution                        SMALLINT,
    is_offensive                        BOOLEAN   NOT NULL DEFAULT false,
    is_assistance                       BOOLEAN   NOT NULL DEFAULT false,
    is_warp_safe                        BOOLEAN   NOT NULL DEFAULT false,
    electronic_chance                   BOOLEAN   NOT NULL DEFAULT false,
    propulsion_chance                   BOOLEAN   NOT NULL DEFAULT false,
    range_chance                        BOOLEAN   NOT NULL DEFAULT false,
    disallow_auto_repeat                BOOLEAN   NOT NULL DEFAULT false,
    published                           BOOLEAN   NOT NULL DEFAULT false,
    discharge_attribute_id              INTEGER   REFERENCES dogma_attributes,
    duration_attribute_id               INTEGER   REFERENCES dogma_attributes,
    range_attribute_id                  INTEGER   REFERENCES dogma_attributes,
    falloff_attribute_id                INTEGER   REFERENCES dogma_attributes,
    tracking_speed_attribute_id         INTEGER   REFERENCES dogma_attributes,
    fitting_usage_chance_attribute_id   INTEGER   REFERENCES dogma_attributes,
    resistance_attribute_id             INTEGER   REFERENCES dogma_attributes,
    npc_activation_chance_attribute_id  INTEGER   REFERENCES dogma_attributes,
    npc_usage_chance_attribute_id       INTEGER   REFERENCES dogma_attributes
);

COMMENT ON TABLE  dogma_effects                       IS 'Module and ship effect definitions. Effects describe how an active module behaves (e.g. "shieldBoosting", "missileLaunching").';
COMMENT ON COLUMN dogma_effects.name                  IS 'Internal camelCase effect name (e.g. "shieldBoosting").';
COMMENT ON COLUMN dogma_effects.guid                  IS 'Fully qualified effect name (e.g. "effects.ShieldBoosting").';
COMMENT ON COLUMN dogma_effects.effect_category_id    IS '0=passive, 1=active, 2=target, 3=area, 4=online, 5=overload, 6=dungeon, 7=system.';
COMMENT ON COLUMN dogma_effects.is_offensive          IS 'True if this effect is hostile to the target (affects criminal flagging).';
COMMENT ON COLUMN dogma_effects.is_warp_safe          IS 'True if this effect can remain active while warping.';
COMMENT ON COLUMN dogma_effects.discharge_attribute_id IS 'Attribute that holds the capacitor cost per activation cycle.';
COMMENT ON COLUMN dogma_effects.duration_attribute_id  IS 'Attribute that holds the activation cycle duration in milliseconds.';
