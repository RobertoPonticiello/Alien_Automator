# Progetto: Pipeline n8n per Alien Mind — Contenuti Instagram aforistico-surrealisti

## Contesto del brand

Sto automatizzando la pubblicazione di contenuti Instagram per il profilo **Alien Mind**, focalizzato sulla **consapevolezza di sé in chiave filosofica e antagonista alla società moderna**. Non è un profilo divulgativo soft. È un profilo che cita Eraclito, Mezzosangue, Caparezza, Nietzsche, Rancore. Lo stile è denso, tagliente, letterario, con immagini surreali alla Magritte/Beksinski che spiazzano.

Il sistema sarà un ibrido **70% citazioni curate / 30% frasi originali generate**.

## Requisiti di stile (CRITICI — leggere con attenzione)

### Voce testuale

**Registro**: aforistico, letterario, mai didascalico. Le frasi sono *massime*, non *spiegazioni*. Hanno la struttura della citazione presocratica o del verso rap conscious italiano.

**Pattern ricorrenti** osservati nei contenuti del profilo:
- Strutture binarie/contrastive: "voi X / io Y" — "X non evita Y / ma limita Z"
- Affermazioni-paradosso: "l'intima natura delle cose ama nascondersi"
- Inversioni di prospettiva: dove ti aspetti A trovi B
- Nessuna prima persona divulgativa ("io credo che…"); ammessa solo prima persona poetica/lirica ("ho un debito immenso con l'uomo dentro lo specchio")
- Tono: solenne ma non pomposo, sferzante ma non aggressivo, intimo ma non sentimentale

**Lessico ricorrente**: verità, libertà, consapevolezza, diversità, presente, paura, morte, vita, specchio, autenticità, individualità, società, massa, silenzio, ascolto

**Da evitare assolutamente** (anti-pattern del brand):
- Tossico-positività ("ce la farai!", "sei forte!")
- Frasi-coach motivazionali ("inizia oggi a…")
- Linguaggio terapeutico/clinico ("pratica la mindfulness")
- Banalità new-age ("vibra alto", "ascolta l'universo")
- Hashtag-style writing ("e tu? cosa ne pensi?")
- Frasi-AI generiche e prevedibili
- Punti esclamativi (mai)
- Emoji nel testo (mai)

**Lunghezza**: 8-25 parole. Mai oltre.

### Voce visiva

**Stile**: surrealismo evocativo, ispirato a Magritte, Beksinski, dipinti onirici. Mai foto realistiche di natura/lifestyle.

**Elementi ricorrenti** osservati:
- Dualismi visivi (vivo/morto, cielo stellato/deserto, riflessi capovolti)
- Cieli notturni stellati, deserti rossi, paesaggi onirici
- Figure umane stilizzate, scheletri, sagome, cloni
- Riflessi su acqua, specchi, mondi rovesciati
- Tavolozze a contrasto netto: blu profondo + ocra deserto, nero + rosso, grigi sfumati
- Composizioni simmetriche o spiazzanti
- Atmosfere oniriche, malinconiche, perturbanti

**Tipografia** (osservata nei post):
- Font bianco con tratto leggermente irregolare/stencil-handmade (stile "Caveat Brush", "Permanent Marker", "Special Elite")
- Capitalizzato (prima lettera di ogni parola maiuscola) o all-caps a seconda del post
- Apostrofi tondi, accenti italiani corretti (è, à, ò)
- Posizionamento: alto centrato o suddiviso top/bottom in base alla composizione dell'immagine
- Leggera ombra/glow per leggibilità su fondo complesso

## Stack tecnico (già deciso)

- **n8n**: self-hosted via Docker Compose, locale
- **Modello testo**: Claude Sonnet 4.6 via API Anthropic — **usato per analizzare le citazioni e generare il 30% di frasi originali**, NON per scrivere genericamente
- **Modello immagine**: **GPT Image 1.5** via OpenAI API, quality `high`, size `1024x1536` (4:5 portrait Instagram)
- **Sovrapposizione testo**: Sharp (Node.js) in un nodo Function di n8n, oppure servizio esterno via HTTP Request — Claude Code decide quale è più affidabile in container n8n
- **Review**: Telegram Bot con inline keyboard
- **Storage**: Google Drive
- **Database citazioni**: SQLite locale persistito in volume Docker (semplice, zero infrastruttura)
- **Volume**: 15-30 contenuti/mese, budget ~30€/mese (~5€ stimati effettivi)
- **Lingua**: tutto in italiano

