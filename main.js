// App per Windows e Mac: una finestra che apre il sito (su Vercel) come un'app installata.
// Il nome (Genio, GeniusFix...) viene da productName: crea-installer.sh lo sceglie al momento della creazione.
// Al primo avvio chiede l'indirizzo del sito e lo ricorda; si cambia dal menu "Cambia indirizzo".
// L'accesso aziendale (Google o Microsoft) si fa nel browser del computer e torna qui con il link genio://:
// Google non lo accetta dentro le app, e Microsoft nel browser usa Windows Hello, passkey e l'account già aperto.
const { app, BrowserWindow, Menu, shell, ipcMain, net } = require('electron');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');

const NAME = app.getName();
// link che riporta all'app dopo l'accesso nel browser: genio://, geniusfix://...
const PROTOCOL = NAME.toLowerCase().replace(/[^a-z0-9]/g, '') || 'genio';
const PAGES = path.join(__dirname, 'pagine');
const isMac = process.platform === 'darwin';

// Senza "Electron" nel nome del browser i siti trattano la finestra come Chrome.
const platformUA = isMac ? 'Macintosh; Intel Mac OS X 10_15_7' : 'Windows NT 10.0; Win64; x64';
app.userAgentFallback = `Mozilla/5.0 (${platformUA}) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/${process.versions.chrome} Safari/537.36`;

