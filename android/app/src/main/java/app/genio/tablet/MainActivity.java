package app.genio.tablet;

import android.Manifest;
import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.ContentValues;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.os.Handler;
import android.os.Looper;
import android.os.Message;
import android.print.PrintAttributes;
import android.print.PrintManager;
import android.provider.MediaStore;
import android.util.Base64;
import android.view.View;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.view.WindowManager;
import android.webkit.CookieManager;
import android.webkit.GeolocationPermissions;
import android.webkit.PermissionRequest;
import android.webkit.RenderProcessGoneDetail;
import android.webkit.URLUtil;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import android.widget.Toast;

import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

// Genio sul tablet del negozio: il sito Genio a tutto schermo, con lo schermo sempre acceso.
// - Il sito riconosce l'app dalla firma "GenioTablet" e si mette nel modo tablet (menu sul lato, tasti grandi).
// - Al primo avvio si inquadra il QR della scheda "App per tablet" (o si scrive l'indirizzo): l'app tiene solo quello.
// - L'accesso Microsoft o Google si fa nel browser del tablet e torna qui con genio://auth (come l'app per computer):
//   Google non accetta l'accesso dentro le app, e così vale la verifica in due passaggi del browser.
// - Fotocamera (tessera sanitaria, ricevute), posizione (timbratura), PDF ed Excel scaricati, stampa.
// Nessun dato di Genio resta nell'app oltre ai cookie della sessione, come in un browser.
public class MainActivity extends Activity {
    static final String TABLET_UA = "GenioTablet";
    static final int WEBVIEW_MIN = 111; // Genio usa color-mix, :has e dvh
    static final String PAGINE = "file:///android_asset/pagine/";
    static final String AZIONE_INDIRIZZO = "app.genio.tablet.INDIRIZZO";
    static final String PROTOCOLLO = "genio";
    static final long ACCESSO_MAX = 10 * 60 * 1000; // l'accesso aperto nel browser vale 10 minuti

    private static final int REQ_FILE = 11, REQ_PERM_FOTO = 21, REQ_PERM_CAMERA = 22, REQ_PERM_POS = 23, REQ_PERM_MEMORIA = 24;
    private static final String[] LOGIN = {"/api/auth/google", "/api/auth/microsoft"};

    WebView web;
    FrameLayout radice;
    SharedPreferences prefs;
    final Handler ui = new Handler(Looper.getMainLooper());
    final ExecutorService bg = Executors.newFixedThreadPool(2);
    volatile String attuale = ""; // pagina aperta, per i controlli del ponte con le pagine
    String accessoInApp = null; // sito senza ritorno all'app: l'accesso resta qui (solo Microsoft funziona)

    private ValueCallback<Uri[]> fileCb;
    private WebChromeClient.FileChooserParams fileParams;
    private Uri foto;
    private PermissionRequest permWeb;
    private GeolocationPermissions.Callback posCb;
    private String posOrigine;
    private Runnable dopoMemoria;

    // ---------- avvio ----------
    @Override
    protected void onCreate(Bundle stato) {
        super.onCreate(stato);
        prefs = getSharedPreferences("genio", MODE_PRIVATE);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        radice = new FrameLayout(this);
        radice.setBackgroundColor(Color.WHITE);
        setContentView(radice);
        tuttoSchermo();
        creaWeb();
        if (stato != null && web.restoreState(stato) != null) return;
        avvia(getIntent());
    }

    @Override
    protected void onNewIntent(Intent i) {
        super.onNewIntent(i);
        setIntent(i);
        avvia(i);
    }

    private void avvia(Intent i) {
        Uri dati = i != null ? i.getData() : null;
        if (dati != null && PROTOCOLLO.equals(dati.getScheme())) { ritornoAccesso(dati); return; }
        if (i != null && AZIONE_INDIRIZZO.equals(i.getAction())) { pagina("indirizzo.html", null); return; }
        if (web.getUrl() != null && (i == null || Intent.ACTION_MAIN.equals(i.getAction()))) return; // riaperta dall'icona: resta dov'era
        int v = versioneWebView();
        if (v > 0 && v < WEBVIEW_MIN && !prefs.getBoolean("webview_ok", false)) { pagina("aggiorna.html", "v=" + v); return; }
        apriSito(null);
    }

