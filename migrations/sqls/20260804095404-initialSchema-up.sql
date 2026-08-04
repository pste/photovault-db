-- UP

-- **
-- Radici di scansione.
-- rel_path e' RELATIVO al mount, non assoluto: il percorso di mount e' una
-- proprieta' del pod (MEDIA_ROOT) e cambia tra sviluppo e cluster, quindi
-- metterlo nel database renderebbe lo stesso DB inutilizzabile altrove.
-- Stringa vuota = la radice della share.
CREATE TABLE roots (
  root_id     SERIAL PRIMARY KEY,
  "name"      varchar NOT NULL,
  rel_path    varchar NOT NULL DEFAULT '',
  enabled     boolean NOT NULL DEFAULT true,
  last_scan   timestamptz,
  media_count int NOT NULL DEFAULT 0,    -- fotografia all'ultimo scan: alimenta il guard del reconcile
  UNIQUE("name")
);

-- **
-- Albero delle cartelle. Si tengono ENTRAMBI parent_id e il path materializzato:
-- parent_id serve alla navigazione (figli di X), path serve al breadcrumb e alla
-- ricerca ricorsiva (path LIKE '2019/%'), che con una CTE ricorsiva costerebbe molto di piu'.
-- Lo scan e' l'unico scrittore e ricalcola il path durante il walk, quindi la
-- denormalizzazione non ha costo di manutenzione.
CREATE TABLE folders (
  folder_id     SERIAL PRIMARY KEY,
  root_id       INT NOT NULL REFERENCES roots,
  parent_id     INT REFERENCES folders,  -- NULL = primo livello della root
  "name"        varchar NOT NULL,
  "path"        varchar NOT NULL,        -- relativo alla root, con slash finale: "2019/Barcellona/"
  depth         int NOT NULL DEFAULT 0,
  media_count   int NOT NULL DEFAULT 0,  -- solo figli diretti, ricalcolato a fine scan
  sub_count     int NOT NULL DEFAULT 0,
  missing_since timestamptz,
  UNIQUE(root_id, "path")
);
CREATE INDEX folders_parent_idx ON folders (parent_id, "name");
CREATE INDEX folders_path_idx   ON folders (root_id, "path" text_pattern_ops);

-- **
CREATE TABLE media (
  media_id      SERIAL PRIMARY KEY,
  folder_id     INT NOT NULL REFERENCES folders,
  file_name     varchar NOT NULL,
  media_kind    varchar NOT NULL,        -- image / video / livephoto
  ext           varchar NOT NULL,        -- minuscolo, senza punto
  file_size     bigint NOT NULL,
  modified      timestamptz NOT NULL,    -- mtime del filesystem, base del rescan incrementale
  -- hash, calcolati da photovault-dedup
  content_hash  varchar,                 -- sha256 esadecimale
  hash_kind     varchar,                 -- sha256 / sha256-partial
  dhash         bit(64),                 -- hash percettivo; bit(64) e non bigint: e' unsigned,
                                         -- e cosi' # e' lo XOR e bit_count() e' core PostgreSQL 14
  dedup_checked timestamptz,             -- NULL = mai confrontato col corpus
  -- proprieta' del media
  width         int,
  height        int,
  duration_s    numeric(10,3),           -- solo video
  orientation   int,                     -- EXIF 1..8, gia' applicato alle thumbnail
  -- metadati di scatto
  capture_ts    timestamptz,             -- EXIF DateTimeOriginal, ripiega su modified
  camera_make   varchar,
  camera_model  varchar,
  gps_lat       double precision,
  gps_lon       double precision,
  -- stato della pipeline: queste colonne SONO la coda di lavoro dei cron
  thumb_status  varchar NOT NULL DEFAULT 'pending',  -- pending / done / unsupported / error
  label_status  varchar NOT NULL DEFAULT 'pending',  -- pending / done / skipped / error
  missing_since timestamptz,             -- impostata dal reconcile, mai una hard delete
  created       timestamptz NOT NULL DEFAULT NOW(),
  -- updated cambia solo quando il file cambia davvero: e' il token di cache delle
  -- thumbnail (?v=), quindi non va toccato a ogni passata dello scan.
  updated       timestamptz NOT NULL DEFAULT NOW(),
  -- last_seen viene aggiornata a OGNI passata, anche sui file immutati: e' cosi'
  -- che il reconcile distingue "non piu' sul disco" da "non modificato".
  last_seen     timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE(folder_id, file_name)
);
-- navigazione: contenuto di una cartella con l'ordinamento di default
CREATE INDEX media_browse_idx     ON media (folder_id, capture_ts DESC NULLS LAST, media_id);
-- duplicati esatti
CREATE INDEX media_hash_idx       ON media (content_hash) WHERE content_hash IS NOT NULL;
-- timeline globale e ricerca per intervallo di date
CREATE INDEX media_capture_idx    ON media (capture_ts DESC NULLS LAST) WHERE missing_since IS NULL;
-- ricerca per nome file
CREATE INDEX media_name_idx       ON media (lower(file_name) varchar_pattern_ops);
-- code di lavoro: indici parziali, restano piccoli una volta finito il backfill
CREATE INDEX media_thumb_todo_idx ON media (media_id) WHERE thumb_status = 'pending';
CREATE INDEX media_label_todo_idx ON media (media_id) WHERE label_status = 'pending';
CREATE INDEX media_hash_todo_idx  ON media (media_id) WHERE content_hash IS NULL;
CREATE INDEX media_dedup_todo_idx ON media (media_id) WHERE dedup_checked IS NULL;

