-- Reprocessing yields.
-- Hand-maintained reference — never executed by DbUp.

CREATE TABLE type_materials (
    type_id           INTEGER   NOT NULL REFERENCES types,
    material_type_id  INTEGER   NOT NULL REFERENCES types,
    quantity          INTEGER   NOT NULL,
    PRIMARY KEY (type_id, material_type_id)
);
