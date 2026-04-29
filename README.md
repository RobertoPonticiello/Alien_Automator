# Alien Mind — Pipeline n8n

Sistema automatizzato per la pubblicazione di contenuti Instagram aforistico-surrealisti per il profilo **Alien Mind**, con review umana via Telegram. Mix 70% citazioni curate / 30% frasi originali generate da Claude, immagini surreali generate da GPT Image 1.5, composizione tipografica con Sharp, archivio su Google Drive.

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
| Account Anthropic | — | Con accesso a Claude Sonnet 4.6 |
| Account OpenAI | — | **Organizzazione verificata** (richiesto per `gpt-image-1.5`) |
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

1. **Anthropic** — *Settings → Credentials → New → "HTTP Header Auth"*
   - Name: `Anthropic API`
   - Header Name: `x-api-key`
   - Header Value: `={{ $env.ANTHROPIC_API_KEY }}`
   - Aggiungi un secondo header: `anthropic-version` = `2023-06-01`

2. **OpenAI** — *Credentials → New → "OpenAI"*
   - API Key: `={{ $env.OPENAI_API_KEY }}`

3. **Telegram** — *Credentials → New → "Telegram"*
   - Access Token: `={{ $env.TELEGRAM_BOT_TOKEN }}`

4. **Google Drive** — *Credentials → New → "Google Drive OAuth2 API"*
   - Segui il flow OAuth (richiede progetto su Google Cloud Console con Drive API abilitata, vedi `docs/google-drive-setup.md` — verrà creato in Step 7).

Le credenziali API vengono lette dalle variabili `.env` tramite le expression `$env.NOMEVAR`, quindi non vanno mai incollate in chiaro nei nodi.

---

## Stima costi reali (30 contenuti/mese)

Tariffe verificate ad aprile 2026:

| Voce | Tariffa | Volume mensile | Costo |
|---|---|---|---|
| **GPT Image 1.5** (1024×1536, quality `high`) | $0.20 / immagine | 30 immagini + ~30% rigenerazioni ≈ **39 chiamate** | **$7.80** |
| **Claude Sonnet 4.6** — generazione frase originale (30% del flusso) | $3 input / $15 output per 1M token | ~9 chiamate × ~2.2k token totali | **$0.08** |
| **Claude Sonnet 4.6** — analisi visiva (su tutte le frasi) | $3 input / $15 output per 1M token | ~30 chiamate × ~1.8k token totali | **$0.27** |
| **Telegram Bot API** | gratuito | — | $0.00 |
| **Google Drive** (entro 15 GB free tier) | gratuito | — | $0.00 |
| **n8n self-hosted** | gratuito (community) | — | $0.00 |
| **Totale stimato** | | | **~$8.15/mese** |

A cambio attuale (~1 USD ≈ 0.92 EUR): **~7.50 €/mese** per 30 contenuti, **~3.80 €/mese** per 15 contenuti.

> La stima 5€/mese del brief è raggiungibile **senza rigenerazioni** e a 25 contenuti/mese: 25 × $0.20 + ~$0.30 LLM = $5.30 ≈ 4.90 €. Considerando il margine di rigenerazioni che farai durante il review, ~7-8 € è realistico. Restiamo ampiamente sotto il budget di 30 €.

### Note sui modelli

- Il brief originale cita `gpt-image-1` (legacy, $0.25/img). Il default 2026 è **`gpt-image-1.5`** ($0.20/img high 1024×1536, ~4× più veloce, migliore preservazione del soggetto). Lo Step 3 userà `gpt-image-1.5` come modello di default — endpoint invariato: `POST https://api.openai.com/v1/images/generations`.
- Claude Sonnet 4.6 (`claude-sonnet-4-6`) è il modello scelto. Endpoint: `POST https://api.anthropic.com/v1/messages` con header `anthropic-version: 2023-06-01`.

---

## Decisione: Sharp dentro n8n vs servizio esterno

**Scelto: Sharp dentro n8n** (in un Code Node), pre-installato nell'immagine via `Dockerfile`.

Motivazioni:
- Zero dipendenze di rete → niente latenza extra né failure mode aggiuntivi
- Niente servizio esterno da mantenere (un container in meno)
- Sharp è battle-tested per composizione immagini in produzione
- L'unico costo è una build iniziale ~2 min (vips + toolchain Alpine)

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

## Prossimi step

- [x] **Step 1** — Setup ambiente (questo)
- [ ] **Step 2** — Schema DB + script seed con 25 citazioni curate
- [ ] **Step 3** — Workflow n8n principale (`workflows/alien-mind-pipeline.json`)
- [ ] **Step 4** — System prompt generazione frase originale
- [ ] **Step 5** — System prompt analisi visiva → prompt GPT Image 1.5
- [ ] **Step 6** — Modulo Sharp per tipografia (`scripts/compose-image.js`)
- [ ] **Step 7** — Setup Telegram Bot (guida step-by-step)
- [ ] **Step 8** — `docs/SETUP.md` finale end-to-end
