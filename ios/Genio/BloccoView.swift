import UIKit

// Schermata "Genio è bloccato" sopra la vista web: copre la pagina (niente dati a vista, anche nell'elenco delle app aperte)
// finché Face ID, Touch ID o il codice non sbloccano la chiave del dispositivo (Sblocco.swift).
// Colore della colonna di Genio (--night, come la striscia in alto), testo bianco, tasto bianco con scritta del colore di fondo.
final class BloccoView: UIView {
    var sblocca: (() -> Void)?
    var esci: (() -> Void)?

    private let icona = UIImageView()
    private let titolo = UILabel()
    private let testo = UILabel()
    private let avviso = UILabel()
    private let tasto = UIButton(type: .system)
    private let esciTasto = UIButton(type: .system)
    private let pila = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        icona.tintColor = .white
        icona.contentMode = .scaleAspectFit
        icona.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 44, weight: .regular)
        let cerchio = UIView()
        cerchio.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        cerchio.layer.cornerRadius = 44
        cerchio.translatesAutoresizingMaskIntoConstraints = false
        icona.translatesAutoresizingMaskIntoConstraints = false
        cerchio.addSubview(icona)

        titolo.text = "Genio è bloccato"
        titolo.font = .systemFont(ofSize: 26, weight: .semibold)
        titolo.adjustsFontForContentSizeCategory = true
        titolo.textColor = .white
        titolo.textAlignment = .center
        titolo.numberOfLines = 0
        titolo.accessibilityTraits = .header

        testo.font = .preferredFont(forTextStyle: .body)
        testo.adjustsFontForContentSizeCategory = true
        testo.textColor = UIColor.white.withAlphaComponent(0.9)
        testo.textAlignment = .center
        testo.numberOfLines = 0

        avviso.font = .preferredFont(forTextStyle: .subheadline)
        avviso.adjustsFontForContentSizeCategory = true
        avviso.textColor = .white
        avviso.textAlignment = .center
        avviso.numberOfLines = 0
        avviso.isHidden = true

        var c = UIButton.Configuration.filled()
        c.baseBackgroundColor = .white
        c.cornerStyle = .large
        c.buttonSize = .large
        c.imagePadding = 8
        tasto.configuration = c
        tasto.addAction(UIAction { [weak self] _ in self?.sblocca?() }, for: .touchUpInside)

        var e = UIButton.Configuration.plain()
        e.baseForegroundColor = .white
        e.buttonSize = .large
        var at = AttributedString("Esci e accedi con un altro account")
        at.uiKit.underlineStyle = .single
        at.uiKit.font = UIFont.preferredFont(forTextStyle: .subheadline)
        e.attributedTitle = at
        esciTasto.configuration = e
        esciTasto.addAction(UIAction { [weak self] _ in self?.esci?() }, for: .touchUpInside)

        pila.axis = .vertical
        pila.alignment = .center
        pila.spacing = 12
        [cerchio, titolo, testo, avviso, tasto, esciTasto].forEach { pila.addArrangedSubview($0) }
        pila.setCustomSpacing(22, after: cerchio)
        pila.setCustomSpacing(28, after: avviso)
        pila.setCustomSpacing(8, after: tasto)
        pila.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pila)
        NSLayoutConstraint.activate([
            cerchio.widthAnchor.constraint(equalToConstant: 88), cerchio.heightAnchor.constraint(equalToConstant: 88),
            icona.centerXAnchor.constraint(equalTo: cerchio.centerXAnchor), icona.centerYAnchor.constraint(equalTo: cerchio.centerYAnchor),
            pila.centerYAnchor.constraint(equalTo: safeAreaLayoutGuide.centerYAnchor),
            pila.leadingAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.leadingAnchor, constant: 24),
            pila.trailingAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor, constant: -24),
            pila.centerXAnchor.constraint(equalTo: centerXAnchor),
            pila.widthAnchor.constraint(lessThanOrEqualToConstant: 420),
            tasto.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
            tasto.widthAnchor.constraint(equalTo: pila.widthAnchor),
            testo.widthAnchor.constraint(equalTo: pila.widthAnchor),
            esciTasto.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
        ])
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { fatalError() }

    /// come: "Face ID", "Touch ID", "il codice"; colore: fondo (--night di Genio); occupato: Face ID in corso
    func mostra(come: String, colore: UIColor, occupato: Bool = false, messaggio: String? = nil) {
        backgroundColor = colore
        let simbolo = come == "Face ID" ? "faceid" : come == "Touch ID" ? "touchid" : come == "Optic ID" ? "opticid" : "lock.fill"
        icona.image = UIImage(systemName: simbolo) ?? UIImage(systemName: "lock.fill")
        testo.text = "Sblocca con \(come) e riprendi da dove eri rimasto."
        var c = tasto.configuration
        c?.title = "Sblocca con \(come)"
        c?.baseForegroundColor = colore
        c?.showsActivityIndicator = occupato
        tasto.configuration = c
        tasto.isEnabled = !occupato
        avviso.text = messaggio
        avviso.isHidden = messaggio == nil
        if let m = messaggio { UIAccessibility.post(notification: .announcement, argument: m) }
    }
}
