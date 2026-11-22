import Foundation

// Controlla che a un indirizzo risponda un Genio (GET /api/auth/desktop risponde con il campo "desktop")
// e restituisce l'indirizzo da salvare: quello scritto, o quello finale dopo un rimando allo stesso Genio con o senza www.
enum Collegamento {
    enum Esito { case ok(String), nonValido, nonGenio, irraggiungibile }

    static func prova(_ testo: String, fatto: @escaping (Esito) -> Void) {
        guard let b = Indirizzo.origine(testo), let url = URL(string: b + "/api/auth/desktop") else { fatto(.nonValido); return }
        var r = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 12)
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: r) { data, resp, err in
            let esito: Esito
            if err != nil || resp == nil {
                esito = .irraggiungibile
            } else if (resp as? HTTPURLResponse)?.statusCode == 200, let d = data,
                      let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any], j["desktop"] != nil {
                let fin = resp?.url.flatMap { Indirizzo.origine($0.absoluteString) }
                esito = .ok(fin != nil && Indirizzo.gemello(URL(string: fin!), b) ? fin! : b)
            } else {
                esito = .nonGenio
            }
            DispatchQueue.main.async { fatto(esito) }
        }.resume()
    }

    // il server sa riportare l'accesso Microsoft o Google all'app (genio://auth)? Come per l'app per computer.
    static func ritornoAllApp(_ base: String, fatto: @escaping (Bool) -> Void) {
        guard let url = URL(string: base + "/api/auth/desktop") else { fatto(false); return }
        URLSession.shared.dataTask(with: URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)) { data, resp, _ in
            var ok = false
            if (resp as? HTTPURLResponse)?.statusCode == 200, let d = data,
               let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                ok = (j["desktop"] as? Int) == 1 || (j["desktop"] as? Bool) == true
            }
            DispatchQueue.main.async { fatto(ok) }
        }.resume()
    }
}
