import XCTest
@testable import Genio

// Schermata dell'indirizzo: testi e campo larghi quasi quanto lo schermo, anche a 320 punti e su iPad (al massimo 420)
final class IndirizzoSchermataTests: XCTestCase {
    private func larghezze(_ w: CGFloat, _ h: CGFloat) -> (campo: CGFloat, testo: CGFloat) {
        let vc = AddressViewController()
        let win = UIWindow(frame: CGRect(x: 0, y: 0, width: w, height: h))
        win.rootViewController = vc
        win.isHidden = false
        vc.view.setNeedsLayout()
        vc.view.layoutIfNeeded()
        func tutte(_ v: UIView) -> [UIView] { [v] + v.subviews.flatMap(tutte) }
        let viste = tutte(vc.view)
        let campo = viste.compactMap { $0 as? UITextField }.first?.frame.width ?? 0
        let testo = viste.compactMap { $0 as? UILabel }.filter { ($0.text ?? "").hasPrefix("Collega l'app") }.first?.frame.width ?? 0
        win.isHidden = true
        return (campo, testo)
    }

    func testTelefoni() {
        for w in [320.0, 375.0, 402.0] {
            let l = larghezze(w, 700)
            XCTAssertEqual(l.campo, w - 48, accuracy: 1, "campo a \(w)")
            XCTAssertEqual(l.testo, w - 48, accuracy: 1, "titolo a \(w)")
        }
    }

    func testIPad() {
        let l = larghezze(1024, 768)
        XCTAssertEqual(l.campo, 420, accuracy: 1)
    }
}
