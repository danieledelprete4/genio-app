import UIKit

// App Genio per iPhone e iPad: il sito Genio dell'azienda a tutto schermo (WebViewController).
// Nessun dato di Genio resta nell'app oltre ai cookie della sessione e all'indirizzo, come in un browser.
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let w = UIWindow(frame: UIScreen.main.bounds)
        w.rootViewController = WebViewController()
        w.backgroundColor = .white
        w.makeKeyAndVisible()
        window = w
        // sull'iPad del negozio lo schermo resta acceso, come sui tablet Android; sull'iPhone si spegne come sempre
        if UIDevice.current.userInterfaceIdiom == .pad { application.isIdleTimerDisabled = true }
        return true
    }
}
