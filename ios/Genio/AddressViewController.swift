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

    // variante A "Notte" (scelta da Daniele il 22/11/2026): stesso blu notte del blocco Face ID (BloccoView.swift),
    // campo e tasto bianchi, riquadro che dice dove trovare l'indirizzo
    private let notte = UIColor(red: 0x09 / 255, green: 0x1f / 255, blue: 0x5b / 255, alpha: 1)
    private let sfondo = CAGradientLayer()
    private let bordoCampo = UIColor.white

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        sfondo.frame = view.bounds
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .light
        view.backgroundColor = notte
        sfondo.colors = [UIColor(red: 0x0b / 255, green: 0x2e / 255, blue: 0x8a / 255, alpha: 1).cgColor, notte.cgColor,
                         UIColor(red: 0x06 / 255, green: 0x12 / 255, blue: 0x3d / 255, alpha: 1).cgColor]
        sfondo.locations = [0, 0.42, 1]
        view.layer.insertSublayer(sfondo, at: 0)

        // lampadina bianca in un riquadro di vetro chiaro, come l'anello del blocco Face ID
        let riquadro = UIView()
        riquadro.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        riquadro.layer.cornerRadius = 18
        riquadro.layer.cornerCurve = .continuous
        riquadro.layer.borderWidth = 1
        riquadro.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        let lampadina = UIImageView(image: UIImage(systemName: "lightbulb"))
        lampadina.tintColor = .white
        lampadina.contentMode = .scaleAspectFit
        lampadina.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 28, weight: .regular)
        lampadina.translatesAutoresizingMaskIntoConstraints = false
        riquadro.addSubview(lampadina)
        riquadro.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            riquadro.widthAnchor.constraint(equalToConstant: 64),
            riquadro.heightAnchor.constraint(equalToConstant: 64),
            lampadina.centerXAnchor.constraint(equalTo: riquadro.centerXAnchor),
            lampadina.centerYAnchor.constraint(equalTo: riquadro.centerYAnchor),
        ])
        riquadro.isAccessibilityElement = false

        let titolo = UILabel()
        titolo.text = "Collega l'app al tuo Genio"
        titolo.font = UIFontMetrics(forTextStyle: .title1).scaledFont(for: .systemFont(ofSize: 26, weight: .semibold))
        titolo.adjustsFontForContentSizeCategory = true
        titolo.textColor = .white
        titolo.textAlignment = .center
        titolo.numberOfLines = 0
        titolo.accessibilityTraits = .header

        let sotto = UILabel()
        sotto.text = "Scrivi l'indirizzo che usi per aprire Genio."
        sotto.font = .preferredFont(forTextStyle: .body)
        sotto.adjustsFontForContentSizeCategory = true
        sotto.textColor = UIColor.white.withAlphaComponent(0.86)
        sotto.textAlignment = .center
        sotto.numberOfLines = 0

        // campo bianco: globo e "https://" fissi davanti, si scrive solo nome.dominio.it (o con /hub)
        campo.attributedPlaceholder = NSAttributedString(string: "nome.dominio.it", attributes: [.foregroundColor: UIColor(red: 0.43, green: 0.45, blue: 0.53, alpha: 1)])
        campo.text = iniziale.map { $0.replacingOccurrences(of: "https://", with: "") }
        campo.keyboardType = .URL
        campo.autocapitalizationType = .none
        campo.autocorrectionType = .no
        campo.spellCheckingType = .no
        campo.textContentType = .URL
        campo.returnKeyType = .go
        campo.clearButtonMode = .whileEditing
        campo.font = .preferredFont(forTextStyle: .body)
        campo.adjustsFontForContentSizeCategory = true
        campo.textColor = UIColor(white: 0.11, alpha: 1)
        campo.tintColor = blu
        campo.backgroundColor = .white
        campo.layer.cornerRadius = 14
        campo.layer.cornerCurve = .continuous
        campo.layer.borderWidth = 2
        campo.layer.borderColor = bordoCampo.cgColor
        let globo = UIImageView(image: UIImage(systemName: "globe"))
        globo.tintColor = UIColor(white: 0.2, alpha: 1)
        globo.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)
        let pre = UILabel()
        pre.text = "https://"
        pre.font = .preferredFont(forTextStyle: .body)
        pre.textColor = UIColor(red: 0.42, green: 0.44, blue: 0.51, alpha: 1)
        let davanti = UIStackView(arrangedSubviews: [globo, pre])
        davanti.spacing = 8
        davanti.alignment = .center
        davanti.isLayoutMarginsRelativeArrangement = true
        davanti.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 6)
        davanti.isUserInteractionEnabled = false
        davanti.frame.size = davanti.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        campo.leftView = davanti
        campo.leftViewMode = .always
        campo.delegate = self
        campo.addTarget(self, action: #selector(scritto), for: .editingChanged)
        campo.accessibilityLabel = "Indirizzo di Genio, dopo https://"
        campo.heightAnchor.constraint(greaterThanOrEqualToConstant: 54).isActive = true

        // tasto bianco con scritta blu notte; premuto un velo azzurrino, mai un rettangolo scuro
        var c = UIButton.Configuration.filled()
        c.title = "Collega"
        c.baseBackgroundColor = .white
        c.baseForegroundColor = notte
        c.cornerStyle = .fixed
        c.background.cornerRadius = 14
        c.buttonSize = .large
        c.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
            var b = a; b.font = UIFontMetrics(forTextStyle: .headline).scaledFont(for: .systemFont(ofSize: 17, weight: .semibold)); return b
        }
        tasto.configuration = c
        let scritta = notte
        tasto.configurationUpdateHandler = { b in
            var k = b.configuration
            k?.background.backgroundColor = b.isHighlighted ? UIColor(red: 0.91, green: 0.93, blue: 0.98, alpha: 1) : .white
            k?.baseForegroundColor = scritta
            b.configuration = k
        }
        tasto.addTarget(self, action: #selector(collega), for: .touchUpInside)
        tasto.heightAnchor.constraint(greaterThanOrEqualToConstant: 54).isActive = true

        // errore: testo rosa chiaro con icona, leggibile sul blu notte
        errore.font = .preferredFont(forTextStyle: .subheadline)
        errore.adjustsFontForContentSizeCategory = true
        errore.textColor = UIColor(red: 1, green: 0.82, blue: 0.82, alpha: 1)
        errore.numberOfLines = 0
        errore.textAlignment = .center
        errore.isHidden = true

        attesa.color = .white
        attesa.hidesWhenStopped = true

        // dove trovare l'indirizzo: riquadro chiaro sul blu
        let aiuto = UIView()
        aiuto.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        aiuto.layer.cornerRadius = 12
        aiuto.layer.cornerCurve = .continuous
        let tel = UIImageView(image: UIImage(systemName: "iphone"))
        tel.tintColor = .white
        tel.setContentHuggingPriority(.required, for: .horizontal)
        let aiutoTesto = UILabel()
        let corpo = UIFont.preferredFont(forTextStyle: .subheadline)
        let grassetto = UIFont.systemFont(ofSize: corpo.pointSize, weight: .semibold)
        let t = NSMutableAttributedString(string: "Lo trovi in Genio, nel ", attributes: [.font: corpo])
        t.append(NSAttributedString(string: "Menu", attributes: [.font: grassetto]))
        t.append(NSAttributedString(string: " alla voce ", attributes: [.font: corpo]))
        t.append(NSAttributedString(string: "Mobile", attributes: [.font: grassetto]))
        t.append(NSAttributedString(string: ", sotto \"iPhone e iPad\".", attributes: [.font: corpo]))
        aiutoTesto.attributedText = t
        aiutoTesto.textColor = .white
        aiutoTesto.numberOfLines = 0
        let rigaAiuto = UIStackView(arrangedSubviews: [tel, aiutoTesto])
        rigaAiuto.spacing = 10
        rigaAiuto.alignment = .top
        rigaAiuto.translatesAutoresizingMaskIntoConstraints = false
        aiuto.addSubview(rigaAiuto)
        NSLayoutConstraint.activate([
            rigaAiuto.topAnchor.constraint(equalTo: aiuto.topAnchor, constant: 12),
            rigaAiuto.bottomAnchor.constraint(equalTo: aiuto.bottomAnchor, constant: -12),
            rigaAiuto.leadingAnchor.constraint(equalTo: aiuto.leadingAnchor, constant: 14),
            rigaAiuto.trailingAnchor.constraint(equalTo: aiuto.trailingAnchor, constant: -14),
        ])
        let icona = riquadro
        let pila = UIStackView(arrangedSubviews: [icona, titolo, sotto, campo, errore, tasto, attesa, aiuto])
        pila.axis = .vertical
        pila.alignment = .fill
        pila.spacing = 12
        pila.setCustomSpacing(18, after: icona)
        pila.setCustomSpacing(6, after: titolo)
        pila.setCustomSpacing(24, after: sotto)
        pila.setCustomSpacing(16, after: tasto)
        pila.translatesAutoresizingMaskIntoConstraints = false
        // l'icona al centro: la pila interna deve essere VERTICALE, altrimenti l'icona (larga 64) riempie la riga
        // e stringe tutta la schermata a 72 punti (testo in colonna, campo minuscolo: build 22)
        let centro = UIStackView(arrangedSubviews: [icona])
        centro.axis = .vertical
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
            chiudi.tintColor = .white
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

    // si riscrive l'indirizzo: via l'errore e il bordo rosso
    @objc private func scritto() {
        errore.isHidden = true
        campo.layer.borderColor = bordoCampo.cgColor
    }

    @objc private func collega() {
        errore.isHidden = true
        campo.layer.borderColor = bordoCampo.cgColor
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
        campo.layer.borderColor = UIColor(red: 1, green: 0.61, blue: 0.61, alpha: 1).cgColor
        UIAccessibility.post(notification: .announcement, argument: t)
    }
}

private extension NSLayoutConstraint {
    func withPriority(_ p: UILayoutPriority) -> NSLayoutConstraint { priority = p; return self }
}
