-- Blueprint type IDs and their production limits.
CREATE TABLE blueprints (
    blueprint_type_id     INTEGER   PRIMARY KEY REFERENCES types,
    max_production_limit  INTEGER
);

COMMENT ON TABLE  blueprints                       IS 'Blueprint items. Every blueprint has one or more activities (manufacturing, invention, etc.) defined in blueprint_activities.';
COMMENT ON COLUMN blueprints.blueprint_type_id     IS 'The type_id of the blueprint item itself (not the product).';
COMMENT ON COLUMN blueprints.max_production_limit  IS 'Maximum number of runs per job for this blueprint (relevant for originals vs copies).';

-- Individual activities available on each blueprint.
CREATE TABLE blueprint_activities (
    blueprint_type_id  INTEGER   NOT NULL REFERENCES blueprints,
    activity           TEXT      NOT NULL CHECK (activity IN (
                                     'manufacturing',
                                     'copying',
                                     'invention',
                                     'reaction',
                                     'research_material',
                                     'research_time'
                                 )),
    activity_id        SMALLINT  NOT NULL,
    time_seconds       INTEGER   NOT NULL,
    PRIMARY KEY (blueprint_type_id, activity)
);

COMMENT ON TABLE  blueprint_activities              IS 'Activities available on each blueprint, with their base time cost.';
COMMENT ON COLUMN blueprint_activities.activity     IS 'SDE activity name: manufacturing, copying, invention, reaction, research_material, or research_time.';
COMMENT ON COLUMN blueprint_activities.activity_id  IS 'ESI numeric activity ID. Mapping: manufacturing=1, research_time=3, research_material=4, copying=5, invention=8, reaction=11. Use this column to join with ESI industry endpoints.';
COMMENT ON COLUMN blueprint_activities.time_seconds IS 'Base duration of one run of this activity in seconds, before skill and structure bonuses.';

-- Input materials consumed by each blueprint activity.
CREATE TABLE blueprint_materials (
    blueprint_type_id  INTEGER   NOT NULL,
    activity           TEXT      NOT NULL,
    material_type_id   INTEGER   NOT NULL REFERENCES types,
    quantity           INTEGER   NOT NULL,
    PRIMARY KEY (blueprint_type_id, activity, material_type_id),
    FOREIGN KEY (blueprint_type_id, activity)
        REFERENCES blueprint_activities (blueprint_type_id, activity)
);

COMMENT ON TABLE  blueprint_materials                  IS 'Input materials consumed by each blueprint activity. Quantities are base values before material efficiency (ME) research is applied.';
COMMENT ON COLUMN blueprint_materials.material_type_id IS 'The input material type (e.g. Tritanium, Morphite, a component blueprint product).';
COMMENT ON COLUMN blueprint_materials.quantity         IS 'Base quantity required per run before ME research and structure bonuses.';

CREATE INDEX idx_blueprint_materials_material_type_id ON blueprint_materials(material_type_id);

-- Output products produced by each blueprint activity.
CREATE TABLE blueprint_products (
    blueprint_type_id  INTEGER   NOT NULL,
    activity           TEXT      NOT NULL,
    product_type_id    INTEGER   NOT NULL REFERENCES types,
    quantity           INTEGER   NOT NULL,
    probability        FLOAT4,
    PRIMARY KEY (blueprint_type_id, activity, product_type_id),
    FOREIGN KEY (blueprint_type_id, activity)
        REFERENCES blueprint_activities (blueprint_type_id, activity)
);

COMMENT ON TABLE  blueprint_products                IS 'Output products of each blueprint activity.';
COMMENT ON COLUMN blueprint_products.product_type_id IS 'The produced item type (the thing being manufactured or invented).';
COMMENT ON COLUMN blueprint_products.probability     IS 'For invention, the chance (0.0–1.0) that this output is produced. NULL means guaranteed (manufacturing/reaction).';

CREATE INDEX idx_blueprint_products_product_type_id ON blueprint_products(product_type_id);

-- Skill prerequisites for blueprint activities (primarily invention).
CREATE TABLE blueprint_skills (
    blueprint_type_id  INTEGER   NOT NULL,
    activity           TEXT      NOT NULL,
    skill_type_id      INTEGER   NOT NULL REFERENCES types,
    level              SMALLINT  NOT NULL,
    PRIMARY KEY (blueprint_type_id, activity, skill_type_id),
    FOREIGN KEY (blueprint_type_id, activity)
        REFERENCES blueprint_activities (blueprint_type_id, activity)
);

COMMENT ON TABLE  blueprint_skills               IS 'Skill requirements for blueprint activities. Primarily used by invention to specify which encryption and science skills are needed.';
COMMENT ON COLUMN blueprint_skills.skill_type_id IS 'The required skill type (category=16 Skill in the types table).';
COMMENT ON COLUMN blueprint_skills.level         IS 'Minimum skill level required (1–5).';

CREATE INDEX idx_blueprint_skills_skill_type_id ON blueprint_skills(skill_type_id);
