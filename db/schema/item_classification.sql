-- Item classification hierarchy: categories → groups, plus meta-groups and market groups.
-- Hand-maintained reference — never executed by DbUp.

CREATE TABLE categories (
    category_id  SMALLINT  PRIMARY KEY,
    name         TEXT      NOT NULL,
    published    BOOLEAN   NOT NULL DEFAULT false,
    icon_id      INTEGER
);

CREATE TABLE groups (
    group_id                INTEGER   PRIMARY KEY,
    category_id             SMALLINT  NOT NULL REFERENCES categories,
    name                    TEXT      NOT NULL,
    published               BOOLEAN   NOT NULL DEFAULT false,
    icon_id                 INTEGER,
    anchorable              BOOLEAN   NOT NULL DEFAULT false,
    anchored                BOOLEAN   NOT NULL DEFAULT false,
    fittable_non_singleton  BOOLEAN   NOT NULL DEFAULT false,
    use_base_price          BOOLEAN   NOT NULL DEFAULT false
);

CREATE TABLE meta_groups (
    meta_group_id  SMALLINT  PRIMARY KEY,
    name           TEXT      NOT NULL,
    description    TEXT,
    icon_id        INTEGER,
    icon_suffix    TEXT
);

CREATE TABLE market_groups (
    market_group_id  INTEGER   PRIMARY KEY,
    parent_group_id  INTEGER   REFERENCES market_groups,
    name             TEXT      NOT NULL,
    description      TEXT,
    has_types        BOOLEAN   NOT NULL DEFAULT false,
    icon_id          INTEGER
);
