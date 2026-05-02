-- Per-type dogma attribute values and active effects.
-- Hand-maintained reference — never executed by DbUp.

CREATE TABLE type_dogma_attributes (
    type_id       INTEGER   NOT NULL REFERENCES types,
    attribute_id  INTEGER   NOT NULL REFERENCES dogma_attributes,
    value         FLOAT8    NOT NULL,
    PRIMARY KEY (type_id, attribute_id)
);

CREATE TABLE type_dogma_effects (
    type_id     INTEGER   NOT NULL REFERENCES types,
    effect_id   INTEGER   NOT NULL REFERENCES dogma_effects,
    is_default  BOOLEAN   NOT NULL DEFAULT false,
    PRIMARY KEY (type_id, effect_id)
);
