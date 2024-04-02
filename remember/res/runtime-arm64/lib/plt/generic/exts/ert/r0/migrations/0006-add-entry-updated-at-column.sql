ALTER TABLE entries ADD COLUMN updated_at TEXT NOT NULL DEFAULT '';
UPDATE entries SET updated_at = STRFTIME('%Y-%m-%dT%H:%M:%f');
