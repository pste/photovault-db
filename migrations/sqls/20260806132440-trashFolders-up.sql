-- Una cartella si puo' cestinare come un file, e con lo stesso meccanismo: una
-- sola rename di tutta la cartella dentro .photovault/trash/<data>/.
--
-- Una rename e' atomica e istantanea anche su una cartella da 11.807 foto --
-- ce n'e' una in archivio -- mentre spostare file per file sarebbero 11.807
-- rename su CIFS. E il ripristino resta un solo mv.
--
-- Conseguenza accettata: la cartella si porta dietro TUTTO il suo contenuto,
-- sottocartelle e file che photovault non conosce compresi. E' quello che
-- l'utente intende chiedendo di cestinare una cartella.
ALTER TABLE trash ADD COLUMN folder_id INT;

-- **
-- La dimensione di una riga di cartella e' la somma dei media che contiene:
-- serve alla pagina Cestino per dire quanto spazio si libera.
ALTER TABLE trash ADD COLUMN file_count INT;

-- **
-- Le cartelle in attesa di spostamento spariscono subito dall'albero, come i
-- media: fino al passaggio di trashapply la riga esiste ma per l'utente la
-- cartella non c'e' piu'.
CREATE INDEX trash_folder_pending_idx ON trash (folder_id) WHERE "status" = 'pending';
