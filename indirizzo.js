// Indirizzo del sito Genio scelto nell'app per computer: solo l'origine (https://host), e lo stesso Genio con o senza "www.".

// Accetta "genio.vercel.app", "https://genio.vercel.app/login", "www. genio.it "... e tiene solo https://host (http solo in locale).
// Toglie anche gli spazi messi dal correttore o incollati per sbaglio.
function normalizeUrl(input) {
  let s = String(input || '').replace(/\s+/g, '');
  if (!s || s.length > 400) return null;
  if (!/^[a-z]+:\/\//i.test(s)) s = `https://${s}`;
  try {
    const u = new URL(s);
    const local = ['localhost', '127.0.0.1'].includes(u.hostname);
    if (u.protocol !== 'https:' && !(local && u.protocol === 'http:')) return null;
    if (!u.hostname.includes('.') && !local) return null;
    return u.origin;
  } catch { return null; }
}

// Lo stesso Genio con o senza "www." davanti (es. genio.nexus che rimanda a www.genio.nexus): solo https, stessa porta.
// Senza questo controllo l'app trattava il www come un altro sito e apriva l'accesso nel browser senza ritorno all'app.
function gemello(url, base) {
  const o = normalizeUrl(url);
  if (!o || !base || o === base || !o.startsWith('https://') || !String(base).startsWith('https://')) return false;
  const a = o.slice(8), b = String(base).slice(8);
  return a === `www.${b}` || b === `www.${a}`;
}

module.exports = { normalizeUrl, gemello };
