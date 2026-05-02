-- Top-level item categories (e.g. Ship, Module, Charge, Skill).
CREATE TABLE categories (
    category_id  SMALLINT  PRIMARY KEY,
    name         TEXT      NOT NULL,
    published    BOOLEAN   NOT NULL DEFAULT false,
    icon_id      INTEGER
);

COMMENT ON TABLE  categories           IS 'Top-level item categories (e.g. "Ship", "Module", "Charge", "Skill", "Ore").';
COMMENT ON COLUMN categories.published IS 'False for internal/hidden categories not visible in the game client.';

-- Item groups — subcategories within a category (e.g. "Frigate" within "Ship").
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

COMMENT ON TABLE  groups                        IS 'Item groups, the second level of item classification below categories (e.g. "Frigate", "Shield Booster", "Projectile Ammo").';
COMMENT ON COLUMN groups.fittable_non_singleton IS 'True if multiple copies of items in this group can be fitted simultaneously.';

CREATE INDEX idx_groups_category_id ON groups(category_id);
CREATE INDEX idx_groups_published   ON groups(published) WHERE published = true;

-- Meta-groups describe the technology tier of an item (T1, T2, Faction, etc.).
CREATE TABLE meta_groups (
    meta_group_id  SMALLINT  PRIMARY KEY,
    name           TEXT      NOT NULL,
    description    TEXT,
    icon_id        INTEGER,
    icon_suffix    TEXT
);

COMMENT ON TABLE  meta_groups      IS 'Technology tier or origin of an item. Common values: 1=Tech I, 2=Tech II, 3=Storyline, 4=Faction, 5=Officer, 6=Deadspace, 14=Tech III, 15=Abyssal.';
COMMENT ON COLUMN meta_groups.name IS 'Display name (e.g. "Tech II", "Faction", "Officer").';

-- Market group hierarchy — the browsable tree structure of the in-game market.
CREATE TABLE market_groups (
    market_group_id  INTEGER   PRIMARY KEY,
    parent_group_id  INTEGER   REFERENCES market_groups,
    name             TEXT      NOT NULL,
    description      TEXT,
    has_types        BOOLEAN   NOT NULL DEFAULT false,
    icon_id          INTEGER
);

COMMENT ON TABLE  market_groups                 IS 'Hierarchical market browser categories. Leaf nodes (has_types=true) contain actual item types. Traverse parent_group_id to build the full path.';
COMMENT ON COLUMN market_groups.parent_group_id IS 'Parent node in the market tree. NULL for root nodes.';
COMMENT ON COLUMN market_groups.has_types       IS 'True if this group directly contains item types (leaf node). False if it only contains child groups.';

CREATE INDEX idx_market_groups_parent_group_id ON market_groups(parent_group_id);
