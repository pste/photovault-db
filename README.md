# photovault-db

Migrations dello schema PostgreSQL di photovault.

È l'unico posto dove lo schema viene definito. Nessun altro componente crea o altera tabelle:
`photovault-api` le usa e basta.

## Requisiti

- Node.js 24
- Un PostgreSQL raggiungibile (in sviluppo: container Docker, vedi sotto)

## Setup

```bash
npm install
cp .env.dist .env
```

Poi si compila `.env` con i parametri di connessione:

```
PG_HOST=localhost
PG_PORT=5432
PG_DB=photovault
PG_USER=photovault
PG_PASSWORD=
```

## Postgres locale

```bash
sh private/run.sh
```

Avvia un container `postgres:14` con volume persistente. Stessa versione che gira sul cluster:
allinearla evita di scoprire in produzione una differenza di comportamento.

## Uso

```bash
# aiuto
node app.js

# creare una nuova migration (genera il .js + i due .sql)
node app.js -e local create <nome-migration>

# applicare tutte le migration pendenti
node app.js -e local up

# applicarne una sola
node app.js -e local up -c 1

# annullare l'ultima
node app.js -e local down
```

Sul cluster si passa da un port-forward:

```bash
kubectl -n photovault port-forward deployment/postgres 5432:5432
node app.js -e local up
```

Sono le stesse variabili: con il port-forward attivo, `localhost:5432` **è** il database del
cluster. Vanno quindi valorizzate con le credenziali del secret `photovault-pgcreds`, non con
quelle dello sviluppo — per questo non si chiamano più `PG_DEV_*`.

## Come si scrive una migration

`node app.js -e local create userFavorites` genera tre file:

```
migrations/20260804120000-userFavorites.js              # NON si tocca
migrations/sqls/20260804120000-userFavorites-up.sql     # qui va la modifica
migrations/sqls/20260804120000-userFavorites-down.sql   # qui va il rollback
```

Il `.js` è boilerplate generato che legge i due `.sql` e li passa a `db.runSql`: non va mai
modificato a mano. Tutto il lavoro sta nei due file SQL — `up` applica la modifica, `down` la
annulla.

Convenzioni SQL del progetto:

- chiave primaria `SERIAL PRIMARY KEY` chiamata `<tabella>_id`;
- **`timestamptz` sempre**, mai `timestamp` nudo: in reimagined-disco l'uso di `timestamp` ha
  prodotto un bug di fuso orario tra Node e PostgreSQL, corretto poi con due migration
  apposite;
- identificatori tra virgolette solo quando servono (`"when"`, `"name"`, `"status"`);
- separatore `-- **` tra le istruzioni;
- `ON DELETE CASCADE` sulle tabelle figlie di `media` (`media_tags`, `media_embeddings`,
  `dup_members`): le righe sono possedute dalla riga media, e la cascade elimina un'intera
  classe di bug di ordinamento delle delete.

La tabella di servizio delle migration si chiama `migrate_table` (forzata in `app.js`, non è
il default di db-migrate).
