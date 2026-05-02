-- All item types in EVE Online.
-- Hand-maintained reference — never executed by DbUp.

CREATE TABLE types (
    type_id                   INTEGER       PRIMARY KEY,
    group_id                  INTEGER       NOT NULL REFERENCES groups,
    name                      TEXT          NOT NULL,
    description               TEXT,
    mass                      FLOAT8,
    volume                    FLOAT8,
    capacity                  FLOAT8,
    radius                    FLOAT8,
    base_price                NUMERIC(18,2),
    portion_size              INTEGER       NOT NULL DEFAULT 1,
    published                 BOOLEAN       NOT NULL DEFAULT false,
    market_group_id           INTEGER       REFERENCES market_groups,
    meta_group_id             SMALLINT      REFERENCES meta_groups,
    meta_level                SMALLINT,
    faction_id                INTEGER       REFERENCES factions,
    race_id                   SMALLINT      REFERENCES races,
    graphic_id                INTEGER,
    icon_id                   INTEGER,
    sound_id                  INTEGER,
    variation_parent_type_id  INTEGER       REFERENCES types
);
