"""Prépare le projet Android avant la compilation.

Génère lib/firebase_options.dart depuis google-services.json, puis ajuste
Android : version minimale, signature permanente, nom, permissions,
icônes et réglages des notifications.
"""
import json
import pathlib
import re
import shutil
import sys

RACINE = pathlib.Path(".")
APP = RACINE / "app_build"
PACKAGE = "sn.lfakebemer.lfanews"
ALIAS = "lfanews"

fichier = RACINE / "google-services.json"
if not fichier.exists():
    sys.exit("ERREUR : google-services.json est introuvable à la racine du dépôt.")

g = json.loads(fichier.read_text(encoding="utf-8"))
projet = g["project_info"]
clients = [c for c in g["client"]
           if c["client_info"]["android_client_info"]["package_name"] == PACKAGE]
if not clients:
    sys.exit(f"ERREUR : aucune application {PACKAGE} dans google-services.json.")
c = clients[0]

(APP / "lib" / "firebase_options.dart").write_text(f"""import 'package:firebase_core/firebase_core.dart';

const firebaseOptions = FirebaseOptions(
  apiKey: '{c["api_key"][0]["current_key"]}',
  appId: '{c["client_info"]["mobilesdk_app_id"]}',
  messagingSenderId: '{projet["project_number"]}',
  projectId: '{projet["project_id"]}',
  storageBucket: '{projet.get("storage_bucket", "")}',
);
""", encoding="utf-8")

# --- Gradle : version minimale et signature ---
kts = APP / "android" / "app" / "build.gradle.kts"
if kts.exists():
    t = kts.read_text(encoding="utf-8")
    t = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 24", t)
    t = t.replace("    buildTypes {", f'''    signingConfigs {{
        create("release") {{
            storeFile = file("upload.jks")
            storePassword = System.getenv("KS_PASS")
            keyAlias = "{ALIAS}"
            keyPassword = System.getenv("KS_PASS")
        }}
    }}

    buildTypes {{''', 1)
    t = t.replace('signingConfig = signingConfigs.getByName("debug")',
                  'signingConfig = signingConfigs.getByName("release")')
    kts.write_text(t, encoding="utf-8")
    ok = 'signingConfigs.getByName("release")' in t
else:
    groovy = APP / "android" / "app" / "build.gradle"
    t = groovy.read_text(encoding="utf-8")
    t = re.sub(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 24", t)
    t = t.replace("    buildTypes {", f'''    signingConfigs {{
        release {{
            storeFile file("upload.jks")
            storePassword System.getenv("KS_PASS")
            keyAlias "{ALIAS}"
            keyPassword System.getenv("KS_PASS")
        }}
    }}

    buildTypes {{''', 1)
    t = t.replace("signingConfig signingConfigs.debug", "signingConfig signingConfigs.release")
    groovy.write_text(t, encoding="utf-8")
    ok = "signingConfigs.release" in t
if not ok:
    sys.exit("ERREUR : impossible de configurer la signature.")

# --- Manifeste : nom, permissions, notifications ---
man = APP / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
m = man.read_text(encoding="utf-8")
m = re.sub(r'android:label="[^"]*"', 'android:label="LFANEWS"', m, count=1)
perms = ""
for p in ("INTERNET", "POST_NOTIFICATIONS"):
    if f"android.permission.{p}" not in m:
        perms += f'    <uses-permission android:name="android.permission.{p}"/>\n'
m = m.replace("    <application", perms + "    <application", 1)
i = m.index("<application")
j = m.index(">", i) + 1
meta = '''
        <meta-data android:name="com.google.firebase.messaging.default_notification_icon"
            android:resource="@drawable/ic_notification" />
        <meta-data android:name="com.google.firebase.messaging.default_notification_color"
            android:resource="@color/lfa_vert" />'''
m = m[:j] + meta + m[j:]
man.write_text(m, encoding="utf-8")

# --- Icônes et couleur ---
res = APP / "android" / "app" / "src" / "main" / "res"
for dossier in (RACINE / "android_res").iterdir():
    cible = res / dossier.name
    cible.mkdir(parents=True, exist_ok=True)
    for f in dossier.iterdir():
        shutil.copy(f, cible / f.name)
(res / "values").mkdir(exist_ok=True)
(res / "values" / "lfa_couleurs.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
    '    <color name="lfa_vert">#0F6B3A</color>\n</resources>\n', encoding="utf-8")

print("Préparation terminée.")