## Come voglio che procedi

A step incrementali. Alla fine di ogni step ti fermi e aspetti il mio "ok, vai con lo step N".

### Step 1 — Setup ambiente n8n

Produci:
- `docker-compose.yml` per n8n self-hosted con: volume persistente per dati n8n, volume separato per il database SQLite citazioni, porta 5678, timezone Europe/Rome
- `.env.example` con tutte le variabili (ANTHROPIC_API_KEY, OPENAI_API_KEY, TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID, GOOGLE_DRIVE_FOLDER_ID per drafts e approved, NGROK_AUTH_TOKEN se serve per webhook)
- `README.md` con: prerequisiti, comandi avvio, prima configurazione UI, troubleshooting webhook locale (ngrok o cloudflare tunnel), stima costi reale per 30 contenuti/mese con breakdown
- Una struttura di cartelle progetto sensata: `/workflows`, `/database`, `/scripts`, `/docs`, `/assets/fonts`

Poi fermati.

### Step 2 — Database citazioni curate

Crea:
- Schema SQLite per tabella `quotes` con campi: `id`, `text` (italiano), `author`, `source` (libro/album/canzone), `theme` (enum: consapevolezza_sé | individualità_vs_società | verità_e_illusione | morte_e_vita | autenticità | presente | paradossi_esistenziali), `mood` (enum: solenne | tagliente | intimo | onirico | provocatorio), `used_count`, `last_used_at`, `created_at`
- Schema per tabella `generated_quotes` (per il 30% generate da Claude) con stessi campi più `quality_score` (1-5, lo metto io a posteriori per fine-tuning)
- Schema per tabella `posts` con: `id`, `quote_id`, `quote_source` (curated|generated), `image_url_drive`, `status` (draft|approved|rejected|published), `created_at`, `approved_at`
- Script `scripts/seed-quotes.js` che popola il DB con un set iniziale di 25 citazioni curate. Suggeriscimi un mix sensato:
  - 5-7 da filosofi (Eraclito, Nietzsche, Cioran, Heidegger, Schopenhauer)
  - 5-7 da rapper italiani conscious (Mezzosangue, Caparezza, Rancore, Murubutu) — ATTENZIONE: per questi serve farmi un suggerimento di citazioni note ma non bisogna inventarle. Se non sei sicuro al 100% di una citazione, NON la includere — segnala che la lascio io
  - 5-7 da scrittori/poeti (Pessoa, Dostoevskij, Rilke, Borges, Calvino)
  - 5-7 da filosofi orientali / mistici (Krishnamurti, Lao Tzu, Rumi, Watts)
- Script `scripts/add-quote.js` da CLI per aggiungere citazioni a mano in seguito
- Tutto commentato in italiano

Poi fermati.

### Step 3 — Workflow n8n principale (JSON importabile)

Genera `workflows/alien-mind-pipeline.json` con questi nodi:

1. **Trigger Manuale** + **Schedule Trigger disattivato**
2. **Code Node — Decisione sorgente**: con probabilità 70% pesca una citazione dal DB SQLite (priorità: usate meno, non usate da > 90 giorni); con probabilità 30% va al ramo "genera frase originale". Output: `{source_type, quote_text, author, theme, mood}`
3. **Branch A — Citazione curata**: solo aggiorna `used_count` e `last_used_at` nel DB
4. **Branch B — Frase originale**: chiamata a Claude Sonnet 4.6 con il system prompt definito nello Step 4. Output JSON `{text, theme, mood}`. Salva in tabella `generated_quotes`
5. **Merge dei due branch**
6. **HTTP Request → Claude (analisi visiva)**: passa la frase a Claude con il prompt definito nello Step 5 per ottenere il prompt visivo per GPT Image 1.5. Output: `{visual_prompt_en, composition_notes, color_palette, text_position}` (top|bottom|split)
7. **HTTP Request → OpenAI Images API (GPT Image 1.5)**:
   - Endpoint: `https://api.openai.com/v1/images/generations`
   - Body: `{model: "gpt-image-1", prompt: visual_prompt_en, quality: "high", size: "1024x1536", n: 1}`
   - Verifica nello Step 1 il nome esatto del modello e l'endpoint corrente, perché l'API OpenAI cambia rapidamente — fai web search se necessario
