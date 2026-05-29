# Alien Mind — Pipeline n8n

Sistema automatizzato per la pubblicazione di contenuti Instagram aforistico-surrealisti per il profilo **Alien Mind**, con review umana via Telegram. Mix 70% citazioni curate / 30% frasi originali generate da OpenAI gpt-5-mini, immagini surreali generate da GPT Image 1.5, composizione tipografica con Sharp, archivio su Google Drive.

> **Una sola API key**: testo (gpt-5-mini) e immagini (gpt-image-1.5) usano entrambi OpenAI. Niente account Anthropic.

> **Stato attuale**: Step 1 completato (setup ambiente). Gli step successivi popoleranno `database/`, `workflows/` e `scripts/`.

---

## Struttura del progetto

```
Alien_Automator/
├── docker-compose.yml          # Orchestrazione n8n + ngrok (profilo dev)
├── Dockerfile                  # n8n esteso con sharp + better-sqlite3
├── .env.example                # Template variabili d'ambiente
├── .gitignore
├── README.md                   # Questo file
├── prompt.md                   # Brief originale del progetto
├── workflows/                  # JSON dei workflow n8n importabili (Step 3)
├── database/                   # DB SQLite citazioni (montato come volume)
├── scripts/                    # Script Node.js (seed, add-quote, compose-image, ...)
├── docs/                       # Guide aggiuntive (Telegram, tipografia, SETUP finale)
└── assets/
    └── fonts/                  # Font custom per la sovrapposizione testo
```

---

## Prerequisiti

