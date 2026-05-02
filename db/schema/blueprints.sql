-- Blueprint activities, materials, products, and skill requirements.
-- Hand-maintained reference — never executed by DbUp.

CREATE TABLE blueprints (
    blueprint_type_id     INTEGER   PRIMARY KEY REFERENCES types,
    max_production_limit  INTEGER
);

CREATE TABLE blueprint_activities (
    blueprint_type_id  INTEGER   NOT NULL REFERENCES blueprints,
    activity           TEXT      NOT NULL,
    time_seconds       INTEGER   NOT NULL,
    PRIMARY KEY (blueprint_type_id, activity)
);

CREATE TABLE blueprint_materials (
    blueprint_type_id  INTEGER   NOT NULL,
    activity           TEXT      NOT NULL,
    material_type_id   INTEGER   NOT NULL REFERENCES types,
    quantity           INTEGER   NOT NULL,
    PRIMARY KEY (blueprint_type_id, activity, material_type_id),
    FOREIGN KEY (blueprint_type_id, activity)
        REFERENCES blueprint_activities (blueprint_type_id, activity)
);

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

CREATE TABLE blueprint_skills (
    blueprint_type_id  INTEGER   NOT NULL,
    activity           TEXT      NOT NULL,
    skill_type_id      INTEGER   NOT NULL REFERENCES types,
    level              SMALLINT  NOT NULL,
    PRIMARY KEY (blueprint_type_id, activity, skill_type_id),
    FOREIGN KEY (blueprint_type_id, activity)
        REFERENCES blueprint_activities (blueprint_type_id, activity)
);
