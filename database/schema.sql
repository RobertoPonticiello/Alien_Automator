-- =============================================================================
-- Schema SQLite per Alien Mind
-- =============================================================================
-- Tre tabelle:
--   quotes            citazioni curate (70% del flusso)
--   generated_quotes  citazioni generate da Claude (30% del flusso)
--   posts             registro dei contenuti creati (link a una delle due sopra)
--
-- Lo schema e' idempotente (CREATE ... IF NOT EXISTS): puoi rieseguirlo
-- senza distruggere dati. seed-quotes.js e add-quote.js lo applicano in apertura.
-- =============================================================================

PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;       -- migliore concorrenza lettura/scrittura

-- -----------------------------------------------------------------------------
-- quotes — citazioni curate da fonti verificate
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS quotes (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  text            TEXT    NOT NULL CHECK (length(text) BETWEEN 10 AND 500),
  author          TEXT    NOT NULL,
  source          TEXT,                                            -- libro/album/canzone/frammento
  theme           TEXT    NOT NULL CHECK (theme IN (
                    'consapevolezza_sé',
                    'individualità_vs_società',
                    'verità_e_illusione',
                    'morte_e_vita',
                    'autenticità',
                    'presente',
                    'paradossi_esistenziali'
                  )),
  mood            TEXT    NOT NULL CHECK (mood IN (
                    'solenne',
                    'tagliente',
                    'intimo',
                    'onirico',
                    'provocatorio'
                  )),
  used_count      INTEGER NOT NULL DEFAULT 0,
  last_used_at    DATETIME,
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (text, author)                                           -- evita duplicati al re-seed
);

-- Indice usato dal workflow per pescare la citazione "piu' fresca":
-- usate meno volte, e tra queste quelle non usate da piu' tempo.
CREATE INDEX IF NOT EXISTS idx_quotes_priority
  ON quotes (used_count ASC, last_used_at ASC);

-- -----------------------------------------------------------------------------
-- generated_quotes — output di Claude per il 30% generato
-- -----------------------------------------------------------------------------
-- Stessi campi di `quotes` piu' `quality_score`, che Roberto compila a posteriori
-- (dopo l'approvazione/rigetto del post) per fine-tuning del prompt.
CREATE TABLE IF NOT EXISTS generated_quotes (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  text            TEXT    NOT NULL CHECK (length(text) BETWEEN 10 AND 500),
  author          TEXT    NOT NULL DEFAULT 'Alien Mind',
  source          TEXT,                                            -- es. 'claude-sonnet-4-6 / structure=binaria'
  theme           TEXT    NOT NULL CHECK (theme IN (
                    'consapevolezza_sé',
                    'individualità_vs_società',
                    'verità_e_illusione',
                    'morte_e_vita',
                    'autenticità',
                    'presente',
                    'paradossi_esistenziali'
                  )),
  mood            TEXT    NOT NULL CHECK (mood IN (
                    'solenne',
                    'tagliente',
                    'intimo',
                    'onirico',
                    'provocatorio'
                  )),
  quality_score   INTEGER CHECK (quality_score BETWEEN 1 AND 5),   -- valutazione manuale post-review
  used_count      INTEGER NOT NULL DEFAULT 0,
  last_used_at    DATETIME,
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_generated_quotes_score
  ON generated_quotes (quality_score DESC, created_at DESC);

-- -----------------------------------------------------------------------------
-- posts — un record per ogni contenuto generato (bozza/approvato/rigettato/pubblicato)
-- -----------------------------------------------------------------------------
-- quote_id punta a `quotes.id` se quote_source='curated', altrimenti a
-- `generated_quotes.id`. Niente FK formale (sarebbe ambigua); l'integrita'
-- la garantisce il workflow n8n in fase di INSERT.
CREATE TABLE IF NOT EXISTS posts (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  quote_id          INTEGER NOT NULL,
  quote_source      TEXT    NOT NULL CHECK (quote_source IN ('curated', 'generated')),
  image_url_drive   TEXT,                                          -- URL Drive del file (settato all'approvazione)
  status            TEXT    NOT NULL DEFAULT 'draft' CHECK (status IN (
                      'draft', 'approved', 'rejected', 'published'
                    )),
  created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  approved_at       DATETIME
);

CREATE INDEX IF NOT EXISTS idx_posts_status ON posts (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_quote  ON posts (quote_source, quote_id);
