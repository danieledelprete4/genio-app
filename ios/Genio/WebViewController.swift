import UIKit
import WebKit
import AuthenticationServices
import CryptoKit

// Genio a tutto schermo nell'app per iPhone e iPad.
// - Il sito riconosce l'app dalla firma "GenioiOS" (barre e menu di vetro, app/ios.css di Genio);
//   sull'iPad anche "GenioTablet": modo tablet come l'app Android (menu sul lato, tasti grandi).
// - Al primo avvio si scrive l'indirizzo del Genio dell'azienda (AddressViewController): l'app tiene solo quello.
// - L'accesso Microsoft o Google si fa in una finestra di Safari e torna qui con genio://auth, come l'app per computer:
//   Google non accetta l'accesso dentro le app, e così valgono la verifica in due passaggi e gli accessi già fatti in Safari.
// - Gli altri siti si aprono in Safari; PDF ed Excel scaricati si salvano o si condividono; fotocamera e posizione
//   le chiede iOS la prima volta (testi in Info.plist).
// - Indirizzo da cambiare: scuotere il telefono, oppure dalla pagina di errore quando Genio non risponde.
final class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate, ASWebAuthenticationPresentationContextProviding {
    static let protocollo = "genio"
    static let hub = "/hub" // pannello di Genio: senza accesso mostra la schermata di accesso
    private static let login = ["/api/auth/google", "/api/auth/microsoft"]

    private var web: WKWebView!
    private let errore = UIView()
    private let erroreTesto = UILabel()
    private var accessoInApp = false // sito senza ritorno all'app: l'accesso Microsoft resta qui
    private var sessione: ASWebAuthenticationSession?
    private var scaricati: [WKDownload: URL] = [:]
    private let prefs = UserDefaults.standard

    private var base: String? {
        get { Indirizzo.origine(prefs.string(forKey: "url")) }
        set { prefs.set(newValue, forKey: "url") }
    }

    private var versione: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0" }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
    override var canBecomeFirstResponder: Bool { true }

    private let barra = UIView()
    private let notte = UIColor(red: 0x09 / 255, green: 0x1f / 255, blue: 0x5b / 255, alpha: 1) // --night di serie

    // ---------- avvio ----------
    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .light
        view.backgroundColor = .white

        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default() // cookie della sessione conservati come in Safari
        cfg.allowsInlineMediaPlayback = true
        cfg.defaultWebpagePreferences.preferredContentMode = .mobile // anche l'iPad si presenta come iPad, non come Mac
        let pad = UIDevice.current.userInterfaceIdiom == .pad
        cfg.applicationNameForUserAgent = "Mobile/15E148" + (pad ? " GenioTablet/\(versione)" : "") + " GenioiOS/\(versione)"

