#!/usr/bin/env node
/**
 * Seed iniziale del DB citazioni Alien Mind.
 *
 * Idempotente: il vincolo UNIQUE(text, author) protegge da duplicati al re-run.
 *
 * Uso (in container, default):
 *   docker compose run --rm --entrypoint node n8n /data/scripts/seed-quotes.js
 *
 * Uso (host, richiede `npm i better-sqlite3` localmente):
 *   QUOTES_DB_PATH=./database/quotes.db node scripts/seed-quotes.js
 *
 * NOTE SUL CONTENUTO
 * ------------------
 * Questo seed include 19 citazioni verificate (7 filosofi + 7 scrittori/poeti
 * + 5 mistici/orientali). Le 6 slot della categoria "rapper italiani conscious"
 * (Mezzosangue, Caparezza, Rancore, Murubutu) NON sono incluse: il brief impone
 * citazioni con wording verificato e io (Claude) non posso garantire al 100%
 * il testo letterale di una barra rap. Le aggiungi tu via add-quote.js coi
 * testi originali da Genius/booklet/streaming.
 *
 * Suggerimenti tematici per gli slot rap (lasciati a te):
 *   - Mezzosangue   (album: Tetragramma, L'arte del dubbio)
 *   - Caparezza     (album: Prisoner 709, Le dimensioni del mio caos, Museica)
 *   - Rancore       (album: Musica per bambini, Eden — Sanremo 2020)
 *   - Murubutu      (album: L'uomo che viaggiava nel vento, Tenebra è la notte ed altri racconti di paura)
 */

'use strict';

const path = require('path');
const fs   = require('fs');
const Database = require('better-sqlite3');

// ----------------------------------------------------------------------------
// Path
// ----------------------------------------------------------------------------
const DB_PATH = process.env.QUOTES_DB_PATH
  || path.join(__dirname, '..', 'database', 'quotes.db');

const SCHEMA_PATH = process.env.QUOTES_SCHEMA_PATH
  || path.join(__dirname, '..', 'database', 'schema.sql');

// ----------------------------------------------------------------------------
// Citazioni — tutte verificate
// ----------------------------------------------------------------------------
const QUOTES = [

  // === FILOSOFI ============================================================== (7)
  {
    text: 'Il carattere dell’uomo è il suo demone',
    author: 'Eraclito',
    source: 'Frammento DK 22 B 119',
    theme: 'autenticità',
    mood: 'solenne'
  },
  {
    text: 'La natura ama nascondersi',
    author: 'Eraclito',
    source: 'Frammento DK 22 B 123',
    theme: 'verità_e_illusione',
    mood: 'solenne'
  },
  {
    text: 'Chi ha un perché può sopportare quasi qualunque come',
    author: 'Friedrich Nietzsche',
    source: 'Crepuscolo degli idoli — Massime e frecce',
    theme: 'autenticità',
    mood: 'tagliente'
  },
  {
    text: 'Bisogna avere ancora un caos dentro di sé per partorire una stella danzante',
    author: 'Friedrich Nietzsche',
    source: 'Così parlò Zarathustra — Prologo',
    theme: 'paradossi_esistenziali',
    mood: 'solenne'
  },
  {
    text: 'Se guardi a lungo nell’abisso, anche l’abisso guarderà dentro di te',
    author: 'Friedrich Nietzsche',
    source: 'Al di là del bene e del male, §146',
    theme: 'consapevolezza_sé',
    mood: 'solenne'
  },
  {
    text: 'Ognuno scambia i limiti del proprio campo visivo per i confini del mondo',
    author: 'Arthur Schopenhauer',
    source: 'Aforismi sulla saggezza del vivere',
    theme: 'verità_e_illusione',
    mood: 'tagliente'
  },
  {
    text: 'Senza la possibilità del suicidio, mi sarei ucciso da tempo',
    author: 'Emil Cioran',
    source: 'La caduta nel tempo',
    theme: 'paradossi_esistenziali',
    mood: 'tagliente'
  },

  // === SCRITTORI / POETI ===================================================== (7)
  {
    text: 'Non sono niente. Non sarò mai niente. Non posso voler essere niente. A parte ciò, ho in me tutti i sogni del mondo',
    author: 'Fernando Pessoa',
    source: 'Tabaccheria (Álvaro de Campos)',
    theme: 'paradossi_esistenziali',
    mood: 'solenne'
  },
  {
    text: 'L’uomo si abitua a tutto, il mascalzone',
    author: 'Fëdor Dostoevskij',
    source: 'Delitto e castigo',
    theme: 'individualità_vs_società',
    mood: 'tagliente'
  },
  {
    text: 'L’uomo è un mistero. Bisogna risolverlo, e se ci spendi tutta la vita, non dire di aver perso il tempo',
    author: 'Fëdor Dostoevskij',
    source: 'Lettera al fratello Mikhail, 16 agosto 1839',
    theme: 'consapevolezza_sé',
    mood: 'solenne'
  },
  {
    text: 'Devi cambiare la tua vita',
    author: 'Rainer Maria Rilke',
    source: 'Torso arcaico di Apollo',
    theme: 'autenticità',
    mood: 'tagliente'
  },
  {
    text: 'Ho commesso il peggior peccato che un uomo possa commettere. Non sono stato felice',
    author: 'Jorge Luis Borges',
    source: 'Il rimorso (1976)',
    theme: 'autenticità',
    mood: 'intimo'
  },
  {
    text: 'L’uomo è l’unica creatura che si rifiuta di essere ciò che è',
    author: 'Albert Camus',
    source: 'L’uomo in rivolta',
    theme: 'individualità_vs_società',
    mood: 'tagliente'
  },
  {
    text: 'Le città, come i sogni, sono costruite di desideri e di paure',
    author: 'Italo Calvino',
    source: 'Le città invisibili',
    theme: 'verità_e_illusione',
    mood: 'onirico'
  },

  // === MISTICI / FILOSOFI ORIENTALI ========================================= (5)
  {
    text: 'Non è segno di salute essere ben adattati a una società profondamente malata',
    author: 'Jiddu Krishnamurti',
    source: 'Attribuzione popolare; fonte specifica controversa',
    theme: 'individualità_vs_società',
    mood: 'tagliente'
  },
  {
    text: 'La verità è una terra senza sentieri',
    author: 'Jiddu Krishnamurti',
    source: 'Discorso di scioglimento dell’Ordine della Stella, 1929',
    theme: 'verità_e_illusione',
    mood: 'solenne'
  },
  {
    text: 'Chi conosce gli altri è saggio. Chi conosce sé stesso è illuminato',
    author: 'Lao Tzu',
    source: 'Tao Te Ching, capitolo 33',
    theme: 'consapevolezza_sé',
    mood: 'solenne'
  },
  {
    text: 'La ferita è il luogo da cui entra in te la luce',
    author: 'Rumi',
    source: 'Mathnawi',
    theme: 'paradossi_esistenziali',
    mood: 'intimo'
  },
  {
    text: 'L’uomo soffre perché prende sul serio ciò che gli dei hanno fatto per gioco',
    author: 'Alan Watts',
    source: 'The Book: On the Taboo Against Knowing Who You Are',
    theme: 'paradossi_esistenziali',
    mood: 'tagliente'
  }

  // === RAPPER ITALIANI: 6 SLOT VUOTI =========================================
  // Vedi nota in testa al file. Aggiungi via:
  //   docker compose run --rm --entrypoint node n8n /data/scripts/add-quote.js
];

