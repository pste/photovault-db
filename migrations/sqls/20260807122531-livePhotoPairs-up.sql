-- Il video di una Live Photo punta alla foto di cui e' il movimento.
--
-- Non si usa media_kind = 'livephoto', come diceva il piano iniziale: quel campo
-- decide come il pod decodifica il file e quali code lo prendono (il dHash
-- esclude i video, thumbs sceglie ffmpeg o image.Decode), e cambiarne il valore
-- obbligherebbe a rivedere ogni punto che lo legge. Una colonna a parte lascia
-- il video un video per tutta la pipeline, e in piu' dice **di quale foto** e'
-- il movimento -- che e' cio' che serve alla UI per collegarli.
--
-- ON DELETE SET NULL e non CASCADE: se si cestina la foto, il video resta e
-- torna un video normale. Il contrario di quello che farebbe CASCADE, che lo
-- cancellerebbe insieme a lei.
ALTER TABLE media ADD COLUMN live_photo_of integer NULL
    REFERENCES media(media_id) ON DELETE SET NULL;

-- Parziale: le Live Photo sono 525 su 338.000, e un indice su tutta la tabella
-- sarebbe quasi tutto NULL. Serve alle due domande che si fanno davvero --
-- "quali sono i video da nascondere" e "quali foto hanno il movimento".
CREATE INDEX media_live_photo_idx ON media (live_photo_of)
    WHERE live_photo_of IS NOT NULL;
