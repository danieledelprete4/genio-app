import UIKit

// Dopo l'accesso, una volta: foglio dal basso "Entra con Face ID" (variante A scelta da Daniele il 22/11/2026).
// Spiega in tre righe cosa cambia, poi un solo tasto "Usa Face ID" e "Non ora". Chiudere il foglio = Non ora.
final class OffertaViewController: UIViewController, UIAdaptivePresentationControllerDelegate {
    var usa: (() -> Void)?
    var nonOra: (() -> Void)?
    private var scelto = false
    private let come: String
    private let giorni: Int
    private let colore: UIColor
    private let mfa: Bool

    init(come: String, giorni: Int, colore: UIColor, mfa: Bool) {
        self.come = come; self.giorni = giorni; self.colore = colore; self.mfa = mfa
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    private let ink = UIColor(red: 0x1b / 255, green: 0x1d / 255, blue: 0x29 / 255, alpha: 1)
    private let ink2 = UIColor(red: 0x4a / 255, green: 0x4e / 255, blue: 0x60 / 255, alpha: 1)
    private let chiaro = UIColor(red: 0xee / 255, green: 0xf2 / 255, blue: 0xfc / 255, alpha: 1)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        overrideUserInterfaceStyle = .light
        presentationController?.delegate = self

        let simbolo = come == "Face ID" ? "faceid" : come == "Touch ID" ? "touchid" : "lock"
        let ico = UIView()
        ico.backgroundColor = colore
        ico.layer.cornerRadius = 18
        ico.layer.cornerCurve = .continuous
        let img = UIImageView(image: UIImage(systemName: simbolo, withConfiguration: UIImage.SymbolConfiguration(pointSize: 30, weight: .regular)))
        img.tintColor = .white
        img.translatesAutoresizingMaskIntoConstraints = false
        ico.addSubview(img)
        ico.translatesAutoresizingMaskIntoConstraints = false
        // icona al centro: la pila riempie la larghezza, il riquadro dell'icona no
        let icoBox = UIView()
        icoBox.addSubview(ico)
        NSLayoutConstraint.activate([ico.topAnchor.constraint(equalTo: icoBox.topAnchor), ico.bottomAnchor.constraint(equalTo: icoBox.bottomAnchor), ico.centerXAnchor.constraint(equalTo: icoBox.centerXAnchor)])

        let titolo = etichetta(come == "il codice" ? "Entra con il codice" : "Entra con \(come)", stile: .title2, peso: .bold, colore: ink, centro: true)
        titolo.accessibilityTraits = .header
        let viso = come == "Face ID" ? "basta guardare il telefono." : come == "Touch ID" ? "basta il dito sul tasto." : "basta il codice del telefono."
        let sotto = etichetta("La prossima volta non serve rifare l'accesso: \(viso)", stile: .body, colore: ink2, centro: true)

        let punti = UIStackView(arrangedSubviews: [
            punto("clock.arrow.circlepath", "Genio si apre subito", come == "Face ID" ? "Con il tuo viso, senza password né codici." : "Senza password né codici di Genio."),
            punto("lock", "Se si blocca, riprendi da lì", "Dopo qualche minuto fermo si blocca: \(come) e torni alla stessa pagina."),
            punto("calendar", "Ogni \(giorni) giorni l'accesso completo", mfa ? "Per sicurezza, con la verifica in due passaggi." : "Per sicurezza, come al primo ingresso."),
        ])
        punti.axis = .vertical
        punti.spacing = 16

        var c = UIButton.Configuration.filled()
        c.title = come == "il codice" ? "Usa il codice" : "Usa \(come)"
        c.baseBackgroundColor = colore
        c.baseForegroundColor = .white
        c.cornerStyle = .fixed
        c.background.cornerRadius = 14
        c.buttonSize = .large
        let si = UIButton(configuration: c, primaryAction: UIAction { [weak self] _ in self?.scegli(true) })
        si.configurationUpdateHandler = { [colore] b in
            var k = b.configuration
            k?.background.backgroundColor = b.isHighlighted ? colore.withAlphaComponent(0.86) : colore
            b.configuration = k
        }
        var n = UIButton.Configuration.plain()
        var at = AttributedString("Non ora")
        at.uiKit.underlineStyle = .single
        at.uiKit.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: .systemFont(ofSize: 15, weight: .semibold))
        at.uiKit.foregroundColor = ink2
        n.attributedTitle = at
        let no = UIButton(configuration: n, primaryAction: UIAction { [weak self] _ in self?.scegli(false) })

