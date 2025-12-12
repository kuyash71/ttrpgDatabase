-- ============================================================
-- 02_seed.sql - Seed / Sample Data (safe re-run)
-- ============================================================

BEGIN;

-- ENTITY_KIND seeds
INSERT INTO entity_kind(kind_code, description) VALUES
  ('CHARACTER', 'Player Character (PC)'),
  ('NPC',       'Non-player character'),
  ('LOCATION',  'Location / place'),
  ('FACTION',   'Faction / organization')
ON CONFLICT (kind_code) DO NOTHING;

-- Systems
INSERT INTO system(name) VALUES
  ('Umbra Caelis'),
  ('Wolfenstein')
ON CONFLICT (name) DO NOTHING;

-- Universe (sample for Umbra Caelis)
INSERT INTO universe(system_id, name, description)
SELECT s.system_id, 'Umbra Caelis Core', 'Main setting'
FROM system s
WHERE s.name = 'Umbra Caelis'
ON CONFLICT (system_id, name) DO NOTHING;

-- Campaign (sample)
INSERT INTO campaign(universe_id, name, status)
SELECT u.universe_id, 'Campaign 1', 'ACTIVE'
FROM universe u
WHERE u.name = 'Umbra Caelis Core'
ON CONFLICT (universe_id, name) DO NOTHING;

INSERT INTO stat_def(system_id, code, name, min_value, max_value)
SELECT s.system_id, v.code, v.name, 0, 6
FROM system s
JOIN (VALUES
 ('HAK','Hakimiyet'),
 ('SEB','Sebahat'),
 ('CAZ','Cazibe'),
 ('HIK','Hikmet'),
 ('GOR','Görü'),
 ('MAR','Marifet'),
 ('YAL','Yalman'),
 ('EFS','Efsun'),
 ('KAC','Kaçınç')
) v(code,name) ON true
WHERE s.name='Umbra Caelis'
ON CONFLICT (system_id, code) DO NOTHING;

-- Umbra Caelis - resources (example 0..6
INSERT INTO resource_def(system_id, code, name, min_value, max_value)
SELECT s.system_id, v.code, v.name, 0, 6
FROM system s
JOIN (VALUES
 ('HP','Sağlık'),
 ('ESIN','Esin Puanı'),
 ('LUM','Lumre')
) v(code,name) ON true
WHERE s.name='Umbra Caelis'
ON CONFLICT (system_id, code) DO NOTHING;

-- Sample class: Fallen Noble
INSERT INTO rpg_class(system_id, name, lore_text)
SELECT s.system_id, 'Fallen Noble', 'Preset example'
FROM system s
WHERE s.name='Umbra Caelis'
ON CONFLICT (system_id, name) DO NOTHING;

-- More classes
INSERT INTO rpg_class(system_id, name, lore_text)
SELECT s.system_id, v.name, v.lore
FROM system s
JOIN (VALUES
 ('Arcanist', 'Magic-focused caster.'),
 ('Warden',   'Defensive / tank archetype.'),
 ('Vagabond', 'Mobile / skill-oriented archetype.')
) v(name, lore) ON true
WHERE s.name='Umbra Caelis'
ON CONFLICT (system_id, name) DO NOTHING;


-- Arcanist: EFS +2, HIK +1, YAL -1
INSERT INTO class_stat_modifier(class_id, stat_id, delta)
SELECT rc.class_id, sd.stat_id, v.delta
FROM rpg_class rc
JOIN system s ON s.system_id = rc.system_id
JOIN stat_def sd ON sd.system_id = s.system_id
JOIN (VALUES
 ('EFS',  2),
 ('HIK',  1),
 ('YAL', -1)
) v(code, delta) ON v.code = sd.code
WHERE s.name='Umbra Caelis' AND rc.name='Arcanist'
ON CONFLICT (class_id, stat_id) DO UPDATE SET delta = EXCLUDED.delta;

-- Warden: HAK +2, MAR +1, CAZ -1
INSERT INTO class_stat_modifier(class_id, stat_id, delta)
SELECT rc.class_id, sd.stat_id, v.delta
FROM rpg_class rc
JOIN system s ON s.system_id = rc.system_id
JOIN stat_def sd ON sd.system_id = s.system_id
JOIN (VALUES
 ('HAK',  2),
 ('MAR',  1),
 ('CAZ', -1)
) v(code, delta) ON v.code = sd.code
WHERE s.name='Umbra Caelis' AND rc.name='Warden'
ON CONFLICT (class_id, stat_id) DO UPDATE SET delta = EXCLUDED.delta;

-- Vagabond: SEB +1, GOR +1, HAK -1
INSERT INTO class_stat_modifier(class_id, stat_id, delta)
SELECT rc.class_id, sd.stat_id, v.delta
FROM rpg_class rc
JOIN system s ON s.system_id = rc.system_id
JOIN stat_def sd ON sd.system_id = s.system_id
JOIN (VALUES
 ('SEB',  1),
 ('GOR',  1),
 ('HAK', -1)
) v(code, delta) ON v.code = sd.code
WHERE s.name='Umbra Caelis' AND rc.name='Vagabond'
ON CONFLICT (class_id, stat_id) DO UPDATE SET delta = EXCLUDED.delta;


-- Sample class stat modifiers (as you tested)
-- CAZ +2, HAK +1, SEB +1, KAC -1
INSERT INTO class_stat_modifier(class_id, stat_id, delta)
SELECT rc.class_id, sd.stat_id, v.delta
FROM rpg_class rc
JOIN system s ON s.system_id = rc.system_id
JOIN stat_def sd ON sd.system_id = s.system_id
JOIN (VALUES
 ('CAZ',  2),
 ('HAK',  1),
 ('SEB',  1),
 ('KAC', -1)
) v(code, delta) ON v.code = sd.code
WHERE s.name='Umbra Caelis' AND rc.name='Fallen Noble'
ON CONFLICT (class_id, stat_id) DO UPDATE SET delta = EXCLUDED.delta;

-- Sample ability + mapping (optional, but useful)
INSERT INTO ability(system_id, name, rules_text, dice_type)
SELECT s.system_id, 'Noble Bearing', 'Sample ability granted by class.', 'd6'
FROM system s
WHERE s.name='Umbra Caelis'
ON CONFLICT (system_id, name) DO NOTHING;

INSERT INTO class_ability(class_id, ability_id, sort_order)
SELECT rc.class_id, a.ability_id, 1
FROM rpg_class rc
JOIN system s ON s.system_id = rc.system_id
JOIN ability a ON a.system_id = s.system_id
WHERE s.name='Umbra Caelis'
  AND rc.name='Fallen Noble'
  AND a.name='Noble Bearing'
ON CONFLICT (class_id, ability_id) DO NOTHING;

-- Sample item
INSERT INTO item(system_id, name, description)
SELECT s.system_id, 'Rope', 'Basic item'
FROM system s
WHERE s.name='Umbra Caelis'
ON CONFLICT (system_id, name) DO NOTHING;

COMMIT;
