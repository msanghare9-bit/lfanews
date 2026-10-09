"""Récupère (ou crée) l'application web Firebase et son site d'hébergement."""
import json, os, sys, time
import google.auth.transport.requests
from google.oauth2 import service_account
import requests

sa = json.loads(os.environ["FIREBASE_SA"])
projet = sa["project_id"]
cred = service_account.Credentials.from_service_account_info(
    sa, scopes=["https://www.googleapis.com/auth/cloud-platform"])
cred.refresh(google.auth.transport.requests.Request())
H = {"Authorization": "Bearer " + cred.token}
B = "https://firebase.googleapis.com/v1beta1"

def appel(m, url, **kw):
    r = requests.request(m, url, headers=H, timeout=60, **kw)
    print(m, url.split("googleapis.com")[1][:90], r.status_code, r.text[:300].replace("\n", " "))
    return r

r = appel("GET", f"{B}/projects/{projet}/webApps")
apps = r.json().get("apps", []) if r.ok else []
if not apps:
    appel("POST", f"{B}/projects/{projet}/webApps", json={"displayName": "LFANEWS web"})
    for _ in range(12):
        time.sleep(5)
        r = appel("GET", f"{B}/projects/{projet}/webApps")
        apps = r.json().get("apps", []) if r.ok else []
        if apps: break
if not apps:
    sys.exit("ERREUR : impossible de créer l'application web Firebase.")
app_id = apps[0]["appId"]
c = appel("GET", f"{B}/projects/{projet}/webApps/{app_id}/config")
if not c.ok:
    sys.exit("ERREUR : configuration web introuvable.")
cfg = c.json()
json.dump(cfg, open("/tmp/webconfig.json", "w"))
# site d'hébergement
appel("GET", f"https://firebasehosting.googleapis.com/v1beta1/projects/{projet}/sites")
appel("POST", f"https://firebasehosting.googleapis.com/v1beta1/projects/{projet}/sites?siteId={projet}", json={})
print("ok", app_id)
