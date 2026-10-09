"""Prépare le projet web (site installable sur iPhone) avant la compilation."""
import json, os, pathlib, re, sys
from PIL import Image

RACINE = pathlib.Path(".")
APP = RACINE / "app_web"
cfg = json.loads(pathlib.Path("/tmp/webconfig.json").read_text())

(APP / "lib" / "firebase_options.dart").write_text(f"""import 'package:firebase_core/firebase_core.dart';

const firebaseOptions = FirebaseOptions(
  apiKey: '{cfg["apiKey"]}',
  appId: '{cfg["appId"]}',
  messagingSenderId: '{cfg.get("messagingSenderId", "")}',
  projectId: '{cfg["projectId"]}',
  authDomain: '{cfg.get("authDomain", cfg["projectId"] + ".firebaseapp.com")}',
  storageBucket: '{cfg.get("storageBucket", "")}',
);
""", encoding="utf-8")

web = APP / "web"
logo = Image.open(RACINE / "assets" / "logo.png").convert("RGBA")
def carre(taille, marge=0.0, fond=(15, 107, 58, 255)):
    im = Image.new("RGBA", (taille, taille), fond)
    z = int(taille * (1 - 2 * marge))
    l = logo.copy(); l.thumbnail((z, z))
    im.paste(l, ((taille - l.width) // 2, (taille - l.height) // 2), l)
    return im.convert("RGB")
(web / "icons").mkdir(exist_ok=True)
for n, t, m in [("Icon-192.png",192,0.12),("Icon-512.png",512,0.12),("Icon-maskable-192.png",192,0.22),("Icon-maskable-512.png",512,0.22)]:
    carre(t, m).save(web / "icons" / n)
carre(180, 0.12).save(web / "apple-touch-icon.png")
carre(32, 0.05).save(web / "favicon.png")

html = (web / "index.html").read_text(encoding="utf-8")
html = re.sub(r"<title>.*?</title>", "<title>LFA News</title>", html, flags=re.S)
html = re.sub(r'<meta name="apple-mobile-web-app-title"[^>]*>', "", html)
html = re.sub(r'<link rel="apple-touch-icon"[^>]*>', "", html)
html = re.sub(r'<meta name="viewport"[^>]*>', "", html)
tete = """<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <meta name="theme-color" content="#0F6B3A">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
  <meta name="apple-mobile-web-app-title" content="LFA News">
  <link rel="apple-touch-icon" href="apple-touch-icon.png">
  <script src="https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js"></script>
  <script>pdfjsLib.GlobalWorkerOptions.workerSrc = "https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js";</script>
"""
html = html.replace("</head>", tete + "</head>", 1)
html = html.replace("<body>", '<body style="background:#ffffff">', 1)
(web / "index.html").write_text(html, encoding="utf-8")

m = json.loads((web / "manifest.json").read_text(encoding="utf-8"))
m.update({"name": "LFA News", "short_name": "LFA News", "display": "standalone",
          "background_color": "#FFFFFF", "theme_color": "#0F6B3A", "lang": "fr",
          "description": "Le journal du Lycée Franco-Arabe de Kébémer",
          "start_url": ".", "orientation": "portrait-primary"})
m["icons"] = [
  {"src": "icons/Icon-192.png", "sizes": "192x192", "type": "image/png"},
  {"src": "icons/Icon-512.png", "sizes": "512x512", "type": "image/png"},
  {"src": "icons/Icon-maskable-192.png", "sizes": "192x192", "type": "image/png", "purpose": "maskable"},
  {"src": "icons/Icon-maskable-512.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable"}]
(web / "manifest.json").write_text(json.dumps(m, ensure_ascii=False, indent=2), encoding="utf-8")
print("web prêt")
