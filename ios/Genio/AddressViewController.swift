import UIKit

// Primo avvio (o "Cambia indirizzo"): si scrive l'indirizzo del Genio dell'azienda, l'app controlla che risponda e lo ricorda.
final class AddressViewController: UIViewController, UITextFieldDelegate {
    var iniziale: String?
    var annullabile = false
    var collegato: ((String) -> Void)?

    private let campo = UITextField()
    private let tasto = UIButton(type: .system)
    private let errore = UILabel()
    private let attesa = UIActivityIndicatorView(style: .medium)
    private let blu = UIColor(red: 0x0f / 255, green: 0x6c / 255, blue: 0xbd / 255, alpha: 1)

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .light
        view.backgroundColor = UIColor(red: 0.953, green: 0.949, blue: 0.945, alpha: 1)

        let icona = UIImageView(image: UIImage(named: "Logo") ?? UIImage(systemName: "lightbulb"))
        icona.contentMode = .scaleAspectFit
        icona.layer.cornerRadius = 16
        icona.clipsToBounds = true
        icona.widthAnchor.constraint(equalToConstant: 72).isActive = true
        icona.heightAnchor.constraint(equalToConstant: 72).isActive = true

        let titolo = UILabel()
        titolo.text = "Collega l'app al tuo Genio"
        titolo.font = .systemFont(ofSize: 24, weight: .semibold)
        titolo.textColor = UIColor(white: 0.14, alpha: 1)
        titolo.textAlignment = .center
        titolo.numberOfLines = 0

        let sotto = UILabel()
        sotto.text = "Scrivi l'indirizzo che usi per aprire Genio. Lo trovi nella sezione Mobile di Genio, sotto \"iPhone e iPad\"."
        sotto.font = .systemFont(ofSize: 16)
        sotto.textColor = UIColor(white: 0.38, alpha: 1)
        sotto.textAlignment = .center
        sotto.numberOfLines = 0

        campo.placeholder = "nome.dominio.it"
        campo.text = iniziale.map { $0.replacingOccurrences(of: "https://", with: "") }
        campo.keyboardType = .URL
        campo.autocapitalizationType = .none
        campo.autocorrectionType = .no
        campo.spellCheckingType = .no
        campo.textContentType = .URL
        campo.returnKeyType = .go
        campo.clearButtonMode = .whileEditing
        campo.font = .systemFont(ofSize: 17)
        campo.textColor = UIColor(white: 0.14, alpha: 1)
        campo.backgroundColor = .white
        campo.layer.cornerRadius = 12
        campo.layer.borderWidth = 1
        campo.layer.borderColor = UIColor(white: 0.82, alpha: 1).cgColor
        campo.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        campo.leftViewMode = .always
        campo.delegate = self
        campo.accessibilityLabel = "Indirizzo di Genio"
        campo.heightAnchor.constraint(equalToConstant: 52).isActive = true

