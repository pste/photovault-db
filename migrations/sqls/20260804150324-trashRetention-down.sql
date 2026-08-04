-- DOWN

-- **
DROP INDEX IF EXISTS trash_purgeable_idx;

-- **
ALTER TABLE parameters DROP COLUMN IF EXISTS trash_retention_days;
