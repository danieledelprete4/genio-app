// Ponte per le pagine dell'app (indirizzo, attesa, errore). Il sito vede solo che è aperto nell'app
// (window.genioDesktop), così non propone di scaricarla.
const { contextBridge, ipcRenderer } = require('electron');

if (location.protocol === 'file:') {
  contextBridge.exposeInMainWorld('genio', {
    get: () => ipcRenderer.invoke('genio:get'),
    save: (url) => ipcRenderer.invoke('genio:save', url),
    open: () => ipcRenderer.invoke('genio:open'),
    address: () => ipcRenderer.invoke('genio:address'),
    reopenBrowser: () => ipcRenderer.invoke('genio:reopenBrowser'),
    cancelLogin: () => ipcRenderer.invoke('genio:cancelLogin'),
  });
}
else contextBridge.exposeInMainWorld('genioDesktop', { app: true });
