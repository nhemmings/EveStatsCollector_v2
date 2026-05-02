-- Ore compression: which compressed form each ore type has.
CREATE TABLE compressible_types (
    type_id             INTEGER   PRIMARY KEY REFERENCES types,
    compressed_type_id  INTEGER   NOT NULL REFERENCES types
);

COMMENT ON TABLE  compressible_types                IS 'Maps each compressible ore or ice type to its compressed variant. Compression reduces volume for transport.';
COMMENT ON COLUMN compressible_types.type_id        IS 'The uncompressed ore or ice type.';
COMMENT ON COLUMN compressible_types.compressed_type_id IS 'The compressed ore or ice type produced by compression.';

CREATE INDEX idx_compressible_types_compressed_type_id ON compressible_types(compressed_type_id);

-- Contraband rules: which factions treat each item as illegal and their penalties.
CREATE TABLE contraband_types (
    type_id             INTEGER   NOT NULL REFERENCES types,
    faction_id          INTEGER   NOT NULL REFERENCES factions,
    attack_min_sec      FLOAT4,
    confiscate_min_sec  FLOAT4,
    fine_by_value       FLOAT4,
    standing_loss       FLOAT4,
    PRIMARY KEY (type_id, faction_id)
);

COMMENT ON TABLE  contraband_types                  IS 'Defines which factions treat an item as contraband and the resulting penalties when caught carrying it in their space.';
COMMENT ON COLUMN contraband_types.attack_min_sec   IS 'Security status threshold at which faction police will shoot the smuggler on sight.';
COMMENT ON COLUMN contraband_types.confiscate_min_sec IS 'Security status threshold at which the item is confiscated.';
COMMENT ON COLUMN contraband_types.fine_by_value    IS 'Fine multiplier applied to the item''s base value.';
COMMENT ON COLUMN contraband_types.standing_loss    IS 'Standing loss with this faction when caught.';

CREATE INDEX idx_contraband_types_faction_id ON contraband_types(faction_id);

-- Planetary interaction schematics — PI production chains.
CREATE TABLE planet_schematics (
    schematic_id  INTEGER   PRIMARY KEY,
    name          TEXT      NOT NULL,
    cycle_time    INTEGER   NOT NULL
);

COMMENT ON TABLE  planet_schematics           IS 'Planetary Interaction (PI) production schematics. Each schematic defines one step in a PI production chain.';
COMMENT ON COLUMN planet_schematics.cycle_time IS 'Duration of one production cycle in seconds.';

-- Inputs and outputs of each PI schematic.
CREATE TABLE planet_schematic_pins (
    schematic_id  INTEGER   NOT NULL REFERENCES planet_schematics,
    type_id       INTEGER   NOT NULL REFERENCES types,
    pin_type      TEXT      NOT NULL CHECK (pin_type IN ('input', 'output')),
    quantity      INTEGER   NOT NULL,
    PRIMARY KEY (schematic_id, type_id, pin_type)
);

COMMENT ON TABLE  planet_schematic_pins              IS 'Input commodities consumed and output commodities produced by each PI schematic.';
COMMENT ON COLUMN planet_schematic_pins.pin_type     IS '"input" for consumed materials, "output" for produced commodities.';
COMMENT ON COLUMN planet_schematic_pins.quantity     IS 'Units consumed or produced per cycle.';

CREATE INDEX idx_planet_schematic_pins_type_id ON planet_schematic_pins(type_id);
