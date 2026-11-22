import XCTest
@testable import Genio

// Resta collegato con Face ID: impronta della chiave come quella del server (SHA-256 esadecimale) e testo per le pagine
final class SbloccoTests: XCTestCase {
    func testImprontaComeIlServer() {
        XCTAssertEqual(Sblocco.impronta("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    func testTestoSicuroPerLePagine() {
        XCTAssertEqual(WebViewController.jsTesto("Face ID"), "\"Face ID\"")
        XCTAssertEqual(WebViewController.jsTesto("a\"b</script>"), "\"a\\\"b<\\/script>\"")
        XCTAssertEqual(WebViewController.jsTesto(""), "\"\"")
    }

    func testSenzaChiaveNonSiResta() {
        Sblocco.dimentica("https://prova.example")
        XCTAssertFalse(Sblocco.presente("https://prova.example"))
    }
}
