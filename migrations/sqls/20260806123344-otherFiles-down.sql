-- Le righe di cestino che venivano da other_files restano, ma perdono il
-- riferimento: sono comunque un registro di percorsi, ed e' li' che sta il
-- valore. I file gia' spostati non tornano indietro da soli in nessun caso.
-- Gli indici vanno tolti a mano: quello su other_id se ne andrebbe con la sua
-- colonna, ma quello su media_id no, e sopravvivere al down significherebbe un
-- "relation already exists" al primo up successivo.
DROP INDEX trash_media_pending_idx;

-- **
DROP INDEX trash_other_pending_idx;

-- **
ALTER TABLE trash DROP COLUMN other_id;

-- **
DROP TABLE other_files;
