#!/usr/bin/env bash
# ==============================================================================
# Test Step 1 — verifica che la pipeline base si costruisca e parta correttamente.
#
# Uso:
#   sudo bash scripts/test-step1.sh
#
# Cosa fa:
#  1. Build dell'immagine n8n custom (sharp + better-sqlite3)
#  2. Avvio del container alien-mind-n8n
#  3. Attesa che n8n risponda su :5678
#  4. Smoke test: require('sharp') e require('better-sqlite3') dentro il container
#  5. Cleanup: docker compose down (volume preservato)
#
# Tutto l'output va a video E in scripts/test-output/test-step1.log
# ==============================================================================
set -u  # NON set -e: vogliamo continuare e fare cleanup anche su errori

# Trova la root del progetto (cartella padre di questo script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

LOG_DIR="${PROJECT_ROOT}/scripts/test-output"
LOG_FILE="${LOG_DIR}/test-step1.log"
mkdir -p "${LOG_DIR}"

# Trova il binario docker (snap o standard)
DOCKER_BIN="$(command -v docker || echo /snap/bin/docker)"
if [[ ! -x "${DOCKER_BIN}" ]]; then
  echo "ERRORE: docker non trovato" | tee "${LOG_FILE}"
  exit 1
fi

# Redirige tutto su stdout E sul log
exec > >(tee "${LOG_FILE}") 2>&1

echo "================================================================"
echo "Alien Mind — Test Step 1"
echo "Avviato:  $(date -Iseconds)"
echo "Docker:   $(${DOCKER_BIN} --version)"
echo "Compose:  $(${DOCKER_BIN} compose version --short 2>/dev/null || echo 'n/a')"
echo "Project:  ${PROJECT_ROOT}"
echo "Log file: ${LOG_FILE}"
echo "================================================================"
echo

# --- 0. Pre-flight: file richiesti -------------------------------------------
echo "[0/5] Pre-flight check..."
for f in docker-compose.yml Dockerfile .env; do
  if [[ ! -f "${PROJECT_ROOT}/${f}" ]]; then
    echo "  MANCA: ${f}"
    if [[ "${f}" == ".env" ]]; then
      echo "  Creo .env temporaneo dal template per il test..."
      cp .env.example .env
    else
      exit 2
    fi
  else
    echo "  OK: ${f}"
  fi
done
echo

# --- 1. Build ----------------------------------------------------------------
echo "[1/5] Build immagine alien-mind/n8n:latest (1-2 min al primo run, poi cached)..."
BUILD_START=$(date +%s)
"${DOCKER_BIN}" compose build 2>&1
BUILD_RC=$?
BUILD_DUR=$(( $(date +%s) - BUILD_START ))
echo
if [[ ${BUILD_RC} -eq 0 ]]; then
  echo "  ✓ Build completata in ${BUILD_DUR}s"
else
  echo "  ✗ Build FALLITA (exit ${BUILD_RC})"
  exit 3
fi
echo

# --- 2. Up -------------------------------------------------------------------
echo "[2/5] Avvio container..."
"${DOCKER_BIN}" compose up -d 2>&1
UP_RC=$?
if [[ ${UP_RC} -ne 0 ]]; then
  echo "  ✗ Up FALLITO (exit ${UP_RC})"
  "${DOCKER_BIN}" compose logs --tail=80 n8n
  "${DOCKER_BIN}" compose down 2>&1 || true
  exit 4
fi
echo "  ✓ Container partito"
echo

# --- 3. Reachability su :5678 ------------------------------------------------
echo "[3/5] Attendo che n8n risponda su http://localhost:5678 ..."
READY=0
for i in $(seq 1 60); do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 2 http://localhost:5678 2>/dev/null || echo "000")
  if [[ "${HTTP_CODE}" =~ ^(200|301|302|401)$ ]]; then
    echo "  ✓ n8n risponde (HTTP ${HTTP_CODE}) dopo ${i} tentativi"
    READY=1
    break
  fi
  sleep 2
done
if [[ ${READY} -eq 0 ]]; then
  echo "  ✗ n8n non risponde dopo 120s. Ultimi log:"
  "${DOCKER_BIN}" compose logs --tail=80 n8n
fi
echo

# --- 4. Smoke test moduli npm ------------------------------------------------
echo "[4/5] Smoke test: require('sharp') + require('better-sqlite3') nel container..."

# Diagnostica: dove si aspetta i moduli node? Dove sono effettivamente?
echo "  Diagnostica resolver Node:"
"${DOCKER_BIN}" exec alien-mind-n8n sh -c '
  echo "    NODE_PATH=${NODE_PATH:-unset}"
  echo "    npm root -g: $(npm root -g 2>/dev/null || echo "n/a")"
  echo "    /opt/n8n-extra-modules/node_modules:"
  ls /opt/n8n-extra-modules/node_modules 2>/dev/null | head -8 | sed "s/^/      /" || echo "      (assente)"
'

SMOKE_OUT=$("${DOCKER_BIN}" exec alien-mind-n8n node -e "
console.log('  module.paths searched:');
for (const p of module.paths) console.log('    ' + p);
const sharp = require('sharp');
const Database = require('better-sqlite3');
const v_sharp = sharp.versions ? sharp.versions.sharp : 'n/a';
const v_vips  = sharp.versions ? sharp.versions.vips  : 'n/a';
console.log('  sharp version:', v_sharp);
console.log('  vips version:',  v_vips);
console.log('  better-sqlite3 version:', require('better-sqlite3/package.json').version);
const db = new Database(':memory:');
db.exec('CREATE TABLE t(x INTEGER); INSERT INTO t VALUES(42);');
const row = db.prepare('SELECT x FROM t').get();
console.log('  better-sqlite3 query:', JSON.stringify(row));
db.close();
console.log('SMOKE_OK');
" 2>&1)
SMOKE_RC=$?
echo "${SMOKE_OUT}"
if [[ ${SMOKE_RC} -eq 0 ]] && echo "${SMOKE_OUT}" | grep -q "SMOKE_OK"; then
  echo "  ✓ Moduli sharp + better-sqlite3 caricabili e funzionanti"
else
  echo "  ✗ Smoke test FALLITO (exit ${SMOKE_RC})"
fi
echo

# --- 4b. Verifica volumi/permessi --------------------------------------------
echo "[4b] Verifica volumi montati e permessi:"
"${DOCKER_BIN}" exec alien-mind-n8n sh -c '
  echo "  /home/node/.n8n   -> $(ls -ld /home/node/.n8n 2>/dev/null | awk "{print \$1, \$3}")"
  echo "  /data/database    -> $(ls -ld /data/database  2>/dev/null | awk "{print \$1, \$3}")"
  echo "  /data/fonts       -> $(ls -ld /data/fonts     2>/dev/null | awk "{print \$1, \$3}")"
  echo "  /data/scripts     -> $(ls -ld /data/scripts   2>/dev/null | awk "{print \$1, \$3}")"
  echo "  TZ:               $(date +%Z)"
  echo "  NODE_FUNCTION_ALLOW_EXTERNAL: ${NODE_FUNCTION_ALLOW_EXTERNAL:-unset}"
'
echo

# --- 5. Cleanup --------------------------------------------------------------
echo "[5/5] Cleanup: stop container (volume e immagine preservati)..."
"${DOCKER_BIN}" compose down 2>&1
echo "  ✓ Cleanup completato"
echo

echo "================================================================"
echo "Test Step 1 — TERMINATO"
echo "Concluso: $(date -Iseconds)"
echo "Log:      ${LOG_FILE}"
echo "================================================================"
