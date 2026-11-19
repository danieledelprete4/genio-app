package app.genio.tablet;

import java.net.URI;
import java.util.Locale;

// Indirizzo del Genio a cui è collegato il tablet: si tiene solo l'origine (https://nome.dominio), mai pagine o parametri.
// Arriva dal QR della scheda "App per tablet" (https://nome.dominio/tablet) o scritto a mano.
final class Indirizzo {
    private Indirizzo() {}

    // null = non valido. Solo https; http solo per le prove in rete locale.
    static String origine(String testo) {
        if (testo == null) return null;
        String s = testo.trim();
        if (s.isEmpty() || s.length() > 400) return null;
        if (!s.matches("(?i)^[a-z][a-z0-9+.-]*://.*")) s = "https://" + s;
        try {
            URI u = new URI(s);
            String sch = u.getScheme() == null ? "" : u.getScheme().toLowerCase(Locale.ROOT);
            String host = u.getHost();
            if (host == null || u.getUserInfo() != null) return null;
            host = host.toLowerCase(Locale.ROOT);
            boolean locale = host.equals("localhost") || host.matches("^(10|127|192\\.168|172\\.(1[6-9]|2\\d|3[01]))\\..*");
            if (!sch.equals("https") && !(sch.equals("http") && locale)) return null;
            if (!host.contains(".") && !locale) return null;
            if (!host.matches("^[a-z0-9.-]+$")) return null;
            int porta = u.getPort();
            return sch + "://" + host + (porta > 0 ? ":" + porta : "");
        } catch (Exception e) {
            return null;
        }
    }

    // stessa origine dell'indirizzo collegato
    static boolean stesso(String url, String base) {
        if (url == null || base == null) return false;
        String o = origine(url);
        return o != null && o.equals(base) && (url.startsWith(base + "/") || url.equals(base) || url.startsWith(base + "?") || url.startsWith(base + "#"));
    }
}
