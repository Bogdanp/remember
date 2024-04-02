ALTER TABLE entries ADD COLUMN next_recurrence_at TEXT;
ALTER TABLE entries ADD COLUMN recurrence_delta INTEGER;
ALTER TABLE entries ADD COLUMN recurrence_modifier INTEGER NULLABLE;
