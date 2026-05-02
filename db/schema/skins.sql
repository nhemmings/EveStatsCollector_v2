-- SKIN cosmetics: materials, skins, hull mappings, and licences.
-- Hand-maintained reference — never executed by DbUp.

CREATE TABLE skin_materials (
    skin_material_id  INTEGER   PRIMARY KEY,
    display_name      TEXT,
    material_set_id   INTEGER
);

CREATE TABLE skins (
    skin_id              INTEGER   PRIMARY KEY,
    internal_name        TEXT      NOT NULL,
    skin_material_id     INTEGER   REFERENCES skin_materials,
    allow_ccp_devs       BOOLEAN   NOT NULL DEFAULT false,
    visible_serenity     BOOLEAN   NOT NULL DEFAULT false,
    visible_tranquility  BOOLEAN   NOT NULL DEFAULT true
);

CREATE TABLE skin_types (
    skin_id  INTEGER   NOT NULL REFERENCES skins,
    type_id  INTEGER   NOT NULL REFERENCES types,
    PRIMARY KEY (skin_id, type_id)
);

CREATE TABLE skin_licenses (
    license_type_id  INTEGER   PRIMARY KEY REFERENCES types,
    skin_id          INTEGER   NOT NULL REFERENCES skins,
    duration         INTEGER   NOT NULL DEFAULT -1
);
