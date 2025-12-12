-- ============================================================
-- 03_procs_triggers.sql - Functions + Procedures + Triggers
-- ============================================================

BEGIN;

-- -------------------------
-- Function: fn_search_characters
-- -------------------------
CREATE OR REPLACE FUNCTION fn_search_characters(
  p_campaign_id INT,
  p_name_like TEXT DEFAULT NULL
)
RETURNS TABLE (
  character_id INT,
  character_name TEXT,
  class_name TEXT,
  level INT
)
LANGUAGE sql
AS $$
  SELECT
    ch.character_id,
    e.name AS character_name,
    rc.name AS class_name,
    ch.level
  FROM character ch
  JOIN entity e ON e.entity_id = ch.entity_id
  JOIN rpg_class rc ON rc.class_id = ch.class_id
  WHERE ch.campaign_id = p_campaign_id
    AND (
      p_name_like IS NULL
      OR p_name_like = ''
      OR e.name ILIKE '%' || p_name_like || '%'
    )
  ORDER BY e.name;
$$;

-- -------------------------
-- Function: fn_character_sheet
-- -------------------------
CREATE OR REPLACE FUNCTION fn_character_sheet(p_character_id INT)
RETURNS TABLE (
  character_id INT,
  character_name TEXT,
  campaign_name TEXT,
  class_name TEXT,
  level INT,
  stat_code TEXT,
  stat_name TEXT,
  stat_value INT
)
LANGUAGE sql
AS $$
  SELECT
    ch.character_id,
    e.name AS character_name,
    c.name AS campaign_name,
    rc.name AS class_name,
    ch.level,
    sd.code AS stat_code,
    sd.name AS stat_name,
    cs.value AS stat_value
  FROM character ch
  JOIN entity e ON e.entity_id = ch.entity_id
  JOIN campaign c ON c.campaign_id = ch.campaign_id
  JOIN rpg_class rc ON rc.class_id = ch.class_id
  JOIN character_stat cs ON cs.character_id = ch.character_id
  JOIN stat_def sd ON sd.stat_id = cs.stat_id
  WHERE ch.character_id = p_character_id
  ORDER BY sd.code;
$$;

-- -------------------------
-- Function: sp_create_character (returns new character_id)
-- Base stat is 3 so negative modifiers (e.g. -1) won't violate min=0
-- -------------------------
CREATE OR REPLACE FUNCTION sp_create_character(
  p_campaign_id INT,
  p_class_id INT,
  p_name TEXT,
  p_description TEXT DEFAULT NULL
) RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
  v_universe_id INT;
  v_system_id   INT;
  v_entity_id   INT;
  v_character_id INT;
BEGIN
  SELECT c.universe_id, u.system_id
    INTO v_universe_id, v_system_id
  FROM campaign c
  JOIN universe u ON u.universe_id = c.universe_id
  WHERE c.campaign_id = p_campaign_id;

  IF v_system_id IS NULL THEN
    RAISE EXCEPTION 'Campaign not found: %', p_campaign_id;
  END IF;

  INSERT INTO entity(universe_id, kind_code, name, description)
  VALUES (v_universe_id, 'CHARACTER', p_name, p_description)
  RETURNING entity_id INTO v_entity_id;

  INSERT INTO character(entity_id, campaign_id, class_id, level)
  VALUES (v_entity_id, p_campaign_id, p_class_id, 0)
  RETURNING character_id INTO v_character_id;

  -- BASE 3 for stats (so negative class modifiers are valid)
  INSERT INTO character_stat(character_id, stat_id, value)
  SELECT v_character_id, sd.stat_id, 3
  FROM stat_def sd
  WHERE sd.system_id = v_system_id;

  -- resources start at min_value
  INSERT INTO character_resource(character_id, resource_id, value)
  SELECT v_character_id, rd.resource_id, rd.min_value
  FROM resource_def rd
  WHERE rd.system_id = v_system_id;

  -- apply class stat modifiers
  UPDATE character_stat cs
  SET value = cs.value + csm.delta
  FROM class_stat_modifier csm
  WHERE csm.class_id = p_class_id
    AND csm.stat_id = cs.stat_id
    AND cs.character_id = v_character_id;

  -- grant class abilities
  INSERT INTO character_ability(character_id, ability_id, source)
  SELECT v_character_id, ca.ability_id, 'CLASS'
  FROM class_ability ca
  WHERE ca.class_id = p_class_id
  ON CONFLICT DO NOTHING;

  RETURN v_character_id;