-- **
CREATE TABLE tags (
  tag_id       SERIAL PRIMARY KEY,
  "name"       varchar NOT NULL,         -- nome macchina, ascii minuscolo: sea, mountain, barcelona
  display_name varchar NOT NULL,         -- etichetta in UI, italiano: Mare, Montagna, Barcellona
  kind         varchar NOT NULL,         -- scene / subject / time / place_type / place / user
  UNIQUE("name")
);
CREATE INDEX tags_kind_idx ON tags (kind, display_name);

-- **
CREATE TABLE media_tags (
  media_id INT NOT NULL REFERENCES media ON DELETE CASCADE,
  tag_id   INT NOT NULL REFERENCES tags ON DELETE CASCADE,
  score    numeric(4,3),                 -- confidenza 0..1, NULL per i tag geo/cartella/utente
  "source" varchar NOT NULL,             -- clip / geo / folder / user
  created  timestamptz NOT NULL DEFAULT NOW(),
  PRIMARY KEY (media_id, tag_id)
);
CREATE INDEX media_tags_tag_idx ON media_tags (tag_id, media_id);

-- **
-- Embedding CLIP come bytea e non pgvector: postgres:14 non include l'estensione,
-- e a questa scala la ricerca per similarita' a forza bruta nell'API (50k x 512 = 25M
-- moltiplicazioni, ~30 ms) e' piu' veloce e molto piu' semplice di un indice HNSW.
CREATE TABLE media_embeddings (
  media_id INT PRIMARY KEY REFERENCES media ON DELETE CASCADE,
  model    varchar NOT NULL,             -- clip-vit-b32
  dim      int NOT NULL,                 -- 512
  "vector" bytea NOT NULL,               -- dim float32 little endian, normalizzati L2
  created  timestamptz NOT NULL DEFAULT NOW()
);

-- **
CREATE TABLE dup_groups (
  dup_group_id SERIAL PRIMARY KEY,
  kind         varchar NOT NULL,         -- exact / similar
  group_key    varchar NOT NULL,         -- content_hash per exact, min(media_id) per similar
  member_count int NOT NULL DEFAULT 0,
  bytes_wasted bigint NOT NULL DEFAULT 0,
  "status"     varchar NOT NULL DEFAULT 'open',  -- open / resolved / ignored
  created      timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE(kind, group_key)
);
CREATE INDEX dup_groups_status_idx ON dup_groups ("status", bytes_wasted DESC);

-- **
CREATE TABLE dup_members (
  dup_group_id INT NOT NULL REFERENCES dup_groups ON DELETE CASCADE,
  media_id     INT NOT NULL REFERENCES media ON DELETE CASCADE,
  distance     int NOT NULL DEFAULT 0,   -- distanza di Hamming dal keeper del gruppo
  is_keeper    boolean NOT NULL DEFAULT false,
  PRIMARY KEY (dup_group_id, media_id)
);
CREATE INDEX dup_members_media_idx ON dup_members (media_id);

-- **
-- Cestino. Non si cancella mai un file: si sposta in .photovault/trash/.
-- Una rename sulla stessa share SMB e' atomica e istantanea, e rende ogni
-- errore recuperabile con un mv.
CREATE TABLE trash (
  trash_id      SERIAL PRIMARY KEY,
  media_id      INT,                     -- riferimento nudo: la riga media sparisce dopo lo spostamento
  root_id       INT NOT NULL REFERENCES roots,
  original_path varchar NOT NULL,        -- relativo alla root
  trash_path    varchar NOT NULL,        -- relativo alla root, sotto .photovault/trash/
  file_size     bigint NOT NULL,
  content_hash  varchar,
  "status"      varchar NOT NULL DEFAULT 'pending',  -- pending / done / error
  requested     timestamptz NOT NULL DEFAULT NOW(),
  executed      timestamptz,
  "result"      varchar
);
CREATE INDEX trash_pending_idx ON trash (trash_id) WHERE "status" = 'pending';

-- **
CREATE TABLE jobs (
  job_id    SERIAL PRIMARY KEY,
  "name"    varchar NOT NULL,            -- scan / fullscan / thumbs / dedup / label / trashapply
  "when"    timestamptz NOT NULL,        -- timestamptz e non timestamp: vedi reimagined-disco
  "status"  varchar NOT NULL DEFAULT 'pending',  -- pending / running / done / error
  "started" timestamptz,
  "ended"   timestamptz,
  "result"  varchar
);
CREATE UNIQUE INDEX jobs_one_pending_per_name ON jobs ("name") WHERE "status" = 'pending';

-- **
CREATE TABLE parameters (
  parameters_id      SERIAL PRIMARY KEY,
  cron_scan          varchar NOT NULL DEFAULT '0 2 * * *',
  cron_label         varchar NOT NULL DEFAULT '30 3 * * *',
  cron_dedup         varchar NOT NULL DEFAULT '0 5 * * 0',
  thumb_small_px     int NOT NULL DEFAULT 320,
  thumb_medium_px    int NOT NULL DEFAULT 1280,
  clip_min_score     numeric(4,3) NOT NULL DEFAULT 0.350,
  dedup_max_distance int NOT NULL DEFAULT 6,
  page_size          int NOT NULL DEFAULT 200
);
INSERT INTO parameters DEFAULT VALUES;

-- **
-- In un sistema guidato da cron nessuno guarda lo stdout: questa tabella e'
-- l'unico modo in cui gli errori diventano visibili in UI.
CREATE TABLE logs (
  log_id    SERIAL PRIMARY KEY,
  "when"    timestamptz NOT NULL DEFAULT NOW(),
  "message" varchar NOT NULL,
  "detail"  varchar
);