    String base() { return Indirizzo.origine(prefs.getString("url", null)); }

    void apriSito(String dove) {
        String b = base();
        if (b == null) { pagina("indirizzo.html", "primo=1"); return; }
        web.loadUrl(dove != null ? dove : b + "/");
    }

    void pagina(String nome, String query) {
        web.loadUrl(PAGINE + nome + (query != null ? "?" + query : ""));
    }

    // tutto lo schermo: le barre di Android compaiono solo trascinando dal bordo e poi si richiudono
    private void tuttoSchermo() {
        if (Build.VERSION.SDK_INT >= 30) {
            getWindow().setDecorFitsSystemWindows(false);
            WindowInsetsController c = getWindow().getInsetsController();
            if (c != null) {
                c.hide(WindowInsets.Type.systemBars());
                c.setSystemBarsBehavior(WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
            }
            // con la tastiera aperta il sito si accorcia, così il campo in cui si scrive resta visibile
            radice.setOnApplyWindowInsetsListener((v, ins) -> {
                int tastiera = ins.getInsets(WindowInsets.Type.ime()).bottom;
                int taglio = ins.getInsets(WindowInsets.Type.displayCutout()).top;
                v.setPadding(0, taglio, 0, tastiera);
                return WindowInsets.CONSUMED;
            });
        } else {
            getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_FULLSCREEN | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY);
        }
    }

    @Override
    public void onWindowFocusChanged(boolean fuoco) {
        super.onWindowFocusChanged(fuoco);
        if (fuoco) tuttoSchermo();
    }

    static int versioneWebView() {
        try {
            PackageInfo p = WebView.getCurrentWebViewPackage();
            if (p == null || p.versionName == null) return 0;
            return Integer.parseInt(p.versionName.split("\\.")[0]);
        } catch (Exception e) {
            return 0;
        }
    }

