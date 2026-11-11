package app.genio.tablet;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.MatrixCursor;
import android.net.Uri;
import android.os.ParcelFileDescriptor;
import android.provider.OpenableColumns;
import android.webkit.MimeTypeMap;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;

// Archivio dell'app: passa i file scaricati (PDF, Excel) e le foto scattate alle altre app, senza permessi sulla memoria.
// Contiene solo due cartelle nella cache dell'app: "file" (download da aprire) e "foto" (scatti per Genio).
// L'archivio non è esportato: un'app vede un file solo quando Genio glielo passa con il permesso su quel file.
public class Archivio extends ContentProvider {
    static final String AUTORITA = "app.genio.tablet.archivio";
    static final String FILE = "file", FOTO = "foto";

    static File cartella(Context c, String nome) {
        File d = new File(c.getCacheDir(), nome);
        if (!d.exists()) d.mkdirs();
        return d;
    }

    static Uri uri(String cartella, String nome) {
        return new Uri.Builder().scheme("content").authority(AUTORITA).appendPath(cartella).appendPath(nome).build();
    }

    // solo un livello: cartella/nome, senza ".." né sottocartelle
    private File file(Uri u) throws FileNotFoundException {
        if (u.getPathSegments().size() != 2) throw new FileNotFoundException();
        String dir = u.getPathSegments().get(0), nome = u.getPathSegments().get(1);
        if (!(FILE.equals(dir) || FOTO.equals(dir)) || nome.contains("/") || nome.startsWith(".")) throw new FileNotFoundException();
        try {
            File base = cartella(getContext(), dir).getCanonicalFile();
            File f = new File(base, nome).getCanonicalFile();
            if (!base.equals(f.getParentFile())) throw new FileNotFoundException();
            return f;
        } catch (IOException e) {
            throw new FileNotFoundException();
        }
    }

    @Override public boolean onCreate() { return true; }

    @Override
    public ParcelFileDescriptor openFile(Uri u, String mode) throws FileNotFoundException {
        File f = file(u);
        // la fotocamera scrive nella foto vuota preparata da Genio; tutto il resto è in sola lettura
        int m = FOTO.equals(u.getPathSegments().get(0)) && mode.contains("w")
                ? ParcelFileDescriptor.MODE_READ_WRITE | ParcelFileDescriptor.MODE_CREATE | ParcelFileDescriptor.MODE_TRUNCATE
                : ParcelFileDescriptor.MODE_READ_ONLY;
        return ParcelFileDescriptor.open(f, m);
    }

    @Override
    public Cursor query(Uri u, String[] proj, String sel, String[] args, String sort) {
        File f;
        try { f = file(u); } catch (FileNotFoundException e) { return null; }
        String[] col = proj != null ? proj : new String[]{OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE};
        MatrixCursor c = new MatrixCursor(col, 1);
        Object[] riga = new Object[col.length];
        for (int i = 0; i < col.length; i++) {
            if (OpenableColumns.DISPLAY_NAME.equals(col[i])) riga[i] = f.getName();
            else if (OpenableColumns.SIZE.equals(col[i])) riga[i] = f.length();
        }
        c.addRow(riga);
        return c;
    }

    @Override
    public String getType(Uri u) {
        String n = String.valueOf(u.getLastPathSegment());
        int p = n.lastIndexOf('.');
        String t = p < 0 ? null : MimeTypeMap.getSingleton().getMimeTypeFromExtension(n.substring(p + 1).toLowerCase(java.util.Locale.ROOT));
        return t != null ? t : "application/octet-stream";
    }

    @Override public Uri insert(Uri u, ContentValues v) { return null; }
    @Override public int delete(Uri u, String s, String[] a) { return 0; }
    @Override public int update(Uri u, ContentValues v, String s, String[] a) { return 0; }
}
