-- Nessun indice da togliere: i tag sono qualche centinaio e la colonna si legge
-- sempre insieme alla riga. La lezione della migration otherFiles -- un indice
-- sopravvissuto a un down fa fallire l'up successivo -- qui non si applica, ma
-- vale la pena scriverlo per chi aggiungesse un indice domani.
ALTER TABLE tags DROP COLUMN blocked;
