const path = require("path");
const { app, BrowserWindow } = require("electron");

function createWindow() {
  const win = new BrowserWindow({
    width: 460,
    height: 980,          // <- taller
    minHeight: 800,       // <- optional
    resizable: true,      // <- optional (set false if you want fixed)
    title: "Noise Studio",
    useContentSize: true, // <- makes width/height apply to the web page area
    webPreferences: { contextIsolation: true },
});


  win.removeMenu();
  win.loadFile(path.join(__dirname, "index.html"));
}

app.whenReady().then(createWindow);

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});

app.on("activate", () => {
  if (BrowserWindow.getAllWindows().length === 0) createWindow();
});