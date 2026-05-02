-- Per-type attribute values — the actual stats for every item.
CREATE TABLE type_dogma_attributes (
    type_id       INTEGER   NOT NULL REFERENCES types,
    attribute_id  INTEGER   NOT NULL REFERENCES dogma_attributes,
    value         FLOAT8    NOT NULL,
    PRIMARY KEY (type_id, attribute_id)
);

COMMENT ON TABLE  type_dogma_attributes              IS 'The numeric attribute values that define every item''s statistics. Join to dogma_attributes for the attribute name and unit. Examples: CPU output of a ship, damage of a weapon, activation cost of a module.';
COMMENT ON COLUMN type_dogma_attributes.type_id      IS 'The item type these stats apply to.';
COMMENT ON COLUMN type_dogma_attributes.attribute_id IS 'Which attribute this value represents (e.g. 50=cpuOutput, 11=powerOutput).';
COMMENT ON COLUMN type_dogma_attributes.value        IS 'The attribute value in the units defined by dogma_attributes.unit_id.';

-- Index on (attribute_id, value) enables efficient queries like
-- "find all ships with cpu_output > 500" without scanning the whole table.
CREATE INDEX idx_type_dogma_attributes_attr_val ON type_dogma_attributes(attribute_id, value);

-- Per-type effects — which activation behaviours each item has.
CREATE TABLE type_dogma_effects (
    type_id     INTEGER   NOT NULL REFERENCES types,
    effect_id   INTEGER   NOT NULL REFERENCES dogma_effects,
    is_default  BOOLEAN   NOT NULL DEFAULT false,
    PRIMARY KEY (type_id, effect_id)
);

COMMENT ON TABLE  type_dogma_effects             IS 'Which dogma effects each item type has. Effects describe activation behaviours (e.g. shield booster, weapon turret, sensor booster).';
COMMENT ON COLUMN type_dogma_effects.is_default  IS 'True if this effect is active by default without the module being explicitly activated.';

CREATE INDEX idx_type_dogma_effects_effect_id ON type_dogma_effects(effect_id);
