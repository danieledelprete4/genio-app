import Foundation

// Indirizzo del Genio a cui è collegata l'app: si tiene solo l'origine (https://nome.dominio), mai pagine o parametri.
// Stesse regole dell'app Android (android/.../Indirizzo.java).
enum Indirizzo {
    // nil = non valido. Solo https; http solo per le prove in rete locale.
    static func origine(_ testo: String?) -> String? {
        guard let testo = testo else { return nil }
        var s = testo.components(separatedBy: .whitespacesAndNewlines).joined() // anche gli spazi messi dal correttore
        if s.isEmpty || s.count > 400 { return nil }
        if s.range(of: "^[a-zA-Z][a-zA-Z0-9+.-]*://", options: .regularExpression) == nil { s = "https://" + s }
        guard let u = URLComponents(string: s), let host0 = u.host, !host0.isEmpty, u.user == nil, u.password == nil else { return nil }
        let sch = (u.scheme ?? "").lowercased()
        let host = host0.lowercased()
        let locale = host == "localhost" || host.range(of: "^(10|127|192\\.168|172\\.(1[6-9]|2[0-9]|3[01]))\\.", options: .regularExpression) != nil
        if sch != "https" && !(sch == "http" && locale) { return nil }
        if !host.contains(".") && !locale { return nil }
        if host.range(of: "^[a-z0-9.-]+$", options: .regularExpression) == nil { return nil }
        let porta = u.port.map { ":\($0)" } ?? ""
        return "\(sch)://\(host)\(porta)"
    }

    // stessa origine dell'indirizzo collegato
    static func stesso(_ url: URL?, _ base: String?) -> Bool {
        guard let url = url, let base = base, let o = origine(url.absoluteString) else { return false }
        return o == base
    }

    // lo stesso Genio con o senza "www." davanti (es. genio.nexus che rimanda a www.genio.nexus), in https
    static func gemello(_ url: URL?, _ base: String?) -> Bool {
        guard let url = url, let base = base, let o = origine(url.absoluteString), o != base,
              o.hasPrefix("https://"), base.hasPrefix("https://") else { return false }
        let a = String(o.dropFirst(8)), b = String(base.dropFirst(8))
        return a == "www." + b || b == "www." + a
    }
}