| Strumento | Versione minima | Note |
|---|---|---|
| Docker Engine | 24+ | Su Linux installa anche `docker-compose-plugin` |
| Docker Compose | v2 | Comando `docker compose` (non `docker-compose`) |
| Account OpenAI | — | Una sola API key per testo + immagini. **Organizzazione verificata** richiesta per `gpt-image-1.5` (~5-10 min, documento d'identità) |
| Bot Telegram | — | Creato via [@BotFather](https://t.me/botfather) |
| Account Google | — | Con due cartelle Drive create per drafts/approved |
| ngrok (solo dev) | — | Account gratuito + authtoken |

---

## Avvio rapido

```bash
# 1. Clona il repo e entra nella cartella
cd Alien_Automator/

# 2. Crea il file .env dal template e compilalo
cp .env.example .env
# Apri .env e inserisci le credenziali. Per generare la chiave di cifratura n8n:
openssl rand -hex 32   # incolla l'output in N8N_ENCRYPTION_KEY

# 3. Build dell'immagine n8n custom (sharp + better-sqlite3)
docker compose build

# 4. Avvio del servizio
docker compose up -d

# 5. Apri n8n
# http://localhost:5678
```

Al primo avvio n8n chiede di creare l'utente owner (email + password locali, non sono le tue credenziali API). Da quel punto sei dentro l'editor.

### Avvio con tunnel ngrok (per webhook Telegram in dev locale)

Telegram richiede HTTPS pubblico per consegnare le callback degli inline button. In locale usa ngrok:

```bash
# Avvia n8n + ngrok insieme (profilo dev)
docker compose --profile dev up -d

# Recupera l'URL pubblico HTTPS dal dashboard ngrok
open http://localhost:4040
# oppure:
docker logs alien-mind-ngrok | grep -oE 'https://[a-z0-9-]+\.ngrok[^ ]*'

# Aggiorna WEBHOOK_URL in .env con l'URL ngrok (incluso il trailing slash) e riavvia n8n:
docker compose up -d --force-recreate n8n
```

> Alternativa più stabile: [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) (gratuito, dominio fisso, niente URL che cambia ad ogni restart). Vedi `docs/cloudflare-tunnel.md` (verrà creato in Step 7 se opti per questa via).

---

## Prima configurazione UI (n8n)

Una volta dentro l'editor (`http://localhost:5678`), prima dell'import dei workflow vanno create le credenziali condivise.

Servono **solo 3 credenziali** (testo e immagini condividono l'unica chiave OpenAI):

1. **OpenAI** — *Settings → Credentials → New → "OpenAI"*
   - API Key: `={{ $env.OPENAI_API_KEY }}`
   - Copre sia gpt-5-mini (testo) sia gpt-image-1.5 (immagini).

2. **Telegram** — *Credentials → New → "Telegram"*
   - Access Token: `={{ $env.TELEGRAM_BOT_TOKEN }}`

3. **Google Drive** — *Credentials → New → "Google Drive OAuth2 API"*
   - Segui il flow OAuth (richiede progetto su Google Cloud Console con Drive API abilitata, vedi `docs/google-drive-setup.md` — verrà creato in Step 7).

Le credenziali API vengono lette dalle variabili `.env` tramite le expression `$env.NOMEVAR`, quindi non vanno mai incollate in chiaro nei nodi.

---

## Stima costi reali (30 contenuti/mese)

Tariffe verificate ad aprile 2026:

| Voce | Tariffa | Volume mensile | Costo |
|---|---|---|---|
| **GPT Image 1.5** (1024×1536, quality `high`) | $0.20 / immagine | 30 immagini + ~30% rigenerazioni ≈ **39 chiamate** | **$7.80** |
| **gpt-5-mini** — generazione frase originale (30% del flusso) | $0.25 input / $2.00 output per 1M token | ~9 chiamate × ~1k token | **$0.01** |
| **gpt-5-mini** — analisi visiva (su tutte le frasi) | $0.25 input / $2.00 output per 1M token | ~39 chiamate × ~1.2k token | **$0.04** |
| **Telegram Bot API** | gratuito | — | $0.00 |
| **Google Drive** (entro 15 GB free tier) | gratuito | — | $0.00 |
| **n8n self-hosted** | gratuito (community) | — | $0.00 |
| **Totale stimato** | | | **~$7.85/mese** |

A cambio attuale (~1 USD ≈ 0.92 EUR): **~7.20 €/mese** per 30 contenuti, **~3.60 €/mese** per 15 contenuti.

> Il costo è dominato quasi interamente dalla generazione immagini ($7.80). La parte testuale con gpt-5-mini è trascurabile (~$0.05/mese). La stima 5€/mese del brief è raggiungibile a ~25 contenuti/mese senza rigenerazioni: 25 × $0.20 + ~$0.04 = $5.04 ≈ 4.70 €. Restiamo ampiamente sotto il budget di 30 €.

### Note sui modelli

- **Testo** (`gpt-5-mini`): genera le frasi originali e i prompt visivi. Endpoint `POST https://api.openai.com/v1/chat/completions` con `response_format: {type: "json_object"}` per garantire output JSON valido.
- **Immagini** (`gpt-image-1.5`): il brief citava `gpt-image-1` (legacy, $0.25/img); il default 2026 è `gpt-image-1.5` ($0.20/img high 1024×1536, ~4× più veloce). Endpoint `POST https://api.openai.com/v1/images/generations`. Se la tua org non è verificata, fallback su `gpt-image-1` (+25% costo).

---

## Decisione: Sharp dentro n8n vs servizio esterno

**Scelto: Sharp dentro n8n** (in un Code Node), pre-installato nell'immagine via `Dockerfile`.

Motivazioni:
- Zero dipendenze di rete → niente latenza extra né failure mode aggiuntivi
- Niente servizio esterno da mantenere (un container in meno)
- Sharp è battle-tested per composizione immagini in produzione
- L'unico costo è una build iniziale ~1-2 min al primo `docker compose build` (npm install di sharp + better-sqlite3 con prebuilt binaries). Le build successive sono cached e pressoché istantanee.

L'immagine n8n custom abilita anche `better-sqlite3` per i Code Node che leggono/scrivono il DB citazioni.

---

## Troubleshooting

### "I can't reach n8n on http://localhost:5678"
```bash
docker compose ps                    # n8n deve essere "Up"
docker compose logs n8n | tail -50   # cerca errori di boot
```
Se vedi `EADDRINUSE`: hai già un altro servizio sulla porta 5678. Cambia la mappatura in `docker-compose.yml` (es. `5679:5678`).

### "Cannot find module 'sharp'" / "'better-sqlite3'" nei Code Node
Il Dockerfile non è stato eseguito (stai usando l'immagine vanilla di n8n). Forza il rebuild:
```bash
docker compose build --no-cache
docker compose up -d --force-recreate n8n
```
Verifica anche che `NODE_FUNCTION_ALLOW_EXTERNAL` includa entrambi i moduli (è già impostato nel compose).

### Webhook Telegram non riceve callback
1. Telegram **non chiama** webhook su `http://` o IP locale — serve HTTPS pubblico.
2. Verifica che `WEBHOOK_URL` in `.env` sia l'URL ngrok corrente (cambia ad ogni `docker compose restart` con piano free).
3. Dopo aver cambiato `WEBHOOK_URL` riavvia n8n: `docker compose up -d --force-recreate n8n`.
4. Registra il webhook su Telegram (vedi `docs/telegram-setup.md`, Step 7):
   ```bash
   curl "https://api.telegram.org/bot<TOKEN>/setWebhook?url=<URL_NGROK>/webhook/alien-mind-callback"
   curl "https://api.telegram.org/bot<TOKEN>/getWebhookInfo"   # per verificare
   ```
5. Se ngrok ti cambia URL ad ogni avvio considera il passaggio a **Cloudflare Tunnel** con dominio fisso.

### "OpenAI API: model not available"
`gpt-image-1.5` richiede **organizzazione verificata** su OpenAI. Vai su [platform.openai.com → Settings → Organization → General](https://platform.openai.com/settings/organization/general) e completa la verifica (richiede documento d'identità, ~10 minuti). Fino al completamento puoi fallback su `gpt-image-1` (cambia il `model` nel nodo HTTP, costo +25%).

### DB SQLite "database is locked"
better-sqlite3 è sincrono e gestisce lock molto meglio di node-sqlite3, ma può capitare se due workflow girano in parallelo. Soluzione: il workflow principale è single-execution (lo Step 3 usa Trigger Manuale + Schedule), quindi non dovrebbe succedere. Se accade, controlla che nessun altro processo (DBeaver, sqlite3 CLI) tenga il file aperto.

### Reset completo (utile in dev)
```bash
docker compose down -v          # ATTENZIONE: cancella il volume con i workflow!
rm -f database/quotes.db
docker compose up -d
```

---

## Comandi utili

```bash
# Logs in tempo reale
docker compose logs -f n8n

# Backup del DB citazioni
cp database/quotes.db database/backups/quotes-$(date +%Y%m%d-%H%M).db

# Backup completo dei dati n8n (workflow + credenziali)
docker run --rm -v alien-mind-n8n-data:/data -v $(pwd)/database/backups:/backup \
  alpine tar czf /backup/n8n-$(date +%Y%m%d).tar.gz -C /data .

# Aggiornare n8n alla versione più recente
docker compose pull
docker compose build --no-cache
docker compose up -d --force-recreate
```

---

## DB citazioni (Step 2)

Lo schema vive in [database/schema.sql](database/schema.sql) e crea tre tabelle:
- `quotes` — citazioni curate (70% del flusso)
- `generated_quotes` — frasi generate da gpt-5-mini (30%) con `quality_score` 1-5 da compilare a mano dopo il review
- `posts` — registro dei contenuti creati (link a una delle due tabelle sopra)

Tutte le operazioni sul DB girano **dentro il container** (better-sqlite3 è installato lì, non sull'host).

```bash
# Seed iniziale: 19 citazioni verificate (7 filosofi + 7 scrittori + 5 mistici)
sudo docker compose run --rm --entrypoint node n8n /data/scripts/seed-quotes.js

# Aggiungere una citazione interattivamente (ti chiede testo, autore, tema, mood)
sudo docker compose run --rm --entrypoint node n8n /data/scripts/add-quote.js

# Aggiungere via flags (utile per script o batch)
sudo docker compose run --rm --entrypoint node n8n /data/scripts/add-quote.js \
  --text "..." --author "Mezzosangue" --source "Tetragramma" \
  --theme "consapevolezza_sé" --mood "tagliente"

# Test end-to-end del DB (seed + add-quote + idempotenza + validazione)
sudo bash scripts/test-step2.sh
```

> **Slot rapper italiani**: il seed *non* include citazioni di Mezzosangue / Caparezza / Rancore / Murubutu. Il brief richiede wording verificato e io non posso garantire al 100% i testi delle barre — li aggiungi tu via `add-quote.js` coi testi originali da Genius/booklet. La distribuzione attesa è ~6 quote rap per arrivare a 25 totali.

Il DB vive su bind-mount in `database/quotes.db` (host) ⇄ `/data/database/quotes.db` (container). Lo backuppi semplicemente copiando il file:
```bash
cp database/quotes.db database/backups/quotes-$(date +%Y%m%d).db
```

---

## Workflow n8n (Step 3)

Tre workflow JSON importabili in `workflows/`:

| File | Cosa fa | Trigger |
|---|---|---|
| [alien-mind-pipeline.json](workflows/alien-mind-pipeline.json) | Pipeline principale: decide sorgente (70% curated / 30% generated) → gpt-5-mini visual prompt → GPT Image 1.5 → Sharp typography → Drive upload → Telegram review | Manual + Schedule (off) + Execute Workflow |
| [alien-mind-callback.json](workflows/alien-mind-callback.json) | Gestisce le 4 azioni inline (Approva / Rigenera img / Cambia frase / Scarta). Approve sposta su Drive, Discard cancella, Regen/Change richiamano la pipeline via Execute Workflow | Webhook POST `/webhook/alien-mind-callback` |
| [alien-mind-error.json](workflows/alien-mind-error.json) | Notifica Telegram quando un altro workflow fallisce. Da assegnare come Error Workflow nei Settings degli altri due | Error Trigger |

### Import in n8n

1. Apri **http://localhost:5678** → Workflows → ⋯ → **Import from File**
2. Importa **`alien-mind-error.json`** *per primo* e attivalo (gli altri due lo referenziano)
3. Importa **`alien-mind-pipeline.json`**, poi **`alien-mind-callback.json`**

### Mappare le credenziali

Tutti i nodi che usano API esterne hanno `credentials.id = "REPLACE_ME"`. n8n te lo segnala con un'icona rossa ⚠️ — clicca sul nodo e seleziona la credential giusta dal menu. Una volta sola: si propagano agli altri nodi dello stesso tipo.

| Tipo credential | Nodo n8n usato | Note |
|---|---|---|
| OpenAI | "Genera frase con OpenAI", "Prompt visivo con OpenAI", "OpenAI gpt-image-1.5" | API Key = `={{ $env.OPENAI_API_KEY }}` — un'unica credential per tutti e tre |
| Telegram | tutti i nodi Telegram | Access Token = `={{ $env.TELEGRAM_BOT_TOKEN }}` |
| Google Drive OAuth2 | "Upload Drive", "Drive: move", "Drive: delete" | Flow OAuth — vedi [docs.n8n.io/integrations/builtin/credentials/googledrive/](https://docs.n8n.io/integrations/builtin/credentials/google/) |

### Caveat importanti dopo l'import

- **Execute Workflow ID**: i nodi "Execute alien-mind-pipeline" nel callback referenziano il workflow per nome. Dopo l'import, n8n potrebbe chiederti di selezionarlo dal dropdown — fallo una volta per regen e una per change.
- **Webhook URL**: il webhook Telegram lavora solo via HTTPS. In dev locale serve ngrok (vedi sopra). Una volta avviato, registra il webhook con:
  ```bash
  curl "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/setWebhook?url=$WEBHOOK_URL/webhook/alien-mind-callback"
  curl "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getWebhookInfo"
  ```
- **Edit message Telegram**: i nodi `editMessageText` (post approve/discard) potrebbero fallire se il messaggio originale era una `sendPhoto` (Telegram richiede `editMessageCaption`). Tweak in UI se vedi errore — n8n lo segnala chiaramente.

### Cosa NON è ancora finalizzato (Step 4-6)

- I **system prompt** dentro "Genera frase con OpenAI" e "Prompt visivo con OpenAI" sono **versioni lavorative** — funzionano ma non sono calibrate al massimo. Lo Step 4 e Step 5 li sostituiranno con prompt completi + few-shot.
- Il **Code Node "Compose typography"** usa font di sistema (DejaVu/Arial) e SVG overlay base. Lo Step 6 produrrà un modulo `scripts/compose-image.js` con font custom da `/data/fonts/`, kerning migliore e gestione `top|bottom|split` raffinata.

### Test rapido manuale

1. Apri il workflow `alien-mind-pipeline` → click **Execute Workflow** (senza modifiche)
2. Dovresti vedere ogni nodo eseguirsi in sequenza
3. Alla fine ricevi su Telegram un messaggio foto con i 4 bottoni
4. Premi **Approva** → il file si sposta su `/approved/` e il messaggio si aggiorna

---

## Prossimi step

- [x] **Step 1** — Setup ambiente
- [x] **Step 2** — Schema DB + seed di 19 citazioni curate (+ slot rap a tua cura)
- [x] **Step 3** — 3 workflow n8n (pipeline + callback + error notifier)
- [ ] **Step 4** — System prompt generazione frase originale
- [ ] **Step 5** — System prompt analisi visiva → prompt GPT Image 1.5
- [ ] **Step 6** — Modulo Sharp per tipografia (`scripts/compose-image.js`)
- [ ] **Step 7** — Setup Telegram Bot (guida step-by-step)
- [ ] **Step 8** — `docs/SETUP.md` finale end-to-end
