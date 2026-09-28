"""Reclasse les anciens articles dans les nouvelles rubriques (à lancer à la main)."""
import json
import os
import sys

import requests
from google.auth.transport.requests import Request
from google.oauth2 import service_account

CORRESPONDANCE = {
    "Examens": "Annonces",
    "Clubs": "Vie scolaire",
    "Portrait": "Rencontre",
    "Interview": "Rencontre",
    "Sport et Culture": "Sport",
    "Culture": "Culture générale",
    "La Communauté": "Actu Kébémer",
}

brut = os.environ.get("FIREBASE_SA", "").strip()
if not brut:
    sys.exit("Secret FIREBASE_SA absent.")
sa = json.loads(brut)
projet = sa["project_id"]
cred = service_account.Credentials.from_service_account_info(
    sa, scopes=["https://www.googleapis.com/auth/datastore"]
)
cred.refresh(Request())
H = {"Authorization": "Bearer " + cred.token}
BASE = f"https://firestore.googleapis.com/v1/projects/{projet}/databases/(default)/documents"

total = 0
detail = {}
for collection in ("articles", "propositions"):
    jeton = None
    while True:
        params = {"pageSize": 300, "mask.fieldPaths": "categorie"}
        if jeton:
            params["pageToken"] = jeton
        r = requests.get(f"{BASE}/{collection}", headers=H, params=params, timeout=30)
        r.raise_for_status()
        data = r.json()
        for doc in data.get("documents", []):
            ancienne = doc.get("fields", {}).get("categorie", {}).get("stringValue", "")
            nouvelle = CORRESPONDANCE.get(ancienne)
            if not nouvelle:
                continue
            ident = doc["name"].split("/")[-1]
            p = requests.patch(
                f"{BASE}/{collection}/{ident}?updateMask.fieldPaths=categorie",
                headers=H,
                json={"fields": {"categorie": {"stringValue": nouvelle}}},
                timeout=30,
            )
            p.raise_for_status()
            total += 1
            cle = f"{ancienne} -> {nouvelle}"
            detail[cle] = detail.get(cle, 0) + 1
        jeton = data.get("nextPageToken")
        if not jeton:
            break

resume = f"{total} article(s) reclasse(s)"
if detail:
    resume += " : " + " ; ".join(f"{k} ({v})" for k, v in detail.items())
print(resume)
print("::notice title=Reclassement::" + resume)
