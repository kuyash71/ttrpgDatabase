BEGIN;
DROP TABLE IF EXISTS audit_log CASCADE;

DROP TABLE IF EXISTS character_item CASCADE;
DROP TABLE IF EXISTS character_ability CASCADE;
DROP TABLE IF EXISTS class_ability CASCADE;
DROP TABLE IF EXISTS class_stat_modifier CASCADE;
DROP TABLE IF EXISTS character_resource CASCADE;
DROP TABLE IF EXISTS character_stat CASCADE;

DROP TABLE IF EXISTS item CASCADE;
DROP TABLE IF EXISTS ability CASCADE;
DROP TABLE IF EXISTS rpg_class CASCADE;

DROP TABLE IF EXISTS faction CASCADE;
DROP TABLE IF EXISTS location CASCADE;
DROP TABLE IF EXISTS npc CASCADE;
DROP TABLE IF EXISTS character CASCADE;

DROP TABLE IF EXISTS entity CASCADE;
DROP TABLE IF EXISTS entity_kind CASCADE;

DROP TABLE IF EXISTS session CASCADE;
DROP TABLE IF EXISTS campaign CASCADE;
DROP TABLE IF EXISTS universe CASCADE;
DROP TABLE IF EXISTS system CASCADE;
-- SYSTEM / UNIVERSE / CAMPAIGN / SESSION
CREATE TABLE system (
  system_id  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name       VARCHAR(120) NOT NULL UNIQUE
);

CREATE TABLE universe (
  universe_id  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  system_id    INTEGER NOT NULL REFERENCES system(system_id) ON DELETE CASCADE,
  name         VARCHAR(160) NOT NULL,
  description  TEXT,
  CONSTRAINT uq_universe__system_name UNIQUE (system_id, name)
);

CREATE TABLE campaign (
  campaign_id  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  universe_id  INTEGER NOT NULL REFERENCES universe(universe_id) ON DELETE CASCADE,
  name         VARCHAR(160) NOT NULL,
  status       VARCHAR(40),
  CONSTRAINT uq_campaign__universe_name UNIQUE (universe_id, name)
);

CREATE TABLE session (
  session_id    INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  campaign_id   INTEGER NOT NULL REFERENCES campaign(campaign_id) ON DELETE CASCADE,
  session_date  DATE,
  notes         TEXT
);
-- ENTITY KIND (lookup) + ENTITY
CREATE TABLE entity_kind (
  kind_code   VARCHAR(24) PRIMARY KEY,
  description VARCHAR(200)
);

CREATE TABLE entity (
  entity_id    INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  universe_id  INTEGER NOT NULL REFERENCES universe(universe_id) ON DELETE CASCADE,
  kind_code    VARCHAR(24) NOT NULL REFERENCES entity_kind(kind_code) ON DELETE RESTRICT,
  name         VARCHAR(160) NOT NULL,
  description  TEXT
);
-- KALITIM TABLOLARI
CREATE TABLE character (
  character_id  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  entity_id     INTEGER NOT NULL UNIQUE REFERENCES entity(entity_id) ON DELETE CASCADE,
  campaign_id   INTEGER NOT NULL REFERENCES campaign(campaign_id) ON DELETE CASCADE,
  class_id      INTEGER NOT NULL,
  level         INTEGER NOT NULL DEFAULT 0 CHECK (level >= 0),
  story         TEXT,
  strengths     TEXT,
  weaknesses    TEXT
);

CREATE TABLE npc (
  npc_id     INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  entity_id  INTEGER NOT NULL UNIQUE REFERENCES entity(entity_id) ON DELETE CASCADE,
  role       VARCHAR(120)
);

CREATE TABLE location (
  location_id  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  entity_id    INTEGER NOT NULL UNIQUE REFERENCES entity(entity_id) ON DELETE CASCADE,
  region       VARCHAR(120)
);

CREATE TABLE faction (
  faction_id  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  entity_id   INTEGER NOT NULL UNIQUE REFERENCES entity(entity_id) ON DELETE CASCADE,
  ideology    VARCHAR(160)
);
-- STAT / RESOURCE DEFINITIONS
CREATE TABLE stat_def (
  stat_id     INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  system_id   INTEGER NOT NULL REFERENCES system(system_id) ON DELETE CASCADE,
  code        VARCHAR(40) NOT NULL,
  name        VARCHAR(120) NOT NULL,
  min_value   INTEGER NOT NULL,
  max_value   INTEGER NOT NULL,
  CONSTRAINT ck_stat_def_minmax CHECK (min_value <= max_value),
  CONSTRAINT uq_stat_def__system_code UNIQUE (system_id, code),
  CONSTRAINT uq_stat_def__system_name UNIQUE (system_id, name)
);

