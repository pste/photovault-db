-- Battito dei job in esecuzione.
--
-- Un pod che muore senza poter chiudere il proprio job lo lascia 'running' per
-- sempre, e da quel momento il claim -- che esclude i nomi gia' in esecuzione
-- -- non prende piu' nessun job con quel nome. E' successo tre volte in un
-- giorno: pod eliminato a mano, API riavviata durante lo scan, job interrotto.
-- Il sintomo e' il peggiore possibile: niente errori, semplicemente i job
-- smettono di partire.
--
-- Non basta un timeout sull'orario di avvio: "thumbs" su un archivio da 338.000
-- file gira legittimamente per giorni. Serve sapere se il pod e' vivo, non da
-- quanto e' partito -- e questo lo dice il battito, che il pod aggiorna a ogni
-- blocco di lavoro completato.
ALTER TABLE jobs ADD COLUMN heartbeat timestamptz;

-- **
-- I job gia' in esecuzione al momento della migration non hanno battito: si
-- parte dal loro orario di avvio, cosi' il primo claim successivo li valuta
-- come tutti gli altri invece di recuperarli subito.
UPDATE jobs SET heartbeat = started WHERE status = 'running';
