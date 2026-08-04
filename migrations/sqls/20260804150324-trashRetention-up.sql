-- UP

-- **
-- Giorni di permanenza nel cestino prima dello svuotamento automatico.
-- E' la finestra entro cui un errore resta recuperabile con un mv.
ALTER TABLE parameters
  ADD COLUMN trash_retention_days int NOT NULL DEFAULT 30;

-- **
-- Il cestino ha un terzo stato oltre a pending/done: 'purged', cioe' file
-- rimosso davvero dal disco dopo la scadenza. Le righe restano in tabella come
-- registro di cosa e' stato cancellato e quando.
CREATE INDEX trash_purgeable_idx ON trash (executed)
  WHERE "status" = 'done';