CREATE TABLE resource_def (
  resource_id  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  system_id    INTEGER NOT NULL REFERENCES system(system_id) ON DELETE CASCADE,
  code         VARCHAR(40) NOT NULL,
  name         VARCHAR(120) NOT NULL,
  min_value    INTEGER NOT NULL,
  max_value    INTEGER NOT NULL,
  CONSTRAINT ck_resource_def_minmax CHECK (min_value <= max_value),
  CONSTRAINT uq_resource_def__system_code UNIQUE (system_id, code),
  CONSTRAINT uq_resource_def__system_name UNIQUE (system_id, name)
);

CREATE TABLE character_stat (
  character_id  INTEGER NOT NULL REFERENCES character(character_id) ON DELETE CASCADE,
  stat_id       INTEGER NOT NULL REFERENCES stat_def(stat_id) ON DELETE RESTRICT,
  value         INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (character_id, stat_id)
);

CREATE TABLE character_resource (
  character_id  INTEGER NOT NULL REFERENCES character(character_id) ON DELETE CASCADE,
  resource_id   INTEGER NOT NULL REFERENCES resource_def(resource_id) ON DELETE RESTRICT,
  value         INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (character_id, resource_id)
);
-- CLASS / ABILITY / ITEM
CREATE TABLE rpg_class (
  class_id    INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  system_id   INTEGER NOT NULL REFERENCES system(system_id) ON DELETE CASCADE,
  name        VARCHAR(120) NOT NULL,
  lore_text   TEXT,
  CONSTRAINT uq_rpg_class__system_name UNIQUE (system_id, name)
);

ALTER TABLE character
  ADD CONSTRAINT fk_character_class
  FOREIGN KEY (class_id) REFERENCES rpg_class(class_id)
  ON DELETE RESTRICT;

CREATE TABLE class_stat_modifier (
  class_id  INTEGER NOT NULL REFERENCES rpg_class(class_id) ON DELETE CASCADE,
  stat_id   INTEGER NOT NULL REFERENCES stat_def(stat_id) ON DELETE RESTRICT,
  delta     INTEGER NOT NULL,
  PRIMARY KEY (class_id, stat_id)
);

CREATE TABLE ability (
  ability_id   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  system_id    INTEGER NOT NULL REFERENCES system(system_id) ON DELETE CASCADE,
  name         VARCHAR(160) NOT NULL,
  rules_text   TEXT,
  dice_type    VARCHAR(40),
  CONSTRAINT uq_ability__system_name UNIQUE (system_id, name)
);

CREATE TABLE class_ability (
  class_id    INTEGER NOT NULL REFERENCES rpg_class(class_id) ON DELETE CASCADE,
  ability_id  INTEGER NOT NULL REFERENCES ability(ability_id) ON DELETE RESTRICT,
  sort_order  INTEGER NOT NULL DEFAULT 0 CHECK (sort_order >= 0),
  PRIMARY KEY (class_id, ability_id)
);

CREATE TABLE character_ability (
  character_id  INTEGER NOT NULL REFERENCES character(character_id) ON DELETE CASCADE,
  ability_id    INTEGER NOT NULL REFERENCES ability(ability_id) ON DELETE RESTRICT,
  source        VARCHAR(60), -- e.g. 'CLASS', 'REWARD', 'ITEM', 'MANUAL'
  PRIMARY KEY (character_id, ability_id)
);

CREATE TABLE item (
  item_id      INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  system_id    INTEGER NOT NULL REFERENCES system(system_id) ON DELETE CASCADE,
  name         VARCHAR(160) NOT NULL,
  description  TEXT,
  CONSTRAINT uq_item__system_name UNIQUE (system_id, name)
);

CREATE TABLE character_item (
  character_id  INTEGER NOT NULL REFERENCES character(character_id) ON DELETE CASCADE,
  item_id       INTEGER NOT NULL REFERENCES item(item_id) ON DELETE RESTRICT,
  qty           INTEGER NOT NULL DEFAULT 1 CHECK (qty >= 0),
  PRIMARY KEY (character_id, item_id)
);

CREATE TABLE audit_log (
  audit_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  table_name TEXT NOT NULL,
  action     TEXT NOT NULL,
  changed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  row_pk     TEXT,
  old_data   JSONB,
  new_data   JSONB
);

CREATE INDEX idx_entity_universe_kind ON entity(universe_id, kind_code);
CREATE INDEX idx_character_campaign ON character(campaign_id);
CREATE INDEX idx_stat_def_system ON stat_def(system_id);
CREATE INDEX idx_resource_def_system ON resource_def(system_id);

COMMIT;
