package app.genio.tablet;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

// L'indirizzo letto dal QR o scritto a mano: si tiene solo l'origine, e solo https.
public class IndirizzoTest {
    @Test public void dalQrDellaSchedaRestaSoloLOrigine() {
        assertEquals("https://genio.example.it", Indirizzo.origine("https://genio.example.it/tablet"));
        assertEquals("https://genio.example.it", Indirizzo.origine("  HTTPS://Genio.Example.IT/tablet?stampa=1  "));
        assertEquals("https://nome.vercel.app", Indirizzo.origine("nome.vercel.app"));
        assertEquals("https://x.it:8443", Indirizzo.origine("https://x.it:8443/"));
    }

    @Test public void indirizziNonValidiRifiutati() {
        assertNull(Indirizzo.origine(""));
        assertNull(Indirizzo.origine("http://genio.example.it"));
        assertNull(Indirizzo.origine("javascript:alert(1)"));
        assertNull(Indirizzo.origine("https://utente:pw@genio.example.it"));
        assertNull(Indirizzo.origine("https://senzapunto"));
        assertNull(Indirizzo.origine("file:///etc/hosts"));
        assertNull(Indirizzo.origine(null));
    }

    @Test public void httpSoloInReteLocale() {
        assertEquals("http://192.168.1.10:3000", Indirizzo.origine("http://192.168.1.10:3000"));
        assertEquals("http://localhost:3000", Indirizzo.origine("http://localhost:3000/login"));
    }

    @Test public void stessoSitoSoloConLaStessaOrigine() {
        String b = "https://genio.example.it";
        assertTrue(Indirizzo.stesso("https://genio.example.it/api/auth/microsoft", b));
        assertTrue(Indirizzo.stesso("https://genio.example.it", b));
        assertFalse(Indirizzo.stesso("https://genio.example.it.altro.com/", b));
        assertFalse(Indirizzo.stesso("https://altro.it/?u=https://genio.example.it/", b));
        assertFalse(Indirizzo.stesso("http://genio.example.it/", b));
        assertFalse(Indirizzo.stesso("https://genio.example.it/", null));
    }
}
