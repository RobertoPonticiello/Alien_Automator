#!/usr/bin/env bash
# ==============================================================================
# Test Step 2 — verifica DB citazioni:
#   1. Build immagine (cached, fast)
#   2. Run seed-quotes.js dentro il container
#   3. Conta righe e distribuzione tema/mood
#   4. Test add-quote.js in modalita' non-interattiva (dummy quote)
#   5. Test re-run seed-quotes.js (idempotenza: 0 nuove righe)
#   6. Test validazione: rifiuta una citazione con punto esclamativo
#   7. Cleanup container effimeri (volume DB preservato)
#
# Uso:
#   sudo bash scripts/test-step2.sh
#
# Tutto loggato in scripts/test-output/test-step2.log
# ==============================================================================
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

LOG_DIR="${PROJECT_ROOT}/scripts/test-output"
LOG_FILE="${LOG_DIR}/test-step2.log"
mkdir -p "${LOG_DIR}"

DOCKER_BIN="$(command -v docker || echo /snap/bin/docker)"
if [[ ! -x "${DOCKER_BIN}" ]]; then
  echo "ERRORE: docker non trovato"
  exit 1
fi

exec > >(tee "${LOG_FILE}") 2>&1

echo "================================================================"
echo "Alien Mind — Test Step 2 (DB citazioni)"
echo "Avviato:  $(date -Iseconds)"
echo "Project:  ${PROJECT_ROOT}"
echo "Log file: ${LOG_FILE}"
echo "================================================================"
echo

# Helper: docker compose run --rm con node entrypoint
RUN_NODE=("${DOCKER_BIN}" compose run --rm --no-deps --entrypoint node n8n)

# --- 0. Cleanup DB precedente -------------------------------------------------
DB_FILE="${PROJECT_ROOT}/database/quotes.db"
if [[ -f "${DB_FILE}" ]]; then
  BACKUP="${DB_FILE}.backup-$(date +%Y%m%d-%H%M%S)"
  echo "[0] Trovato DB precedente: ${DB_FILE}"
  echo "    Backup -> ${BACKUP}"
  mv "${DB_FILE}" "${BACKUP}"
fi
rm -f "${PROJECT_ROOT}/database/quotes.db-journal" "${PROJECT_ROOT}/database/quotes.db-wal" "${PROJECT_ROOT}/database/quotes.db-shm"
echo

# --- 1. Build (cached) --------------------------------------------------------
echo "[1] Build immagine (dovrebbe essere CACHED)..."
"${DOCKER_BIN}" compose build 2>&1 | tail -8
echo

# --- 2. Run seed-quotes.js ----------------------------------------------------
echo "[2] Run seed-quotes.js dentro il container..."
"${RUN_NODE[@]}" /data/scripts/seed-quotes.js
SEED_RC=$?
if [[ ${SEED_RC} -ne 0 ]]; then
  echo "  ✗ seed-quotes.js exit ${SEED_RC}"
  exit 2
fi
echo "  ✓ seed-quotes.js completato"
echo

# --- 3. Verifica conteggio + distribuzione -----------------------------------
echo "[3] Verifica DB letta direttamente da Node..."
"${RUN_NODE[@]}" -e "
const Database = require('better-sqlite3');
const db = new Database('/data/database/quotes.db', { readonly: true });
const total = db.prepare('SELECT COUNT(*) AS n FROM quotes').get().n;
console.log('  Totale citazioni:', total);
const themes = db.prepare(\"SELECT theme, COUNT(*) AS n FROM quotes GROUP BY theme ORDER BY n DESC\").all();
console.log('  Per tema:'); for (const r of themes) console.log('    ', r.theme.padEnd(28), r.n);
const moods = db.prepare(\"SELECT mood, COUNT(*) AS n FROM quotes GROUP BY mood ORDER BY n DESC\").all();
console.log('  Per mood:'); for (const r of moods)  console.log('    ', r.mood.padEnd(14), r.n);
const tables = db.prepare(\"SELECT name FROM sqlite_master WHERE type='table' ORDER BY name\").all().map(r => r.name);
console.log('  Tabelle create:', tables.join(', '));
db.close();
if (total !== 19) { console.error('  ✗ ATTESO 19, TROVATO ' + total); process.exit(3); }
console.log('  ✓ 19 citazioni come atteso');
"
[[ $? -ne 0 ]] && exit 3
echo

# --- 4. add-quote.js non-interattivo -----------------------------------------
echo "[4] add-quote.js: aggiungo una citazione di test (non-interattivo)..."
"${RUN_NODE[@]}" /data/scripts/add-quote.js \
  --text "Questa è una citazione di test inserita dal test-step2 per verificare add-quote" \
  --author "Test Author" \
  --source "Smoke test step 2" \
  --theme "consapevolezza_sé" \
  --mood "intimo"
ADD_RC=$?
if [[ ${ADD_RC} -ne 0 ]]; then
  echo "  ✗ add-quote.js exit ${ADD_RC}"
  exit 4
fi
echo "  ✓ add-quote.js OK (totale atteso: 20)"
echo

# --- 5. Idempotenza del seed --------------------------------------------------
echo "[5] Re-run seed-quotes.js (deve dire: 0 nuove righe inserite)..."
SEED_OUT=$("${RUN_NODE[@]}" /data/scripts/seed-quotes.js 2>&1)
echo "${SEED_OUT}" | grep -E "(Citazioni nuove|Totale citazioni)"
if echo "${SEED_OUT}" | grep -qE "Citazioni nuove inserite: 0"; then
  echo "  ✓ Idempotenza confermata (0 nuove righe)"
else
  echo "  ✗ Idempotenza fallita: il seed ha inserito righe in piu'"
  exit 5
fi
echo

# --- 6. Validazione: rifiuta punto esclamativo --------------------------------
echo "[6] Validazione: aspetto che add-quote.js rifiuti una frase con '!'..."
"${RUN_NODE[@]}" /data/scripts/add-quote.js \
  --text "Citazione tossico-positiva ce la farai vai cosi tutto bene!" \
  --author "Anti-pattern" --theme "autenticità" --mood "tagliente" \
  > /tmp/_add-quote-fail.log 2>&1
REJECT_RC=$?
if [[ ${REJECT_RC} -eq 2 ]]; then
  echo "  ✓ add-quote.js ha correttamente rifiutato (exit 2):"
  grep "Punto esclamativo" /tmp/_add-quote-fail.log | sed 's/^/    /'
else
  echo "  ✗ Doveva rifiutare ma e' uscito con ${REJECT_RC}"
  cat /tmp/_add-quote-fail.log
  exit 6
fi
echo

# --- 7. Stato finale ----------------------------------------------------------
echo "[7] Stato finale del DB:"
"${RUN_NODE[@]}" -e "
const db = require('better-sqlite3')('/data/database/quotes.db', { readonly: true });
const t = db.prepare('SELECT COUNT(*) AS n FROM quotes').get().n;
const g = db.prepare('SELECT COUNT(*) AS n FROM generated_quotes').get().n;
const p = db.prepare('SELECT COUNT(*) AS n FROM posts').get().n;
console.log('  quotes:           ' + t + ' (atteso: 20 — 19 seed + 1 di test)');
console.log('  generated_quotes: ' + g + ' (atteso: 0)');
console.log('  posts:            ' + p + ' (atteso: 0)');
db.close();
"
echo

echo "================================================================"
echo "Test Step 2 — TERMINATO OK"
echo "Concluso: $(date -Iseconds)"
echo "================================================================"