END;
$$;

-- -------------------------
-- Procedure: sp_apply_class_to_character
-- Resets stats to BASE 3 then re-applies modifiers (consistent with create)
-- -------------------------
CREATE OR REPLACE PROCEDURE sp_apply_class_to_character(
  p_character_id INT,
  p_new_class_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_system_id   INT;
BEGIN
  SELECT u.system_id INTO v_system_id
  FROM character ch
  JOIN campaign c ON c.campaign_id = ch.campaign_id
  JOIN universe u ON u.universe_id = c.universe_id
  WHERE ch.character_id = p_character_id;

  IF v_system_id IS NULL THEN
    RAISE EXCEPTION 'Character not found: %', p_character_id;
  END IF;

  UPDATE character
  SET class_id = p_new_class_id
  WHERE character_id = p_character_id;

  -- reset to BASE 3 (not 0)
  UPDATE character_stat
  SET value = 3
  WHERE character_id = p_character_id;

  -- apply new modifiers
  UPDATE character_stat cs
  SET value = cs.value + csm.delta
  FROM class_stat_modifier csm
  WHERE csm.class_id = p_new_class_id
    AND csm.stat_id = cs.stat_id
    AND cs.character_id = p_character_id;

  -- grant class abilities
  INSERT INTO character_ability(character_id, ability_id, source)
  SELECT p_character_id, ca.ability_id, 'CLASS'
  FROM class_ability ca
  WHERE ca.class_id = p_new_class_id
  ON CONFLICT DO NOTHING;
END;
$$;

-- -------------------------
-- Procedure: sp_transfer_item
-- Moves items between characters; checks availability
-- -------------------------
CREATE OR REPLACE PROCEDURE sp_transfer_item(
  p_from_character_id INT,
  p_to_character_id   INT,
  p_item_id           INT,
  p_qty               INT
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_have INT;
BEGIN
  IF p_qty IS NULL OR p_qty <= 0 THEN
    RAISE EXCEPTION 'qty must be > 0';
  END IF;

  IF p_from_character_id = p_to_character_id THEN
    RAISE EXCEPTION 'from_character_id and to_character_id must be different';
  END IF;

  SELECT qty INTO v_have
  FROM character_item
  WHERE character_id = p_from_character_id
    AND item_id = p_item_id;

  IF v_have IS NULL OR v_have < p_qty THEN
    RAISE EXCEPTION 'Not enough item. Have %, need % (character_id=%, item_id=%)',
      COALESCE(v_have, 0), p_qty, p_from_character_id, p_item_id;
  END IF;

  UPDATE character_item
  SET qty = qty - p_qty
  WHERE character_id = p_from_character_id
    AND item_id = p_item_id;

  INSERT INTO character_item(character_id, item_id, qty)
  VALUES (p_to_character_id, p_item_id, p_qty)
  ON CONFLICT (character_id, item_id)
  DO UPDATE SET qty = character_item.qty + EXCLUDED.qty;
END;
$$;

-- ============================
-- CHARACTER INVENTORY FUNCTION
-- ============================
CREATE OR REPLACE FUNCTION fn_character_inventory(p_character_id INT)
RETURNS TABLE (
  character_id INT,
  character_name TEXT,
  item_name TEXT,
  qty INT
)
LANGUAGE sql
AS $$
  SELECT
    ch.character_id,
    e.name AS character_name,
    i.name AS item_name,
    ci.qty
  FROM character_item ci
  JOIN character ch ON ch.character_id = ci.character_id
  JOIN entity e ON e.entity_id = ch.entity_id
  JOIN item i ON i.item_id = ci.item_id
  WHERE ci.character_id = p_character_id
  ORDER BY i.name;
$$;
CREATE OR REPLACE FUNCTION fn_create_campaign(
  p_universe_id INT,
  p_name TEXT,
  p_status TEXT DEFAULT 'ACTIVE'
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
  v_campaign_id INT;
BEGIN
  -- varsa id'yi döndür
  SELECT campaign_id INTO v_campaign_id
  FROM campaign
  WHERE universe_id = p_universe_id
    AND name = p_name;

  IF v_campaign_id IS NOT NULL THEN
    RETURN v_campaign_id;
  END IF;

  INSERT INTO campaign(universe_id, name, status)
  VALUES (p_universe_id, p_name, p_status)
  RETURNING campaign_id INTO v_campaign_id;

  RETURN v_campaign_id;
END;
$$;
CREATE OR REPLACE PROCEDURE sp_add_item_to_character(
  p_character_id INT,
  p_item_id INT,
  p_qty INT DEFAULT 1
)
LANGUAGE plpgsql
AS $$
BEGIN
  IF p_qty IS NULL OR p_qty <= 0 THEN
    RAISE EXCEPTION 'qty must be > 0';
  END IF;

  INSERT INTO character_item(character_id, item_id, qty)
  VALUES (p_character_id, p_item_id, p_qty)
  ON CONFLICT (character_id, item_id)
  DO UPDATE SET qty = character_item.qty + EXCLUDED.qty;
END;
$$;


-- ============================================================
-- TRIGGERS
-- ============================================================

-- Trigger function: stat bounds
CREATE OR REPLACE FUNCTION trg_check_stat_bounds()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE vmin INT; vmax INT;
BEGIN
  SELECT min_value, max_value INTO vmin, vmax
  FROM stat_def WHERE stat_id = NEW.stat_id;

  IF NEW.value < vmin OR NEW.value > vmax THEN
    RAISE EXCEPTION 'Stat out of bounds (stat_id=%): % not in [%..%]',
      NEW.stat_id, NEW.value, vmin, vmax;
  END IF;

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS t_check_stat_bounds ON character_stat;
CREATE TRIGGER t_check_stat_bounds
BEFORE INSERT OR UPDATE ON character_stat
FOR EACH ROW EXECUTE FUNCTION trg_check_stat_bounds();

-- Trigger function: resource bounds
CREATE OR REPLACE FUNCTION trg_check_resource_bounds()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE vmin INT; vmax INT;
BEGIN
  SELECT min_value, max_value INTO vmin, vmax
  FROM resource_def WHERE resource_id = NEW.resource_id;

  IF NEW.value < vmin OR NEW.value > vmax THEN
    RAISE EXCEPTION 'Resource out of bounds (resource_id=%): % not in [%..%]',
      NEW.resource_id, NEW.value, vmin, vmax;
  END IF;

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS t_check_resource_bounds ON character_resource;
CREATE TRIGGER t_check_resource_bounds
BEFORE INSERT OR UPDATE ON character_resource
FOR EACH ROW EXECUTE FUNCTION trg_check_resource_bounds();

-- Trigger function: qty=0 cleanup (UPDATE-only, as designed)
CREATE OR REPLACE FUNCTION trg_character_item_qty_cleanup()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.qty = 0 THEN
    DELETE FROM character_item
    WHERE character_id = NEW.character_id
      AND item_id = NEW.item_id;
    RETURN NULL;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS t_item_qty_cleanup ON character_item;
CREATE TRIGGER t_item_qty_cleanup
BEFORE UPDATE ON character_item
FOR EACH ROW EXECUTE FUNCTION trg_character_item_qty_cleanup();

-- Trigger function: generic audit (we attach to character)
CREATE OR REPLACE FUNCTION trg_audit_generic()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO audit_log(table_name, action, row_pk, new_data)
    VALUES (TG_TABLE_NAME, TG_OP, NULL, to_jsonb(NEW));
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO audit_log(table_name, action, row_pk, old_data, new_data)
    VALUES (TG_TABLE_NAME, TG_OP, NULL, to_jsonb(OLD), to_jsonb(NEW));
    RETURN NEW;
  ELSE
    INSERT INTO audit_log(table_name, action, row_pk, old_data)
    VALUES (TG_TABLE_NAME, TG_OP, NULL, to_jsonb(OLD));
    RETURN OLD;
  END IF;
END $$;

DROP TRIGGER IF EXISTS t_audit_character ON character;
CREATE TRIGGER t_audit_character
AFTER INSERT OR UPDATE OR DELETE ON character
FOR EACH ROW EXECUTE FUNCTION trg_audit_generic();

COMMIT;