        let pila = UIStackView(arrangedSubviews: [icoBox, titolo, sotto, punti, si, no])
        pila.axis = .vertical
        pila.alignment = .fill
        pila.spacing = 8
        pila.setCustomSpacing(16, after: icoBox)
        pila.setCustomSpacing(22, after: sotto)
        pila.setCustomSpacing(26, after: punti)
        pila.setCustomSpacing(6, after: si)
        pila.translatesAutoresizingMaskIntoConstraints = false

        let scorri = UIScrollView()
        scorri.alwaysBounceVertical = false
        scorri.translatesAutoresizingMaskIntoConstraints = false
        scorri.addSubview(pila)
        view.addSubview(scorri)
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scorri.topAnchor.constraint(equalTo: view.topAnchor), scorri.bottomAnchor.constraint(equalTo: g.bottomAnchor),
            scorri.leadingAnchor.constraint(equalTo: view.leadingAnchor), scorri.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pila.topAnchor.constraint(equalTo: scorri.contentLayoutGuide.topAnchor, constant: 32),
            pila.bottomAnchor.constraint(equalTo: scorri.contentLayoutGuide.bottomAnchor, constant: -8),
            pila.centerXAnchor.constraint(equalTo: scorri.centerXAnchor),
            pila.widthAnchor.constraint(equalTo: scorri.frameLayoutGuide.widthAnchor, constant: -44).conPriorita(.defaultHigh),
            pila.widthAnchor.constraint(lessThanOrEqualToConstant: 440),
            ico.widthAnchor.constraint(equalToConstant: 64), ico.heightAnchor.constraint(equalToConstant: 64),
            img.centerXAnchor.constraint(equalTo: ico.centerXAnchor), img.centerYAnchor.constraint(equalTo: ico.centerYAnchor),
            si.heightAnchor.constraint(greaterThanOrEqualToConstant: 54),
            no.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
        ])
        // altezza del foglio: quanto serve (fino a tutto schermo sui telefoni piccoli, dove si scorre)
        if let s = sheetPresentationController {
            s.prefersGrabberVisible = true
            s.preferredCornerRadius = 28
            if #available(iOS 16.0, *) {
                s.detents = [.custom { [weak self, weak pila] ctx in
                    guard let self = self, let p = pila else { return ctx.maximumDetentValue }
                    let w = min(440, self.view.bounds.width - 44)
                    let h = p.systemLayoutSizeFitting(CGSize(width: w, height: 0), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height
                    return min(ctx.maximumDetentValue, h + 48)
                }]
            }
        }
    }

    private func scegli(_ si: Bool) {
        scelto = true
        dismiss(animated: true) { [usa, nonOra] in if si { usa?() } else { nonOra?() } }
    }

    func presentationControllerDidDismiss(_ p: UIPresentationController) { if !scelto { nonOra?() } }

    private func etichetta(_ t: String, stile: UIFont.TextStyle, peso: UIFont.Weight = .regular, colore: UIColor, centro: Bool = false) -> UILabel {
        let l = UILabel()
        l.text = t
        let base = UIFont.preferredFont(forTextStyle: stile)
        l.font = peso == .regular ? base : UIFont.systemFont(ofSize: base.pointSize, weight: peso)
        l.adjustsFontForContentSizeCategory = true
        l.textColor = colore
        l.numberOfLines = 0
        if centro { l.textAlignment = .center }
        return l
    }

    private func punto(_ simbolo: String, _ titolo: String, _ testo: String) -> UIView {
        let box = UIView()
        box.backgroundColor = chiaro
        box.layer.cornerRadius = 10
        box.layer.cornerCurve = .continuous
        let i = UIImageView(image: UIImage(systemName: simbolo, withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)))
        i.tintColor = colore
        i.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(i)
        box.translatesAutoresizingMaskIntoConstraints = false
        let t = etichetta(titolo, stile: .subheadline, peso: .semibold, colore: ink)
        let d = etichetta(testo, stile: .subheadline, colore: ink2)
        let col = UIStackView(arrangedSubviews: [t, d])
        col.axis = .vertical
        col.spacing = 2
        let riga = UIStackView(arrangedSubviews: [box, col])
        riga.spacing = 12
        riga.alignment = .top
        NSLayoutConstraint.activate([
            box.widthAnchor.constraint(equalToConstant: 36), box.heightAnchor.constraint(equalToConstant: 36),
            i.centerXAnchor.constraint(equalTo: box.centerXAnchor), i.centerYAnchor.constraint(equalTo: box.centerYAnchor),
        ])
        riga.isAccessibilityElement = true
        riga.accessibilityLabel = "\(titolo). \(testo)"
        return riga
    }
}