8. **Code Node — Composizione tipografia**: usa Sharp per sovrapporre il testo sull'immagine generata
   - Font: usa un font OTF/TTF custom (suggerisci 2-3 alternative free open-source che matchano lo stile dei post — es. Caveat Brush, Permanent Marker, Special Elite)
   - Colore testo: bianco con leggero glow/shadow per leggibilità
   - Posizione: top|bottom|split secondo `text_position`
   - Capitalize first letter di ogni parola
   - Wrapping automatico se la frase supera N caratteri per linea
   - Output: buffer immagine 1080x1350
9. **Google Drive Upload**: cartella `/alien-mind-drafts/YYYY-MM/`, nome file `YYYYMMDD-HHmm-{first8charsOfQuote}.png`
10. **Code Node — INSERT post in tabella `posts`**: status=draft
11. **Telegram Send Photo**: invia immagine + caption con la frase, autore (se citazione), tema, e inline keyboard:
    - ✅ Approva
    - 🔄 Rigenera immagine (stessa frase, nuovo prompt visivo)
    - 🔁 Cambia frase (pesca/genera nuova frase, nuova immagine)
    - ❌ Scarta
12. **Webhook receiver** separato per le callback_query Telegram
13. **Switch sulle callback**:
    - Approva → sposta file in `/alien-mind-approved/`, UPDATE post status=approved, conferma
    - Rigenera immagine → ritriggera workflow dal nodo 6 mantenendo la frase
    - Cambia frase → ritriggera workflow dal nodo 1
    - Scarta → elimina file, UPDATE status=rejected, conferma

Sticky notes in italiano sui nodi. Error Trigger separato che mi notifica errori su Telegram.

Poi fermati.

### Step 4 — System prompt per generazione frase originale (30% del flusso)

Il prompt deve istruire Claude a generare UNA frase nello stile aforistico-letterario di Alien Mind.

Includi nel prompt:

**Contesto del brand**: spiega che il profilo è influenzato da Eraclito, Mezzosangue, Caparezza, Nietzsche, Cioran. Stile aforistico, tagliente, mai didascalico.

**Pattern strutturali** da scegliere con probabilità diverse:
- Struttura binaria/contrastiva (40%): "X non Y, ma Z" / "Voi X, io Y"
- Affermazione-paradosso (30%): "L'X più Y è quello che Z"
- Inversione prospettica (20%): "Dove cerchi A, trovi B"
- Constatazione lirica (10%): "Ho un debito con X" (prima persona poetica)

**Vincoli espliciti**:
- 8-25 parole massimo
- Nessun punto esclamativo
- Nessun emoji
- Mai prescrittiva ("dovresti", "ricordati di")
- Mai consolatoria ("non sei solo")
- Mai banale ("la vita è un viaggio")
- Linguaggio italiano denso, scelto, mai colloquiale né accademico

**Output JSON stretto**:
```json
{
  "text": "...",
  "theme": "consapevolezza_sé | individualità_vs_società | verità_e_illusione | morte_e_vita | autenticità | presente | paradossi_esistenziali",
  "mood": "solenne | tagliente | intimo | onirico | provocatorio",
  "structure_used": "binaria | paradosso | inversione | lirica"
}
```

**Esempi few-shot di frasi nello stile target** (calibrazione critica):

