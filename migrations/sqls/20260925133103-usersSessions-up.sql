-- Utenti e sessioni web.
--
-- Fino al 2026-09-25 photovault non aveva login: girava solo in LAN, e la sola
-- regola era il bearer token su /api/internal. Resta in LAN, ma chi apre l'app
-- ora si identifica: per alzare la sicurezza, e perche' e' il presupposto per
-- sapere chi ha fatto cosa.
--
-- Tutti gli utenti vedono la stessa libreria: niente ruoli. Si creano da riga
-- di comando nel pod API (node app.js user add), non da una pagina web.
--
-- password_hash e' "scrypt$<N>$<r>$<p>$<salt>$<hash>": la password non si
-- salva mai in chiaro, e i parametri stanno nella stringa, cosi' si possono
-- alzare in futuro senza invalidare gli hash esistenti.
CREATE TABLE users (
  user_id       SERIAL PRIMARY KEY,
  username      varchar NOT NULL,
  password_hash varchar NOT NULL,
  created       timestamptz NOT NULL DEFAULT NOW(),
  last_login    timestamptz
);
-- Unico senza distinzione fra maiuscole e minuscole: "Steo" e "steo" sono la
-- stessa persona, e il login li tratta allo stesso modo.
CREATE UNIQUE INDEX users_username_idx ON users (lower(username));

-- Sessioni di @fastify/session: stanno in database per sopravvivere ai
-- riavvii del pod API, che senza sloggerebbero tutti.
CREATE TABLE sessions (
  sid     varchar PRIMARY KEY,
  data    jsonb NOT NULL,          -- sessione serializzata: cookie e utente
  expires timestamptz NOT NULL     -- = cookie.expires, per la pulizia delle scadute
);
CREATE INDEX sessions_expires_idx ON sessions (expires);