    // ---------- il sito ----------
    private void creaWeb() {
        web = new WebView(this);
        web.setBackgroundColor(Color.WHITE);
        radice.addView(web, new FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setGeolocationEnabled(true);
        s.setSupportMultipleWindows(true);
        s.setJavaScriptCanOpenWindowsAutomatically(true);
        s.setMediaPlaybackRequiresUserGesture(true);
        s.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        s.setAllowFileAccess(false); // le pagine dell'app sono in android_asset, che resta leggibile
        s.setAllowContentAccess(true); // foto scattate (content://app.genio.tablet.archivio)
        s.setTextZoom(100); // Genio sceglie già la grandezza dei testi per il tablet
        s.setBuiltInZoomControls(false);
        s.setUserAgentString(s.getUserAgentString() + " " + TABLET_UA + "/" + BuildConfig.VERSION_NAME);
        CookieManager.getInstance().setAcceptCookie(true);
        CookieManager.getInstance().setAcceptThirdPartyCookies(web, false);
        WebView.setWebContentsDebuggingEnabled(BuildConfig.DEBUG);
        web.setRendererPriorityPolicy(WebView.RENDERER_PRIORITY_IMPORTANT, true);
        web.addJavascriptInterface(new Ponte(this), "GenioApp");
        web.setWebViewClient(new Client());
        web.setWebChromeClient(new Chrome());
        web.setDownloadListener((url, ua, disp, mime, len) -> scarica(url, disp, mime));
    }

    boolean paginaApp(String url) { return url != null && url.startsWith(PAGINE); }
    boolean nelSito(String url) { return Indirizzo.stesso(url, base()); }

    private class Client extends WebViewClient {
        @Override
        public boolean shouldOverrideUrlLoading(WebView v, WebResourceRequest r) {
            return decidi(r.getUrl().toString());
        }

        @Override
        public void onPageStarted(WebView v, String url, Bitmap icona) {
            attuale = url;
        }

        @Override
        public void onPageFinished(WebView v, String url) {
            attuale = url;
            // nel sito: stampa con la stampa di Android e nome dei file scaricati con un link
            if (nelSito(url)) v.evaluateJavascript(
                "(function(){if(window.__genioApp)return;window.__genioApp=1;"
                + "window.print=function(){GenioApp.stampa(document.title||'')};"
                + "document.addEventListener('click',function(e){var a=e.target&&e.target.closest&&e.target.closest('a[download]');if(a)window.__genioNome=a.getAttribute('download')||''},true);"
                + "var c=HTMLAnchorElement.prototype.click;HTMLAnchorElement.prototype.click=function(){if(this.hasAttribute('download'))window.__genioNome=this.getAttribute('download')||'';return c.apply(this,arguments)};"
                + "})()", null);
        }

        @Override
        public void onReceivedError(WebView v, WebResourceRequest r, WebResourceError e) {
            if (!r.isForMainFrame() || paginaApp(r.getUrl().toString())) return;
            String u = r.getUrl().toString();
            pagina("errore.html", "url=" + enc(u) + "&desc=" + enc(String.valueOf(e.getDescription())));
        }

        // il sito si è chiuso per poca memoria (tablet con 6 GB pieni): si riapre invece di chiudere l'app
        @Override
        public boolean onRenderProcessGone(WebView v, RenderProcessGoneDetail d) {
            String dove = v.getUrl();
            radice.removeView(v);
            v.destroy();
            creaWeb();
            if (dove != null && nelSito(dove)) web.loadUrl(dove); else apriSito(null);
            return true;
        }
    }

    // dove va un link: il sito e le pagine dell'app restano qui, il resto si apre nell'app giusta
    boolean decidi(String url) {
        if (paginaApp(url)) return false;
        Uri u = Uri.parse(url);
        String sch = u.getScheme() == null ? "" : u.getScheme().toLowerCase(java.util.Locale.ROOT);
        if (PROTOCOLLO.equals(sch)) { ritornoAccesso(u); return true; }
        if (nelSito(url)) {
            String p = u.getPath() == null ? "" : u.getPath();
            for (String l : LOGIN) if (p.equals(l)) { accesso(l.endsWith("google") ? "google" : "microsoft"); return true; }
            return false;
        }
        if (accessoInApp != null && (sch.equals("https"))) return false; // pagine di accesso Microsoft dentro l'app
        if (sch.equals("intent")) { apriIntent(url); return true; }
        apriFuori(url);
        return true;
    }

    void apriFuori(String url) {
        try {
            Intent i = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
            i.addCategory(Intent.CATEGORY_BROWSABLE);
            startActivity(i);
        } catch (ActivityNotFoundException e) {
            avviso("Nessuna app per aprire questo link");
        }
    }

    // link intent:// (per esempio WhatsApp): solo app che accettano link dal browser, altrimenti l'indirizzo di riserva
    private void apriIntent(String url) {
        try {
            Intent i = Intent.parseUri(url, Intent.URI_INTENT_SCHEME);
            i.addCategory(Intent.CATEGORY_BROWSABLE);
            i.setComponent(null);
            i.setSelector(null);
            try { startActivity(i); return; } catch (ActivityNotFoundException ignored) {}
            String riserva = i.getStringExtra("browser_fallback_url");
            if (riserva != null && riserva.startsWith("https://")) apriFuori(riserva);
        } catch (Exception e) {
            avviso("Link non valido");
        }
    }

    private class Chrome extends WebChromeClient {
        @Override
        public boolean onShowFileChooser(WebView v, ValueCallback<Uri[]> cb, FileChooserParams p) {
            if (fileCb != null) fileCb.onReceiveValue(null);
            fileCb = cb;
            fileParams = p;
            boolean foto = false;
            for (String t : p.getAcceptTypes()) if (t != null && t.startsWith("image")) foto = true;
            if (foto && checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
                requestPermissions(new String[]{Manifest.permission.CAMERA}, REQ_PERM_FOTO);
                return true;
            }
            scegliFile(foto);
            return true;
        }

        // fotocamera dentro il sito (lettura della tessera): solo per il Genio collegato
        @Override
        public void onPermissionRequest(PermissionRequest r) {
            ui.post(() -> {
                boolean video = false;
                for (String res : r.getResources()) if (PermissionRequest.RESOURCE_VIDEO_CAPTURE.equals(res)) video = true;
                if (!video || !nelSito(r.getOrigin().toString())) { r.deny(); return; }
                if (checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
                    r.grant(new String[]{PermissionRequest.RESOURCE_VIDEO_CAPTURE});
                } else {
                    permWeb = r;
                    requestPermissions(new String[]{Manifest.permission.CAMERA}, REQ_PERM_CAMERA);
                }
            });
        }

        // posizione per la timbratura in negozio: solo per il Genio collegato
        @Override
        public void onGeolocationPermissionsShowPrompt(String origine, GeolocationPermissions.Callback cb) {
            if (!nelSito(origine)) { cb.invoke(origine, false, false); return; }
            if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
                cb.invoke(origine, true, false);
            } else {
                posCb = cb;
                posOrigine = origine;
                requestPermissions(new String[]{Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION}, REQ_PERM_POS);
            }
        }

        // nuova scheda (Apri PDF, WhatsApp): una vista invisibile prende il primo indirizzo e lo passa all'app giusta
        @Override
        public boolean onCreateWindow(WebView v, boolean dialogo, boolean gesto, Message msg) {
            WebView tmp = new WebView(MainActivity.this);
            tmp.getSettings().setJavaScriptEnabled(false);
            tmp.setWebViewClient(new WebViewClient() {
                boolean fatto = false;
                private boolean prendi(String url) {
                    if (fatto || url == null || url.equals("about:blank")) return true;
                    fatto = true;
                    ui.post(() -> {
                        if (nelSito(url)) scarica(url, null, null); else decidi(url);
                        tmp.destroy();
                    });
                    return true;
                }
                @Override public boolean shouldOverrideUrlLoading(WebView w, WebResourceRequest r) { return prendi(r.getUrl().toString()); }
                @Override public void onPageStarted(WebView w, String url, Bitmap b) { if (!"about:blank".equals(url)) { w.stopLoading(); prendi(url); } }
            });
            ((WebView.WebViewTransport) msg.obj).setWebView(tmp);
            msg.sendToTarget();
            return true;
        }
    }

