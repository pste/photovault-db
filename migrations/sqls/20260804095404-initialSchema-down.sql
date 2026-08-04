-- DOWN

-- **
-- Ordine inverso rispetto alle dipendenze. Le tabelle figlie di media hanno
-- ON DELETE CASCADE, ma il DROP va comunque fatto prima della tabella padre.
DROP TABLE IF EXISTS logs;
DROP TABLE IF EXISTS parameters;
DROP TABLE IF EXISTS jobs;
DROP TABLE IF EXISTS trash;
DROP TABLE IF EXISTS dup_members;
DROP TABLE IF EXISTS dup_groups;
DROP TABLE IF EXISTS media_embeddings;
DROP TABLE IF EXISTS media_tags;
DROP TABLE IF EXISTS tags;
DROP TABLE IF EXISTS media;
DROP TABLE IF EXISTS folders;
DROP TABLE IF EXISTS roots;
