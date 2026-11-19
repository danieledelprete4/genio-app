package app.genio.tablet;

import android.webkit.JavascriptInterface;

// Ponte tra le pagine e l'app (window.GenioApp). Ogni metodo controlla chi lo chiama:
// quelli dell'indirizzo e dell'accesso solo dalle pagine dell'app, file e stampa solo dal Genio collegato.
// Un altro sito non arriva mai qui: i link esterni si aprono nel browser, fuori dall'app.
final class Ponte {
    private final MainActivity a;

    Ponte(MainActivity a) { this.a = a; }

    private boolean app() { return a.paginaApp(a.attuale); }
    private boolean sito() { return a.nelSito(a.attuale); }

    // --- pagine dell'app ---
    @JavascriptInterface public String info() { return app() ? a.info() : "{}"; }
    @JavascriptInterface public void collega(String url) { if (app()) a.collega(url); }
    @JavascriptInterface public void scansiona() { if (app()) a.ui.post(a::scansiona); }
    @JavascriptInterface public void apri() { if (app()) a.ui.post(() -> a.apriSito(null)); }
    @JavascriptInterface public void indirizzo() { if (app()) a.ui.post(() -> a.pagina("indirizzo.html", null)); }
    @JavascriptInterface public void riapriBrowser() { if (app()) a.ui.post(a::riapriBrowser); }
    @JavascriptInterface public void annullaAccesso() { if (app()) a.ui.post(a::annullaAccesso); }
    @JavascriptInterface public void aggiornaWebView() { if (app()) a.ui.post(a::aggiornaWebView); }
    @JavascriptInterface public void continuaComunque() { if (app()) a.ui.post(a::continuaComunque); }

    // --- Genio collegato ---
    @JavascriptInterface public void salvaFile(String b64, String tipo, String nome) { if (sito()) a.ui.post(() -> a.salvaBase64(b64, tipo, nome)); }
    @JavascriptInterface public void stampa(String titolo) { if (sito()) a.stampa(titolo); }
}