```
{"text": "Voi inseguite la felicità. Io ho smesso quando ho capito che era già stanca di scappare.", "theme": "paradossi_esistenziali", "mood": "tagliente", "structure_used": "binaria"}

{"text": "Conoscersi non è guardarsi dentro. È accettare quello che ti guarda dentro quando smetti di fingere.", "theme": "consapevolezza_sé", "mood": "solenne", "structure_used": "paradosso"}

{"text": "Hanno chiamato libertà la possibilità di scegliere tra le loro gabbie.", "theme": "individualità_vs_società", "mood": "tagliente", "structure_used": "inversione"}

{"text": "Il silenzio non è assenza di parole. È quello che resta quando le parole hanno finito di mentire.", "theme": "verità_e_illusione", "mood": "solenne", "structure_used": "paradosso"}

{"text": "Ho un debito con tutte le versioni di me che ho dovuto seppellire per arrivare a questa.", "theme": "autenticità", "mood": "intimo", "structure_used": "lirica"}

{"text": "Il presente è l'unico posto dove non puoi più scappare. Per questo lo evitano tutti.", "theme": "presente", "mood": "tagliente", "structure_used": "paradosso"}
```

Genera tu altri 4-6 esempi nello stesso registro per arricchire la calibrazione, mantenendo il livello altissimo. Se una frase ti sembra suonare "AI", scartala.

### Step 5 — System prompt per analisi visiva (da frase a prompt GPT Image 1.5)

Claude analizza la frase ricevuta e produce un prompt in inglese per GPT Image 1.5 che generi un'immagine surreale evocativa, NON didascalica.

**Principio**: l'immagine non deve illustrare la frase letteralmente. Deve creare tensione semantica con essa, come fanno i post originali (es. "non troverai mai la verità" + uomo blu vivo / scheletro = la verità implica vedere ciò che non si vuole vedere).

**Stile visivo richiesto** (sempre):
- Surrealist painting style, inspired by Magritte, Beksinski, dreamlike compositions
- Strong symbolic visual metaphors
- High contrast palettes: deep night blues, desert ochres, stark blacks, crimson reds
- Stylized human figures, skeletons, silhouettes, mirror reflections, cosmic landscapes
- Dual/split compositions (life vs death, light vs dark, real vs reflected)
- Cinematic, oneiric, slightly unsettling
- NO photorealism, NO Pinterest aesthetic, NO soft pastels, NO lifestyle imagery
- NO recognizable celebrities, NO copyrighted artwork reproductions
- Aspect ratio 4:5 portrait (1024x1536)

**Output JSON stretto**:
```json
{
  "visual_prompt_en": "...",
  "composition_notes": "...",
  "color_palette": ["...", "..."],
  "text_position": "top | bottom | split",
  "negative_elements": ["realistic photo", "stock imagery", "..."]
}
```

Includi 3-4 esempi few-shot di coppia frase italiana → visual_prompt_en di alta qualità.

### Step 6 — Tipografia e composizione finale (Sharp)

Produci `scripts/compose-image.js` modulo Node.js che:
- Riceve: buffer immagine generata, frase, posizione testo
- Carica un font custom da `/assets/fonts/` (suggerisci 2-3 alternative free e includi link al download)
- Renderizza il testo bianco con sottile shadow per leggibilità
- Capitalize first letter di ogni parola
- Wrappa automaticamente se la frase è lunga
- Posiziona top, bottom, o split (prima parte in alto / seconda in basso) in base al parametro
- Output: buffer PNG 1080x1350

Test del modulo con 2-3 frasi di esempio prima di integrarlo nel workflow n8n.

### Step 7 — Telegram Bot setup

Step-by-step (in italiano) per:
- Creazione bot via @BotFather
- Ottenimento chat_id
- Configurazione webhook (con ngrok se locale)
- Gestione delle 4 callback con esempi di payload

### Step 8 — SETUP.md finale

Guida unica da clone repo a prima generazione end-to-end, in italiano, con tutto.

## Vincoli assoluti

- **Human-in-the-loop obbligatorio**: nessun auto-publish
- **Nessuna riproduzione di opere d'arte protette**: solo generazione ex-novo "in stile" surrealista
- **Citazioni verificate**: se Claude Code non è certo di una citazione, non la inserisce — me la lascia decidere
- **Tutto in italiano**: frasi, messaggi Telegram, commenti, README
- **Idempotenza**: retry non duplicano file Drive né record DB
- **No banalità**: il sistema deve rifiutare di produrre frasi mediocri. Se la generazione fallisce 3 volte il quality bar, scarta e mi notifica

## Output atteso

Inizia dallo Step 1 e fermati. Aspetta il mio "ok, vai con lo step 2" prima di procedere.