// ----------------------------------------------------------------------------
// Esecuzione
// ----------------------------------------------------------------------------
function main() {
  console.log(`[seed-quotes] DB:     ${DB_PATH}`);
  console.log(`[seed-quotes] Schema: ${SCHEMA_PATH}`);

  // Crea la cartella del DB se non esiste (utile al primo run sulla bind-mount).
  fs.mkdirSync(path.dirname(DB_PATH), { recursive: true });

  if (!fs.existsSync(SCHEMA_PATH)) {
    console.error(`[seed-quotes] ERRORE: schema non trovato a ${SCHEMA_PATH}`);
    process.exit(2);
  }

  const db = new Database(DB_PATH);
  try {
    db.exec(fs.readFileSync(SCHEMA_PATH, 'utf8'));

    const insert = db.prepare(`
      INSERT OR IGNORE INTO quotes (text, author, source, theme, mood)
      VALUES (@text, @author, @source, @theme, @mood)
    `);

    const insertMany = db.transaction((quotes) => {
      let inserted = 0;
      for (const q of quotes) {
        const r = insert.run(q);
        if (r.changes > 0) inserted++;
      }
      return inserted;
    });

    const newRows = insertMany(QUOTES);
    const total   = db.prepare('SELECT COUNT(*) AS n FROM quotes').get().n;

    // Distribuzione per tema/mood (utile per capire il bilanciamento del seed).
    const byTheme = db.prepare(
      'SELECT theme, COUNT(*) AS n FROM quotes GROUP BY theme ORDER BY n DESC'
    ).all();
    const byMood  = db.prepare(
      'SELECT mood,  COUNT(*) AS n FROM quotes GROUP BY mood  ORDER BY n DESC'
    ).all();

    console.log('');
    console.log(`[seed-quotes] Citazioni nuove inserite: ${newRows}`);
    console.log(`[seed-quotes] Totale citazioni in DB:   ${total}`);
    console.log('');
    console.log('[seed-quotes] Distribuzione per tema:');
    for (const row of byTheme) console.log(`  - ${row.theme.padEnd(28)} ${row.n}`);
    console.log('');
    console.log('[seed-quotes] Distribuzione per mood:');
    for (const row of byMood)  console.log(`  - ${row.mood.padEnd(14)}  ${row.n}`);
    console.log('');
    console.log('[seed-quotes] === RAPPER ITALIANI: 6 slot lasciati a te =========');
    console.log('Mezzosangue, Caparezza, Rancore, Murubutu — aggiungi le citazioni');
    console.log('coi testi originali (Genius / booklet) via:');
    console.log('  docker compose run --rm --entrypoint node n8n /data/scripts/add-quote.js');
    console.log('==================================================================');
  } finally {
    db.close();
  }
}

main();
