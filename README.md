# Genio per Windows e Mac

L'app apre il sito Genio dell'azienda in una finestra propria, con l'icona sul desktop, come un programma installato.
Qui ci sono solo l'app per computer e i file da scaricare: il codice di Genio non è in questo repository.

## Scaricare

Dall'ultima versione in [Releases](../../releases/latest):

- **Windows 10 e 11**: `Genio-Windows-Setup.exe` (oppure `Genio-Windows.zip` se il browser blocca l'exe)
- **Mac con chip Apple** (M1, M2, M3, M4 e successivi): `Genio-Mac-AppleSilicon.zip`
- **Mac con processore Intel**: `Genio-Mac-Intel.zip`

Link fissi, sempre all'ultima versione (sono quelli da incollare in Genio, Utenti e accessi > App per computer):

- `https://github.com/danieledelprete4/genio-app/releases/latest/download/Genio-Windows-Setup.exe`
- `https://github.com/danieledelprete4/genio-app/releases/latest/download/Genio-Mac-AppleSilicon.zip`
- `https://github.com/danieledelprete4/genio-app/releases/latest/download/Genio-Mac-Intel.zip`

## Installare su Windows

1. Apri `Genio-Windows-Setup.exe`.
2. Se compare "Windows ha protetto il PC", clicca **Ulteriori informazioni** e poi **Esegui comunque** (l'app non è firmata).
3. Segui l'installazione: alla fine trovi Genio sul desktop e nel menu Start.

## Installare su Mac

1. Apri lo zip giusto per il tuo Mac (Menu Apple > Informazioni su questo Mac: "Chip Apple" oppure "Processore Intel").
2. Trascina **Genio** nella cartella **Applicazioni**.
3. Apri Genio: il Mac avvisa che non può verificare lo sviluppatore. Chiudi l'avviso.
4. Vai in **Impostazioni di Sistema > Privacy e sicurezza**, scorri in basso e clicca **Apri comunque** accanto a Genio, poi conferma. Serve solo la prima volta.

## Primo avvio e accesso

Al primo avvio scrivi l'indirizzo del sito Genio dell'azienda e clicca **Apri**: l'app lo ricorda.
Si cambia dal menu con **Cambia indirizzo** (Ctrl+Maiusc+L su Windows, Cmd+Maiusc+L su Mac).

Con **Accedi con Microsoft** o **Accedi con Google** si apre il browser del computer: scegli il tuo account aziendale,
poi il browser chiede di aprire Genio. Scegli **Apri** e Genio torna in primo piano, già dentro.

## Nuova versione

Si cambia `version` in `package.json` e si crea il tag con lo stesso numero (es. `v1.0.2`):
l'automazione in `.github/workflows/app.yml` crea i file su Windows e Mac e li pubblica nella Release.

---

Software proprietario, tutti i diritti riservati. Vedi la licenza di Genio.
