-- L'indice va tolto prima della colonna solo per simmetria con l'up: cadrebbe
-- comunque insieme a folder_id.
DROP INDEX trash_folder_pending_idx;

-- **
ALTER TABLE trash DROP COLUMN folder_id;

-- **
ALTER TABLE trash DROP COLUMN file_count;
