#!/usr/bin/env node
/**
 * Aggiunge una citazione al DB Alien Mind. Tutto in italiano.
 *
 * Uso INTERATTIVO (default — ti guida step-by-step):
 *   docker compose run --rm --entrypoint node n8n /data/scripts/add-quote.js
 *
 * Uso NON-INTERATTIVO (per script o batch):
 *   docker compose run --rm --entrypoint node n8n /data/scripts/add-quote.js \
 *     --text "..." --author "..." --source "..." \
 *     --theme "individualità_vs_società" --mood "tagliente"
 *
 * Validazioni (refuse i testi non in linea col brand):
 *   - lunghezza testo: 10-500 caratteri (vincolo schema), max 25 parole (brand book)
 *   - niente punti esclamativi (anti-pattern del brand)
 *   - tema e mood devono essere uno dei valori enumerati
 *   - duplicati (text + author) silenziosamente ignorati
 */

'use strict';

const path = require('path');
const fs   = require('fs');
const readline = require('readline');
const Database = require('better-sqlite3');

// ----------------------------------------------------------------------------
// Config
// ----------------------------------------------------------------------------
const DB_PATH = process.env.QUOTES_DB_PATH
  || path.join(__dirname, '..', 'database', 'quotes.db');

const SCHEMA_PATH = process.env.QUOTES_SCHEMA_PATH
  || path.join(__dirname, '..', 'database', 'schema.sql');

const THEMES = [
  'consapevolezza_sé',
  'individualità_vs_società',
  'verità_e_illusione',
  'morte_e_vita',
  'autenticità',
  'presente',
  'paradossi_esistenziali'
];

const MOODS = ['solenne', 'tagliente', 'intimo', 'onirico', 'provocatorio'];

// ----------------------------------------------------------------------------
// Argv parser (modalita' non-interattiva)
// ----------------------------------------------------------------------------
function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i++) {
    if (argv[i].startsWith('--')) {
      const key = argv[i].slice(2);
      const val = (i + 1 < argv.length && !argv[i + 1].startsWith('--')) ? argv[++i] : true;
      args[key] = val;
    }
  }
  return args;
}

// ----------------------------------------------------------------------------
// Prompt interattivo
// ----------------------------------------------------------------------------
function makePrompt() {
  return readline.createInterface({ input: process.stdin, output: process.stdout });
}

function ask(rl, question) {
  return new Promise(resolve => rl.question(question, ans => resolve(ans)));
}

async function askEnum(rl, label, options) {
  console.log(`\n${label}`);
  options.forEach((o, i) => console.log(`  ${i + 1}. ${o}`));
  while (true) {
    const ans = (await ask(rl, '> ')).trim();
    const idx = parseInt(ans, 10);
    if (Number.isFinite(idx) && idx >= 1 && idx <= options.length) return options[idx - 1];
    if (options.includes(ans)) return ans;
    console.log('Scelta non valida, riprova (numero o nome esatto).');
  }
}

async function interactiveCollect() {
  const rl = makePrompt();
  console.log('=== Aggiungi citazione al DB Alien Mind ===');

  const text = (await ask(rl, '\nTesto (italiano, max 25 parole, niente "!"):\n> ')).trim();
  const author = (await ask(rl, '\nAutore: ')).trim();
  const source = ((await ask(rl, '\nFonte (libro/album/canzone, vuoto = nessuna): ')).trim() || null);
  const theme = await askEnum(rl, 'Tema:', THEMES);
  const mood  = await askEnum(rl, 'Mood:', MOODS);

  rl.close();
  return { text, author, source, theme, mood };
}

// ----------------------------------------------------------------------------
// Validazione (replicata sopra al CHECK SQL per dare errori leggibili)
// ----------------------------------------------------------------------------
function validate(q) {
  const errors = [];

  if (!q.text || typeof q.text !== 'string') {
    errors.push('Testo mancante');
  } else {
    if (q.text.length < 10)  errors.push(`Testo troppo corto (${q.text.length} char, min 10)`);
    if (q.text.length > 500) errors.push(`Testo troppo lungo (${q.text.length} char, max 500)`);
    const words = q.text.split(/\s+/).filter(Boolean).length;
    if (words > 25) errors.push(`Testo ha ${words} parole (max 25 dal brand book)`);
    if (/!/.test(q.text)) errors.push('Punto esclamativo non ammesso (anti-pattern del brand)');
  }

  if (!q.author || typeof q.author !== 'string') {
    errors.push('Autore mancante');
  }

  if (!THEMES.includes(q.theme)) {
    errors.push(`Tema non valido: "${q.theme}". Ammessi: ${THEMES.join(', ')}`);
  }
  if (!MOODS.includes(q.mood)) {
    errors.push(`Mood non valido: "${q.mood}". Ammessi: ${MOODS.join(', ')}`);
  }

  return errors;
}

// ----------------------------------------------------------------------------
// Main
// ----------------------------------------------------------------------------
async function main() {
  const args = parseArgs(process.argv);

  // Modalita' non-interattiva: serve almeno text+author+theme+mood.
  const hasAllArgs = args.text && args.author && args.theme && args.mood;
  const quote = hasAllArgs
    ? {
        text:   String(args.text).trim(),
        author: String(args.author).trim(),
        source: args.source ? String(args.source).trim() : null,
        theme:  String(args.theme).trim(),
        mood:   String(args.mood).trim()
      }
    : await interactiveCollect();

  const errors = validate(quote);
  if (errors.length > 0) {
    console.error('\nValidazione fallita:');
    for (const e of errors) console.error(`  - ${e}`);
    process.exit(2);
  }

  // Apri DB e applica schema (idempotente).
  fs.mkdirSync(path.dirname(DB_PATH), { recursive: true });
  const db = new Database(DB_PATH);
  try {
    if (fs.existsSync(SCHEMA_PATH)) {
      db.exec(fs.readFileSync(SCHEMA_PATH, 'utf8'));
    }

    const result = db.prepare(`
      INSERT OR IGNORE INTO quotes (text, author, source, theme, mood)
      VALUES (@text, @author, @source, @theme, @mood)
    `).run(quote);

    if (result.changes > 0) {
      console.log(`\nCitazione inserita (id=${result.lastInsertRowid}).`);
    } else {
      console.log('\nCitazione già presente (UNIQUE su text+author): nessun INSERT.');
    }

    const total = db.prepare('SELECT COUNT(*) AS n FROM quotes').get().n;
    console.log(`Totale citazioni in DB: ${total}`);
  } finally {
    db.close();
  }
}

main().catch(err => {
  console.error('Errore:', err && err.message ? err.message : err);
  process.exit(1);
});
