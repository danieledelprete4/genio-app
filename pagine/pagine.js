// Pagine dell'app: indirizzo del sito, attesa dell'accesso nel browser, sito non raggiungibile.
const $ = (id) => document.getElementById(id);
const q = new URLSearchParams(location.search);
const pagina = document.body.dataset.page;
// nome dell'app (Genio, GeniusFix...) nei testi
window.genio.get().then(({ name }) => { if (name) document.querySelectorAll('.nome').forEach((e) => { e.textContent = name; }); });

if (pagina === 'indirizzo') {
  window.genio.get().then(({ url, name }) => {
    if (url) {
      $('url').value = url;
      $('titolo').textContent = 'Indirizzo del sito';
      $('testo').textContent = `Scrivi il nuovo indirizzo del sito ${name} da aprire.`;
      $('annulla').hidden = false;
    }
    $('url').select();
  });
  $('annulla').onclick = () => window.genio.open();
  $('f').onsubmit = async (e) => {
    e.preventDefault();
    $('err').textContent = '';
    $('ok').disabled = true;
    $('ok').textContent = 'Controllo…';
    const r = await window.genio.save($('url').value);
    if (r && r.error) {
      $('err').textContent = r.error;
      $('ok').disabled = false;
      $('ok').textContent = 'Apri';
    }
  };
}

if (pagina === 'attesa') {
  const chi = { google: ' di Google', microsoft: ' di Microsoft' }[q.get('p')];
  if (chi) $('chi').textContent = chi;
  $('riapri').onclick = () => window.genio.reopenBrowser();
  $('annulla').onclick = () => window.genio.cancelLogin();
}

if (pagina === 'errore') {
  try { $('dove').textContent = new URL(q.get('url')).host; } catch {}
  $('riprova').onclick = () => window.genio.open();
  $('cambia').onclick = () => window.genio.address();
}