        var c = UIButton.Configuration.filled()
        c.title = "Collega"
        c.baseBackgroundColor = blu
        c.baseForegroundColor = .white
        c.cornerStyle = .large
        c.buttonSize = .large
        tasto.configuration = c
        tasto.addTarget(self, action: #selector(collega), for: .touchUpInside)
        tasto.heightAnchor.constraint(equalToConstant: 52).isActive = true

        errore.font = .systemFont(ofSize: 15)
        errore.textColor = UIColor(red: 0.64, green: 0.15, blue: 0.16, alpha: 1)
        errore.numberOfLines = 0
        errore.textAlignment = .center
        errore.isHidden = true

        attesa.hidesWhenStopped = true

        let pila = UIStackView(arrangedSubviews: [icona, titolo, sotto, campo, tasto, attesa, errore])
        pila.axis = .vertical
        pila.alignment = .fill
        pila.spacing = 16
        pila.setCustomSpacing(24, after: sotto)
        pila.translatesAutoresizingMaskIntoConstraints = false
        let centro = UIStackView(arrangedSubviews: [icona])
        centro.alignment = .center
        pila.removeArrangedSubview(icona)
        pila.insertArrangedSubview(centro, at: 0)

        // tutto dentro uno scorrimento che finisce sopra la tastiera: campo e tasto restano sempre visibili
        let scorri = UIScrollView()
        scorri.translatesAutoresizingMaskIntoConstraints = false
        scorri.keyboardDismissMode = .interactive
        scorri.alwaysBounceVertical = true
        view.addSubview(scorri)
        scorri.addSubview(pila)

        let g = view.safeAreaLayoutGuide
        let cont = scorri.contentLayoutGuide
        let cornice = scorri.frameLayoutGuide
        NSLayoutConstraint.activate([
            scorri.topAnchor.constraint(equalTo: g.topAnchor),
            scorri.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scorri.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scorri.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            // contenuto largo quanto lo schermo, alto almeno quanto lo spazio visibile (così la pila sta al centro)
            cont.widthAnchor.constraint(equalTo: cornice.widthAnchor),
            cont.heightAnchor.constraint(greaterThanOrEqualTo: cornice.heightAnchor),
            cont.heightAnchor.constraint(equalTo: cornice.heightAnchor).withPriority(.defaultLow),
            pila.centerYAnchor.constraint(equalTo: cont.centerYAnchor),
            pila.topAnchor.constraint(greaterThanOrEqualTo: cont.topAnchor, constant: 24),
            pila.bottomAnchor.constraint(lessThanOrEqualTo: cont.bottomAnchor, constant: -24),
            // larghezza: tutto lo schermo meno 24 per lato, al massimo 420 (iPad)
            pila.centerXAnchor.constraint(equalTo: cont.centerXAnchor),
            pila.leadingAnchor.constraint(greaterThanOrEqualTo: cont.leadingAnchor, constant: 24),
            pila.widthAnchor.constraint(lessThanOrEqualToConstant: 420),
            pila.widthAnchor.constraint(equalTo: cornice.widthAnchor, constant: -48).withPriority(.init(999)),
        ])

        if annullabile {
            let chiudi = UIButton(type: .system)
            chiudi.setTitle("Annulla", for: .normal)
            chiudi.titleLabel?.font = .systemFont(ofSize: 17)
            chiudi.tintColor = blu
            chiudi.addTarget(self, action: #selector(annulla), for: .touchUpInside)
            chiudi.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(chiudi)
            NSLayoutConstraint.activate([
                chiudi.topAnchor.constraint(equalTo: g.topAnchor, constant: 8),
                chiudi.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -16),
                chiudi.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            ])
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        campo.becomeFirstResponder()
    }

    func textFieldShouldReturn(_ t: UITextField) -> Bool { collega(); return true }

    @objc private func annulla() { dismiss(animated: true) }

    @objc private func collega() {
        errore.isHidden = true
        tasto.isEnabled = false
        attesa.startAnimating()
        Collegamento.prova(campo.text ?? "") { [weak self] esito in
            guard let self = self else { return }
            self.tasto.isEnabled = true
            self.attesa.stopAnimating()
            switch esito {
            case .ok(let b): self.collegato?(b)
            case .nonValido: self.mostra("Indirizzo non valido: scrivilo come nome.dominio.it")
            case .nonGenio: self.mostra("A questo indirizzo non risponde Genio: controlla di averlo scritto bene.")
            case .irraggiungibile: self.mostra("Indirizzo non raggiungibile: controlla la connessione a internet e l'indirizzo.")
            }
        }
    }

    private func mostra(_ t: String) {
        errore.text = t
        errore.isHidden = false
        UIAccessibility.post(notification: .announcement, argument: t)
    }
}

private extension NSLayoutConstraint {
    func withPriority(_ p: UILayoutPriority) -> NSLayoutConstraint { priority = p; return self }
}
