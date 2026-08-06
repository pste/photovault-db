-- Coda dei tag di luogo, separata da quella di CLIP.
--
-- I luoghi si ricavano dal GPS EXIF o dal nome della cartella, quindi non
-- dipendono dalle thumbnail: possono girare subito, mentre label_status
-- aspetta thumb_status='done' perche' CLIP legge la thumbnail m.
-- Tenerli sulla stessa colonna significherebbe o bloccare i luoghi dietro
-- 331.000 anteprime, o marcare come etichettata una foto che CLIP non ha
-- ancora visto.
--
-- Valori: pending / done / error.
ALTER TABLE media ADD COLUMN place_status varchar NOT NULL DEFAULT 'pending';

-- **
-- Indice parziale come gli altri della pipeline: la coda e' "cosa manca", e
-- l'indice deve contenere solo quello.
CREATE INDEX media_place_todo_idx ON media (media_id) WHERE place_status = 'pending';
