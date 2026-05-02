-- SKIN material sets — the visual style of a SKIN (e.g. "Ardishapur", "Quafe").
CREATE TABLE skin_materials (
    skin_material_id  INTEGER   PRIMARY KEY,
    display_name      TEXT,
    material_set_id   INTEGER
);

COMMENT ON TABLE  skin_materials                IS 'Visual material definitions used by ship SKINs. Groups related colour/texture variants under a material_set_id.';
COMMENT ON COLUMN skin_materials.display_name   IS 'English display name of this material style (e.g. "Ardishapur", "Quafe").';
COMMENT ON COLUMN skin_materials.material_set_id IS 'Groups material variants that share the same visual theme.';

CREATE INDEX idx_skin_materials_material_set_id ON skin_materials(material_set_id);

-- SKINs — cosmetic re-skins available for ship hulls.
CREATE TABLE skins (
    skin_id              INTEGER   PRIMARY KEY,
    internal_name        TEXT      NOT NULL,
    skin_material_id     INTEGER   REFERENCES skin_materials,
    allow_ccp_devs       BOOLEAN   NOT NULL DEFAULT false,
    visible_serenity     BOOLEAN   NOT NULL DEFAULT false,
    visible_tranquility  BOOLEAN   NOT NULL DEFAULT true
);

COMMENT ON TABLE  skins                         IS 'Cosmetic SKINs that change a ship''s appearance. Each SKIN applies to one or more ship hull types.';
COMMENT ON COLUMN skins.internal_name           IS 'Internal identifier string (e.g. "Megathron Quafe").';
COMMENT ON COLUMN skins.visible_tranquility     IS 'True if this SKIN is available on the Tranquility (main) server.';
COMMENT ON COLUMN skins.visible_serenity        IS 'True if this SKIN is available on the Serenity (Chinese) server.';

CREATE INDEX idx_skins_skin_material_id ON skins(skin_material_id);

-- Junction: which ship hull types each SKIN applies to.
CREATE TABLE skin_types (
    skin_id  INTEGER   NOT NULL REFERENCES skins,
    type_id  INTEGER   NOT NULL REFERENCES types,
    PRIMARY KEY (skin_id, type_id)
);

COMMENT ON TABLE skin_types IS 'Mapping between SKINs and the ship hull types they can be applied to. Most SKINs apply to exactly one hull; some apply to whole family groups.';

CREATE INDEX idx_skin_types_type_id ON skin_types(type_id);

-- SKIN licenses — the market items that grant a SKIN to a character.
CREATE TABLE skin_licenses (
    license_type_id  INTEGER   PRIMARY KEY REFERENCES types,
    skin_id          INTEGER   NOT NULL REFERENCES skins,
    duration         INTEGER   NOT NULL DEFAULT -1
);

COMMENT ON TABLE  skin_licenses              IS 'SKIN licence items sold on the market or in the New Eden Store. Activating a licence permanently (or temporarily) unlocks the SKIN for a character.';
COMMENT ON COLUMN skin_licenses.duration     IS 'Licence validity in seconds. -1 means permanent.';

CREATE INDEX idx_skin_licenses_skin_id ON skin_licenses(skin_id);
