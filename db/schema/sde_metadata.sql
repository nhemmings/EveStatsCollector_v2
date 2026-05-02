-- SDE import tracking.
-- Hand-maintained reference — never executed by DbUp.

CREATE TABLE sde_imports (
    build_number  INTEGER      PRIMARY KEY,
    release_date  TIMESTAMPTZ  NOT NULL,
    imported_at   TIMESTAMPTZ  NOT NULL DEFAULT now()
);
