// Pagine dell'app per tablet: collegamento a Genio (QR o indirizzo), attesa dell'accesso nel browser, Genio irraggiungibile,
// Android System WebView da aggiornare. Parlano con l'app solo attraverso window.GenioApp.
(function () {
  var $ = function (id) { return document.getElementById(id); };
  var q = new URLSearchParams(location.search);
  var app = window.GenioApp;
  var pagina = document.body.dataset.page;
  var info = {};
  try { info = JSON.parse(app.info()); } catch (e) {}

  if (pagina === 'indirizzo') {
    var ok = $('ok'), qr = $('qr'), qrt = $('qrt');
    var occupato = function (si, testo) {
      ok.disabled = si; qr.disabled = si;
      ok.textContent = si ? 'Controllo…' : 'Collega';
      qrt.textContent = si && testo ? testo : 'Inquadra il QR';
    };
    if (info.url && !q.get('primo')) {
      $('url').value = info.url.replace(/^https:\/\//, '');
      $('titolo').textContent = 'Cambia il Genio collegato';
      $('testo').textContent = 'Inquadra il QR dell\'altro Genio o scrivi il suo indirizzo. Dopo il cambio si entra di nuovo con il proprio account.';
      $('annulla').hidden = false;
    } else {
      $('ok').parentNode.classList.add('one');
    }
    // risposte dell'app
    window.esito = function (_ok, testo) { occupato(false); $('err').textContent = testo || ''; };
    window.attesa = function () { $('err').textContent = ''; occupato(true, 'Collego…'); };
    qr.onclick = function () { $('err').textContent = ''; app.scansiona(); };
    $('annulla').onclick = function () { app.apri(); };
    $('f').onsubmit = function (e) {
      e.preventDefault();
      var v = $('url').value.trim();
      $('err').textContent = '';
      if (!v) { $('err').textContent = 'Scrivi l\'indirizzo, per esempio nome.vercel.app'; $('url').focus(); return; }
      occupato(true);
      app.collega(v);
    };
  }

  if (pagina === 'attesa') {
    var chi = { google: ' di Google', microsoft: ' di Microsoft' }[q.get('p')];
    if (chi) $('chi').textContent = chi;
    $('riapri').onclick = function () { app.riapriBrowser(); };
    $('annulla').onclick = function () { app.annullaAccesso(); };
  }

  if (pagina === 'errore') {
    try { $('dove').textContent = 'Indirizzo: ' + new URL(q.get('url')).host; } catch (e) {}
    $('riprova').onclick = function () { app.apri(); };
    $('cambia').onclick = function () { app.indirizzo(); };
  }

  if (pagina === 'aggiorna') {
    $('ver').textContent = 'versione ' + (q.get('v') || info.webview || '?') + ', serve la ' + (info.minimo || 111) + ' o successiva';
    $('aggiorna').onclick = function () { app.aggiornaWebView(); };
    $('comunque').onclick = function () { app.continuaComunque(); };
  }
})();
