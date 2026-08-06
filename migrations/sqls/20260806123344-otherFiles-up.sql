-- I file che photovault non gestisce: tutto cio' che non e' immagine, video o
-- RAW secondo l'allowlist dello scan. Finora venivano semplicemente saltati e
-- non esisteva modo di sapere cosa ci fosse sulla share oltre alla libreria.
--
-- Tabella separata da media, non un media_kind in piu', per due ragioni:
-- media ha le colonne della pipeline (thumb_status, label_status, dhash...) e
-- un .psd finirebbe in coda per una thumbnail che nessuno sa fare; e ogni
-- query esistente dovrebbe crescere di un "AND media_kind <> 'other'".
--
-- Il percorso e' testo e non un folder_id: una cartella che contiene solo file
-- non gestiti non deve comparire nell'albero di Sfoglia come cartella vuota.
CREATE TABLE other_files (
  other_id      SERIAL PRIMARY KEY,
  root_id       INT NOT NULL REFERENCES roots,
  "path"        varchar NOT NULL,        -- cartella, relativa alla root, con lo slash finale
  file_name     varchar NOT NULL,
  ext           varchar NOT NULL,
  file_size     bigint NOT NULL,
  modified      timestamptz NOT NULL,
  created       timestamptz NOT NULL DEFAULT NOW(),
  last_seen     timestamptz NOT NULL DEFAULT NOW(),
  missing_since timestamptz,
  UNIQUE(root_id, "path", file_name)
);

-- **
-- L'elenco si ordina per dimensione (i file grossi sono quelli che interessa
-- togliere) e per estensione (per fare pulizia di categoria).
CREATE INDEX other_files_size_idx ON other_files (file_size DESC) WHERE missing_since IS NULL;

-- **
CREATE INDEX other_files_ext_idx ON other_files (ext) WHERE missing_since IS NULL;

-- **
-- Il cestino accoglie anche questi file. media_id e other_id sono entrambi
-- facoltativi e mutuamente esclusivi: una riga di cestino sa da quale delle due
-- tabelle e' venuta, e completeTrash cancella quella giusta a spostamento
-- avvenuto. Riferimento nudo come media_id, per lo stesso motivo: la riga di
-- origine sparisce, quella di cestino resta come registro.
ALTER TABLE trash ADD COLUMN other_id INT;

-- **
-- Il cestino diventa anche un filtro: griglia, ricerca, anteprime e conteggi
-- escludono cio' che ha una richiesta di cestinamento ancora pendente, perche'
-- fino al passaggio di trashapply la riga esiste ma per l'utente il file non
-- c'e' piu'. Questi due indici servono a quel NOT EXISTS.
CREATE INDEX trash_media_pending_idx ON trash (media_id) WHERE "status" = 'pending';

-- **
CREATE INDEX trash_other_pending_idx ON trash (other_id) WHERE "status" = 'pending';
