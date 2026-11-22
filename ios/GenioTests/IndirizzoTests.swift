import XCTest
@testable import Genio

// L'indirizzo scritto a mano: si tiene solo l'origine, e solo https (come nell'app Android).
final class IndirizzoTests: XCTestCase {
    func testRestaSoloLOrigine() {
        XCTAssertEqual(Indirizzo.origine("https://genio.example.it/tablet"), "https://genio.example.it")
        XCTAssertEqual(Indirizzo.origine("  HTTPS://Genio.Example.IT/tablet?stampa=1  "), "https://genio.example.it")
        XCTAssertEqual(Indirizzo.origine("nome.vercel.app"), "https://nome.vercel.app")
        XCTAssertEqual(Indirizzo.origine("genio. nexus"), "https://genio.nexus") // spazio del correttore
        XCTAssertEqual(Indirizzo.origine("https://x.it:8443/"), "https://x.it:8443")
    }

    func testIndirizziNonValidi() {
        XCTAssertNil(Indirizzo.origine(""))
        XCTAssertNil(Indirizzo.origine(nil))
        XCTAssertNil(Indirizzo.origine("http://genio.example.it"))
        XCTAssertNil(Indirizzo.origine("javascript:alert(1)"))
        XCTAssertNil(Indirizzo.origine("https://utente:pw@genio.example.it"))
        XCTAssertNil(Indirizzo.origine("https://senzapunto"))
        XCTAssertNil(Indirizzo.origine("file:///etc/hosts"))
    }

    func testHttpSoloInReteLocale() {
        XCTAssertEqual(Indirizzo.origine("http://192.168.1.10:3000"), "http://192.168.1.10:3000")
        XCTAssertEqual(Indirizzo.origine("http://localhost:3000/login"), "http://localhost:3000")
    }

    func testStessoSito() {
        let b = "https://genio.example.it"
        XCTAssertTrue(Indirizzo.stesso(URL(string: "https://genio.example.it/api/auth/microsoft"), b))
        XCTAssertFalse(Indirizzo.stesso(URL(string: "https://genio.example.it.altro.com/"), b))
        XCTAssertFalse(Indirizzo.stesso(URL(string: "https://altro.it/?u=https://genio.example.it/"), b))
        XCTAssertFalse(Indirizzo.stesso(URL(string: "http://genio.example.it/"), b))
    }

    func testGemelloConOSenzaWww() {
        XCTAssertTrue(Indirizzo.gemello(URL(string: "https://www.genio.nexus/hub"), "https://genio.nexus"))
        XCTAssertTrue(Indirizzo.gemello(URL(string: "https://genio.nexus/"), "https://www.genio.nexus"))
        XCTAssertFalse(Indirizzo.gemello(URL(string: "https://www.altro.nexus/"), "https://genio.nexus"))
        XCTAssertFalse(Indirizzo.gemello(URL(string: "https://genio.nexus/"), "https://genio.nexus"))
    }

    func testImprontaDellaChiave() {
        // stessa impronta che calcola il server (SHA-256 in base64url senza "=")
        XCTAssertEqual(WebViewController.impronta("abc"), "ungWv48Bz-pBQUDeXa4iI7ADYaOWF3qctBD_YfIAFa0")
        XCTAssertEqual(WebViewController.casuale().count, 43)
    }
}
