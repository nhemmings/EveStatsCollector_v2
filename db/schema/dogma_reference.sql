-- Dogma system reference tables: units, attribute categories, attributes, effects.
-- Hand-maintained reference — never executed by DbUp.

CREATE TABLE dogma_units (
    unit_id      SMALLINT  PRIMARY KEY,
    name         TEXT      NOT NULL,
    display_name TEXT,
    description  TEXT
);

CREATE TABLE dogma_attribute_categories (
    category_id  SMALLINT  PRIMARY KEY,
    name         TEXT      NOT NULL,
    description  TEXT
);

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
