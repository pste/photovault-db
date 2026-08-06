-- Le colonne tornano con la definizione originale, e vengono ripopolate: un
-- rollback che le ricreasse a zero lascerebbe la versione precedente dell'API a
-- mostrare "vuota" ovunque fino alla prima scansione completata.
ALTER TABLE folders ADD COLUMN media_count int NOT NULL DEFAULT 0;

-- **
ALTER TABLE folders ADD COLUMN sub_count int NOT NULL DEFAULT 0;

-- **
UPDATE folders f SET media_count = COALESCE(c.n, 0)
FROM (
  SELECT fo.folder_id, count(m.media_id) AS n
  FROM folders fo
  LEFT JOIN media m ON m.folder_id = fo.folder_id AND m.missing_since IS NULL
  GROUP BY fo.folder_id
) c
WHERE f.folder_id = c.folder_id;

-- **
UPDATE folders f SET sub_count = COALESCE(c.n, 0)
FROM (
  SELECT fo.folder_id, count(s.folder_id) AS n
  FROM folders fo
  LEFT JOIN folders s ON s.parent_id = fo.folder_id AND s.missing_since IS NULL
  GROUP BY fo.folder_id
) c
WHERE f.folder_id = c.folder_id;