    // ---------- foto e file da mandare al sito ----------
    private void scegliFile(boolean anchefoto) {
        List<Intent> extra = new ArrayList<>();
        Intent camera = null;
        if (anchefoto && checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            String nome = "foto-" + System.currentTimeMillis() + ".jpg";
            try { new File(Archivio.cartella(this, Archivio.FOTO), nome).createNewFile(); } catch (Exception ignored) {}
            foto = Archivio.uri(Archivio.FOTO, nome);
            camera = new Intent(MediaStore.ACTION_IMAGE_CAPTURE);
            camera.putExtra(MediaStore.EXTRA_OUTPUT, foto);
            camera.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION | Intent.FLAG_GRANT_READ_URI_PERMISSION);
            extra.add(camera);
        } else {
            foto = null;
        }
        Intent scelta;
        if (camera != null && fileParams != null && fileParams.isCaptureEnabled()) {
            scelta = camera; // capture="environment": subito la fotocamera
        } else {
            Intent galleria = fileParams != null ? fileParams.createIntent() : new Intent(Intent.ACTION_GET_CONTENT).setType("*/*");
            galleria.addCategory(Intent.CATEGORY_OPENABLE);
            if (fileParams != null && fileParams.getMode() == WebChromeClient.FileChooserParams.MODE_OPEN_MULTIPLE) galleria.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
            scelta = Intent.createChooser(galleria, anchefoto ? "Scatta o scegli una foto" : "Scegli un file");
            if (!extra.isEmpty()) scelta.putExtra(Intent.EXTRA_INITIAL_INTENTS, extra.toArray(new Intent[0]));
        }
        try {
            startActivityForResult(scelta, REQ_FILE);
        } catch (ActivityNotFoundException e) {
            if (fileCb != null) fileCb.onReceiveValue(null);
            fileCb = null;
            avviso("Nessuna app per scegliere il file");
        }
    }

    @Override
    protected void onActivityResult(int req, int esito, Intent dati) {
        super.onActivityResult(req, esito, dati);
        if (req != REQ_FILE || fileCb == null) return;
        Uri[] r = null;
        if (esito == RESULT_OK) {
            if (dati != null && dati.getClipData() != null) {
                int n = dati.getClipData().getItemCount();
                r = new Uri[n];
                for (int i = 0; i < n; i++) r[i] = dati.getClipData().getItemAt(i).getUri();
            } else if (dati != null && dati.getData() != null) {
                r = new Uri[]{dati.getData()};
            } else if (foto != null) {
                File f = new File(Archivio.cartella(this, Archivio.FOTO), foto.getLastPathSegment());
                if (f.length() > 0) r = new Uri[]{foto};
            }
        }
        fileCb.onReceiveValue(r);
        fileCb = null;
        fileParams = null;
    }

    @Override
    public void onRequestPermissionsResult(int req, String[] perm, int[] esiti) {
        boolean ok = esiti.length > 0 && esiti[0] == PackageManager.PERMISSION_GRANTED;
        if (req == REQ_PERM_FOTO) {
            boolean anchefoto = ok;
            if (!ok) avviso("Senza fotocamera puoi scegliere una foto già fatta");
            scegliFile(anchefoto);
        } else if (req == REQ_PERM_CAMERA && permWeb != null) {
            if (ok) permWeb.grant(new String[]{PermissionRequest.RESOURCE_VIDEO_CAPTURE}); else permWeb.deny();
            permWeb = null;
        } else if (req == REQ_PERM_POS && posCb != null) {
            posCb.invoke(posOrigine, ok, false);
            posCb = null;
        } else if (req == REQ_PERM_MEMORIA && dopoMemoria != null) {
            Runnable r = dopoMemoria;
            dopoMemoria = null;
            r.run();
        }
    }

    // ---------- file scaricati (PDF, Excel) ----------
    void scarica(String url, String disp, String mime) {
        if (url.startsWith("blob:") || url.startsWith("data:")) {
            // file preparato dal sito: lo legge la pagina e lo passa all'app
            web.evaluateJavascript("(function(){var n=window.__genioNome||'';window.__genioNome='';fetch(" + JSONObject.quote(url) + ").then(function(r){return r.blob()}).then(function(b){var f=new FileReader();f.onload=function(){GenioApp.salvaFile(String(f.result).split(',')[1]||'',b.type||'',n)};f.readAsDataURL(b)}).catch(function(){GenioApp.salvaFile('','','')})})()", null);
            return;
        }
        if (!nelSito(url)) { apriFuori(url); return; }
        avviso("Download in corso…");
        final String cookie = CookieManager.getInstance().getCookie(url);
        final String ua = web.getSettings().getUserAgentString();
        bg.execute(() -> {
            HttpURLConnection c = null;
            try {
                c = (HttpURLConnection) new URL(url).openConnection();
                c.setConnectTimeout(20000);
                c.setReadTimeout(60000);
                if (cookie != null) c.setRequestProperty("Cookie", cookie);
                c.setRequestProperty("User-Agent", ua);
                int st = c.getResponseCode();
                String tipo = c.getContentType() != null ? c.getContentType().split(";")[0].trim() : (mime != null ? mime : "");
                if (st >= 400) throw new Exception("risposta " + st);
                if (tipo.startsWith("text/html")) { ui.post(() -> web.loadUrl(url)); return; } // era una pagina: si apre qui
                String d = c.getHeaderField("Content-Disposition");
                String nome = URLUtil.guessFileName(url, d != null ? d : disp, tipo);
                try (InputStream in = c.getInputStream()) { salva(in, nome, tipo); }
            } catch (Exception e) {
                ui.post(() -> avviso("Download non riuscito: riprova"));
            } finally {
                if (c != null) c.disconnect();
            }
        });
    }

    // salva nella cache dell'app, copia in Download e apre il file con l'app giusta (lettore PDF, Excel…)
    void salva(InputStream in, String nome, String tipo) throws Exception {
        String pulito = nome.replaceAll("[\\\\/:*?\"<>|\\p{Cntrl}]", "_").replaceAll("^\\.+", "");
        if (pulito.isEmpty()) pulito = "file";
        File f = new File(Archivio.cartella(this, Archivio.FILE), pulito);
        try (OutputStream out = new FileOutputStream(f)) {
            byte[] buf = new byte[16384];
            int n;
            while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
        }
        final String nomeFile = pulito;
        final String mime = tipo == null || tipo.isEmpty() ? "application/octet-stream" : tipo;
        ui.post(() -> copiaInDownload(f, nomeFile, mime, () -> apriFile(nomeFile, mime)));
    }

    void salvaBase64(String b64, String tipo, String nome) {
        if (b64 == null || b64.isEmpty()) { avviso("Download non riuscito: riprova"); return; }
        bg.execute(() -> {
            try {
                byte[] dati = Base64.decode(b64, Base64.DEFAULT);
                String n = nome == null || nome.isEmpty() ? URLUtil.guessFileName("file", null, tipo) : nome;
                salva(new java.io.ByteArrayInputStream(dati), n, tipo);
            } catch (Exception e) {
                ui.post(() -> avviso("Download non riuscito: riprova"));
            }
        });
    }

    private void copiaInDownload(File f, String nome, String mime, Runnable poi) {
        if (Build.VERSION.SDK_INT >= 29) {
            bg.execute(() -> {
                boolean ok = false;
                try {
                    ContentValues v = new ContentValues();
                    v.put(MediaStore.Downloads.DISPLAY_NAME, nome);
                    v.put(MediaStore.Downloads.MIME_TYPE, mime);
                    Uri u = getContentResolver().insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, v);
                    if (u != null) try (OutputStream out = getContentResolver().openOutputStream(u); InputStream in = new java.io.FileInputStream(f)) {
                        byte[] buf = new byte[16384];
                        int n;
                        while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
                        ok = true;
                    }
                } catch (Exception ignored) {}
                final boolean salvato = ok;
                ui.post(() -> { if (salvato) avviso("Salvato in Download: " + nome); poi.run(); });
            });
        } else if (checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED) {
            bg.execute(() -> {
                try {
                    File d = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS);
                    d.mkdirs();
                    try (InputStream in = new java.io.FileInputStream(f); OutputStream out = new FileOutputStream(new File(d, nome))) {
                        byte[] buf = new byte[16384];
                        int n;
                        while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
                    }
                    ui.post(() -> avviso("Salvato in Download: " + nome));
                } catch (Exception ignored) {}
                ui.post(poi);
            });
        } else {
            dopoMemoria = () -> copiaInDownload(f, nome, mime, poi);
            requestPermissions(new String[]{Manifest.permission.WRITE_EXTERNAL_STORAGE}, REQ_PERM_MEMORIA);
        }
    }

    private void apriFile(String nome, String mime) {
        Intent i = new Intent(Intent.ACTION_VIEW);
        i.setDataAndType(Archivio.uri(Archivio.FILE, nome), mime);
        i.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        try { startActivity(i); } catch (ActivityNotFoundException e) { /* resta in Download */ }
    }

    void stampa(String titolo) {
        ui.post(() -> {
            PrintManager pm = (PrintManager) getSystemService(PRINT_SERVICE);
            String nome = titolo == null || titolo.isEmpty() ? "Genio" : titolo;
            if (pm != null) pm.print(nome, web.createPrintDocumentAdapter(nome), new PrintAttributes.Builder().build());
        });
    }

    // ---------- accesso Microsoft o Google nel browser ----------
    void accesso(String prov) {
        String b = base();
        if (b == null) return;
        bg.execute(() -> {
            boolean ritorno = false;
            try {
                HttpURLConnection c = (HttpURLConnection) new URL(b + "/api/auth/desktop").openConnection();
                c.setConnectTimeout(10000);
                c.setReadTimeout(10000);
                c.setUseCaches(false);
                if (c.getResponseCode() == 200) {
                    try (InputStream in = c.getInputStream()) {
                        ritorno = new JSONObject(leggi(in)).optInt("desktop", 0) == 1;
                    }
                }
                c.disconnect();
            } catch (Exception ignored) {}
            final boolean r = ritorno;
            ui.post(() -> {
                if (!r) { accessoInApp = prov; web.loadUrl(b + "/api/auth/" + prov); return; }
                String v = casuale();
                String link = b + "/api/auth/desktop/start?c=" + impronta(v) + "&p=" + prov;
                prefs.edit().putString("acc_v", v).putString("acc_base", b).putString("acc_link", link).putLong("acc_at", System.currentTimeMillis()).apply();
                apriFuori(link);
                pagina("attesa.html", "p=" + prov);
            });
        });
    }

    void riapriBrowser() {
        String l = prefs.getString("acc_link", null);
        if (l != null) apriFuori(l);
    }

    void annullaAccesso() {
        prefs.edit().remove("acc_v").remove("acc_base").remove("acc_link").remove("acc_at").apply();
        String b = base();
        if (b != null) web.loadUrl(b + "/login"); else pagina("indirizzo.html", "primo=1");
    }

    // genio://auth?code=... dal browser: si scambia il codice con la chiave che solo questa app conosce
    private void ritornoAccesso(Uri u) {
        if (!"auth".equals(u.getHost())) return;
        String code = u.getQueryParameter("code");
        String v = prefs.getString("acc_v", null), b = prefs.getString("acc_base", null);
        long at = prefs.getLong("acc_at", 0);
        prefs.edit().remove("acc_v").remove("acc_base").remove("acc_link").remove("acc_at").apply();
        String ora = base();
        if (code == null || v == null || b == null || !b.equals(ora) || System.currentTimeMillis() - at > ACCESSO_MAX) {
            if (ora != null) web.loadUrl(ora + "/login?err=stato"); else pagina("indirizzo.html", "primo=1");
            return;
        }
        web.loadUrl(b + "/api/auth/desktop?code=" + enc(code) + "&v=" + enc(v));
    }

    static String casuale() {
        byte[] b = new byte[32];
        new SecureRandom().nextBytes(b);
        return Base64.encodeToString(b, Base64.URL_SAFE | Base64.NO_PADDING | Base64.NO_WRAP);
    }

    static String impronta(String v) {
        try {
            byte[] h = MessageDigest.getInstance("SHA-256").digest(v.getBytes("US-ASCII"));
            return Base64.encodeToString(h, Base64.URL_SAFE | Base64.NO_PADDING | Base64.NO_WRAP);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    // ---------- indirizzo del Genio ----------
    // controlla che all'indirizzo risponda un Genio, poi lo salva e lo apre; esito alla pagina con window.esito(...)
    void collega(String testo) {
        String b = Indirizzo.origine(testo);
        if (b == null) { esito(false, "Indirizzo non valido: inquadra il QR della scheda App per tablet o scrivi un indirizzo come nome.vercel.app"); return; }
        bg.execute(() -> {
            boolean genio = false;
            String errore = "Indirizzo non raggiungibile: controlla la connessione a internet e l'indirizzo.";
            try {
                HttpURLConnection c = (HttpURLConnection) new URL(b + "/api/auth/desktop").openConnection();
                c.setConnectTimeout(10000);
                c.setReadTimeout(10000);
                c.setUseCaches(false);
                int st = c.getResponseCode();
                if (st == 200) try (InputStream in = c.getInputStream()) { genio = new JSONObject(leggi(in)).has("desktop"); } catch (Exception ignored) {}
                c.disconnect();
                if (!genio) errore = "A questo indirizzo non risponde Genio: controlla di aver inquadrato il QR giusto.";
            } catch (Exception ignored) {}
            final boolean ok = genio;
            final String err = errore;
            ui.post(() -> {
                if (!ok) { esito(false, err); return; }
                if (!b.equals(base())) CookieManager.getInstance().removeAllCookies(null); // un altro Genio: si entra da capo
                prefs.edit().putString("url", b).apply();
                accessoInApp = null;
                apriSito(null);
            });
        });
    }

    void scansiona() {
        try {
            com.google.mlkit.vision.codescanner.GmsBarcodeScannerOptions o = new com.google.mlkit.vision.codescanner.GmsBarcodeScannerOptions.Builder()
                    .setBarcodeFormats(com.google.mlkit.vision.barcode.common.Barcode.FORMAT_QR_CODE)
                    .build();
            com.google.mlkit.vision.codescanner.GmsBarcodeScanning.getClient(this, o).startScan()
                    .addOnSuccessListener(c -> { String t = c.getRawValue(); if (t != null) { esitoAttesa(); collega(t); } })
                    .addOnFailureListener(e -> esito(false, "Lettore del QR non disponibile su questo tablet: scrivi l'indirizzo qui sotto."));
        } catch (Exception e) {
            esito(false, "Lettore del QR non disponibile su questo tablet: scrivi l'indirizzo qui sotto.");
        }
    }

    private void esitoAttesa() {
        if (paginaApp(attuale)) web.evaluateJavascript("window.attesa&&window.attesa()", null);
    }

    private void esito(boolean ok, String testo) {
        ui.post(() -> {
            if (paginaApp(attuale)) web.evaluateJavascript("window.esito&&window.esito(" + ok + "," + JSONObject.quote(testo) + ")", null);
            else avviso(testo);
        });
    }

    void aggiornaWebView() {
        String pkg = "com.google.android.webview";
        try { PackageInfo p = WebView.getCurrentWebViewPackage(); if (p != null) pkg = p.packageName; } catch (Exception ignored) {}
        try {
            startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=" + pkg)));
        } catch (ActivityNotFoundException e) {
            apriFuori("https://play.google.com/store/apps/details?id=" + pkg);
        }
    }

    void continuaComunque() {
        prefs.edit().putBoolean("webview_ok", true).apply();
        apriSito(null);
    }

    String info() {
        try {
            JSONObject o = new JSONObject();
            o.put("url", prefs.getString("url", ""));
            o.put("versione", BuildConfig.VERSION_NAME);
            o.put("webview", versioneWebView());
            o.put("minimo", WEBVIEW_MIN);
            return o.toString();
        } catch (Exception e) {
            return "{}";
        }
    }

    // ---------- varie ----------
    @Override
    public void onBackPressed() {
        String u = web.getUrl();
        if (paginaApp(u) && u.contains("attesa.html")) { annullaAccesso(); return; }
        if (paginaApp(u) && u.contains("indirizzo.html") && base() != null) { apriSito(null); return; }
        if (web.canGoBack()) { web.goBack(); return; }
        moveTaskToBack(true); // il tasto Indietro non chiude Genio: resta aperto dov'era
    }

    @Override
    protected void onSaveInstanceState(Bundle out) {
        super.onSaveInstanceState(out);
        web.saveState(out);
    }

    @Override
    protected void onPause() {
        super.onPause();
        CookieManager.getInstance().flush();
    }

    @Override
    protected void onDestroy() {
        bg.shutdownNow();
        if (web != null) web.destroy();
        super.onDestroy();
    }

    void avviso(String t) { Toast.makeText(this, t, Toast.LENGTH_LONG).show(); }

    static String enc(String s) {
        try { return URLEncoder.encode(s, "UTF-8"); } catch (Exception e) { return ""; }
    }

    static String leggi(InputStream in) throws java.io.IOException {
        java.io.ByteArrayOutputStream b = new java.io.ByteArrayOutputStream();
        byte[] buf = new byte[4096];
        int n;
        while ((n = in.read(buf)) > 0 && b.size() < 65536) b.write(buf, 0, n);
        return b.toString("UTF-8");
    }
}