// ---------- impostazioni (indirizzo e dimensioni della finestra) ----------
const configFile = () => path.join(app.getPath('userData'), 'impostazioni.json');
function readConfig() {
  try { return JSON.parse(fs.readFileSync(configFile(), 'utf8')) || {}; } catch { return {}; }
}
function writeConfig(patch) {
  const next = { ...readConfig(), ...patch };
  try { fs.mkdirSync(path.dirname(configFile()), { recursive: true }); fs.writeFileSync(configFile(), JSON.stringify(next, null, 2)); } catch {}
  return next;
}
// Accetta "genio.vercel.app", "https://genio.vercel.app/login"... e tiene solo https://host (http solo in locale).
function normalizeUrl(input) {
  let s = String(input || '').trim();
  if (!s) return null;
  if (!/^[a-z]+:\/\//i.test(s)) s = `https://${s}`;
  try {
    const u = new URL(s);
    const local = ['localhost', '127.0.0.1'].includes(u.hostname);
    if (u.protocol !== 'https:' && !(local && u.protocol === 'http:')) return null;
    if (!u.hostname.includes('.') && !local) return null;
    return u.origin;
  } catch { return null; }
}
const baseUrl = () => normalizeUrl(readConfig().url);
const sameSite = (url) => { try { return new URL(url).origin === baseUrl(); } catch { return false; } };
const isLocalPage = (url) => String(url).startsWith('file:');
// pagine di accesso di Google e Microsoft: restano nella finestra solo sui siti senza ritorno all'app
const LOGIN_HOSTS = {
  google: ['google.com', 'gstatic.com', 'googleusercontent.com'],
  microsoft: ['microsoftonline.com', 'microsoft.com', 'live.com', 'msauth.net', 'msftauth.net', 'msauthimages.net', 'microsoftonline-p.com', 'windows.net'],
};
const loginHost = (prov, url) => { try { const h = new URL(url).hostname; return (LOGIN_HOSTS[prov] || []).some((d) => h === d || h.endsWith(`.${d}`)); } catch { return false; } };
// tasti "Accedi con Google" e "Accedi con Microsoft" del sito
const LOGIN_PATHS = { '/api/auth/google': 'google', '/api/auth/microsoft': 'microsoft' };

// ---------- finestra ----------
let win = null;
let pendingLogin = null; // { verifier, base, at, link, prov } mentre l'accesso è aperto nel browser
let inAppLogin = null; // sito senza ritorno all'app (es. demo): 'google' o 'microsoft', l'accesso resta nella finestra

function page(name, query = {}) {
  win.loadFile(path.join(PAGES, name), { query });
}
function openSite(target) {
  const base = baseUrl();
  if (!base) return page('indirizzo.html', { primo: '1' });
  win.loadURL(target || `${base}/`);
}

function createWindow() {
  const b = readConfig().bounds || {};
  win = new BrowserWindow({
    width: b.width || 1280, height: b.height || 840, x: b.x, y: b.y,
    minWidth: 380, minHeight: 500, title: NAME, backgroundColor: '#ffffff', show: false,
    autoHideMenuBar: !isMac,
    icon: path.join(__dirname, 'build', 'icon.png'),
    webPreferences: { preload: path.join(__dirname, 'preload.js'), contextIsolation: true, sandbox: true, nodeIntegration: false, spellcheck: true },
  });
  if (b.max) win.maximize();
  win.once('ready-to-show', () => win.show());
  const saveBounds = () => { if (!win.isMinimized() && !win.isFullScreen()) writeConfig({ bounds: { ...(win.isMaximized() ? readConfig().bounds : win.getBounds()), max: win.isMaximized() } }); };
  win.on('close', saveBounds);

  const wc = win.webContents;
  // link e navigazioni: il sito resta nella finestra, il resto si apre nel browser
  wc.on('will-navigate', (e, url) => {
    if (isLocalPage(url) || (inAppLogin && loginHost(inAppLogin, url))) return;
    if (sameSite(url)) {
      const prov = LOGIN_PATHS[new URL(url).pathname];
      if (prov) { e.preventDefault(); startLogin(prov); }
      return;
    }
    e.preventDefault();
    if (/^https?:|^mailto:|^tel:/i.test(url)) shell.openExternal(url);
  });
  wc.setWindowOpenHandler(({ url }) => {
    if (sameSite(url) || url.startsWith('blob:') || url === 'about:blank') {
      return { action: 'allow', overrideBrowserWindowOptions: { autoHideMenuBar: true, icon: path.join(__dirname, 'build', 'icon.png'), webPreferences: { contextIsolation: true, sandbox: true } } };
    }
    if (/^https?:|^mailto:|^tel:/i.test(url)) shell.openExternal(url);
    return { action: 'deny' };
  });
  // sito irraggiungibile (niente rete o indirizzo sbagliato): pagina con Riprova e Cambia indirizzo
  wc.on('did-fail-load', (_e, code, desc, url, isMain) => {
    if (!isMain || code === -3 || isLocalPage(url)) return; // -3 = navigazione annullata
    page('errore.html', { url, desc });
  });
  wc.on('page-title-updated', (e) => { e.preventDefault(); });
  wc.on('context-menu', (_e, p) => contextMenu(p));

  openSite();
}

function contextMenu(p) {
  const items = [];
  if (p.linkURL && /^https?:/.test(p.linkURL)) items.push({ label: 'Copia link', click: () => require('electron').clipboard.writeText(p.linkURL) }, { type: 'separator' });
  if (p.isEditable) items.push({ role: 'cut', label: 'Taglia', enabled: p.editFlags.canCut }, { role: 'copy', label: 'Copia', enabled: p.editFlags.canCopy }, { role: 'paste', label: 'Incolla', enabled: p.editFlags.canPaste }, { type: 'separator' }, { role: 'selectAll', label: 'Seleziona tutto' });
  else if (p.selectionText) items.push({ role: 'copy', label: 'Copia' });
  if (p.misspelledWord && p.dictionarySuggestions.length) items.unshift(...p.dictionarySuggestions.slice(0, 4).map((s) => ({ label: s, click: () => win.webContents.replaceMisspelling(s) })), { type: 'separator' });
  if (items.length) Menu.buildFromTemplate(items).popup({ window: win });
}

// ---------- accesso Google o Microsoft ----------
async function startLogin(prov) {
  const base = baseUrl();
  if (!base) return;
  // il sito sa riportare l'accesso all'app? (Genio sì; le altre versioni lasciano l'accesso nella finestra)
  let handoff = false;
  try {
    const r = await net.fetch(`${base}/api/auth/desktop`, { cache: 'no-store' });
    handoff = r.ok && !!(await r.json().catch(() => ({}))).desktop;
  } catch {}
  if (!handoff) {
    inAppLogin = prov;
    return win.loadURL(`${base}/api/auth/${prov}`);
  }
  const verifier = crypto.randomBytes(32).toString('base64url');
  const challenge = crypto.createHash('sha256').update(verifier).digest('base64url');
  // p = tasto scelto: i siti Genio meno recenti lo ignorano e usano l'accesso attivo
  pendingLogin = { verifier, base, prov, at: Date.now(), link: `${base}/api/auth/desktop/start?c=${challenge}&p=${prov}` };
  shell.openExternal(pendingLogin.link);
  page('attesa.html', { p: prov });
}

// genio://auth?code=... arriva dal browser alla fine dell'accesso
function handleDeepLink(link) {
  let u;
  try { u = new URL(link); } catch { return; }
  if (u.protocol !== `${PROTOCOL}:` || u.hostname !== 'auth') return;
  const code = u.searchParams.get('code');
  if (!win) return;
  if (win.isMinimized()) win.restore();
  win.show(); win.focus();
  if (isMac) app.focus({ steal: true });
  const p = pendingLogin;
  if (!code || !p || Date.now() - p.at > 10 * 60 * 1000 || p.base !== baseUrl()) {
    pendingLogin = null;
    return win.loadURL(`${baseUrl() || ''}/login?err=stato`);
  }
  pendingLogin = null;
  win.loadURL(`${p.base}/api/auth/desktop?code=${encodeURIComponent(code)}&v=${encodeURIComponent(p.verifier)}`);
}

// ---------- pagine locali (indirizzo, attesa, errore) ----------
ipcMain.handle('genio:get', () => ({ url: baseUrl() || '', version: app.getVersion(), name: NAME }));
ipcMain.handle('genio:save', async (_e, input) => {
  const base = normalizeUrl(input);
  if (!base) return { error: 'Scrivi un indirizzo valido, ad esempio https://nome.vercel.app' };
  try {
    await net.fetch(`${base}/login`, { method: 'GET', cache: 'no-store' });
  } catch {
    return { error: 'Indirizzo non raggiungibile: controlla che sia scritto bene e che ci sia la connessione.' };
  }
  writeConfig({ url: base });
  inAppLogin = null;
  openSite();
  return { ok: true };
});
ipcMain.handle('genio:open', () => { inAppLogin = null; openSite(); });
ipcMain.handle('genio:address', () => page('indirizzo.html'));
ipcMain.handle('genio:reopenBrowser', () => { if (pendingLogin) shell.openExternal(pendingLogin.link); });
ipcMain.handle('genio:cancelLogin', () => { pendingLogin = null; openSite(`${baseUrl()}/login`); });

// ---------- menu ----------
function buildMenu() {
  const change = { label: 'Cambia indirizzo…', accelerator: 'CmdOrCtrl+Shift+L', click: () => win && page('indirizzo.html') };
  const home = { label: 'Pagina iniziale', accelerator: 'CmdOrCtrl+Shift+H', click: () => win && openSite() };
  const template = [
    ...(isMac ? [{ label: NAME, submenu: [{ role: 'about', label: `Informazioni su ${NAME}` }, { type: 'separator' }, change, { type: 'separator' }, { role: 'hide', label: `Nascondi ${NAME}` }, { role: 'hideOthers', label: 'Nascondi altre' }, { role: 'unhide', label: 'Mostra tutte' }, { type: 'separator' }, { role: 'quit', label: `Esci da ${NAME}` }] }]
      : [{ label: 'File', submenu: [home, change, { type: 'separator' }, { role: 'quit', label: 'Esci' }] }]),
    { label: 'Modifica', submenu: [{ role: 'undo', label: 'Annulla' }, { role: 'redo', label: 'Ripeti' }, { type: 'separator' }, { role: 'cut', label: 'Taglia' }, { role: 'copy', label: 'Copia' }, { role: 'paste', label: 'Incolla' }, { role: 'selectAll', label: 'Seleziona tutto' }] },
    { label: 'Vista', submenu: [...(isMac ? [home] : []), { role: 'reload', label: 'Ricarica' }, { label: 'Indietro', accelerator: isMac ? 'Cmd+[' : 'Alt+Left', click: () => win?.webContents.navigationHistory.canGoBack() && win.webContents.navigationHistory.goBack() }, { label: 'Avanti', accelerator: isMac ? 'Cmd+]' : 'Alt+Right', click: () => win?.webContents.navigationHistory.canGoForward() && win.webContents.navigationHistory.goForward() }, { type: 'separator' }, { role: 'resetZoom', label: 'Dimensione reale' }, { role: 'zoomIn', label: 'Ingrandisci' }, { role: 'zoomOut', label: 'Riduci' }, { type: 'separator' }, { role: 'togglefullscreen', label: 'Schermo intero' }] },
    ...(isMac ? [{ label: 'Finestra', submenu: [{ role: 'minimize', label: 'Contrai' }, { role: 'zoom', label: 'Ridimensiona' }, { type: 'separator' }, { role: 'front', label: 'Porta tutto in primo piano' }] }] : []),
  ];
  Menu.setApplicationMenu(Menu.buildFromTemplate(template));
}

// ---------- avvio ----------
// il link genio:// apre (o riporta in primo piano) questa app
if (process.defaultApp) app.setAsDefaultProtocolClient(PROTOCOL, process.execPath, [path.resolve(process.argv[1] || '.')]);
else app.setAsDefaultProtocolClient(PROTOCOL);

if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.on('second-instance', (_e, argv) => {
    const link = argv.find((a) => a.startsWith(`${PROTOCOL}://`));
    if (link) handleDeepLink(link);
    else if (win) { if (win.isMinimized()) win.restore(); win.focus(); }
  });
  app.on('open-url', (e, link) => { e.preventDefault(); if (app.isReady() && win) handleDeepLink(link); });
  app.whenReady().then(() => {
    app.setAboutPanelOptions?.({ applicationName: NAME, applicationVersion: app.getVersion() });
    // permessi (notifiche, appunti, fotocamera...) solo al sito scelto
    const { session } = require('electron');
    session.defaultSession.setPermissionRequestHandler((wc, _perm, cb) => cb(sameSite(wc.getURL())));
    buildMenu();
    createWindow();
    app.on('activate', () => { if (!BrowserWindow.getAllWindows().length) createWindow(); });
  });
  app.on('window-all-closed', () => { if (!isMac) app.quit(); });
}
