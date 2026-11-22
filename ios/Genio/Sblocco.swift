import Foundation
import LocalAuthentication
import Security
import CryptoKit
import WebKit

// Restare collegati con Face ID, Touch ID o il codice del telefono (lib/appSblocco.js di Genio).
// Dopo l'accesso Genio dà all'app una "chiave del dispositivo": l'app la chiude nel Portachiavi di iOS, apribile solo
// da chi sblocca il telefono (Face ID, Touch ID o codice), mai copiata su altri dispositivi né nei backup.
// Quando la sessione si chiude o l'app si riapre, la chiave si scambia con una sessione nuova (POST /api/auth/app):
// la chiave passa solo tra l'app e Genio, mai dalle pagine. Sul telefono senza codice non si resta collegati.
enum Sblocco {
    private static let servizio = "app.genio.chiave"
    private static let prefs = UserDefaults.standard
    private static let percorso = "/api/auth/app"

    /// come si sblocca questo telefono; nil se non ha un codice (allora non si resta collegati)
    static func nome() -> String? {
        let c = LAContext()
        guard c.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else { return nil }
        _ = c.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch c.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default:
            if #available(iOS 17.0, *), c.biometryType == .opticID { return "Optic ID" }
            return "il codice"
        }
    }

    // la chiave c'è? (segno non segreto accanto: leggerla dal Portachiavi chiederebbe Face ID)
    static func presente(_ base: String) -> Bool { prefs.string(forKey: "impronta:" + base) != nil }

    static func salva(_ chiave: String, base: String) -> Bool {
        dimentica(base)
        guard let ac = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .userPresence, nil) else { return false }
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: servizio, kSecAttrAccount as String: base,
                                kSecValueData as String: Data(chiave.utf8), kSecAttrAccessControl as String: ac]
        guard SecItemAdd(q as CFDictionary, nil) == errSecSuccess else { return false }
        prefs.set(impronta(chiave), forKey: "impronta:" + base)
        return true
    }

    /// toglie la chiave da qui e la fa annullare a Genio (con la sola impronta, senza chiedere Face ID)
    static func dimentica(_ base: String, avvisa: Bool = false, ua: String = "") {
        if avvisa, let h = prefs.string(forKey: "impronta:" + base) { invia(base, ["azione": "togli", "impronta": h], ua: ua, cookie: nil) { _, _, _ in } }
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: servizio, kSecAttrAccount as String: base]
        SecItemDelete(q as CFDictionary)
        prefs.removeObject(forKey: "impronta:" + base)
    }

    enum Lettura { case chiave(String), annullato, nulla }

    /// Face ID (o Touch ID, o il codice) e lettura della chiave; il messaggio lo mostra iOS
    static func leggi(_ base: String, fatto: @escaping (Lettura) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let ctx = LAContext()
            ctx.localizedReason = "Sblocca Genio per continuare"
            ctx.localizedCancelTitle = "Annulla"
            let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: servizio, kSecAttrAccount as String: base,
                                    kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne, kSecUseAuthenticationContext as String: ctx]
            var out: CFTypeRef?
            let st = SecItemCopyMatching(q as CFDictionary, &out)
            let r: Lettura
            if st == errSecSuccess, let d = out as? Data, let t = String(data: d, encoding: .utf8) { r = .chiave(t) }
            else if st == errSecUserCanceled || st == errSecAuthFailed { r = .annullato }
            else { r = .nulla } // tolta, o codice del telefono tolto (iOS cancella la chiave da solo)
            DispatchQueue.main.async { fatto(r) }
        }
    }

    static func impronta(_ t: String) -> String { SHA256.hash(data: Data(t.utf8)).map { String(format: "%02x", $0) }.joined() }

    // ---------- richieste a Genio, con una sessione di rete propria: nessun cookie salvato fuori dalla vista web ----------
    private static let rete: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.httpCookieAcceptPolicy = .never
        c.httpShouldSetCookies = false
        c.httpCookieStorage = nil
        c.urlCache = nil
        c.timeoutIntervalForRequest = 15
        return URLSession(configuration: c)
    }()

    /// cookie della vista web per l'indirizzo di Genio (anche quelli httpOnly), per le richieste fatte dall'app
    static func cookie(_ base: String, fatto: @escaping (String?) -> Void) {
        guard let host = URL(string: base)?.host?.lowercased() else { fatto(nil); return }
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { tutti in
            let suoi = tutti.filter { c in
                let d = c.domain.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
                return host == d || host.hasSuffix("." + d)
            }
            fatto(HTTPCookie.requestHeaderFields(with: suoi)["Cookie"])
        }
    }

    /// risposta: codice HTTP (0 = rete assente), JSON, risposta
    static func invia(_ base: String, _ corpo: [String: Any]?, ua: String, cookie: String?, fatto: @escaping (Int, [String: Any], HTTPURLResponse?) -> Void) {
        guard let u = URL(string: base + percorso) else { fatto(0, [:], nil); return }
        var r = URLRequest(url: u, cachePolicy: .reloadIgnoringLocalCacheData)
        r.httpMethod = corpo == nil ? "GET" : "POST"
        r.setValue(ua, forHTTPHeaderField: "User-Agent")
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        if let c = cookie { r.setValue(c, forHTTPHeaderField: "Cookie") }
        if let b = corpo {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = try? JSONSerialization.data(withJSONObject: b)
        }
        rete.dataTask(with: r) { data, resp, err in
            let h = resp as? HTTPURLResponse
            let j = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
            DispatchQueue.main.async { fatto(err != nil ? 0 : h?.statusCode ?? 0, j, h) }
        }.resume()
    }

    /// la sessione nuova arrivata da Genio entra nella vista web (stessi cookie che avrebbe messo l'accesso)
    static func metti(_ resp: HTTPURLResponse, base: String, fatto: @escaping () -> Void) {
        guard let u = URL(string: base) else { fatto(); return }
        var campi: [String: String] = [:]
        for (k, v) in resp.allHeaderFields { if let k = k as? String, let v = v as? String { campi[k] = v } }
        let nuovi = HTTPCookie.cookies(withResponseHeaderFields: campi, for: u)
        let store = WKWebsiteDataStore.default().httpCookieStore
        let g = DispatchGroup()
        for c in nuovi {
            g.enter()
            if let e = c.expiresDate, e < Date() { store.delete(c) { g.leave() } } else { store.setCookie(c) { g.leave() } }
        }
        g.notify(queue: .main, execute: fatto)
    }
}
