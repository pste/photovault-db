-- L'indice cade con la colonna, ma lo si toglie esplicitamente: la migration
-- otherFiles ha gia' insegnato che un indice sopravvissuto a un down fa fallire
-- l'up successivo con "relation already exists", e l'errore non dice da dove venga.
DROP INDEX IF EXISTS media_live_photo_idx;

-- **
ALTER TABLE media DROP COLUMN live_photo_of;
