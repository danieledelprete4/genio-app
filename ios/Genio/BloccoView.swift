import UIKit

// Schermata "Genio è bloccato" sopra la vista web (variante A "Notte", scelta da Daniele il 22/11/2026):
// fondo blu della colonna di Genio, ora grande in alto, icona di Face ID al centro, "Ciao <nome>", un solo tasto bianco.
// Copre la pagina (niente dati a vista, anche nell'elenco delle app aperte) finché Face ID, Touch ID o il codice
// non sbloccano la chiave del dispositivo (Sblocco.swift).
final class BloccoView: UIView {
    var sblocca: (() -> Void)?
    var esci: (() -> Void)?

    private let sfondo = CAGradientLayer()
    private let ora = UILabel()
    private let data = UILabel()
    private let anello = UIView()
    private let icona = UIImageView()
    private let titolo = UILabel()
    private let testo = UILabel()
    private let avviso = UIView()
    private let avvisoTesto = UILabel()
    private let tasto = UIButton(type: .system)
    private let esciTasto = UIButton(type: .system)
    private var orologio: Timer?
    private var nome = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.insertSublayer(sfondo, at: 0)

        ora.font = .monospacedDigitSystemFont(ofSize: 64, weight: .light)
        ora.textColor = .white
        ora.textAlignment = .center
        ora.adjustsFontSizeToFitWidth = true
        data.font = .preferredFont(forTextStyle: .body)
        data.adjustsFontForContentSizeCategory = true
        data.textColor = UIColor.white.withAlphaComponent(0.82)
        data.textAlignment = .center
        let alto = UIStackView(arrangedSubviews: [ora, data])
        alto.axis = .vertical
        alto.spacing = 6
        alto.isAccessibilityElement = false
        ora.isAccessibilityElement = false
        data.isAccessibilityElement = false

