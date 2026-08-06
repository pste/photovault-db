-- I due contatori denormalizzati di folders spariscono: la navigazione li
-- calcola al momento, con una query sola per tutte le sottocartelle della
-- richiesta (misurata in 2,9 ms su 132k media e 1.730 cartelle).
--
-- Erano aggiornati solo a fine scansione: il numero restava quindi vecchio per
-- tutta la durata dello scan, e per sempre se lo scan falliva prima del
-- reconcile -- una cartella con 11.807 foto dentro mostrava "vuota".
--
-- ATTENZIONE: roots.media_count e' un'altra colonna e resta dov'e'. E' la
-- fotografia dell'ultimo scan che alimenta il guard del 90% del reconcile.
ALTER TABLE folders DROP COLUMN media_count;

-- **
ALTER TABLE folders DROP COLUMN sub_count;
