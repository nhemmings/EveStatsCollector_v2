-- Reprocessing yields — what minerals/materials an item produces when reprocessed.
CREATE TABLE type_materials (
    type_id           INTEGER   NOT NULL REFERENCES types,
    material_type_id  INTEGER   NOT NULL REFERENCES types,
    quantity          INTEGER   NOT NULL,
    PRIMARY KEY (type_id, material_type_id)
);

COMMENT ON TABLE  type_materials                  IS 'Reprocessing output: the minerals and materials recovered when an item is reprocessed. Base quantities before efficiency and skills are applied.';
COMMENT ON COLUMN type_materials.type_id          IS 'The item being reprocessed (e.g. an ore type or a ship module).';
COMMENT ON COLUMN type_materials.material_type_id IS 'The recovered material (typically a mineral such as Tritanium or Mexallon).';
COMMENT ON COLUMN type_materials.quantity         IS 'Base quantity recovered per portion_size units of the source item, before skill and efficiency modifiers.';

CREATE INDEX idx_type_materials_material_type_id ON type_materials(material_type_id);
