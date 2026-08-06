-- L'indice cade insieme alla colonna, ma lo si toglie esplicitamente: la
-- migration otherFiles ha gia' insegnato che un indice sopravvissuto a un down
-- fa fallire l'up successivo con "relation already exists", e l'errore non dice
-- da dove venga.
DROP INDEX IF EXISTS media_place_todo_idx;

-- **
ALTER TABLE media DROP COLUMN place_status;