        anello.layer.cornerRadius = 28
        anello.layer.cornerCurve = .continuous
        anello.layer.borderWidth = 1.5
        anello.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        icona.tintColor = .white
        icona.contentMode = .scaleAspectFit
        icona.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 46, weight: .light)
        icona.translatesAutoresizingMaskIntoConstraints = false
        anello.addSubview(icona)
        anello.translatesAutoresizingMaskIntoConstraints = false

        titolo.font = UIFontMetrics(forTextStyle: .title1).scaledFont(for: .systemFont(ofSize: 26, weight: .semibold))
        titolo.adjustsFontForContentSizeCategory = true
        titolo.textColor = .white
        titolo.textAlignment = .center
        titolo.numberOfLines = 0
        titolo.accessibilityTraits = .header

        testo.font = .preferredFont(forTextStyle: .body)
        testo.adjustsFontForContentSizeCategory = true
        testo.textColor = UIColor.white.withAlphaComponent(0.88)
        testo.textAlignment = .center
        testo.numberOfLines = 0
        testo.text = "Genio si è bloccato per sicurezza. Sbloccalo e riprendi dalla stessa pagina."
        let mezzo = UIStackView(arrangedSubviews: [anello, titolo, testo])
        mezzo.axis = .vertical
        mezzo.alignment = .center
        mezzo.spacing = 14
        mezzo.setCustomSpacing(20, after: anello)

        // avviso (rete assente): riquadro chiaro sul blu, con icona
        avviso.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        avviso.layer.cornerRadius = 12
        avviso.layer.cornerCurve = .continuous
        let wifi = UIImageView(image: UIImage(systemName: "wifi.slash"))
        wifi.tintColor = .white
        wifi.setContentHuggingPriority(.required, for: .horizontal)
        avvisoTesto.font = .preferredFont(forTextStyle: .subheadline)
        avvisoTesto.adjustsFontForContentSizeCategory = true
        avvisoTesto.textColor = .white
        avvisoTesto.numberOfLines = 0
        let riga = UIStackView(arrangedSubviews: [wifi, avvisoTesto])
        riga.spacing = 10
        riga.alignment = .top
        riga.translatesAutoresizingMaskIntoConstraints = false
        avviso.addSubview(riga)
        avviso.isHidden = true

        var c = UIButton.Configuration.filled()
        c.baseBackgroundColor = .white
        c.cornerStyle = .fixed
        c.background.cornerRadius = 14
        c.buttonSize = .large
        c.imagePadding = 10
        c.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        tasto.configuration = c
        tasto.configurationUpdateHandler = { b in
            // premuto: un velo azzurrino, mai un rettangolo scuro; in corso: grigio chiaro con la rotella
            var k = b.configuration
            k?.background.backgroundColor = b.isHighlighted ? UIColor(red: 0.91, green: 0.93, blue: 0.98, alpha: 1) : .white
            b.configuration = k
        }
        tasto.addAction(UIAction { [weak self] _ in self?.sblocca?() }, for: .touchUpInside)

        var e = UIButton.Configuration.plain()
        e.baseForegroundColor = .white
        e.buttonSize = .large
        esciTasto.configuration = e
        esciTasto.addAction(UIAction { [weak self] _ in self?.esci?() }, for: .touchUpInside)

        let giu = UIStackView(arrangedSubviews: [avviso, tasto, esciTasto])
        giu.axis = .vertical
        giu.spacing = 14
        giu.setCustomSpacing(6, after: tasto)

        [alto, mezzo, giu].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; addSubview($0) }
        let g = safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            alto.topAnchor.constraint(equalTo: g.topAnchor, constant: 48),
            alto.centerXAnchor.constraint(equalTo: centerXAnchor),
            alto.leadingAnchor.constraint(greaterThanOrEqualTo: g.leadingAnchor, constant: 24),
            anello.widthAnchor.constraint(equalToConstant: 96), anello.heightAnchor.constraint(equalToConstant: 96),
            icona.centerXAnchor.constraint(equalTo: anello.centerXAnchor), icona.centerYAnchor.constraint(equalTo: anello.centerYAnchor),
            mezzo.centerXAnchor.constraint(equalTo: centerXAnchor),
            mezzo.centerYAnchor.constraint(equalTo: g.centerYAnchor, constant: 40).withPriority(.defaultHigh),
            mezzo.topAnchor.constraint(greaterThanOrEqualTo: alto.bottomAnchor, constant: 24),
            mezzo.widthAnchor.constraint(equalTo: giu.widthAnchor),
            giu.topAnchor.constraint(greaterThanOrEqualTo: mezzo.bottomAnchor, constant: 24),
            giu.bottomAnchor.constraint(equalTo: g.bottomAnchor, constant: -12),
            giu.centerXAnchor.constraint(equalTo: centerXAnchor),
            giu.leadingAnchor.constraint(greaterThanOrEqualTo: g.leadingAnchor, constant: 24),
            giu.widthAnchor.constraint(lessThanOrEqualToConstant: 400),
            giu.widthAnchor.constraint(equalTo: g.widthAnchor, constant: -48).withPriority(.defaultHigh),
            tasto.heightAnchor.constraint(greaterThanOrEqualToConstant: 54),
            esciTasto.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            riga.topAnchor.constraint(equalTo: avviso.topAnchor, constant: 12), riga.bottomAnchor.constraint(equalTo: avviso.bottomAnchor, constant: -12),
            riga.leadingAnchor.constraint(equalTo: avviso.leadingAnchor, constant: 14), riga.trailingAnchor.constraint(equalTo: avviso.trailingAnchor, constant: -14),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        sfondo.frame = bounds
    }

    override var isHidden: Bool {
        didSet {
            orologio?.invalidate()
            orologio = nil
            if !isHidden {
                aggiornaOra()
                orologio = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in self?.aggiornaOra() }
            }
        }
    }

    private func aggiornaOra() {
        let d = Date()
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "HH:mm"
        ora.text = f.string(from: d)
        f.dateFormat = "EEEE d MMMM"
        data.text = f.string(from: d)
    }

    /// come: "Face ID", "Touch ID", "il codice"; nome: chi ha fatto l'accesso; colore: --night di Genio
    func mostra(come: String, nome: String, colore: UIColor, occupato: Bool = false, messaggio: String? = nil) {
        self.nome = nome
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        colore.getRed(&r, green: &g, blue: &b, alpha: &a)
        let su = UIColor(red: min(1, r * 1.15 + 0.01), green: min(1, g * 1.2 + 0.03), blue: min(1, b * 1.35 + 0.06), alpha: 1)
        let giu = UIColor(red: r * 0.66, green: g * 0.6, blue: b * 0.68, alpha: 1)
        sfondo.colors = [su.cgColor, colore.cgColor, giu.cgColor]
        sfondo.locations = [0, 0.42, 1]
        backgroundColor = colore

        let simbolo = come == "Face ID" ? "faceid" : come == "Touch ID" ? "touchid" : come == "Optic ID" ? "opticid" : "lock"
        icona.image = UIImage(systemName: simbolo) ?? UIImage(systemName: "lock")
        // anello che "respira" solo mentre iOS controlla il viso (niente movimento con Riduci movimento)
        anello.layer.removeAllAnimations()
        if occupato && !UIAccessibility.isReduceMotionEnabled {
            let k = CABasicAnimation(keyPath: "opacity")
            k.fromValue = 0.45; k.toValue = 1; k.duration = 0.7; k.autoreverses = true; k.repeatCount = .infinity
            k.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            anello.layer.add(k, forKey: "respira")
        }
        titolo.text = nome.isEmpty ? "Genio è bloccato" : "Ciao \(nome)"

        var c = tasto.configuration
        c?.title = occupato ? "Guarda lo schermo…" : "Sblocca con \(come)"
        if come == "il codice" { c?.title = occupato ? "Inserisci il codice…" : "Sblocca con il codice" }
        c?.image = occupato ? nil : UIImage(systemName: simbolo)
        c?.baseForegroundColor = colore
        c?.showsActivityIndicator = false
        tasto.configuration = c
        tasto.isUserInteractionEnabled = !occupato
        tasto.accessibilityTraits = occupato ? [.button, .notEnabled] : .button

        var e = esciTasto.configuration
        var at = AttributedString(nome.isEmpty ? "Esci" : "Non sei \(nome)? Esci")
        at.uiKit.underlineStyle = .single
        at.uiKit.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: .systemFont(ofSize: 15, weight: .semibold))
        e?.attributedTitle = at
        esciTasto.configuration = e

        avvisoTesto.text = messaggio
        avviso.isHidden = messaggio == nil
        if let m = messaggio { UIAccessibility.post(notification: .announcement, argument: m) }
    }
}
