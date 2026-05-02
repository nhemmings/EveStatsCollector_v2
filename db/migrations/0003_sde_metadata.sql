CREATE TABLE sde_imports (
    build_number  INTEGER      PRIMARY KEY,
    release_date  TIMESTAMPTZ  NOT NULL,
    imported_at   TIMESTAMPTZ  NOT NULL DEFAULT now()
);

COMMENT ON TABLE  sde_imports              IS 'Tracks which SDE build has been imported. Insert one row per successful import run.';
COMMENT ON COLUMN sde_imports.build_number IS 'CCP build number from the SDE _sde.jsonl metadata record (e.g. 3328718).';
COMMENT ON COLUMN sde_imports.release_date IS 'Official release timestamp of this SDE build as published by CCP.';
COMMENT ON COLUMN sde_imports.imported_at  IS 'When this build was imported into this database instance.';
