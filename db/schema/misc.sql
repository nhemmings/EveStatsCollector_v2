-- Miscellaneous type data: compression, contraband, and PI schematics.
-- Hand-maintained reference — never executed by DbUp.

CREATE TABLE compressible_types (
    type_id             INTEGER   PRIMARY KEY REFERENCES types,
    compressed_type_id  INTEGER   NOT NULL REFERENCES types
);

CREATE TABLE contraband_types (
    type_id             INTEGER   NOT NULL REFERENCES types,
    faction_id          INTEGER   NOT NULL REFERENCES factions,
    attack_min_sec      FLOAT4,
    confiscate_min_sec  FLOAT4,
    fine_by_value       FLOAT4,
    standing_loss       FLOAT4,
    PRIMARY KEY (type_id, faction_id)
);

CREATE TABLE planet_schematics (
    schematic_id  INTEGER   PRIMARY KEY,
    name          TEXT      NOT NULL,
    cycle_time    INTEGER   NOT NULL
);

CREATE TABLE planet_schematic_pins (
    schematic_id  INTEGER   NOT NULL REFERENCES planet_schematics,
    type_id       INTEGER   NOT NULL REFERENCES types,
    pin_type      TEXT      NOT NULL CHECK (pin_type IN ('input', 'output')),
    quantity      INTEGER   NOT NULL,
    PRIMARY KEY (schematic_id, type_id, pin_type)
);