        web = WKWebView(frame: .zero, configuration: cfg)
        web.navigationDelegate = self
        web.uiDelegate = self
        web.allowsBackForwardNavigationGestures = true
        web.allowsLinkPreview = false
        web.scrollView.contentInsetAdjustmentBehavior = .never // le zone sicure (notch, barra Home) le gestisce Genio
        web.isOpaque = false
        web.backgroundColor = .white
        web.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(web)
        // striscia sotto l'ora e la batteria (notch / Dynamic Island) del colore della colonna di Genio:
        // la pagina parte sotto, così niente finisce coperto
        barra.backgroundColor = notte
        barra.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(barra)
        NSLayoutConstraint.activate([
            barra.topAnchor.constraint(equalTo: view.topAnchor),
            barra.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            barra.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            barra.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            web.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            web.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            web.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            web.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        preparaErrore()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
        if web.url == nil && presentedViewController == nil { avvia() }
    }

    private func avvia() {
        if base == nil { chiediIndirizzo(annullabile: false) } else { apriSito() }
    }

    private func apriSito(_ percorso: String = WebViewController.hub) {
        guard let b = base, let u = URL(string: b + percorso) else { chiediIndirizzo(annullabile: false); return }
        errore.isHidden = true
        web.load(URLRequest(url: u))
    }

    // ---------- indirizzo ----------
    private func chiediIndirizzo(annullabile: Bool) {
        let a = AddressViewController()
        a.iniziale = base
        a.annullabile = annullabile
        a.modalPresentationStyle = .fullScreen
        a.collegato = { [weak self, weak a] nuovo in
            guard let self = self else { return }
            let cambia = nuovo != self.base
            self.base = nuovo
            self.accessoInApp = false
            let apri = { a?.dismiss(animated: true); self.apriSito() }
            // un altro Genio: si entra da capo, senza i cookie di quello di prima
            if cambia {
                WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast, completionHandler: apri)
            } else { apri() }
        }
        present(a, animated: !annullabile ? false : true)
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard motion == .motionShake, presentedViewController == nil else { return }
        let a = UIAlertController(title: "Cambiare indirizzo?", message: "L'app è collegata a \(base ?? "nessun Genio"). Puoi collegarla a un altro indirizzo di Genio.", preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "Annulla", style: .cancel))
        a.addAction(UIAlertAction(title: "Cambia indirizzo", style: .default) { [weak self] _ in self?.chiediIndirizzo(annullabile: true) })
        present(a, animated: true)
    }

    // ---------- pagina di errore (Genio non risponde) ----------
    private func preparaErrore() {
        errore.backgroundColor = UIColor(red: 0.953, green: 0.949, blue: 0.945, alpha: 1)
        errore.isHidden = true
        errore.translatesAutoresizingMaskIntoConstraints = false
        erroreTesto.font = .systemFont(ofSize: 17)
        erroreTesto.textColor = UIColor(white: 0.2, alpha: 1)
        erroreTesto.numberOfLines = 0
        erroreTesto.textAlignment = .center
        let titolo = UILabel()
        titolo.text = "Genio non risponde"
        titolo.font = .systemFont(ofSize: 22, weight: .semibold)
        titolo.textAlignment = .center
        var c1 = UIButton.Configuration.filled()
        c1.title = "Riprova"; c1.baseBackgroundColor = UIColor(red: 0x0f / 255, green: 0x6c / 255, blue: 0xbd / 255, alpha: 1); c1.cornerStyle = .large; c1.buttonSize = .large
        let riprova = UIButton(configuration: c1, primaryAction: UIAction { [weak self] _ in self?.apriSito() })
        var c2 = UIButton.Configuration.bordered()
        c2.title = "Cambia indirizzo"; c2.baseForegroundColor = UIColor(white: 0.14, alpha: 1); c2.cornerStyle = .large; c2.buttonSize = .large
        let cambia = UIButton(configuration: c2, primaryAction: UIAction { [weak self] _ in self?.chiediIndirizzo(annullabile: true) })
        let pila = UIStackView(arrangedSubviews: [titolo, erroreTesto, riprova, cambia])
        pila.axis = .vertical
        pila.spacing = 14
        pila.setCustomSpacing(24, after: erroreTesto)
        pila.translatesAutoresizingMaskIntoConstraints = false
        errore.addSubview(pila)
        view.addSubview(errore)
        NSLayoutConstraint.activate([
            errore.topAnchor.constraint(equalTo: view.topAnchor), errore.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            errore.leadingAnchor.constraint(equalTo: view.leadingAnchor), errore.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pila.centerYAnchor.constraint(equalTo: errore.safeAreaLayoutGuide.centerYAnchor),
            pila.leadingAnchor.constraint(equalTo: errore.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            pila.trailingAnchor.constraint(equalTo: errore.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            riprova.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
            cambia.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
        ])
    }

    private func mostraErrore(_ e: Error) {
        let n = e as NSError
        if n.domain == NSURLErrorDomain && n.code == NSURLErrorCancelled { return }
        if n.domain == "WebKitErrorDomain" && n.code == 102 { return } // navigazione fermata da noi (download, link esterno)
        erroreTesto.text = "Controlla la connessione a internet e riprova. Indirizzo collegato: \(base ?? "nessuno")."
        errore.isHidden = false
    }

    func webView(_ w: WKWebView, didFailProvisionalNavigation n: WKNavigation!, withError e: Error) { mostraErrore(e) }
    func webView(_ w: WKWebView, didFail n: WKNavigation!, withError e: Error) { mostraErrore(e) }
    func webView(_ w: WKWebView, didFinish n: WKNavigation!) {
        errore.isHidden = true
        // colore della colonna scelto in Aspetto (--night), per la striscia in alto
        w.evaluateJavaScript("getComputedStyle(document.documentElement).getPropertyValue('--night')") { [weak self] v, _ in
            guard let self = self, let c = (v as? String).flatMap(Self.coloreHex) else { return }
            self.barra.backgroundColor = c
        }
    }

    /// "#rrggbb" (anche con spazi) -> colore; nil per altri formati
    static func coloreHex(_ s: String) -> UIColor? {
        var t = s.trimmingCharacters(in: .whitespaces)
        guard t.hasPrefix("#") else { return nil }
        t.removeFirst()
        if t.count == 3 { t = t.map { "\($0)\($0)" }.joined() }
        guard t.count == 6, let n = UInt32(t, radix: 16) else { return nil }
        return UIColor(red: CGFloat((n >> 16) & 0xff) / 255, green: CGFloat((n >> 8) & 0xff) / 255, blue: CGFloat(n & 0xff) / 255, alpha: 1)
    }
    func webViewWebContentProcessDidTerminate(_ w: WKWebView) { w.reload() }

    // ---------- dove si apre ogni link ----------
    func webView(_ w: WKWebView, decidePolicyFor a: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = a.request.url else { decisionHandler(.cancel); return }
        let sch = (url.scheme ?? "").lowercased()
        if a.shouldPerformDownload { decisionHandler(.download); return }
        if sch == "about" || sch == "blob" || sch == "data" { decisionHandler(.allow); return }
        if sch != "http" && sch != "https" { esterno(url); decisionHandler(.cancel); return } // tel:, mailto:, whatsapp:...
        let principale = a.targetFrame?.isMainFrame ?? true
        if Indirizzo.stesso(url, base) {
            if principale, WebViewController.login.contains(url.path), !accessoInApp {
                accesso(url.path.hasSuffix("google") ? "google" : "microsoft")
                decisionHandler(.cancel); return
            }
            if principale { accessoInApp = false }
            decisionHandler(.allow); return
        }
        // lo stesso Genio con o senza www: si aggiorna l'indirizzo e si resta nell'app
        if Indirizzo.gemello(url, base) { base = Indirizzo.origine(url.absoluteString); decisionHandler(.allow); return }
        if !principale || accessoInApp { decisionHandler(.allow); return } // riquadri interni; accesso Microsoft dentro l'app
        esterno(url)
        decisionHandler(.cancel)
    }

    func webView(_ w: WKWebView, decidePolicyFor r: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        let disp = (r.response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Disposition")?.lowercased() ?? ""
        if !r.canShowMIMEType || disp.hasPrefix("attachment") { decisionHandler(.download) } else { decisionHandler(.allow) }
    }

    private func esterno(_ url: URL) { UIApplication.shared.open(url) }

    // finestre nuove (target=_blank, window.open): Genio nella stessa vista, il resto in Safari
    func webView(_ w: WKWebView, createWebViewWith c: WKWebViewConfiguration, for a: WKNavigationAction, windowFeatures f: WKWindowFeatures) -> WKWebView? {
        if let url = a.request.url {
            if Indirizzo.stesso(url, base) || Indirizzo.gemello(url, base) { w.load(a.request) } else if url.scheme == "http" || url.scheme == "https" { esterno(url) }
        }
        return nil
    }

    // alert, conferme e domande delle pagine
    func webView(_ w: WKWebView, runJavaScriptAlertPanelWithMessage m: String, initiatedByFrame f: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let a = UIAlertController(title: nil, message: m, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        presentaOppure(a) { completionHandler() }
    }

    func webView(_ w: WKWebView, runJavaScriptConfirmPanelWithMessage m: String, initiatedByFrame f: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let a = UIAlertController(title: nil, message: m, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "Annulla", style: .cancel) { _ in completionHandler(false) })
        a.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        presentaOppure(a) { completionHandler(false) }
    }

    func webView(_ w: WKWebView, runJavaScriptTextInputPanelWithPrompt p: String, defaultText d: String?, initiatedByFrame f: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let a = UIAlertController(title: nil, message: p, preferredStyle: .alert)
        a.addTextField { $0.text = d }
        a.addAction(UIAlertAction(title: "Annulla", style: .cancel) { _ in completionHandler(nil) })
        a.addAction(UIAlertAction(title: "OK", style: .default) { [weak a] _ in completionHandler(a?.textFields?.first?.text) })
        presentaOppure(a) { completionHandler(nil) }
    }

    private func presentaOppure(_ a: UIAlertController, altrimenti: @escaping () -> Void) {
        if presentedViewController == nil { present(a, animated: true) } else { altrimenti() }
    }

    // fotocamera e microfono (tessera, codici a barre) solo per il Genio collegato; iOS chiede comunque il permesso la prima volta
    func webView(_ w: WKWebView, requestMediaCapturePermissionFor o: WKSecurityOrigin, initiatedByFrame f: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        let origine = "\(o.protocol)://\(o.host)" + (o.port > 0 ? ":\(o.port)" : "")
        decisionHandler(origine == base ? .prompt : .deny)
    }

    // ---------- file scaricati (PDF, Excel): si salvano in File o si condividono ----------
    func webView(_ w: WKWebView, navigationAction a: WKNavigationAction, didBecome d: WKDownload) { d.delegate = self }
    func webView(_ w: WKWebView, navigationResponse r: WKNavigationResponse, didBecome d: WKDownload) { d.delegate = self }

    func download(_ d: WKDownload, decideDestinationUsing r: URLResponse, suggestedFilename nome: String, completionHandler: @escaping (URL?) -> Void) {
        let cartella = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: cartella, withIntermediateDirectories: true)
        let pulito = nome.replacingOccurrences(of: "/", with: "-")
        let dest = cartella.appendingPathComponent(pulito.isEmpty ? "Genio" : pulito)
        scaricati[d] = dest
        completionHandler(dest)
    }

    func downloadDidFinish(_ d: WKDownload) {
        guard let f = scaricati.removeValue(forKey: d) else { return }
        let c = UIActivityViewController(activityItems: [f], applicationActivities: nil)
        c.popoverPresentationController?.sourceView = view
        c.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        c.popoverPresentationController?.permittedArrowDirections = []
        if presentedViewController == nil { present(c, animated: true) }
    }

    func download(_ d: WKDownload, didFailWithError e: Error, resumeData: Data?) {
        scaricati.removeValue(forKey: d)
        let a = UIAlertController(title: "File non scaricato", message: "Riprova tra poco.", preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        presentaOppure(a) {}
    }

    // ---------- accesso Microsoft o Google in Safari, ritorno con genio://auth ----------
    private func accesso(_ prov: String) {
        guard let b = base else { return }
        Collegamento.ritornoAllApp(b) { [weak self] ok in
            guard let self = self else { return }
            guard ok else {
                // Genio senza ritorno all'app: l'accesso resta qui (funziona con Microsoft, non con Google)
                self.accessoInApp = true
                if let u = URL(string: b + "/api/auth/" + prov) { self.web.load(URLRequest(url: u)) }
                return
            }
            let v = WebViewController.casuale()
            guard let link = URL(string: b + "/api/auth/desktop/start?c=" + WebViewController.impronta(v) + "&p=" + prov) else { return }
            let s = ASWebAuthenticationSession(url: link, callbackURLScheme: WebViewController.protocollo) { [weak self] ritorno, err in
                guard let self = self else { return }
                self.sessione = nil
                guard err == nil, let r = ritorno, r.host == "auth",
                      let code = URLComponents(url: r, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "code" })?.value,
                      self.base == b else {
                    if (err as? ASWebAuthenticationSessionError)?.code != .canceledLogin { self.apriSito("/login?err=stato") }
                    return
                }
                var q = URLComponents(string: b + "/api/auth/desktop")
                q?.queryItems = [URLQueryItem(name: "code", value: code), URLQueryItem(name: "v", value: v)]
                if let u = q?.url { self.web.load(URLRequest(url: u)) }
            }
            s.presentationContextProvider = self
            s.prefersEphemeralWebBrowserSession = false // vale l'accesso già fatto in Safari
            self.sessione = s
            s.start()
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor { view.window ?? ASPresentationAnchor() }

    static func casuale() -> String {
        var b = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, b.count, &b)
        return base64url(Data(b))
    }

    static func impronta(_ v: String) -> String { base64url(Data(SHA256.hash(data: Data(v.utf8)))) }

    static func base64url(_ d: Data) -> String {
        d.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}
